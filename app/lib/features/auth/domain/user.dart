import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';

/// The signed-in person. `timezone` and `dayStartTime` define "today".
@freezed
abstract class User with _$User {
  const factory User({
    required String id,
    required String email,
    required String displayName,
    required String timezone,

    /// Local wall-clock time the user's day begins, e.g. 04:00.
    required Duration dayStartTime,
    required bool isOnboarded,
  }) = _User;

  const User._();

  /// Name to greet with; falls back to the email's local part.
  String get greetingName => displayName.trim().isNotEmpty ? displayName.trim() : email.split('@').first;
}
