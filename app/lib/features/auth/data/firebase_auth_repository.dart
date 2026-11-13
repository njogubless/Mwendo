import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../../core/errors/app_failure.dart';
import '../../../core/firebase/firebase_failure_mapper.dart';
import '../../../core/firebase/firestore_scope.dart';
import '../domain/auth_repository.dart';
import '../domain/user.dart';
import 'firebase_user_mapper.dart';

/// Email/password accounts with Firebase Auth; the profile lives in `users/{uid}`.
///
/// Password reset differs from Django (D-019 → D-031): Firebase emails a *link* to its own reset page, so
/// [confirmPasswordReset] isn't used — the Forgot password screen tells the user to follow the link.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this.scope);

  final FirestoreScope scope;

  fb.FirebaseAuth get _auth => scope.auth;

  @override
  Future<User?> restoreSession() => guardFirebase(() async {
    // Wait for Firebase to restore the persisted session before deciding.
    final user =
        _auth.currentUser ??
        await _auth.authStateChanges().first.timeout(const Duration(seconds: 5), onTimeout: () => null);
    if (user == null) return null;
    return _profile(user);
  });

  @override
  Future<User> signIn({required String email, required String password}) => guardFirebase(() async {
    final cred = await _auth.signInWithEmailAndPassword(email: email.trim().toLowerCase(), password: password);
    return _profile(cred.user!);
  });

  @override
  Future<User> register({
    required String email,
    required String password,
    required String displayName,
    required String timezone,
  }) => guardFirebase(() async {
    validateNewPassword(password);
    validateTimezone(timezone);
    final normalised = email.trim().toLowerCase();
    final cred = await _auth.createUserWithEmailAndPassword(email: normalised, password: password);
    final user = cred.user!;
    if (displayName.trim().isNotEmpty) unawaited(user.updateDisplayName(displayName.trim()).catchError((Object _) {}));
    await scope.db.collection('users').doc(user.uid).set({
      'email': normalised,
      'displayName': displayName.trim(),
      'timezone': timezone,
      'dayStartMinutes': defaultDayStartMinutes,
      'onboardedAt': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return _profile(user);
  });

  /// Reads the profile, creating a default one for accounts made outside the app (e.g. the Firebase console).
  Future<User> _profile(fb.User user) async {
    final doc = scope.db.collection('users').doc(user.uid);
    final snap = await doc.get();
    final data = snap.data();
    if (data != null) return userFromProfile(user.uid, data, fallbackEmail: user.email);
    final created = {
      'email': user.email?.toLowerCase() ?? '',
      'displayName': user.displayName ?? '',
      'timezone': 'UTC',
      'dayStartMinutes': defaultDayStartMinutes,
      'onboardedAt': null,
      'createdAt': FieldValue.serverTimestamp(),
    };
    await doc.set(created);
    return userFromProfile(user.uid, created);
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on Object {
      // Signing out locally must never fail.
    }
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
    } on fb.FirebaseAuthException catch (e) {
      // Same as Django: succeed whether or not the email has an account.
      if (e.code == 'user-not-found') return;
      throw mapFirebaseFailure(e);
    }
  }

  @override
  Future<User> confirmPasswordReset({required String email, required String code, required String newPassword}) =>
      throw const ConflictFailure(
        userMessage: 'Open the link in the email we sent to choose a new password, then sign in.',
        code: 'reset_by_link',
      );
}
