import '../../../routines/domain/routine.dart';
import '../day.dart';

/// Deterministic adaptation planner (Minimum Day, Time Budget / Running Late), ported from backend
/// `apps/tracking/domain/adaptation.py`. Pure functions. Guarantees (tested on both sides):
///  * a kept step is never planned below its floor (minimum value, or target when no minimum is set);
///  * essential steps are never dropped by a time budget;
///  * non-essential steps are dropped optional → standard → core, later steps first;
///  * spare minutes go back to kept steps core → standard → optional, proportionally to headroom;
///  * total planned minutes ≤ budget whenever the essentials' floors fit (`fits` says so otherwise).
/// Only duration steps consume minutes; count/check steps are kept at target (D-021).
class PlanItem {
  const PlanItem({
    required this.id,
    required this.targetKind,
    required this.targetValue,
    required this.isEssential,
    required this.priority,
    required this.position,
    this.minimumValue,
  });

  final String id;
  final TargetKind targetKind;
  final double targetValue;
  final double? minimumValue;
  final bool isEssential;
  final StepPriority priority;
  final int position;

  bool get isTimed => targetKind == TargetKind.duration;
  double get floor => minimumValue ?? targetValue;
}

class ItemOutcome {
  const ItemOutcome({required this.id, required this.plannedValue, required this.status});

  final String id;
  final double plannedValue;

  /// [StepStatus.pending] (kept) or [StepStatus.cancelled] (set aside).
  final StepStatus status;
}

class AdaptationPlan {
  const AdaptationPlan({
    required this.items,
    required this.originalMinutes,
    required this.plannedMinutes,
    required this.fits,
    required this.essentialsKept,
    required this.essentialsTotal,
  });

  final List<ItemOutcome> items;
  final int originalMinutes;
  final int plannedMinutes;
  final bool fits;
  final int essentialsKept;
  final int essentialsTotal;
}

int _rank(StepPriority p) => switch (p) {
  StepPriority.optional => 0,
  StepPriority.standard => 1,
  StepPriority.core => 2,
};

const _distributionOrder = [StepPriority.core, StepPriority.standard, StepPriority.optional];

double _minutes(Iterable<PlanItem> items, Map<String, double> values) =>
    items.where((i) => i.isTimed).fold(0.0, (total, i) => total + values[i.id]!);

AdaptationPlan _result(List<PlanItem> items, Map<String, double> kept, double? budget) {
  final outcomes = [
    for (final i in items)
      kept.containsKey(i.id)
          ? ItemOutcome(id: i.id, plannedValue: kept[i.id]!, status: StepStatus.pending)
          : ItemOutcome(id: i.id, plannedValue: i.targetValue, status: StepStatus.cancelled),
  ];
  var planned = 0.0;
  for (final (index, o) in outcomes.indexed) {
    if (items[index].isTimed && o.status == StepStatus.pending) planned += o.plannedValue;
  }
  final original = items.where((i) => i.isTimed).fold(0.0, (total, i) => total + i.targetValue);
  final essentials = items.where((i) => i.isEssential).toList();
  return AdaptationPlan(
    items: outcomes,
    originalMinutes: original.floor(),
    plannedMinutes: planned.floor(),
    fits: budget == null || planned <= budget,
    essentialsKept: essentials.where((i) => kept.containsKey(i.id)).length,
    essentialsTotal: essentials.length,
  );
}

/// Most important first: highest priority, then earliest position.
PlanItem _mostImportant(List<PlanItem> items) => items.reduce((best, i) {
  final byRank = _rank(i.priority).compareTo(_rank(best.priority));
  if (byRank != 0) return byRank > 0 ? i : best;
  return i.position < best.position ? i : best;
});

/// Keep only essentials, each at its floor. If none are marked essential, keep the most important step.
AdaptationPlan planMinimumDay(List<PlanItem> items) {
  var essentials = items.where((i) => i.isEssential).toList();
  if (essentials.isEmpty && items.isNotEmpty) essentials = [_mostImportant(items)];
  return _result(items, {for (final i in essentials) i.id: i.floor}, null);
}

AdaptationPlan planTimeBudget(List<PlanItem> items, int budgetMinutes) {
  final budget = (budgetMinutes < 0 ? 0 : budgetMinutes).toDouble();
  final full = {for (final i in items) i.id: i.targetValue};
  if (_minutes(items, full) <= budget) return _result(items, full, budget);

  final kept = [...items];
  final floors = {for (final i in items) i.id: i.floor};
  final droppable = items.where((i) => !i.isEssential && i.isTimed).toList()
    ..sort((a, b) {
      final byRank = _rank(a.priority).compareTo(_rank(b.priority));
      return byRank != 0 ? byRank : b.position.compareTo(a.position);
    });
  for (final candidate in droppable) {
    if (_minutes(kept, floors) <= budget) break;
    kept.remove(candidate);
  }

  // Untimed steps cost no minutes, so a time budget never shrinks them.
  final planned = {for (final i in kept) i.id: i.isTimed ? floors[i.id]! : i.targetValue};
  var spare = budget - _minutes(kept, planned);
  for (final tier in _distributionOrder) {
    if (spare <= 0) break;
    final tierItems = kept.where((i) => i.priority == tier && i.isTimed && i.targetValue > planned[i.id]!).toList();
    final headroom = tierItems.fold(0.0, (total, i) => total + (i.targetValue - planned[i.id]!));
    if (headroom <= 0) continue;
    if (spare >= headroom) {
      for (final i in tierItems) {
        planned[i.id] = i.targetValue;
      }
      spare -= headroom;
      continue;
    }
    var given = 0.0;
    for (final i in tierItems) {
      final share = ((i.targetValue - planned[i.id]!) * spare / headroom).floorToDouble();
      planned[i.id] = planned[i.id]! + share;
      given += share;
    }
    var leftover = spare - given;
    for (final i in [...tierItems]..sort((a, b) => a.position.compareTo(b.position))) {
      if (leftover <= 0) break;
      if (planned[i.id]! + 1 <= i.targetValue) {
        planned[i.id] = planned[i.id]! + 1;
        leftover -= 1;
      }
    }
    spare = 0;
  }
  return _result(items, planned, budget);
}

/// Budget pills for the UI and which one to recommend.
({List<int> options, int? recommended}) suggestedBudgets(int? availableMinutes, int originalMinutes) {
  var options = [15, 30, 45, 60].where((m) => m < originalMinutes).toList();
  if (options.isEmpty) options = [15];
  if (availableMinutes == null) return (options: options, recommended: null);
  final fitting = options.where((m) => m <= availableMinutes).toList();
  return (options: options, recommended: fitting.isNotEmpty ? fitting.last : options.first);
}
