import '../../../routines/domain/routine.dart';
import '../day.dart';

/// Stored state of one day — the device-side equivalent of the backend's DailyPlan, RoutineInstance,
/// ActivityCompletion, Reflection and Adjustment rows. Storage-agnostic and mutable: the engine loads a
/// record, applies one operation, and the data layer saves it back.

/// One step on a day (an ActivityCompletion). Snapshot fields are copied from the template when the day is
/// materialised, so later template edits never rewrite history (D-006).
class StepRecord {
  StepRecord({
    required this.id,
    required this.title,
    required this.targetKind,
    required this.priority,
    required this.targetValue,
    required this.plannedValue,
    this.activityId,
    this.position = 0,
    this.description = '',
    this.icon = 'check_circle',
    this.unit = '',
    this.isEssential = false,
    this.minimumValue,
    this.actualValue,
    this.completionRatio = 0,
    this.status = StepStatus.pending,
    this.skipReason = '',
    this.scheduledAt,
    this.startedAt,
    this.runningSince,
    this.completedAt,
    this.activeSeconds = 0,
    List<String>? reflections,
  }) : reflections = reflections ?? [];

  final String id;

  /// The template step this came from (null once that step no longer exists).
  String? activityId;
  int position;
  String title;
  String description;
  String icon;
  TargetKind targetKind;
  String unit;
  bool isEssential;
  StepPriority priority;
  double targetValue;
  double? minimumValue;
  double plannedValue;
  double? actualValue;
  double completionRatio;
  StepStatus status;
  String skipReason;
  DateTime? scheduledAt;
  DateTime? startedAt;

  /// Null while paused.
  DateTime? runningSince;
  DateTime? completedAt;
  int activeSeconds;

  /// Notes, newest first.
  final List<String> reflections;

  bool get isTimed => targetKind == TargetKind.duration;
  bool get isRunning => status == StepStatus.inProgress && runningSince != null;
  double get floor => minimumValue ?? targetValue;
}

/// A routine as it happens on one date (a RoutineInstance). Survives edits/deletion of the template.
class InstanceRecord {
  InstanceRecord({
    required this.id,
    required this.routineName,
    required this.category,
    required this.createdAt,
    this.routineId,
    this.scheduledStart,
    this.finishBy,
    this.isAdHoc = false,
    List<StepRecord>? steps,
  }) : steps = steps ?? [];

  final String id;
  String? routineId;
  String routineName;
  RoutineCategory category;
  DateTime? scheduledStart;
  DateTime? finishBy;
  bool isAdHoc;
  final DateTime createdAt;

  /// Ordered by position.
  final List<StepRecord> steps;
}

/// A step's adaptable state, recorded before and after an adjustment so it can be reverted.
class StepState {
  const StepState({required this.plannedValue, required this.status, this.scheduledAt});

  final double plannedValue;
  final StepStatus status;
  final DateTime? scheduledAt;
}

class StepChange {
  const StepChange({required this.stepId, required this.before, required this.after});

  final String stepId;
  final StepState before;
  final StepState after;
}

enum AdjustmentKind {
  timeBudget('time_budget'),
  minimumDay('minimum_day'),
  recovery('recovery');

  const AdjustmentKind(this.api);

  /// The name shared with the Django API and [AdjustmentRef.kind].
  final String api;

  static AdjustmentKind parse(String v) => values.firstWhere((k) => k.api == v);
}

/// An approved adaptation, transparent and revertible.
class AdjustmentRecord {
  AdjustmentRecord({
    required this.id,
    required this.kind,
    required this.createdAt,
    this.instanceId,
    this.budgetMinutes,
    this.mode,
    List<StepChange>? changes,
    this.revertedAt,
  }) : changes = changes ?? [];

  final String id;
  final AdjustmentKind kind;

  /// Null for day-level adjustments (Minimum Day / Recovery).
  final String? instanceId;
  final int? budgetMinutes;
  final DayMode? mode;
  final List<StepChange> changes;
  DateTime? revertedAt;
  final DateTime createdAt;

  bool get isActive => revertedAt == null;
}

/// The whole day (a DailyPlan with its children).
class DayRecord {
  DayRecord({
    required this.date,
    this.mode = DayMode.normal,
    this.recoveryDismissed = false,
    List<InstanceRecord>? instances,
    List<AdjustmentRecord>? adjustments,
    this.persisted = false,
  }) : instances = instances ?? [],
       adjustments = adjustments ?? [];

  /// ISO `YYYY-MM-DD`.
  final String date;
  DayMode mode;
  bool recoveryDismissed;
  final List<InstanceRecord> instances;
  final List<AdjustmentRecord> adjustments;

  /// False for a day that was never materialised (read-only past/future days with nothing recorded).
  bool persisted;

  Iterable<StepRecord> get steps => instances.expand((i) => i.steps);

  /// True when at least one step was done or partly done (feeds "days away").
  bool get hasProgress => steps.any((s) => s.status.isDone);

  StepRecord? step(String id) {
    for (final s in steps) {
      if (s.id == id) return s;
    }
    return null;
  }

  InstanceRecord? instance(String id) {
    for (final i in instances) {
      if (i.id == id) return i;
    }
    return null;
  }

  InstanceRecord? instanceOf(StepRecord step) {
    for (final i in instances) {
      if (i.steps.contains(step)) return i;
    }
    return null;
  }

  AdjustmentRecord? adjustment(String id) {
    for (final a in adjustments) {
      if (a.id == id) return a;
    }
    return null;
  }
}
