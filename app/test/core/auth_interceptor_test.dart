import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mwendo/core/errors/app_failure.dart';
import 'package:mwendo/core/network/api_client.dart';
import 'package:mwendo/core/storage/token_storage.dart';

import '../helpers/fake_http.dart';

void main() {
  late InMemoryTokenStorage storage;
  late FakeHttpAdapter adapter;
  late int expiredCalls;
  late Dio dio;

  setUp(() {
    storage = InMemoryTokenStorage(const AuthTokens(access: 'old-access', refresh: 'refresh-1'));
    expiredCalls = 0;
    adapter = FakeHttpAdapter((_) async => jsonBody({}, 200));
    dio = buildApiClient(
      baseUrl: 'http://api.test/api/v1',
      storage: storage,
      onSessionExpired: () => expiredCalls++,
      adapter: adapter,
    );
  });

  test('attaches bearer token and request id', () async {
    await dio.get<void>('/me/');

    final sent = adapter.requests.single;
    expect(sent.headers['Authorization'], 'Bearer old-access');
    expect(sent.headers['X-Request-ID'], isA<String>());
  });

  test('refreshes once on 401 and retries with the new token', () async {
    adapter.responder = (options) async {
      if (options.path.endsWith('/auth/refresh/')) {
        return jsonBody({'access': 'new-access', 'refresh': 'refresh-2'}, 200);
      }
      final auth = options.headers['Authorization'];
      return auth == 'Bearer new-access' ? jsonBody({'ok': true}, 200) : jsonBody({}, 401);
    };

    final response = await dio.get<Map<String, dynamic>>('/me/');

    expect(response.data, {'ok': true});
    final tokens = await storage.read();
    expect(tokens!.access, 'new-access');
    expect(tokens.refresh, 'refresh-2');
    expect(adapter.requests.where((r) => r.path.endsWith('/auth/refresh/')), hasLength(1));
  });

  test('concurrent 401s trigger a single refresh', () async {
    adapter.responder = (options) async {
      if (options.path.endsWith('/auth/refresh/')) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return jsonBody({'access': 'new-access', 'refresh': 'refresh-2'}, 200);
      }
      return options.headers['Authorization'] == 'Bearer new-access' ? jsonBody({}, 200) : jsonBody({}, 401);
    };

    await Future.wait([dio.get<void>('/a/'), dio.get<void>('/b/'), dio.get<void>('/c/')]);

    expect(adapter.requests.where((r) => r.path.endsWith('/auth/refresh/')), hasLength(1));
  });

  test('failed refresh clears tokens, signals expiry and surfaces UnauthorizedFailure', () async {
    adapter.responder = (options) async => jsonBody({}, 401);

    await expectLater(
      dio.get<void>('/me/'),
      throwsA(isA<DioException>().having((e) => e.error, 'error', isA<UnauthorizedFailure>())),
    );
    expect(await storage.read(), isNull);
    expect(expiredCalls, 1);
  });

  test('does not attempt refresh without stored tokens', () async {
    await storage.clear();
    adapter.responder = (_) async => jsonBody({}, 401);

    await expectLater(dio.get<void>('/me/'), throwsA(isA<DioException>()));
    expect(adapter.requests, hasLength(1));
    expect(expiredCalls, 0);
  });
}
