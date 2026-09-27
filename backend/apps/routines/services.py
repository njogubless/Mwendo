from django.db import transaction
from django.db.models import Max
from django.utils import timezone

from apps.tracking.services import start_routine_now, sync_today

from .models import Routine, RoutineActivity


@transaction.atomic
def create_routine(user, *, activities: list[dict] | None = None, **fields) -> Routine:
    routine = Routine.objects.create(user=user, **fields)
    RoutineActivity.objects.bulk_create(
        RoutineActivity(routine=routine, user=user, position=i, **a) for i, a in enumerate(activities or [])
    )
    sync_today(routine)
    return routine


@transaction.atomic
def update_routine(routine: Routine, **fields) -> Routine:
    for key, value in fields.items():
        setattr(routine, key, value)
    if fields.get("status") == Routine.Status.ARCHIVED and routine.archived_at is None:
        routine.archived_at = timezone.now()
    elif "status" in fields and fields["status"] != Routine.Status.ARCHIVED:
        routine.archived_at = None
    routine.save()
    sync_today(routine)
    return routine


def archive_routine(routine: Routine) -> Routine:
    return update_routine(routine, status=Routine.Status.ARCHIVED)


@transaction.atomic
def add_activity(routine: Routine, **fields) -> RoutineActivity:
    last = routine.activities.filter(archived_at__isnull=True).aggregate(m=Max("position"))["m"]
    activity = RoutineActivity.objects.create(
        routine=routine, user=routine.user, position=(last + 1) if last is not None else 0, **fields
    )
    sync_today(routine)
    return activity


@transaction.atomic
def update_activity(activity: RoutineActivity, **fields) -> RoutineActivity:
    for key, value in fields.items():
        setattr(activity, key, value)
    activity.save()
    sync_today(activity.routine)
    return activity


@transaction.atomic
def archive_activity(activity: RoutineActivity) -> None:
    activity.archived_at = timezone.now()
    activity.save(update_fields=["archived_at", "updated_at"])
    sync_today(activity.routine)


@transaction.atomic
def reorder_activities(routine: Routine, ordered_ids: list) -> None:
    activities = {a.id: a for a in routine.activities.select_for_update().filter(archived_at__isnull=True)}
    if set(ordered_ids) != set(activities):
        from apps.core.exceptions import DomainError

        raise DomainError(
            "Send every step of the routine exactly once.", code="invalid_order", status_code=400
        )
    for position, activity_id in enumerate(ordered_ids):
        activities[activity_id].position = position
    RoutineActivity.objects.bulk_update(activities.values(), ["position"])
    sync_today(routine)


def start_now(routine: Routine):
    return start_routine_now(routine)
