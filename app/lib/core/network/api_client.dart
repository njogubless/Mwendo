import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../storage/token_storage.dart';
import 'auth_interceptor.dart';
import 'session_events.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => SecureTokenStorage());

BaseOptions _options(String baseUrl) => BaseOptions(
  baseUrl: baseUrl,
  connectTimeout: const Duration(seconds: 10),
  receiveTimeout: const Duration(seconds: 20),
  sendTimeout: const Duration(seconds: 20),
  contentType: Headers.jsonContentType,
  responseType: ResponseType.json,
);

/// Adds a per-request `X-Request-ID` for correlating client and server logs.
class RequestIdInterceptor extends Interceptor {
  final _random = Random.secure();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers.putIfAbsent('X-Request-ID', () {
      return List.generate(16, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    });
    handler.next(options);
  }
}

Dio buildApiClient({
  required String baseUrl,
  required TokenStorage storage,
  required void Function() onSessionExpired,
  HttpClientAdapter? adapter,
}) {
  final plain = Dio(_options(baseUrl))..interceptors.add(RequestIdInterceptor());
  final dio = Dio(_options(baseUrl));
  if (adapter != null) {
    plain.httpClientAdapter = adapter;
    dio.httpClientAdapter = adapter;
  }
  dio.interceptors.addAll([
    RequestIdInterceptor(),
    AuthInterceptor(storage: storage, refreshClient: plain, retryClient: plain, onSessionExpired: onSessionExpired),
  ]);
  return dio;
}

final apiClientProvider = Provider<Dio>((ref) {
  return buildApiClient(
    baseUrl: Env.apiBaseUrl,
    storage: ref.watch(tokenStorageProvider),
    onSessionExpired: ref.watch(sessionEventsProvider).notifyExpired,
  );
});
