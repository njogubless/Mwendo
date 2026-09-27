"""Business operations for a user's day. Views call these; they own transactions and invariants."""

import datetime as dt
from decimal import Decimal

from django.db import transaction
from django.db.models import Prefetch
from django.utils import timezone

from apps.core.clock import at_local, user_today
from apps.core.exceptions import DomainError
from apps.routines.models import Routine, RoutineActivity

from .domain.adaptation import PlanItem, plan_minimum_day, plan_time_budget
from .domain.progress import completion_ratio
from .models import ActivityCompletion, Adjustment, DailyPlan, Reflection, RoutineInstance

S = ActivityCompletion.Status
ADAPTABLE = (S.PENDING, S.CANCELLED)
MAX_ACTUAL = Decimal(100000)


# ---------------------------------------------------------------- materialisation


def _active_activities():
    return Prefetch(
        "activities",
        queryset=RoutineActivity.objects.filter(archived_at__isnull=True).order_by("position", "created_at"),
    )


def _snapshot(activity: RoutineActivity) -> dict:
    return {
        "position": activity.position,
        "title": activity.title,
        "description": activity.description,
        "icon": activity.icon,
        "target_kind": activity.target_kind,
        "unit": activity.unit,
        "is_essential": activity.is_essential,
        "priority": activity.priority,
        "target_value": activity.target_value,
        "minimum_value": activity.minimum_value,
        "planned_value": activity.target_value,
    }


def _create_instance(plan: DailyPlan, routine: Routine, *, ad_hoc=False, now=None) -> RoutineInstance | None:
    activities = list(routine.activities.all())
    if not activities:
        return None
    user = plan.user
    start = timezone.now() if ad_hoc else at_local(user, plan.local_date, routine.start_time)
    finish_by = None if ad_hoc else at_local(user, plan.local_date, routine.finish_by)
    if finish_by and start and finish_by <= start:
        finish_by += dt.timedelta(days=1)
    instance = RoutineInstance.objects.create(
        user=user,
        daily_plan=plan,
        routine=routine,
        routine_name=routine.name,
        category=routine.category,
        local_date=plan.local_date,
        scheduled_start=start,
        finish_by=finish_by,
        is_ad_hoc=ad_hoc,
    )
    ActivityCompletion.objects.bulk_create(
        ActivityCompletion(user=user, routine_instance=instance, activity=a, **_snapshot(a))
        for a in activities
    )
    reschedule(instance, start)
    return instance


def reschedule(instance: RoutineInstance, start: dt.datetime | None) -> None:
    """Lay open steps back-to-back from `start` by planned duration. Finished steps keep their times."""
    if start is None:
        return
    cursor = start
    items = list(instance.completions.order_by("position", "created_at"))
    for item in items:
        if item.status in (S.PENDING, S.CANCELLED):
            item.scheduled_at = cursor
        if item.status in (S.PENDING, S.IN_PROGRESS) and item.target_kind == "duration":
            cursor += dt.timedelta(minutes=float(item.planned_value))
    ActivityCompletion.objects.bulk_update(items, ["scheduled_at"])


@transaction.atomic
def ensure_day(user, day: dt.date, now: dt.datetime | None = None) -> DailyPlan:
    """Idempotently materialise `day` (only today is ever created; other days are read as they are)."""
    today = user_today(user, now)
    if day != today:
        plan = DailyPlan.objects.filter(user=user, local_date=day).first()
        return plan or DailyPlan(user=user, local_date=day)

    plan, _ = DailyPlan.objects.get_or_create(user=user, local_date=day)
    plan = DailyPlan.objects.select_for_update().get(pk=plan.pk)
    existing = set(plan.instances.filter(is_ad_hoc=False).values_list("routine_id", flat=True))
    routines = (
        Routine.objects.filter(
            user=user, status=Routine.Status.ACTIVE, days_of_week__contains=[day.isoweekday()]
        )
        .exclude(id__in=existing)
        .prefetch_related(_active_activities())
    )
    created = [i for r in routines if (i := _create_instance(plan, r)) is not None]
    if created and plan.mode != DailyPlan.Mode.NORMAL:
        _apply_day_mode_to(plan, created)
    return plan


