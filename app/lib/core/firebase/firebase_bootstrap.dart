import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// Starts Firebase before the first frame (Firebase backend only).
///
/// Uses the generated `firebase_options.dart` when present, otherwise the platform config files
/// (`google-services.json` / `GoogleService-Info.plist`). Returns an error message instead of throwing so
/// `main` can show a calm setup screen rather than crash.
Future<String?> initFirebase() async {
  try {
    if (Firebase.apps.isNotEmpty) return null;
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } on UnsupportedError {
      // Placeholder options: rely on the native config files.
      await Firebase.initializeApp();
    }
    // Offline-first: reads fall back to the device cache and writes queue until the connection returns.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    return null;
  } on Object catch (e) {
    debugPrint('Firebase failed to start: $e');
    return 'Firebase is not configured for this build yet.\n\n'
        'Run `flutterfire configure` in app/ (or add google-services.json), then rebuild. '
        'See docs/engineering/firebase.md.\n\n$e';
  }
}
