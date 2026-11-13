import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/backend.dart';
import 'core/config/env.dart';
import 'core/config/server_config.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/mw_tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backend = BackendConfig.selected;
  if (backend == Backend.firebase) {
    final problem = await initFirebase();
    if (problem != null) return runApp(_SetupNeeded(problem));
  }
  // Debug builds remember the server picked in the developer Server screen (Django backend only).
  final saved = backend == Backend.django && Env.canSwitchServer ? await ServerStore().read() : null;
  runApp(
    ProviderScope(
      // No silent automatic retries: failures surface immediately with a calm "Try again" (see ErrorView).
      retry: (_, _) => null,
      overrides: [savedServerProvider.overrideWithValue(saved)],
      child: const MwendoApp(),
    ),
  );
}

/// Shown instead of the app when Firebase isn't configured for this build (developer setup only).
class _SetupNeeded extends StatelessWidget {
  const _SetupNeeded(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildTheme(Brightness.light),
    darkTheme: buildTheme(Brightness.dark),
    home: Builder(
      builder: (context) => Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(MwSpace.lg),
            child: Text(message, style: context.text.bodyMedium),
          ),
        ),
      ),
    ),
  );
}