@transaction.atomic
def start_routine_now(routine: Routine) -> RoutineInstance:
    """ "Start now": reuse today's run if it still has open steps, otherwise add an ad-hoc run."""
    plan = ensure_day(routine.user, user_today(routine.user))
    open_run = (
        plan.instances.filter(routine=routine, completions__status__in=(S.PENDING, S.IN_PROGRESS))
        .order_by("created_at")
        .first()
    )
    if open_run:
        return open_run
    routine = Routine.objects.prefetch_related(_active_activities()).get(pk=routine.pk)
    instance = _create_instance(plan, routine, ad_hoc=True)
    if instance is None:
        raise DomainError(
            "Add a step to this routine before starting it.", code="routine_empty", status_code=400
        )
    return instance


@transaction.atomic
def sync_today(routine: Routine) -> None:
    """After a template edit, bring today's *untouched* steps in line. Started/finished steps never change."""
    user = routine.user
    today = user_today(user)
    plan = DailyPlan.objects.select_for_update().filter(user=user, local_date=today).first()
    if plan is None:
        return  # Today not materialised yet; it will pick up the new template.

    scheduled = routine.is_scheduled_on(today.isoweekday())
    instance = plan.instances.filter(routine=routine, is_ad_hoc=False).first()
    routine = Routine.objects.prefetch_related(_active_activities()).get(pk=routine.pk)

    if instance is None:
        if scheduled and (created := _create_instance(plan, routine)) and plan.mode != DailyPlan.Mode.NORMAL:
            _apply_day_mode_to(plan, [created])
        return

    untouched = instance.completions.filter(status__in=ADAPTABLE, started_at__isnull=True)
    if not scheduled:
        untouched.delete()
        if not instance.completions.exists():
            instance.delete()
        return

    active = {a.id: a for a in routine.activities.all()}
    rows = {c.activity_id: c for c in instance.completions.all()}
    for row in untouched:
        if row.activity_id not in active:
            row.delete()
        else:
            for field, value in _snapshot(active[row.activity_id]).items():
                setattr(row, field, value)
            row.status = S.PENDING
            row.save()
    ActivityCompletion.objects.bulk_create(
        ActivityCompletion(user=user, routine_instance=instance, activity=a, **_snapshot(a))
        for a_id, a in active.items()
        if a_id not in rows
    )
    instance.routine_name = routine.name
    instance.category = routine.category
    instance.save(update_fields=["routine_name", "category", "updated_at"])
    Adjustment.objects.filter(routine_instance=instance, reverted_at__isnull=True).update(
        reverted_at=timezone.now()
    )
    if plan.mode != DailyPlan.Mode.NORMAL:
        _apply_day_mode_to(plan, [instance])
    reschedule(instance, max(filter(None, [instance.scheduled_start, timezone.now()])))


# ---------------------------------------------------------------- step transitions


def _locked(user, completion_id) -> ActivityCompletion:
    try:
        return ActivityCompletion.objects.select_for_update().get(pk=completion_id, user=user)
    except ActivityCompletion.DoesNotExist as exc:
        from django.http import Http404

        raise Http404 from exc


def _require_today(user, completion: ActivityCompletion, now=None):
    if completion.routine_instance.local_date != user_today(user, now):
        raise DomainError("Only today's steps can be changed.", code="not_today")


def _stop_clock(c: ActivityCompletion, now: dt.datetime) -> None:
    if c.running_since:
        c.active_seconds += max(0, int((now - c.running_since).total_seconds()))
        c.running_since = None


@transaction.atomic
def start(user, completion_id, now=None) -> ActivityCompletion:
    now = now or timezone.now()
    c = _locked(user, completion_id)
    _require_today(user, c, now)
    if c.status in (S.COMPLETED, S.PARTIAL, S.SKIPPED):
        raise DomainError(
            "This step is already wrapped up. Undo it first to start again.", code="already_done"
        )
    if c.status == S.IN_PROGRESS and c.running_since:
        return c
    # Only one step runs at a time: pause any other running step.
    for other in (
        ActivityCompletion.objects.select_for_update()
        .filter(user=user, status=S.IN_PROGRESS, running_since__isnull=False)
        .exclude(pk=c.pk)
    ):
        _stop_clock(other, now)
        other.save(update_fields=["active_seconds", "running_since", "updated_at"])
    c.status = S.IN_PROGRESS
    c.started_at = c.started_at or now
    c.running_since = now
    c.save()
    return c


@transaction.atomic
def pause(user, completion_id, now=None) -> ActivityCompletion:
    now = now or timezone.now()
    c = _locked(user, completion_id)
    _require_today(user, c, now)
    if c.status != S.IN_PROGRESS:
        raise DomainError("Only a step in progress can be paused.", code="not_in_progress")
    _stop_clock(c, now)
    c.save()
    return c


