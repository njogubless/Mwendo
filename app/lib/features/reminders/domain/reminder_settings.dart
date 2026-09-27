/// What the user wants to be reminded about. `enabled == null` means we haven't asked yet.
class ReminderSettings {
  const ReminderSettings({
    this.enabled,
    this.stepStarts = true,
    this.routineSoon = true,
    this.shiftedNudge = true,
    this.windDown = true,
    this.windDownMinutes = 21 * 60,
    this.milestones = true,
  });

  factory ReminderSettings.fromJson(Map<String, dynamic> j) => ReminderSettings(
    enabled: j['enabled'] as bool?,
    stepStarts: j['stepStarts'] as bool? ?? true,
    routineSoon: j['routineSoon'] as bool? ?? true,
    shiftedNudge: j['shiftedNudge'] as bool? ?? true,
    windDown: j['windDown'] as bool? ?? true,
    windDownMinutes: j['windDownMinutes'] as int? ?? 21 * 60,
    milestones: j['milestones'] as bool? ?? true,
  );

  final bool? enabled;
  final bool stepStarts;
  final bool routineSoon;
  final bool shiftedNudge;
  final bool windDown;

  /// Minutes since midnight for the evening wind-down note.
  final int windDownMinutes;
  final bool milestones;

  bool get isOn => enabled ?? false;

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'stepStarts': stepStarts,
    'routineSoon': routineSoon,
    'shiftedNudge': shiftedNudge,
    'windDown': windDown,
    'windDownMinutes': windDownMinutes,
    'milestones': milestones,
  };

  ReminderSettings copyWith({
    bool? enabled,
    bool? stepStarts,
    bool? routineSoon,
    bool? shiftedNudge,
    bool? windDown,
    int? windDownMinutes,
    bool? milestones,
  }) => ReminderSettings(
    enabled: enabled ?? this.enabled,
    stepStarts: stepStarts ?? this.stepStarts,
    routineSoon: routineSoon ?? this.routineSoon,
    shiftedNudge: shiftedNudge ?? this.shiftedNudge,
    windDown: windDown ?? this.windDown,
    windDownMinutes: windDownMinutes ?? this.windDownMinutes,
    milestones: milestones ?? this.milestones,
  );
}
