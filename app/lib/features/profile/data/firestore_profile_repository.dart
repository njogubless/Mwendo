import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../../core/errors/app_failure.dart';
import '../../../core/firebase/firebase_failure_mapper.dart';
import '../../../core/firebase/firestore_scope.dart';
import '../../auth/data/firebase_user_mapper.dart';
import '../../auth/domain/user.dart';
import '../domain/profile_repository.dart';

/// Profile on Firestore (`users/{uid}`), password changes and account deletion through Firebase Auth.
class FirestoreProfileRepository implements ProfileRepository {
  FirestoreProfileRepository(this.scope);

  final FirestoreScope scope;

  Future<User> _read() async {
    final snap = await scope.userDoc.get();
    return userFromProfile(scope.uid, snap.data() ?? const {}, fallbackEmail: scope.auth.currentUser?.email);
  }

  Future<void> _write(Map<String, Object?> fields) async {
    final ctx = await scope.context();
    final batch = scope.db.batch()..set(scope.userDoc, fields, SetOptions(merge: true));
    await scope.commit(batch, offline: ctx.offline);
  }

  @override
  Future<User> update({String? displayName, String? timezone, int? dayStartMinutes}) => guardFirebase(() async {
    if (timezone != null) validateTimezone(timezone);
    if (displayName != null && displayName.trim().length > 80) {
      throw const ValidationFailure(
        userMessage: 'Please check the highlighted fields.',
        fieldErrors: {
          'display_name': ['Keep your name under 80 characters.'],
        },
      );
    }
    await _write({
      'displayName': ?displayName?.trim(),
      'timezone': ?timezone,
      'dayStartMinutes': ?dayStartMinutes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return _read();
  });

  @override
  Future<void> savePreferences({required List<String> focusAreas, required String structure, int? wakeMinutes}) =>
      guardFirebase(
        () => _write({
          'preferences': {'focusAreas': focusAreas, 'structure': structure, 'wakeMinutes': wakeMinutes},
        }),
      );

  @override
  Future<User> completeOnboarding() => guardFirebase(() async {
    final current = await _read();
    if (!current.isOnboarded) await _write({'onboardedAt': writeTime(scope.now())});
    return _read();
  });

  @override
  Future<void> changePassword({required String current, required String next}) => guardFirebase(() async {
    validateNewPassword(next, field: 'new_password');
    final user = await _reauthenticate(current, field: 'current_password');
    await user.updatePassword(next);
  });

  @override
  Future<void> deleteAccount(String password) => guardFirebase(() async {
    final user = await _reauthenticate(password, field: 'password');
    for (final collection in [scope.days, scope.routines, scope.goals, scope.habits]) {
      final docs = (await collection.get()).docs;
      for (var i = 0; i < docs.length; i += 400) {
        final batch = scope.db.batch();
        for (final d in docs.skip(i).take(400)) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
    }
    await scope.userDoc.delete();
    await user.delete();
  });

  Future<fb.User> _reauthenticate(String password, {required String field}) async {
    final user = scope.auth.currentUser;
    if (user == null || user.email == null) throw const UnauthorizedFailure();
    try {
      await user.reauthenticateWithCredential(fb.EmailAuthProvider.credential(email: user.email!, password: password));
      return user;
    } on fb.FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential' || e.code == 'invalid-login-credentials') {
        throw ValidationFailure(
          userMessage: "That's not your current password.",
          fieldErrors: {
            field: ["That's not your current password."],
          },
        );
      }
      rethrow;
    }
  }
}
