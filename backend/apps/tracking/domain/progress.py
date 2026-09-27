"""Today's progress (decision D-007).

progress = Σ completion_ratio / number of steps, excluding `cancelled` (set aside by an approved adaptation).
Skipped steps count as 0 but stay in the denominator: honest data, shown neutrally in the UI.
"""

from collections.abc import Iterable
from dataclasses import dataclass
from decimal import Decimal


@dataclass(frozen=True)
class Progress:
    ratio: float
    total: int
    completed: int
    partial: int
    skipped: int
    in_progress: int
    remaining: int
    cancelled: int


def compute_progress(items: Iterable) -> Progress:
    counts = {
        "completed": 0,
        "partially_completed": 0,
        "skipped": 0,
        "in_progress": 0,
        "pending": 0,
        "cancelled": 0,
    }
    ratio_sum = Decimal(0)
    for item in items:
        counts[item.status] += 1
        if item.status != "cancelled":
            ratio_sum += Decimal(item.completion_ratio or 0)
    total = sum(v for k, v in counts.items() if k != "cancelled")
    return Progress(
        ratio=round(float(ratio_sum / total), 3) if total else 0.0,
        total=total,
        completed=counts["completed"],
        partial=counts["partially_completed"],
        skipped=counts["skipped"],
        in_progress=counts["in_progress"],
        remaining=counts["pending"],
        cancelled=counts["cancelled"],
    )


def completion_ratio(actual: Decimal, planned: Decimal) -> Decimal:
    if planned <= 0:
        return Decimal(1)
    return min(Decimal(1), max(Decimal(0), actual / planned)).quantize(Decimal("0.001"))
