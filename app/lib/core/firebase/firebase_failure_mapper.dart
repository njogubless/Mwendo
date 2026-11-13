import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../errors/app_failure.dart';

/// Translates Firebase errors into [AppFailure]s with the same field names the Django API uses
/// (`email`, `password`, `current_password`, …) so forms render them without knowing the backend.
AppFailure mapFirebaseFailure(Object error) {
  if (error is AppFailure) return error;
  if (error is TimeoutException) return const TimeoutFailure();
  if (error is FirebaseAuthException) return _auth(error);
  if (error is FirebaseException) return _firestore(error);
  return UnknownFailure(cause: error);
}

/// Runs [call] and rethrows anything as an [AppFailure].
Future<T> guardFirebase<T>(Future<T> Function() call) async {
  try {
    return await call();
  } catch (e) {
    throw mapFirebaseFailure(e);
  }
}

AppFailure _auth(FirebaseAuthException e) => switch (e.code) {
  'invalid-credential' || 'wrong-password' || 'user-not-found' || 'invalid-login-credentials' =>
    const ValidationFailure(userMessage: "That email and password don't match.", code: 'invalid_credentials'),
  'email-already-in-use' => const ValidationFailure(
    userMessage: 'Please check the highlighted fields.',
    fieldErrors: {
      'email': ['An account with this email already exists.'],
    },
  ),
  'invalid-email' => const ValidationFailure(
    userMessage: 'Please check the highlighted fields.',
    fieldErrors: {
      'email': ['Enter a valid email address.'],
    },
  ),
  'weak-password' => const ValidationFailure(
    userMessage: 'Please check the highlighted fields.',
    fieldErrors: {
      'password': ['Choose a stronger password.'],
    },
  ),
  'user-disabled' => const UnauthorizedFailure(userMessage: 'This account is turned off.', code: 'user_disabled'),
  'requires-recent-login' || 'user-token-expired' => const UnauthorizedFailure(code: 'requires_recent_login'),
  'too-many-requests' => const RateLimitedFailure(),
  'network-request-failed' => const NetworkFailure(),
  _ => ServerFailure(code: e.code),
};

AppFailure _firestore(FirebaseException e) => switch (e.code) {
  'unavailable' => const NetworkFailure(),
  'deadline-exceeded' => const TimeoutFailure(),
  'permission-denied' || 'unauthenticated' => UnauthorizedFailure(
    userMessage: 'Mwendo could not open your data. Please sign in again.',
    code: e.code,
  ),
  'not-found' => const NotFoundFailure(),
  'resource-exhausted' => const RateLimitedFailure(),
  _ => ServerFailure(code: e.code),
};
