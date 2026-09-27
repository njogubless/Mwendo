import 'package:flutter/foundation.dart';

/// Which API the app talks to — decided in exactly one place ([resolveApiBaseUrl]).
///
/// Priority, highest first:
///   1. `--dart-define=API_BASE_URL=…` at build time (CI, staging/production builds). Always wins.
///   2. Release builds: [Env.productionApiUrl].
///   3. Debug/profile builds: the server picked in the in-app developer "Server" screen (remembered on the device).
///   4. Debug/profile builds: [Env.localApiUrl] (the backend on this computer).
///
/// So `flutter run` needs no flags: pick a server once in the app and it's remembered across runs.
abstract final class Env {
  /// Set at build time; empty when not provided.
  static const definedApiUrl = String.fromEnvironment('API_BASE_URL');

  /// The deployed API. Release builds use this unless API_BASE_URL is given.
  /// TODO(deploy): replace with the real production domain before the first store build.
  static const productionApiUrl = 'https://api.mwendo.app/api/v1';

  /// Optional shared staging server offered in the developer Server screen (empty = not offered).
  static const stagingApiUrl = String.fromEnvironment('STAGING_API_URL');

  /// The backend running on this computer (`runserver 0.0.0.0:8001`).
  static const localApiUrl = 'http://localhost:8001/api/v1';

  /// Android emulators reach the host computer at 10.0.2.2.
  static const emulatorApiUrl = 'http://10.0.2.2:8001/api/v1';

  /// Enables developer-only routes and tools (gallery, Server screen).
  static const showDevTools = bool.fromEnvironment('MWENDO_DEV_TOOLS', defaultValue: !kReleaseMode);

  /// Whether the server can be switched at runtime (debug builds without a build-time URL).
  static bool get canSwitchServer => !kReleaseMode && definedApiUrl.isEmpty;
}

/// Pure resolution of the API base URL (unit-tested).
String resolveApiBaseUrl({required String defined, required bool release, String? saved}) {
  if (defined.isNotEmpty) return normaliseApiUrl(defined);
  if (release) return Env.productionApiUrl;
  if (saved != null && saved.isNotEmpty) return normaliseApiUrl(saved);
  return Env.localApiUrl;
}

/// Accepts "192.168.1.5:8001", "http://host:8001", or a full ".../api/v1" URL and returns ".../api/v1".
String normaliseApiUrl(String input) {
  var url = input.trim();
  if (!url.contains('://')) url = 'http://$url';
  url = url.replaceAll(RegExp(r'/+$'), '');
  if (!url.endsWith('/api/v1')) url = '$url/api/v1';
  return url;
}
