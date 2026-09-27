import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'env.dart';

/// Persists the developer-picked server (debug builds only). Kept apart from auth tokens.
class ServerStore {
  ServerStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'mwendo.server';
  final FlutterSecureStorage _storage;

  Future<String?> read() async {
    try {
      return await _storage.read(key: _key);
    } on Object {
      return null; // A storage hiccup must never block app start.
    }
  }

  Future<void> write(String? url) => url == null ? _storage.delete(key: _key) : _storage.write(key: _key, value: url);
}

final serverStoreProvider = Provider<ServerStore>((ref) => ServerStore());

/// The saved server loaded before the app starts (overridden in `main`).
final savedServerProvider = Provider<String?>((ref) => null);

/// The API base URL every request uses. Changing it rebuilds the HTTP client.
class ApiBaseUrlController extends Notifier<String> {
  @override
  String build() =>
      resolveApiBaseUrl(defined: Env.definedApiUrl, release: kReleaseMode, saved: ref.watch(savedServerProvider));

  /// Switch server (debug only). Pass null to go back to the default.
  Future<void> set(String? url) async {
    if (!Env.canSwitchServer) return;
    final value = url == null ? null : normaliseApiUrl(url);
    await ref.read(serverStoreProvider).write(value);
    state = resolveApiBaseUrl(defined: Env.definedApiUrl, release: kReleaseMode, saved: value);
  }
}

final apiBaseUrlProvider = NotifierProvider<ApiBaseUrlController, String>(ApiBaseUrlController.new);
