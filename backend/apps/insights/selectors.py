"""Deterministic insights from completion history. No ML: every statement is traceable to counts."""

import datetime as dt
from collections import defaultdict
from zoneinfo import ZoneInfo

from apps.core.clock import user_today
from apps.tracking.models import ActivityCompletion

S = ActivityCompletion.Status
MIN_SAMPLES = 5  # below this we don't claim a pattern
PARTS_OF_DAY = (("morning", 4, 12), ("afternoon", 12, 17), ("evening", 17, 28))


def _part_of_day(moment: dt.datetime, tz: ZoneInfo) -> str:
    hour = moment.astimezone(tz).hour
    hour = hour + 24 if hour < 4 else hour
    return next(name for name, start, end in PARTS_OF_DAY if start <= hour < end)


def build_summary(user, days: int = 7) -> dict:
    today = user_today(user)
    since = today - dt.timedelta(days=days - 1)
    tz = ZoneInfo(user.timezone)
    rows = list(
        ActivityCompletion.objects.filter(
            user=user, routine_instance__local_date__gte=since, routine_instance__local_date__lte=today
        )
        .exclude(status=S.CANCELLED)
        .values(
            "status",
            "completion_ratio",
            "scheduled_at",
            "skip_reason",
            "routine_instance__local_date",
            "routine_instance__routine_id",
            "routine_instance__routine_name",
        )
    )
    # Today's untouched steps are still open, not missed.
    rows = [r for r in rows if not (r["routine_instance__local_date"] == today and r["status"] == S.PENDING)]

    per_day = defaultdict(lambda: {"planned": 0, "ratio_sum": 0.0, "done": 0})
    per_routine = defaultdict(lambda: {"name": "", "planned": 0, "ratio_sum": 0.0})
    per_part = defaultdict(lambda: {"planned": 0, "ratio_sum": 0.0})
    skip_reasons = defaultdict(int)
    partials = 0
    for r in rows:
        ratio = float(r["completion_ratio"])
        day = per_day[r["routine_instance__local_date"]]
        day["planned"] += 1
        day["ratio_sum"] += ratio
        day["done"] += r["status"] in (S.COMPLETED, S.PARTIAL)
        routine = per_routine[r["routine_instance__routine_id"]]
        routine["name"] = r["routine_instance__routine_name"]
        routine["planned"] += 1
        routine["ratio_sum"] += ratio
        if r["scheduled_at"]:
            part = per_part[_part_of_day(r["scheduled_at"], tz)]
            part["planned"] += 1
            part["ratio_sum"] += ratio
        if r["status"] == S.SKIPPED and r["skip_reason"]:
            skip_reasons[r["skip_reason"]] += 1
        partials += r["status"] == S.PARTIAL

    series = []
    for offset in range(days):
        day = since + dt.timedelta(days=offset)
        d = per_day.get(day)
        series.append(
            {
                "date": day,
                "planned": d["planned"] if d else 0,
                "done": d["done"] if d else 0,
                "ratio": round(d["ratio_sum"] / d["planned"], 3) if d and d["planned"] else None,
            }
        )
    planned_days = [s for s in series if s["planned"]]
    showed_up = [s for s in planned_days if s["done"]]
    total_planned = sum(d["planned"] for d in per_day.values())
    completion_rate = (
        round(sum(d["ratio_sum"] for d in per_day.values()) / total_planned, 3) if total_planned else None
    )

    routines = sorted(
        (
            {
                "routine_id": rid,
                "name": v["name"],
                "steps": v["planned"],
                "rate": round(v["ratio_sum"] / v["planned"], 3),
            }
            for rid, v in per_routine.items()
            if v["planned"]
        ),
        key=lambda x: -x["rate"],
    )
    parts = [
        {
            "part": name,
            "steps": per_part[name]["planned"],
            "rate": round(per_part[name]["ratio_sum"] / per_part[name]["planned"], 3),
        }
        for name, _, _ in PARTS_OF_DAY
        if per_part[name]["planned"]
    ]

    return {
        "days": days,
        "start": since,
        "end": today,
        "days_showed_up": len(showed_up),
        "days_planned": len(planned_days),
        "consistency": round(len(showed_up) / len(planned_days), 3) if planned_days else None,
        "completion_rate": completion_rate,
        "partial_wins": partials,
        "series": series,
        "routines": routines,
        "parts_of_day": parts,
        "skip_reasons": [
            {"reason": k, "count": v} for k, v in sorted(skip_reasons.items(), key=lambda kv: -kv[1])
        ],
        "observations": _observations(
            len(showed_up), len(planned_days), parts, partials, skip_reasons, total_planned
        ),
    }


def _observations(showed_up, planned_days, parts, partials, skip_reasons, total) -> list[dict]:
    notes = []
    if total < MIN_SAMPLES:
        return [
            {
                "kind": "learning",
                "text": "Keep going — after a few more days Mwendo will show what helps you most.",
            }
        ]
    if planned_days:
        notes.append(
            {"kind": "consistency", "text": f"You showed up on {showed_up} of {planned_days} planned days."}
        )
    solid = [p for p in parts if p["steps"] >= MIN_SAMPLES]
    if len(solid) >= 2:
        best = max(solid, key=lambda p: p["rate"])
        worst = min(solid, key=lambda p: p["rate"])
        if best["rate"] - worst["rate"] >= 0.2:
            notes.append(
                {
                    "kind": "timing",
                    "text": f"Your {best['part']} steps go best ({round(best['rate'] * 100)}%). "
                    f"Consider moving something from the {worst['part']} ({round(worst['rate'] * 100)}%).",
                }
            )
    if partials:
        notes.append(
            {
                "kind": "partial",
                "text": f"{partials} partial {'win' if partials == 1 else 'wins'} — small actions count.",
            }
        )
    if skip_reasons:
        reason, count = max(skip_reasons.items(), key=lambda kv: kv[1])
        if reason == "no_time" and count >= 3:
            notes.append(
                {
                    "kind": "suggestion",
                    "text": "Time was tight on several days. A shorter minimum version could help.",
                }
            )
        elif reason == "low_energy" and count >= 3:
            notes.append(
                {
                    "kind": "suggestion",
                    "text": "Energy was low a few times. Minimum Day is there when you need it.",
                }
            )
    return notes
