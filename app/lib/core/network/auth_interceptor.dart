import 'package:dio/dio.dart';

import '../errors/app_failure.dart';
import '../storage/token_storage.dart';

/// Attaches the access token and transparently refreshes it once on 401.
///
/// Extends [QueuedInterceptor] so concurrent 401s are handled one at a time:
/// the first performs the refresh, later ones notice the token already changed
/// and simply retry — a single-flight refresh without extra locking.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required TokenStorage storage,
    required Dio refreshClient,
    required Dio retryClient,
    required void Function() onSessionExpired,
  }) : _storage = storage,
       _refreshClient = refreshClient,
       _retryClient = retryClient,
       _onSessionExpired = onSessionExpired;

  static const skipAuthKey = 'mwendo.skipAuth';
  static const _retriedKey = 'mwendo.retried';
  static const refreshPath = '/auth/refresh/';

  final TokenStorage _storage;
  final Dio _refreshClient;
  final Dio _retryClient;
  final void Function() _onSessionExpired;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra[skipAuthKey] != true) {
      final tokens = await _storage.read();
      if (tokens != null) options.headers['Authorization'] = 'Bearer ${tokens.access}';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final request = err.requestOptions;
    final isAuthRetryable =
        err.response?.statusCode == 401 && request.extra[skipAuthKey] != true && request.extra[_retriedKey] != true;
    if (!isAuthRetryable) return handler.next(err);

    final tokens = await _storage.read();
    if (tokens == null) return handler.next(err);

    final sentHeader = request.headers['Authorization'];
    var access = tokens.access;

    // Another queued request may already have refreshed the token.
    if (sentHeader == 'Bearer ${tokens.access}') {
      final refreshed = await _refresh(tokens.refresh);
      if (refreshed == null) {
        await _storage.clear();
        _onSessionExpired();
        return handler.next(
          DioException(requestOptions: request, response: err.response, error: const UnauthorizedFailure()),
        );
      }
      access = refreshed.access;
    }

    request.headers['Authorization'] = 'Bearer $access';
    request.extra[_retriedKey] = true;
    try {
      handler.resolve(await _retryClient.fetch<dynamic>(request));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  Future<AuthTokens?> _refresh(String refreshToken) async {
    try {
      final response = await _refreshClient.post<Map<String, dynamic>>(refreshPath, data: {'refresh': refreshToken});
      final data = response.data;
      final access = data?['access'] as String?;
      if (access == null) return null;
      final tokens = AuthTokens(access: access, refresh: (data?['refresh'] as String?) ?? refreshToken);
      await _storage.write(tokens);
      return tokens;
    } on DioException {
      return null;
    }
  }
}
