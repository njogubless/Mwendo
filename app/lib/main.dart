import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/config/server_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Debug builds remember the server picked in the developer Server screen.
  final saved = Env.canSwitchServer ? await ServerStore().read() : null;
  runApp(
    ProviderScope(
      // No silent automatic retries: failures surface immediately with a calm "Try again" (see ErrorView).
      retry: (_, _) => null,
      overrides: [savedServerProvider.overrideWithValue(saved)],
      child: const MwendoApp(),
    ),
  );
}
