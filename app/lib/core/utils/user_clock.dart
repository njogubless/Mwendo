import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// The user's notion of "now" and "today" (Dart port of backend `apps/core/clock.py`).
///
/// A person's day starts at [dayStart] in their [timezone]: someone awake at 01:00 with a 04:00 day start is
/// still in yesterday. Dates are ISO `YYYY-MM-DD` strings so they double as stable document ids.
class UserClock {
  UserClock({required String timezone, required this.dayStart, DateTime Function()? now})
    : location = _location(timezone),
      _now = now ?? DateTime.now;

  final tz.Location location;
  final Duration dayStart;
  final DateTime Function() _now;

  static tz.Location _location(String name) {
    if (!tz.timeZoneDatabase.isInitialized) tz_data.initializeTimeZones();
    try {
      return tz.getLocation(name.isEmpty ? 'UTC' : name);
    } on Object {
      return tz.UTC;
    }
  }

  /// The current instant (UTC).
  DateTime now() => _now().toUtc();

  tz.TZDateTime localNow() => tz.TZDateTime.from(now(), location);

  /// Today's ISO date for this user, honouring their day start.
  String today() {
    final local = localNow();
    final sinceMidnight = Duration(hours: local.hour, minutes: local.minute, seconds: local.second);
    var day = DateTime.utc(local.year, local.month, local.day);
    if (sinceMidnight < dayStart) day = day.subtract(const Duration(days: 1));
    return isoDay(day);
  }

  /// The UTC instant for a wall-clock time ([minutes] since midnight) on the user's local [date].
  DateTime? atLocal(String date, int? minutes) {
    if (minutes == null) return null;
    final d = parseIsoDay(date);
    return tz.TZDateTime(location, d.year, d.month, d.day, minutes ~/ 60, minutes % 60).toUtc();
  }

  /// The local hour of [instant] (used for part-of-day insights).
  int localHour(DateTime instant) => tz.TZDateTime.from(instant, location).hour;
}

String isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// `YYYY-MM-DD` → a UTC midnight [DateTime] (safe for day arithmetic).
DateTime parseIsoDay(String v) {
  final p = v.split('-').map(int.parse).toList();
  return DateTime.utc(p[0], p[1], p[2]);
}

/// ISO weekday (Monday = 1) of an ISO date.
int isoWeekday(String date) => parseIsoDay(date).weekday;

String addDays(String date, int days) => isoDay(parseIsoDay(date).add(Duration(days: days)));

int daysBetween(String from, String to) => parseIsoDay(to).difference(parseIsoDay(from)).inDays;
