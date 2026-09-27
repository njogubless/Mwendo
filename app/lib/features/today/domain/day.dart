import '../../routines/domain/routine.dart';

enum StepStatus {
  pending,
  inProgress,
  completed,
  partiallyCompleted,
  skipped,
  cancelled;

  static StepStatus parse(String v) => switch (v) {
    'in_progress' => inProgress,
    'partially_completed' => partiallyCompleted,
    _ => values.byName(v),
  };

  bool get isOpen => this == pending || this == inProgress;
  bool get isDone => this == completed || this == partiallyCompleted;
}

enum DayMode {
  normal,
  minimum,
  recovery;

  static DayMode parse(String v) => values.byName(v);
}

enum TimingStatus {
  empty,
  done,
  onTrack,
  shifted;

  static TimingStatus parse(String v) => switch (v) {
    'on_track' => onTrack,
    _ => values.byName(v),
  };
}

enum SkipReason {
  noTime('no_time', 'Not enough time'),
  lowEnergy('low_energy', 'Low energy'),
  notRelevant('not_relevant', 'Not relevant today'),
  other('other', 'Something else');

  const SkipReason(this.api, this.label);
  final String api;
  final String label;
}

/// One step on a day (an ActivityCompletion).
class DayStep {
  const DayStep({
    required this.id,
    required this.routineInstanceId,
    required this.title,
    required this.icon,
    required this.targetKind,
    required this.unit,
    required this.isEssential,
    required this.priority,
    required this.targetValue,
    required this.plannedValue,
    required this.status,
    required this.completionRatio,
    required this.elapsedSeconds,
    required this.isRunning,
    this.description = '',
    this.minimumValue,
    this.actualValue,
    this.skipReason = '',
    this.scheduledAt,
    this.completedAt,
    this.reflection = '',
  });

  final String id;
  final String routineInstanceId;
  final String title;
  final String description;
  final String icon;
  final TargetKind targetKind;
  final String unit;
  final bool isEssential;
  final StepPriority priority;
  final double targetValue;
  final double? minimumValue;
  final double plannedValue;
  final double? actualValue;
  final StepStatus status;
  final double completionRatio;
  final String skipReason;
  final DateTime? scheduledAt;
  final DateTime? completedAt;
  final int elapsedSeconds;
  final bool isRunning;
  final String reflection;

  bool get isAdapted => plannedValue != targetValue;

  DayStep copyWith({StepStatus? status, bool? isRunning, double? actualValue, double? completionRatio}) => DayStep(
    id: id,
    routineInstanceId: routineInstanceId,
    title: title,
    description: description,
    icon: icon,
    targetKind: targetKind,
    unit: unit,
    isEssential: isEssential,
    priority: priority,
    targetValue: targetValue,
    minimumValue: minimumValue,
    plannedValue: plannedValue,
    actualValue: actualValue ?? this.actualValue,
    status: status ?? this.status,
    completionRatio: completionRatio ?? this.completionRatio,
    skipReason: skipReason,
    scheduledAt: scheduledAt,
    completedAt: completedAt,
    elapsedSeconds: elapsedSeconds,
    isRunning: isRunning ?? this.isRunning,
    reflection: reflection,
  );
}

class AdjustmentRef {
  const AdjustmentRef({required this.id, required this.kind, this.budgetMinutes});

  final String id;
  final String kind;
  final int? budgetMinutes;
}

class DayRoutine {
  const DayRoutine({
    required this.id,
    required this.name,
    required this.category,
    required this.steps,
    this.routineId,
    this.scheduledStart,
    this.finishBy,
    this.isAdHoc = false,
    this.adjustment,
  });

  final String id;
  final String? routineId;
  final String name;
  final RoutineCategory category;
  final DateTime? scheduledStart;
  final DateTime? finishBy;
  final bool isAdHoc;
  final AdjustmentRef? adjustment;
  final List<DayStep> steps;

  /// True when some untouched step still takes time — i.e. a time budget could change something.
  bool get canCompress => steps.any((s) => s.status == StepStatus.pending && s.targetKind == TargetKind.duration);
}

class DayProgress {
  const DayProgress({
    required this.ratio,
    required this.total,
    required this.completed,
    required this.partial,
    required this.skipped,
    required this.inProgress,
    required this.remaining,
    required this.cancelled,
  });

  final double ratio;
  final int total;
  final int completed;
  final int partial;
  final int skipped;
  final int inProgress;
  final int remaining;
  final int cancelled;

  int get done => completed + partial;
}

class Day {
  const Day({
    required this.date,
    required this.isToday,
    required this.mode,
    required this.progress,
    required this.timing,
    required this.shiftedMinutes,
    required this.routines,
    required this.fetchedAt,
    this.focusId,
    this.timingInstanceId,
    this.recoverySuggested = false,
    this.daysAway,
    this.adjustments = const [],
  });

