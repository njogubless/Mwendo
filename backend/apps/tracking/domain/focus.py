"""Answers "What should I focus on now?" deterministically."""

import datetime as dt
from collections.abc import Sequence

_OPEN = {"pending", "in_progress"}


def _sort_key(item):
    far = dt.datetime.max.replace(tzinfo=dt.UTC)
    return (item.scheduled_at or far, item.position)


def select_focus(items: Sequence):
    """A running step wins, then a paused one (latest started), else the earliest scheduled pending step."""
    in_progress = [i for i in items if i.status == "in_progress"]
    if in_progress:
        never = dt.datetime.min.replace(tzinfo=dt.UTC)
        return max(
            in_progress,
            key=lambda i: (getattr(i, "running_since", None) is not None, i.started_at or never),
        )
    pending = sorted((i for i in items if i.status == "pending"), key=_sort_key)
    return pending[0] if pending else None


def shifted_minutes(focus, now: dt.datetime) -> int:
    """How far behind the plan the focus step is (0 when on time or unscheduled). Minutes, never negative."""
    if focus is None or focus.scheduled_at is None or focus.status != "pending":
        return 0
    return max(0, int((now - focus.scheduled_at).total_seconds() // 60))


def is_open(item) -> bool:
    return item.status in _OPEN
