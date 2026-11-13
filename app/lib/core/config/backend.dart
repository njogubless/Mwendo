import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which backend the data layer talks to (D-031).
///
/// * [firebase] — Firebase Auth + Cloud Firestore. Today's rules run on the device (the same rules as the
///   Django services, ported to Dart in `features/today/domain/engine/`). Needs no server of our own.
/// * [django] — the Django REST API in `backend/` (D-025 decides which server).
///
/// Chosen once at build time: `--dart-define=BACKEND=django` selects Django; anything else is Firebase.
/// Every repository provider switches on [backendProvider], so features never know which one is live.
enum Backend { django, firebase }

abstract final class BackendConfig {
  static const _defined = String.fromEnvironment('BACKEND');

  static Backend get selected => _defined == 'django' ? Backend.django : Backend.firebase;
}

/// Overridable in tests. Nothing else in the app reads [BackendConfig] directly.
final backendProvider = Provider<Backend>((ref) => BackendConfig.selected);
