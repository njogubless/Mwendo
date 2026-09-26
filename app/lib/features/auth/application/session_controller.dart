import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/network/session_events.dart';
import '../data/auth_repository_impl.dart';
import '../domain/user.dart';

sealed class SessionState {
  const SessionState();
}

/// App start, before the stored session has been checked.
final class SessionRestoring extends SessionState {
  const SessionRestoring();
}

/// A stored session exists but couldn't be verified (e.g. offline at launch).
/// The user stays signed in on the device; the splash screen offers a retry.
final class SessionUnavailable extends SessionState {
  const SessionUnavailable(this.failure);

  final AppFailure failure;
}

final class SignedOut extends SessionState {
  const SignedOut({this.reason});

  /// Set when the session ended on its own (expired), so UI can explain gently.
  final String? reason;
}

final class SignedIn extends SessionState {
  const SignedIn(this.user);

  final User user;
}

/// Owns who is signed in. Screens call its methods; routing reacts to its state.
class SessionController extends Notifier<SessionState> {
  StreamSubscription<void>? _expiredSub;

  @override
  SessionState build() {
    _expiredSub = ref.watch(sessionEventsProvider).expired.listen((_) {
      state = const SignedOut(reason: 'Your session ended. Please sign in again.');
    });
    ref.onDispose(() => _expiredSub?.cancel());
    Future.microtask(restore);
    return const SessionRestoring();
  }

  Future<void> restore() async {
    state = const SessionRestoring();
    try {
      final user = await ref.read(authRepositoryProvider).restoreSession();
      state = user == null ? const SignedOut() : SignedIn(user);
    } on AppFailure catch (failure) {
      // Post-MVP offline-first will restore the cached user here instead.
      state = SessionUnavailable(failure);
    }
  }

  /// Throws [AppFailure] so forms can render field errors.
  Future<void> signIn({required String email, required String password}) async {
    final user = await ref.read(authRepositoryProvider).signIn(email: email, password: password);
    state = SignedIn(user);
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    required String timezone,
  }) async {
    final user = await ref
        .read(authRepositoryProvider)
        .register(email: email, password: password, displayName: displayName, timezone: timezone);
    state = SignedIn(user);
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = const SignedOut();
  }

  /// Replace the cached user after profile/onboarding updates.
  void updateUser(User user) {
    if (state is SignedIn) state = SignedIn(user);
  }
}

final sessionControllerProvider = NotifierProvider<SessionController, SessionState>(SessionController.new);
