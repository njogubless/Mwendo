"""Read models for the day. No side effects beyond `ensure_day` materialisation (idempotent)."""

import datetime as dt

from django.db.models import Prefetch
from django.utils import timezone

from apps.core.clock import user_today

from .domain.adaptation import plan_minimum_day, plan_time_budget, suggested_budgets
from .domain.focus import select_focus, shifted_minutes
from .domain.progress import compute_progress
from .models import ActivityCompletion, Adjustment, DailyPlan, Reflection, RoutineInstance
from .services import _plan_items, adaptable_completions, days_away, ensure_day

SHIFT_THRESHOLD_MINUTES = 10
RECOVERY_AFTER_DAYS = 2


def elapsed_seconds(c: ActivityCompletion, now: dt.datetime) -> int:
    running = int((now - c.running_since).total_seconds()) if c.running_since else 0
    return c.active_seconds + max(0, running)


def _completion_dict(c: ActivityCompletion, now) -> dict:
    notes = [r.note for r in c.reflections.all() if r.note]
    return {
        "id": c.id,
        "routine_instance_id": c.routine_instance_id,
        "activity_id": c.activity_id,
        "title": c.title,
        "description": c.description,
        "icon": c.icon,
        "target_kind": c.target_kind,
        "unit": c.unit,
        "is_essential": c.is_essential,
        "priority": c.priority,
        "target_value": c.target_value,
        "minimum_value": c.minimum_value,
        "planned_value": c.planned_value,
        "actual_value": c.actual_value,
        "completion_ratio": c.completion_ratio,
        "status": c.status,
        "skip_reason": c.skip_reason,
        "scheduled_at": c.scheduled_at,
        "started_at": c.started_at,
        "completed_at": c.completed_at,
        "elapsed_seconds": elapsed_seconds(c, now),
        "is_running": c.is_running,
        "reflection": notes[0] if notes else "",
    }


def _adjustment_dict(a: Adjustment) -> dict:
    return {"id": a.id, "kind": a.kind, "params": a.params, "routine_instance_id": a.routine_instance_id}


def build_day(user, day: dt.date, now: dt.datetime | None = None) -> dict:
    now = now or timezone.now()
    plan = ensure_day(user, day, now)
    today = user_today(user, now)
    instances = []
    if not plan._state.adding:
        instances = list(
            RoutineInstance.objects.filter(daily_plan=plan)
            .select_related("routine")
            .prefetch_related(
                Prefetch(
                    "completions",
                    queryset=ActivityCompletion.objects.order_by("position", "created_at").prefetch_related(
                        Prefetch("reflections", queryset=Reflection.objects.order_by("-created_at"))
                    ),
                ),
                Prefetch("adjustments", queryset=Adjustment.objects.filter(reverted_at__isnull=True)),
            )
            .order_by("scheduled_start", "created_at")
        )
    items = [c for i in instances for c in i.completions.all()]
    progress = compute_progress(items)
    focus = select_focus(items) if day == today else None
    shifted = shifted_minutes(focus, now)
    focus_instance = next((i for i in instances if focus and i.id == focus.routine_instance_id), None)

    if not items:
        timing = "empty"
    elif focus is None:
        timing = "done"
    elif shifted >= SHIFT_THRESHOLD_MINUTES:
        timing = "shifted"
    else:
        timing = "on_track"

    away = days_away(user, today) if day == today else None
    recovery_suggested = bool(
        day == today
        and away is not None
        and away >= RECOVERY_AFTER_DAYS
        and not plan._state.adding
        and plan.mode == DailyPlan.Mode.NORMAL
        and not plan.recovery_dismissed
        and progress.completed + progress.partial == 0
    )
    day_adjustments = [] if plan._state.adding else list(plan.adjustments.filter(reverted_at__isnull=True))

    return {
        "date": day,
        "is_today": day == today,
        "mode": plan.mode,
        "energy": plan.energy,
        "progress": progress.__dict__,
        "focus_id": focus.id if focus else None,
        "timing": {
            "status": timing,
            "shifted_minutes": shifted,
            "routine_instance_id": focus_instance.id if focus_instance else None,
        },
        "recovery": {"suggested": recovery_suggested, "days_away": away},
        "adjustments": [_adjustment_dict(a) for a in day_adjustments],
        "routines": [
            {
                "id": i.id,
                "routine_id": i.routine_id,
                "name": i.routine_name,
                "category": i.category,
                "scheduled_start": i.scheduled_start,
                "finish_by": i.finish_by,
                "is_ad_hoc": i.is_ad_hoc,
                "adjustment": next((_adjustment_dict(a) for a in i.adjustments.all()), None),
                "completions": [_completion_dict(c, now) for c in i.completions.all()],
            }
            for i in instances
        ],
    }


def build_adaptation_preview(user, instance_id, *, budget_minutes=None, minimum=False, now=None) -> dict:
    now = now or timezone.now()
    instance = RoutineInstance.objects.select_related("daily_plan").get(pk=instance_id, user=user)
    completions = adaptable_completions(instance)
    items = _plan_items(completions)
    everything = list(instance.completions.all())
    focus = select_focus(everything)
    original = int(sum(i.target_value for i in items if i.is_timed))
    available = max(0, int((instance.finish_by - now).total_seconds() // 60)) if instance.finish_by else None
    options, recommended = suggested_budgets(available, original)

    if minimum:
        plan = plan_minimum_day(items)
        budget = None
    else:
        budget = budget_minutes or recommended or options[-1]
        plan = plan_time_budget(items, budget)

    by_id = {c.id: c for c in completions}
    active = instance.adjustments.filter(reverted_at__isnull=True).first()
    return {
        "routine_instance_id": instance.id,
        "routine_name": instance.routine_name,
        "mode": "minimum" if minimum else "time_budget",
        "budget_minutes": budget,
        "options": options,
        "recommended": recommended,
        "context": {
            "shifted_minutes": shifted_minutes(focus, now),
            "available_minutes": available,
            "finish_by": instance.finish_by,
            "day_mode": instance.daily_plan.mode,
        },
        "active_adjustment": _adjustment_dict(active) if active else None,
        "original_minutes": plan.original_minutes,
        "planned_minutes": plan.planned_minutes,
        "fits": plan.fits,
        "essentials_kept": plan.essentials_kept,
        "essentials_total": plan.essentials_total,
        "items": [
            {
                "completion_id": o.id,
                "title": by_id[o.id].title,
                "icon": by_id[o.id].icon,
                "target_kind": by_id[o.id].target_kind,
                "unit": by_id[o.id].unit,
                "is_essential": by_id[o.id].is_essential,
                "priority": by_id[o.id].priority,
                "target_value": by_id[o.id].target_value,
                "planned_value": o.planned_value,
                "status": o.status,
            }
            for o in plan.items
        ],
    }
