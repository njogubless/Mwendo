import '../../auth/domain/user.dart';

/// Account settings and onboarding answers for the signed-in user. Implementations throw `AppFailure`s.
abstract interface class ProfileRepository {
  Future<User> update({String? displayName, String? timezone, int? dayStartMinutes});
  Future<void> savePreferences({required List<String> focusAreas, required String structure, int? wakeMinutes});
  Future<User> completeOnboarding();

  /// Field errors use `current_password` and `new_password`.
  Future<void> changePassword({required String current, required String next});

  /// Deletes the account and all its data. Field errors use `password`.
  Future<void> deleteAccount(String password);
}
