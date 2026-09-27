"""Deterministic first-routine generator used by onboarding.

Given focus areas, a structure preference and a wake time it proposes 1–3 routines with sensible steps,
minimum versions and essentials. It never saves anything: the user reviews, edits and then creates.
"""

import datetime as dt

FOCUS_AREAS = ("health", "mind", "learning", "focus", "relationships", "rest")
WEEKDAYS = [1, 2, 3, 4, 5]
EVERY_DAY = [1, 2, 3, 4, 5, 6, 7]


def _step(
    title,
    icon,
    minutes=None,
    *,
    minimum=None,
    essential=False,
    priority="standard",
    kind=None,
    unit="",
    description="",
):
    kind = kind or ("duration" if minutes else "check")
    target = minutes if kind != "check" else 1
    return {
        "title": title,
        "description": description,
        "icon": icon,
        "target_kind": kind,
        "target_value": target,
        "minimum_value": minimum if kind != "check" else None,
        "unit": unit,
        "is_essential": essential,
        "priority": priority,
    }


def _shift(time: dt.time, minutes: int) -> dt.time:
    return (dt.datetime.combine(dt.date(2000, 1, 1), time) + dt.timedelta(minutes=minutes)).time()


def generate_routines(*, focus_areas: list[str], structure: str, wake_time: dt.time | None) -> list[dict]:
    areas = [a for a in focus_areas if a in FOCUS_AREAS] or ["health", "mind"]
    wake = wake_time or dt.time(6, 30)
    loose = structure == "loose"
    structured = structure == "structured"

    morning = [_step("Drink a glass of water", "water_drop", essential=True, priority="core")]
    if "health" in areas:
        morning.append(
            _step(
                "Move your body",
                "directions_run",
                20,
                minimum=5,
                essential=True,
                priority="core",
                description="A walk, stretch or workout — any movement counts.",
            )
        )
    if "mind" in areas or loose:
        morning.append(
            _step(
                "Breathe and settle",
                "self_improvement",
                5,
                minimum=2,
                essential="health" not in areas,
                priority="core" if "health" not in areas else "standard",
            )
        )
    if "learning" in areas and not loose:
        morning.append(_step("Read", "menu_book", 15, minimum=5, priority="optional"))
    if not loose:
        morning.append(
            _step(
                "Plan your day",
                "edit_note",
                5,
                minimum=2,
                priority="standard",
                description="Pick the one thing that matters most today.",
            )
        )
    if structured:
        morning.append(_step("Nourishing breakfast", "restaurant", 20, minimum=10, priority="optional"))
    morning_minutes = sum(s["target_value"] for s in morning if s["target_kind"] == "duration")

    routines = [
        {
            "name": "Morning",
            "category": "morning",
            "description": "Start the day grounded.",
            "days_of_week": EVERY_DAY,
            "start_time": _shift(wake, 10).strftime("%H:%M"),
            "finish_by": _shift(wake, 10 + morning_minutes + 30).strftime("%H:%M") if structured else None,
            "activities": morning,
        }
    ]

    if ("focus" in areas or "learning" in areas) and not loose:
        routines.append(
            {
                "name": "Focus block",
                "category": "work",
                "description": "Protected time for what matters.",
                "days_of_week": WEEKDAYS,
                "start_time": "09:00",
                "finish_by": None,
                "activities": [
                    _step("Set one clear intention", "flag", 2, minimum=1, essential=True, priority="core"),
                    _step(
                        "Deep work",
                        "psychology",
                        90 if structured else 60,
                        minimum=25,
                        essential=True,
                        priority="core",
                    ),
                    _step("Short reset", "local_cafe", 10, minimum=5, priority="optional"),
                ],
            }
        )

    evening = [_step("Reflect on today", "edit_note", 5, minimum=2, essential=True, priority="core")]
    if "relationships" in areas:
        evening.append(
            _step(
                "Connect with someone",
                "favorite",
                15,
                minimum=5,
                priority="standard",
                description="A call, a message or time together.",
            )
        )
    if "learning" in areas:
        evening.append(
            _step("Read", "menu_book", 20, minimum=5, kind="count", unit="pages", priority="standard")
        )
    if "rest" in areas or structured:
        evening.append(_step("Screens off", "bedtime", essential="rest" in areas, priority="standard"))
    evening.append(_step("Gratitude", "spa", 3, minimum=1, priority="optional"))
    routines.append(
        {
            "name": "Evening wind-down",
            "category": "evening",
            "description": "Close the day gently.",
            "days_of_week": EVERY_DAY,
            "start_time": "21:00",
            "finish_by": None,
            "activities": evening,
        }
    )
    return routines
