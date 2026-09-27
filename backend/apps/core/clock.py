"""The user's notion of "now" and "today".

A person's day starts at `user.day_start_time` in `user.timezone` — someone awake at 01:00 with a 04:00 day
start is still in yesterday. Every "today" decision in Mwendo goes through here.
"""

import datetime as dt
from zoneinfo import ZoneInfo

from django.utils import timezone


def user_tz(user) -> ZoneInfo:
    return ZoneInfo(user.timezone or "UTC")


def local_now(user, now: dt.datetime | None = None) -> dt.datetime:
    return (now or timezone.now()).astimezone(user_tz(user))


def user_today(user, now: dt.datetime | None = None) -> dt.date:
    local = local_now(user, now)
    day = local.date()
    if local.time() < user.day_start_time:
        day -= dt.timedelta(days=1)
    return day


def at_local(user, day: dt.date, time: dt.time | None) -> dt.datetime | None:
    """Aware datetime for a wall-clock time on the user's local date."""
    if time is None:
        return None
    return dt.datetime.combine(day, time, tzinfo=user_tz(user))
