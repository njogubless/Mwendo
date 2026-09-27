import 'package:flutter/material.dart';

/// "45 min", "1 h", "1 h 30 min".
String formatMinutes(num minutes) {
  final m = minutes.round();
  if (m < 60) return '$m min';
  final h = m ~/ 60;
  final rest = m % 60;
  return rest == 0 ? '$h h' : '$h h $rest min';
}

/// "12", "2.5" — drops needless decimals.
String formatAmount(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);

/// Clock time respecting the device's 12/24h setting.
String formatClock(BuildContext context, int minutesSinceMidnight) => MaterialLocalizations.of(context).formatTimeOfDay(
  TimeOfDay(hour: minutesSinceMidnight ~/ 60, minute: minutesSinceMidnight % 60),
  alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
);

String formatDateTimeClock(BuildContext context, DateTime t) => formatClock(context, t.hour * 60 + t.minute);

String formatElapsed(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

const weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "Every day", "Weekdays", "Mon, Wed, Fri".
String formatDays(List<int> days) {
  final sorted = [...days]..sort();
  if (sorted.length == 7) return 'Every day';
  if (sorted.join() == '12345') return 'Weekdays';
  if (sorted.join() == '67') return 'Weekends';
  if (sorted.isEmpty) return 'Not scheduled';
  return sorted.map((d) => weekdayShort[d - 1]).join(', ');
}

String percent(double ratio) => '${(ratio * 100).round()}%';
