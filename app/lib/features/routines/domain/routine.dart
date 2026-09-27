enum RoutineCategory {
  morning('Morning'),
  work('Focus'),
  evening('Evening'),
  rest('Rest'),
  other('Other');

  const RoutineCategory(this.label);
  final String label;

  static RoutineCategory parse(String v) => values.firstWhere((e) => e.name == v, orElse: () => other);
}

enum RoutineStatus { active, paused, archived }

/// How a step is measured.
enum TargetKind {
  duration('Minutes'),
  count('Amount'),
  check('Just do it');

  const TargetKind(this.label);
  final String label;

  static TargetKind parse(String v) => values.firstWhere((e) => e.name == v, orElse: () => check);
}

enum StepPriority {
  core('Core'),
  standard('Standard'),
  optional('Optional');

  const StepPriority(this.label);
  final String label;

  static StepPriority parse(String v) => values.firstWhere((e) => e.name == v, orElse: () => standard);
}

/// One step of a routine template.
class RoutineStep {
  const RoutineStep({
    required this.title,
    this.id,
    this.position = 0,
    this.description = '',
    this.icon = 'check_circle',
    this.targetKind = TargetKind.duration,
    this.targetValue = 10,
    this.minimumValue,
    this.unit = '',
    this.isEssential = false,
    this.priority = StepPriority.standard,
    this.habitId,
  });

  final String? id;
  final int position;
  final String title;
  final String description;
  final String icon;
  final TargetKind targetKind;
  final double targetValue;
  final double? minimumValue;
  final String unit;
  final bool isEssential;
  final StepPriority priority;
  final String? habitId;

  bool get isTimed => targetKind == TargetKind.duration;

  RoutineStep copyWith({bool? isEssential}) => RoutineStep(
    id: id,
    position: position,
    title: title,
    description: description,
    icon: icon,
    targetKind: targetKind,
    targetValue: targetValue,
    minimumValue: minimumValue,
    unit: unit,
    isEssential: isEssential ?? this.isEssential,
    priority: priority,
    habitId: habitId,
  );
}

class RoutineStats {
  const RoutineStats({
    required this.steps,
    required this.totalMinutes,
    required this.essentialSteps,
    required this.minimumMinutes,
    this.consistency,
  });

  static const empty = RoutineStats(steps: 0, totalMinutes: 0, essentialSteps: 0, minimumMinutes: 0);

  final int steps;
  final int totalMinutes;
  final int essentialSteps;
  final int minimumMinutes;

  /// Average completion over the last 14 days; null until there's history.
  final double? consistency;
}

/// Routine fields shared by create and edit (no steps).
class RoutineDetails {
  const RoutineDetails({
    required this.name,
    required this.category,
    required this.daysOfWeek,
    this.description = '',
    this.startMinutes,
    this.finishByMinutes,
  });

  final String name;
  final RoutineCategory category;
  final String description;

  /// ISO weekdays, Monday = 1.
  final List<int> daysOfWeek;

  /// Minutes since midnight.
  final int? startMinutes;
  final int? finishByMinutes;
}

class Routine {
  const Routine({
    required this.id,
    required this.details,
    required this.status,
    required this.steps,
    required this.stats,
  });

  final String id;
  final RoutineDetails details;
  final RoutineStatus status;
  final List<RoutineStep> steps;
  final RoutineStats stats;

  String get name => details.name;
  bool get isActive => status == RoutineStatus.active;
}

/// A generated, unsaved routine proposal (onboarding).
class RoutineDraft {
  const RoutineDraft({required this.details, required this.steps});

  final RoutineDetails details;
  final List<RoutineStep> steps;

  int get totalMinutes => steps.where((s) => s.isTimed).fold(0, (sum, s) => sum + s.targetValue.round());
}
