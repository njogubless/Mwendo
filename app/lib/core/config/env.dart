import 'package:flutter/foundation.dart';

/// Build-time configuration via `--dart-define` (never hardcode secrets here).
///
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8001/api/v1   # Android emulator
abstract final class Env {
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8001/api/v1');

  /// Enables developer-only routes such as the design-system gallery.
  static const showDevTools = bool.fromEnvironment('MWENDO_DEV_TOOLS', defaultValue: !kReleaseMode);
}
