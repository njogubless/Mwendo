import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/errors/app_failure.dart';
import '../../../core/utils/json.dart';
import '../domain/user.dart';

/// Default day start (04:00), as in the Django `User` model.
const defaultDayStartMinutes = 4 * 60;

/// `users/{uid}` profile document → [User].
User userFromProfile(String uid, Json data, {String? fallbackEmail}) => User(
  id: uid,
  email: (data['email'] as String?) ?? fallbackEmail ?? '',
  displayName: (data['displayName'] as String?) ?? '',
  timezone: (data['timezone'] as String?) ?? 'UTC',
  dayStartTime: Duration(minutes: (data['dayStartMinutes'] as num?)?.toInt() ?? defaultDayStartMinutes),
  isOnboarded: data['onboardedAt'] != null,
);

/// Same rule as the backend's password validators' minimum length.
void validateNewPassword(String password, {String field = 'password'}) {
  if (password.length < 8) {
    throw ValidationFailure(
      userMessage: 'Please check the highlighted fields.',
      fieldErrors: {
        field: ['Use at least 8 characters.'],
      },
    );
  }
}

/// Rejects names that aren't IANA time zones (backend `validate_timezone`).
void validateTimezone(String name) {
  if (!tz.timeZoneDatabase.isInitialized) tz_data.initializeTimeZones();
  try {
    tz.getLocation(name);
  } on Object {
    throw ValidationFailure(
      userMessage: 'Please check the highlighted fields.',
      fieldErrors: {
        'timezone': ['"$name" is not a known time zone.'],
      },
    );
  }
}
