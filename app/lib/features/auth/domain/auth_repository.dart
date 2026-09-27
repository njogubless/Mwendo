import 'user.dart';

/// Authentication boundary. Implementations throw `AppFailure` subclasses.
abstract interface class AuthRepository {
  /// Returns the user for a persisted session, or null when signed out.
  Future<User?> restoreSession();

  Future<User> signIn({required String email, required String password});

  Future<User> register({
    required String email,
    required String password,
    required String displayName,
    required String timezone,
  });

  /// Always clears local credentials, even if the server call fails.
  Future<void> signOut();

  /// Emails a 6-digit code. Succeeds whether or not the email has an account.
  Future<void> requestPasswordReset(String email);

  /// Sets a new password with the emailed code and signs in.
  Future<User> confirmPasswordReset({required String email, required String code, required String newPassword});
}
