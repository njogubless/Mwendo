import datetime as dt
from decimal import Decimal

from django.db.models import Prefetch, Sum

from apps.core.clock import user_today
from apps.tracking.models import ActivityCompletion

from .models import Goal, Habit, Measurement

HABIT_WINDOW_DAYS = 7
DONE = (ActivityCompletion.Status.COMPLETED, ActivityCompletion.Status.PARTIAL)


def goals_for(user, *, include_archived=False):
    qs = Goal.objects.filter(user=user).prefetch_related(
        Prefetch(
            "habits", queryset=Habit.objects.filter(archived_at__isnull=True).prefetch_related("activities")
        ),
        Prefetch("measurements", queryset=Measurement.objects.order_by("-recorded_on", "-created_at")),
    )
    return qs if include_archived else qs.exclude(status=Goal.Status.ARCHIVED)


def habit_stats(user, habits: list[Habit]) -> dict:
    """Per habit, over the last 7 days: days it happened, days it was planned, and linked steps."""
    today = user_today(user)
    since = today - dt.timedelta(days=HABIT_WINDOW_DAYS - 1)
    rows = (
        ActivityCompletion.objects.filter(
            user=user,
            activity__habit__in=habits,
            routine_instance__local_date__gte=since,
            routine_instance__local_date__lte=today,
        )
        .exclude(status=ActivityCompletion.Status.CANCELLED)
        .values_list("activity__habit_id", "routine_instance__local_date", "status")
    )
    planned: dict = {}
    done: dict = {}
    for habit_id, day, status in rows:
        if not (day == today and status == ActivityCompletion.Status.PENDING):
            planned.setdefault(habit_id, set()).add(day)
        if status in DONE:
            done.setdefault(habit_id, set()).add(day)
    stats = {}
    for h in habits:
        happened = len(done.get(h.id, ()))
        stats[h.id] = {
            "days_done": happened,
            "days_planned": len(planned.get(h.id, ())),
            "weekly_target": HABIT_WINDOW_DAYS if h.frequency_per == Habit.Per.DAY else h.frequency_times,
            "linked_steps": [
                {"id": a.id, "title": a.title, "routine_id": a.routine_id}
                for a in h.activities.all()
                if a.archived_at is None
            ],
        }
    return stats


def attach_progress(user, goals: list[Goal]) -> list[Goal]:
    habits = [h for g in goals for h in g.habits.all()]
    stats = habit_stats(user, habits)
    for g in goals:
        current = sum((m.value for m in g.measurements.all()), Decimal(0))
        ratio = None
        if g.target_value:
            ratio = float(min(Decimal(1), current / g.target_value))
        habit_rows = []
        for h in g.habits.all():
            habit_rows.append(
                {
                    "id": h.id,
                    "title": h.title,
                    "frequency_per": h.frequency_per,
                    "frequency_times": h.frequency_times,
                    **stats[h.id],
                }
            )
        g.progress = {"current_value": current, "ratio": ratio}
        g.habit_rows = habit_rows
    return goals


def measurement_total(goal: Goal) -> Decimal:
    return goal.measurements.aggregate(total=Sum("value"))["total"] or Decimal(0)
