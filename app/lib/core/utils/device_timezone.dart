import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

/// The device's IANA time zone (e.g. `Africa/Nairobi`). Falls back to UTC if
/// the platform can't tell us; the user can correct it in Profile.
final deviceTimezoneProvider = FutureProvider<String>((ref) async {
  try {
    return (await FlutterTimezone.getLocalTimezone()).identifier;
  } on Object {
    return 'UTC';
  }
});