  final DateTime date;
  final bool isToday;
  final DayMode mode;
  final DayProgress progress;
  final String? focusId;
  final TimingStatus timing;
  final int shiftedMinutes;
  final String? timingInstanceId;
  final bool recoverySuggested;
  final int? daysAway;
  final List<AdjustmentRef> adjustments;
  final List<DayRoutine> routines;

  /// When this snapshot was received — used to tick running timers locally.
  final DateTime fetchedAt;

  /// All steps across routines, in time order (the day's timeline).
  List<DayStep> get timeline {
    final steps = [for (final r in routines) ...r.steps];
    final far = DateTime(9999);
    final order = {for (final (i, s) in steps.indexed) s.id: i};
    steps.sort((a, b) {
      final byTime = (a.scheduledAt ?? far).compareTo(b.scheduledAt ?? far);
      return byTime != 0 ? byTime : order[a.id]!.compareTo(order[b.id]!);
    });
    return steps;
  }

  DayStep? get focus => focusId == null ? null : stepById(focusId!);

  DayStep? stepById(String id) {
    for (final r in routines) {
      for (final s in r.steps) {
        if (s.id == id) return s;
      }
    }
    return null;
  }

  DayRoutine? routineOf(DayStep step) {
    for (final r in routines) {
      if (r.id == step.routineInstanceId) return r;
    }
    return null;
  }

  /// Steps that come after the focus and are still open ("Up next").
  List<DayStep> get upNext => timeline.where((s) => s.status == StepStatus.pending && s.id != focusId).toList();

  AdjustmentRef? get dayAdjustment {
    for (final a in adjustments) {
      if (a.kind == 'minimum_day' || a.kind == 'recovery') return a;
    }
    return null;
  }

  /// Minutes of essentials — what a Minimum Day would ask for.
  int get minimumDayMinutes {
    var total = 0.0;
    for (final s in timeline) {
      if (s.isEssential && s.status.isOpen && s.targetKind == TargetKind.duration) {
        total += s.minimumValue ?? s.targetValue;
      }
    }
    return total.round();
  }

  /// Replaces one step (used for optimistic updates).
  Day withStep(DayStep step) => Day(
    date: date,
    isToday: isToday,
    mode: mode,
    progress: progress,
    focusId: focusId,
    timing: timing,
    shiftedMinutes: shiftedMinutes,
    timingInstanceId: timingInstanceId,
    recoverySuggested: recoverySuggested,
    daysAway: daysAway,
    adjustments: adjustments,
    fetchedAt: fetchedAt,
    routines: [
      for (final r in routines)
        DayRoutine(
          id: r.id,
          routineId: r.routineId,
          name: r.name,
          category: r.category,
          scheduledStart: r.scheduledStart,
          finishBy: r.finishBy,
          isAdHoc: r.isAdHoc,
          adjustment: r.adjustment,
          steps: [for (final s in r.steps) s.id == step.id ? step : s],
        ),
    ],
  );
}

/// Live elapsed time for a running step, ticking from the snapshot.
int liveElapsedSeconds(DayStep step, DateTime fetchedAt, DateTime now) =>
    step.isRunning ? step.elapsedSeconds + now.difference(fetchedAt).inSeconds.clamp(0, 86400) : step.elapsedSeconds;

class AdaptationItem {
  const AdaptationItem({
    required this.completionId,
    required this.title,
    required this.icon,
    required this.targetKind,
    required this.unit,
    required this.isEssential,
    required this.priority,
    required this.targetValue,
    required this.plannedValue,
    required this.kept,
  });

  final String completionId;
  final String title;
  final String icon;
  final TargetKind targetKind;
  final String unit;
  final bool isEssential;
  final StepPriority priority;
  final double targetValue;
  final double plannedValue;
  final bool kept;
}

class AdaptationPreview {
  const AdaptationPreview({
    required this.instanceId,
    required this.routineName,
    required this.isMinimum,
    required this.options,
    required this.originalMinutes,
    required this.plannedMinutes,
    required this.fits,
    required this.essentialsKept,
    required this.essentialsTotal,
    required this.items,
    required this.shiftedMinutes,
    required this.dayMode,
    this.budgetMinutes,
    this.recommended,
    this.availableMinutes,
    this.finishBy,
    this.activeAdjustment,
  });

  final String instanceId;
  final String routineName;
  final bool isMinimum;
  final int? budgetMinutes;
  final List<int> options;
  final int? recommended;
  final int shiftedMinutes;
  final int? availableMinutes;
  final DateTime? finishBy;
  final DayMode dayMode;
  final AdjustmentRef? activeAdjustment;
  final int originalMinutes;
  final int plannedMinutes;
  final bool fits;
  final int essentialsKept;
  final int essentialsTotal;
  final List<AdaptationItem> items;
}
