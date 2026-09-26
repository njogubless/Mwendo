from functools import lru_cache
from zoneinfo import available_timezones

from django.core.exceptions import ValidationError


@lru_cache(maxsize=1)
def _zones() -> frozenset[str]:
    return frozenset(available_timezones())


def validate_timezone(value: str) -> None:
    if value not in _zones():
        raise ValidationError(
            "Choose a valid time zone, for example Africa/Nairobi.", code="invalid_timezone"
        )
