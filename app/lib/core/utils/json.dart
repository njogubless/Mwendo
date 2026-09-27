/// Small, strict helpers for reading API JSON in data-layer mappers.
typedef Json = Map<String, dynamic>;

double toDouble(Object? v) => v is num ? v.toDouble() : double.parse(v.toString());

double? toDoubleOrNull(Object? v) => v == null ? null : toDouble(v);

DateTime? toDateTimeOrNull(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();

DateTime toDate(Object? v) {
  final parts = (v as String).split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2]);
}

List<Json> jsonList(Object? v) => (v as List<dynamic>? ?? const []).cast<Json>();

/// `HH:MM[:SS]` → minutes since midnight.
int? parseClock(Object? v) {
  if (v == null) return null;
  final p = (v as String).split(':').map(int.parse).toList();
  return p[0] * 60 + (p.length > 1 ? p[1] : 0);
}

String formatClockForApi(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
