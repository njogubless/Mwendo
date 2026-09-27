import datetime as dt

from django.db.models import Avg, Prefetch, Q

from apps.core.clock import user_today
from apps.tracking.models import ActivityCompletion

from .models import Routine, RoutineActivity

CONSISTENCY_WINDOW_DAYS = 14


def routines_for(user, *, include_archived=False, category=None):
    qs = Routine.objects.filter(user=user).prefetch_related(
        Prefetch("activities", queryset=RoutineActivity.objects.filter(archived_at__isnull=True))
    )
    if not include_archived:
        qs = qs.exclude(status=Routine.Status.ARCHIVED)
    if category:
        qs = qs.filter(category=category)
    return qs


def attach_stats(user, routines: list[Routine]) -> list[Routine]:
    """Adds `.stats` to each routine: size, minimum-day size and recent consistency (one query)."""
    since = user_today(user) - dt.timedelta(days=CONSISTENCY_WINDOW_DAYS)
    rows = (
        ActivityCompletion.objects.filter(
            user=user,
            routine_instance__routine__in=routines,
            routine_instance__local_date__gte=since,
        )
        .exclude(status=ActivityCompletion.Status.CANCELLED)
        # Today's not-yet-started steps aren't "missed" — leave them out until the day is over.
        .exclude(
            Q(status=ActivityCompletion.Status.PENDING) & Q(routine_instance__local_date=user_today(user))
        )
        .values("routine_instance__routine")
        .annotate(avg=Avg("completion_ratio"))
    )
    consistency = {row["routine_instance__routine"]: row["avg"] for row in rows}
    for r in routines:
        steps = list(r.activities.all())
        timed = [a for a in steps if a.target_kind == "duration"]
        essentials = [a for a in steps if a.is_essential]
        avg = consistency.get(r.id)
        r.stats = {
            "steps": len(steps),
            "total_minutes": int(sum(a.target_value for a in timed)),
            "essential_steps": len(essentials),
            "minimum_minutes": int(
                sum((a.minimum_value or a.target_value) for a in essentials if a.target_kind == "duration")
            ),
            "consistency": round(float(avg), 3) if avg is not None else None,
        }
    return routines
