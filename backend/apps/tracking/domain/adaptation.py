"""Deterministic adaptation planner (Minimum Day, Time Budget / Running Late).

Pure functions, no ORM. Guarantees (tested):
  * a kept step is never planned below its floor (minimum_value, or target when no minimum is set);
  * essential steps are never dropped by a time budget;
  * non-essential steps are dropped optional → standard → core, later steps first;
  * spare minutes go back to kept steps core → standard → optional, proportionally to headroom;
  * total planned minutes ≤ budget whenever the essentials' floors fit (`fits` says so otherwise).
Only duration steps consume minutes; count/check steps are kept at target.
"""

from dataclasses import dataclass
from decimal import ROUND_FLOOR, Decimal

PRIORITY_RANK = {"optional": 0, "standard": 1, "core": 2}
DISTRIBUTION_ORDER = ("core", "standard", "optional")


@dataclass(frozen=True)
class PlanItem:
    id: object
    target_kind: str
    target_value: Decimal
    minimum_value: Decimal | None
    is_essential: bool
    priority: str
    position: int

    @property
    def is_timed(self) -> bool:
        return self.target_kind == "duration"

    @property
    def floor(self) -> Decimal:
        return self.minimum_value if self.minimum_value is not None else self.target_value


@dataclass(frozen=True)
class ItemOutcome:
    id: object
    planned_value: Decimal
    status: str  # "pending" or "cancelled"


@dataclass(frozen=True)
class AdaptationPlan:
    items: list[ItemOutcome]
    original_minutes: int
    planned_minutes: int
    fits: bool
    essentials_kept: int
    essentials_total: int


def _minutes(items, values) -> Decimal:
    return sum((values[i.id] for i in items if i.is_timed), Decimal(0))


def _result(items: list[PlanItem], kept: dict, budget: Decimal | None) -> AdaptationPlan:
    outcomes = [
        ItemOutcome(i.id, kept[i.id], "pending")
        if i.id in kept
        else ItemOutcome(i.id, i.target_value, "cancelled")
        for i in items
    ]
    planned = sum(
        (
            o.planned_value
            for o, i in zip(outcomes, items, strict=True)
            if i.is_timed and o.status == "pending"
        ),
        Decimal(0),
    )
    original = sum((i.target_value for i in items if i.is_timed), Decimal(0))
    essentials = [i for i in items if i.is_essential]
    return AdaptationPlan(
        items=outcomes,
        original_minutes=int(original),
        planned_minutes=int(planned),
        fits=budget is None or planned <= budget,
        essentials_kept=sum(1 for i in essentials if i.id in kept),
        essentials_total=len(essentials),
    )


def plan_minimum_day(items: list[PlanItem]) -> AdaptationPlan:
    """Keep only essentials, each at its floor. If none are marked essential, keep the most important step."""
    essentials = [i for i in items if i.is_essential]
    if not essentials and items:
        essentials = [max(items, key=lambda i: (PRIORITY_RANK[i.priority], -i.position))]
    return _result(items, {i.id: i.floor for i in essentials}, None)


def plan_time_budget(items: list[PlanItem], budget_minutes: int) -> AdaptationPlan:
    budget = Decimal(max(0, budget_minutes))
    full = {i.id: i.target_value for i in items}
    if _minutes(items, full) <= budget:
        return _result(items, full, budget)

    kept = list(items)
    floors = {i.id: i.floor for i in items}
    droppable = sorted(
        (i for i in items if not i.is_essential and i.is_timed),
        key=lambda i: (PRIORITY_RANK[i.priority], -i.position),
    )
    for candidate in droppable:
        if _minutes(kept, floors) <= budget:
            break
        kept.remove(candidate)

    # Untimed steps cost no minutes, so a time budget never shrinks them.
    planned = {i.id: floors[i.id] if i.is_timed else i.target_value for i in kept}
    spare = budget - _minutes(kept, planned)
    for tier in DISTRIBUTION_ORDER:
        if spare <= 0:
            break
        tier_items = [i for i in kept if i.priority == tier and i.is_timed and i.target_value > planned[i.id]]
        headroom = sum((i.target_value - planned[i.id] for i in tier_items), Decimal(0))
        if headroom <= 0:
            continue
        if spare >= headroom:
            for i in tier_items:
                planned[i.id] = i.target_value
            spare -= headroom
            continue
        given = Decimal(0)
        for i in tier_items:
            share = ((i.target_value - planned[i.id]) * spare / headroom).to_integral_value(ROUND_FLOOR)
            planned[i.id] += share
            given += share
        leftover = spare - given
        for i in sorted(tier_items, key=lambda i: i.position):
            if leftover <= 0:
                break
            if planned[i.id] + 1 <= i.target_value:
                planned[i.id] += 1
                leftover -= 1
        spare = Decimal(0)
    return _result(items, planned, budget)


def suggested_budgets(available_minutes: int | None, original_minutes: int) -> tuple[list[int], int | None]:
    """Budget pills for the UI and which one to recommend."""
    options = [m for m in (15, 30, 45, 60) if m < original_minutes] or [15]
    if available_minutes is None:
        return options, None
    fitting = [m for m in options if m <= available_minutes]
    return options, (fitting[-1] if fitting else options[0])
