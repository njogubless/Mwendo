import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/app_failure.dart';
import '../utils/json.dart';
import '../utils/user_clock.dart';
import 'firebase_failure_mapper.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

/// "Now" for the device-side rules. Overridden in tests.
final clockNowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final firestoreScopeProvider = Provider<FirestoreScope>(
  (ref) => FirestoreScope(
    db: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
    now: ref.watch(clockNowProvider),
  ),
);

/// The signed-in user's slice of Firestore. Everything lives under `users/{uid}` so the security rules can
/// say "only the owner" in one line (the Firestore form of `OwnedModelViewSet`).
///
/// ```
/// users/{uid}                       profile: displayName, email, timezone, dayStartMinutes, onboardedAt, preferences
/// users/{uid}/routines/{routineId}  template with embedded `steps` (ordered)
/// users/{uid}/days/{YYYY-MM-DD}     one materialised day: routine runs, step outcomes, adjustments
/// users/{uid}/goals/{goalId}        goal with embedded `measurements`
/// users/{uid}/habits/{habitId}
/// ```
class FirestoreScope {
  FirestoreScope({required this.db, required this.auth, DateTime Function()? now}) : _now = now ?? DateTime.now;

  final FirebaseFirestore db;
  final FirebaseAuth auth;
  final DateTime Function() _now;

  /// The current instant (UTC), from the injectable clock.
  DateTime now() => _now().toUtc();

  String get uid {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedFailure();
    return user.uid;
  }

  DocumentReference<Json> get userDoc => db.collection('users').doc(uid);

  CollectionReference<Json> get routines => userDoc.collection('routines');
  CollectionReference<Json> get days => userDoc.collection('days');
  CollectionReference<Json> get goals => userDoc.collection('goals');
  CollectionReference<Json> get habits => userDoc.collection('habits');

  /// The profile plus a [UserClock] built from its time zone and day start.
  Future<UserContext> context() async {
    final snap = await userDoc.get();
    final data = snap.data() ?? const <String, dynamic>{};
    return UserContext(
      profile: data,
      clock: UserClock(
        timezone: (data['timezone'] as String?) ?? 'UTC',
        dayStart: Duration(minutes: (data['dayStartMinutes'] as int?) ?? 240),
        now: _now,
      ),
      offline: snap.metadata.isFromCache,
    );
  }

  /// Commits [batch]. Online, it waits for the server so rule failures surface as [AppFailure]s.
  /// Offline (the last read came from the device cache) it returns at once: Firestore keeps the change in
  /// its local cache, so the app carries on, and syncs it when the connection returns.
  Future<void> commit(WriteBatch batch, {required bool offline}) async {
    final write = batch.commit();
    if (offline) {
      unawaited(write.catchError((Object e) => debugPrint('Queued Firestore write failed: $e')));
      return;
    }
    await guardFirebase(() => write);
  }
}

class UserContext {
  const UserContext({required this.profile, required this.clock, required this.offline});

  final Json profile;
  final UserClock clock;

  /// True when the profile came from the device cache (no connection).
  final bool offline;
}

DateTime? readTime(Object? v) => switch (v) {
  final Timestamp t => t.toDate().toUtc(),
  final DateTime d => d.toUtc(),
  final String s => DateTime.parse(s).toUtc(),
  _ => null,
};

Timestamp? writeTime(DateTime? v) => v == null ? null : Timestamp.fromDate(v.toUtc());

/// Nested Firestore maps can arrive as `Map<Object?, Object?>`; copy them into [Json].
Json readMap(Object? v) => v == null ? <String, dynamic>{} : Map<String, dynamic>.from(v as Map);

List<Json> readMaps(Object? v) => [for (final e in (v as List<dynamic>?) ?? const []) readMap(e)];
