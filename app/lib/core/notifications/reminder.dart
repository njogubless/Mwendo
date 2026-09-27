enum ReminderKind { stepStart, routineSoon, shifted, windDown, milestone }

/// One notification to show now or at [at]. [route] opens when tapped.
class Reminder {
  const Reminder({
    required this.id,
    required this.kind,
    required this.at,
    required this.title,
    required this.body,
    this.route,
  });

  /// Stable per logical reminder, so rescheduling replaces rather than duplicates.
  final int id;
  final ReminderKind kind;
  final DateTime at;
  final String title;
  final String body;
  final String? route;

  static int idFor(String key) => key.hashCode & 0x7fffffff;

  @override
  String toString() => 'Reminder($kind, $at, $title)';
}