@transaction.atomic
def complete(user, completion_id, actual_value: Decimal | None = None, now=None) -> ActivityCompletion:
    """Full completion when `actual_value` is omitted; partial when it is below the planned value."""
    now = now or timezone.now()
    c = _locked(user, completion_id)
    _require_today(user, c, now)
    if c.target_kind == "check":
        actual_value = Decimal(1)
    if actual_value is None:
        actual_value = c.planned_value
    if actual_value <= 0 or actual_value > MAX_ACTUAL:
        raise DomainError(
            "Log an amount above zero, or skip the step instead.", code="invalid_amount", status_code=400
        )
    _stop_clock(c, now)
    c.actual_value = actual_value
    c.completion_ratio = completion_ratio(actual_value, c.planned_value)
    c.status = S.COMPLETED if actual_value >= c.planned_value else S.PARTIAL
    c.skip_reason = ""
    c.started_at = c.started_at or now
    c.completed_at = now
    c.save()
    return c


@transaction.atomic
def skip(user, completion_id, reason: str = "", now=None) -> ActivityCompletion:
    now = now or timezone.now()
    c = _locked(user, completion_id)
    _require_today(user, c, now)
    _stop_clock(c, now)
    c.status = S.SKIPPED
    c.skip_reason = reason
    c.actual_value = None
    c.completion_ratio = 0
    c.completed_at = now
    c.save()
    return c


@transaction.atomic
def reset(user, completion_id, now=None) -> ActivityCompletion:
    """Undo: back to pending, as if nothing happened."""
    c = _locked(user, completion_id)
    _require_today(user, c, now)
    c.status = S.PENDING
    c.actual_value = None
    c.completion_ratio = 0
    c.skip_reason = ""
    c.started_at = c.running_since = c.completed_at = None
    c.active_seconds = 0
    c.save()
    return c


@transaction.atomic
def add_reflection(user, *, completion_id=None, day=None, note="", mood=None) -> Reflection:
    completion = plan = None
    if completion_id:
        completion = _locked(user, completion_id)
    if day:
        plan = ensure_day(user, day)
        if plan._state.adding:
            raise DomainError("There's nothing recorded for that day yet.", code="no_day", status_code=400)
    return Reflection.objects.create(user=user, completion=completion, daily_plan=plan, note=note, mood=mood)


# ---------------------------------------------------------------- adaptation


def _plan_items(completions) -> list[PlanItem]:
    return [
        PlanItem(
            id=c.id,
            target_kind=c.target_kind,
            target_value=c.target_value,
            minimum_value=c.minimum_value,
            is_essential=c.is_essential,
            priority=c.priority,
            position=c.position,
        )
        for c in completions
    ]


def _state(c: ActivityCompletion) -> dict:
    return {
        "planned_value": str(c.planned_value),
        "status": c.status,
        "scheduled_at": c.scheduled_at.isoformat() if c.scheduled_at else None,
    }


def _apply_outcomes(completions, plan) -> list[dict]:
    by_id = {c.id: c for c in completions}
    changes = []
    for outcome in plan.items:
        c = by_id[outcome.id]
        before = _state(c)
        c.planned_value = outcome.planned_value
        c.status = outcome.status
        c.save(update_fields=["planned_value", "status", "updated_at"])
        changes.append({"completion": str(c.id), "before": before, "after": _state(c)})
    return changes


def _revert(adjustment: Adjustment, now=None) -> None:
    if adjustment.reverted_at:
        return
    ids = [ch["completion"] for ch in adjustment.changes]
    rows = {str(c.id): c for c in ActivityCompletion.objects.select_for_update().filter(id__in=ids)}
    for ch in adjustment.changes:
        c = rows.get(ch["completion"])
        if c is None or c.status not in ADAPTABLE or c.started_at:
            continue  # The user already acted on it; their action stands.
        before = ch["before"]
        c.planned_value = Decimal(before["planned_value"])
        c.status = before["status"]
        c.scheduled_at = dt.datetime.fromisoformat(before["scheduled_at"]) if before["scheduled_at"] else None
        c.save(update_fields=["planned_value", "status", "scheduled_at", "updated_at"])
    adjustment.reverted_at = now or timezone.now()
    adjustment.save(update_fields=["reverted_at", "updated_at"])


_MODE_KIND = {
    DailyPlan.Mode.MINIMUM: Adjustment.Kind.MINIMUM_DAY,
    DailyPlan.Mode.RECOVERY: Adjustment.Kind.RECOVERY,
}


