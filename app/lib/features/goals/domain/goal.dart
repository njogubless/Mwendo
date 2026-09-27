enum GoalStatus {
  active('Active'),
  paused('Paused'),
  achieved('Achieved'),
  archived('Archived');

  const GoalStatus(this.label);
  final String label;
}

class LinkedStep {
  const LinkedStep({required this.id, required this.title, required this.routineId});

  final String id;
  final String title;
  final String routineId;
}

/// A habit under a goal, with how often it happened in the last 7 days.
class HabitSummary {
  const HabitSummary({
    required this.id,
    required this.title,
    required this.perWeek,
    required this.daysDone,
    required this.daysPlanned,
    required this.weeklyTarget,
    required this.linkedSteps,
    required this.frequencyTimes,
  });

  final String id;
  final String title;

  /// true = "N times a week", false = daily.
  final bool perWeek;
  final int frequencyTimes;
  final int daysDone;
  final int daysPlanned;
  final int weeklyTarget;
  final List<LinkedStep> linkedSteps;

  String get frequencyLabel => perWeek ? '$frequencyTimes× a week' : 'Every day';
}

class Measurement {
  const Measurement({required this.id, required this.value, required this.recordedOn, required this.note});

  final String id;
  final double value;
  final DateTime recordedOn;
  final String note;
}

class GoalDraft {
  const GoalDraft({required this.title, this.description = '', this.targetValue, this.unit = '', this.targetDate});

  final String title;
  final String description;
  final double? targetValue;
  final String unit;
  final DateTime? targetDate;
}

class Goal {
  const Goal({
    required this.id,
    required this.draft,
    required this.status,
    required this.currentValue,
    required this.ratio,
    required this.habits,
    required this.measurements,
  });

  final String id;
  final GoalDraft draft;
  final GoalStatus status;
  final double currentValue;

  /// Share of the target reached; null for goals without a numeric target.
  final double? ratio;
  final List<HabitSummary> habits;
  final List<Measurement> measurements;

  String get title => draft.title;
  bool get hasTarget => draft.targetValue != null;
}

/// Lightweight habit for pickers (step editor).
class HabitOption {
  const HabitOption({required this.id, required this.title, this.goalId});

  final String id;
  final String title;
  final String? goalId;
}