def _apply_day_mode_to(plan: DailyPlan, instances) -> Adjustment:
    adjustment = plan.adjustments.filter(
        routine_instance__isnull=True, reverted_at__isnull=True
    ).first() or Adjustment(
        user=plan.user, daily_plan=plan, kind=_MODE_KIND[plan.mode], params={"mode": plan.mode}
    )
    for instance in instances:
        completions = list(
            instance.completions.select_for_update().filter(status__in=ADAPTABLE, started_at__isnull=True)
        )
        adjustment.changes = [
            *adjustment.changes,
            *_apply_outcomes(completions, plan_minimum_day(_plan_items(completions))),
        ]
        reschedule(instance, instance.scheduled_start)
    adjustment.save()
    return adjustment


@transaction.atomic
def set_day_mode(user, day: dt.date, mode: str, now=None) -> DailyPlan:
    if day != user_today(user, now):
        raise DomainError("Only today's plan can be changed.", code="not_today")
    plan = ensure_day(user, day, now)
    plan = DailyPlan.objects.select_for_update().get(pk=plan.pk)
    if plan.mode == mode:
        return plan
    for adjustment in plan.adjustments.filter(reverted_at__isnull=True).order_by("-created_at"):
        _revert(adjustment, now)
    plan.mode = mode
    plan.save(update_fields=["mode", "updated_at"])
    if mode != DailyPlan.Mode.NORMAL:
        _apply_day_mode_to(plan, list(plan.instances.all()))
    return plan


def update_day(user, day: dt.date, *, mode=None, energy=None, recovery_dismissed=None, now=None) -> DailyPlan:
    plan = set_day_mode(user, day, mode, now) if mode else ensure_day(user, day, now)
    if plan._state.adding:
        raise DomainError("Only today's plan can be changed.", code="not_today")
    fields = []
    if energy is not None:
        plan.energy, fields = energy, [*fields, "energy"]
    if recovery_dismissed is not None:
        plan.recovery_dismissed, fields = recovery_dismissed, [*fields, "recovery_dismissed"]
    if fields:
        plan.save(update_fields=[*fields, "updated_at"])
    return plan


def adaptable_completions(instance: RoutineInstance):
    return list(
        instance.completions.filter(status__in=ADAPTABLE, started_at__isnull=True).order_by(
            "position", "created_at"
        )
    )


@transaction.atomic
def apply_time_budget(user, instance_id, budget_minutes: int, now=None) -> Adjustment:
    now = now or timezone.now()
    instance = RoutineInstance.objects.select_for_update().get(pk=instance_id, user=user)
    if instance.local_date != user_today(user, now):
        raise DomainError("Only today's routines can be adjusted.", code="not_today")
    if instance.daily_plan.mode != DailyPlan.Mode.NORMAL:
        raise DomainError(
            "Minimum Day is on. Switch back to a normal day to choose a time budget.",
            code="minimum_day_active",
        )
    for previous in instance.adjustments.filter(reverted_at__isnull=True):
        _revert(previous, now)
    completions = adaptable_completions(instance)
    if not completions:
        raise DomainError("There's nothing left to adjust in this routine.", code="nothing_to_adapt")
    plan = plan_time_budget(_plan_items(completions), budget_minutes)
    adjustment = Adjustment.objects.create(
        user=user,
        daily_plan=instance.daily_plan,
        routine_instance=instance,
        kind=Adjustment.Kind.TIME_BUDGET,
        params={"budget_minutes": budget_minutes},
        changes=_apply_outcomes(completions, plan),
    )
    reschedule(instance, max(filter(None, [instance.scheduled_start, now])))
    return adjustment


@transaction.atomic
def revert_adjustment(user, adjustment_id, now=None) -> Adjustment:
    adjustment = Adjustment.objects.select_for_update().get(pk=adjustment_id, user=user)
    if adjustment.daily_plan.local_date != user_today(user, now):
        raise DomainError("Only today's changes can be undone.", code="not_today")
    if adjustment.routine_instance_id is None:
        set_day_mode(user, adjustment.daily_plan.local_date, DailyPlan.Mode.NORMAL, now)
        adjustment.refresh_from_db()
    else:
        _revert(adjustment, now)
    return adjustment


# ---------------------------------------------------------------- recovery


def days_away(user, today: dt.date) -> int | None:
    """Days since the user last made progress, when they have history before today; else None."""
    last = (
        ActivityCompletion.objects.filter(
            user=user, status__in=(S.COMPLETED, S.PARTIAL), routine_instance__local_date__lt=today
        )
        .order_by("-routine_instance__local_date")
        .values_list("routine_instance__local_date", flat=True)
        .first()
    )
    return (today - last).days if last else None
