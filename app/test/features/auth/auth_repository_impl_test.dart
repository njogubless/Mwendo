import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mwendo/core/errors/app_failure.dart';
import 'package:mwendo/core/network/api_client.dart';
import 'package:mwendo/core/storage/token_storage.dart';
import 'package:mwendo/features/auth/data/auth_repository_impl.dart';

import '../../helpers/fake_http.dart';

void main() {
  late InMemoryTokenStorage storage;
  late FakeHttpAdapter adapter;
  late AuthRepositoryImpl repository;

  setUp(() {
    storage = InMemoryTokenStorage();
    adapter = FakeHttpAdapter((_) async => jsonBody({}, 200));
    repository = AuthRepositoryImpl(
      client: buildApiClient(
        baseUrl: 'http://api.test/api/v1',
        storage: storage,
        onSessionExpired: () {},
        adapter: adapter,
      ),
      storage: storage,
    );
  });

  test('sign in stores tokens and maps the user', () async {
    adapter.responder = (_) async => jsonBody({'access': 'a', 'refresh': 'r', 'user': userJson()}, 200);

    final user = await repository.signIn(email: 'zawadi@example.com', password: 'pw');

    expect(user.displayName, 'Zawadi');
    expect(user.dayStartTime, const Duration(hours: 4));
    expect((await storage.read())!.refresh, 'r');
    expect(adapter.requests.single.headers.containsKey('Authorization'), isFalse);
  });

  test('register surfaces field errors', () async {
    adapter.responder = (_) async => jsonBody(
      errorEnvelope(
        'validation_error',
        'Some details need another look.',
        details: {
          'email': ['An account with this email already exists.'],
        },
      ),
      400,
    );

    await expectLater(
      repository.register(email: 'a@b.co', password: 'pw', displayName: 'A', timezone: 'UTC'),
      throwsA(isA<ValidationFailure>().having((f) => f.firstErrorFor('email'), 'email', isNotNull)),
    );
    expect(await storage.read(), isNull);
  });

  test('restoreSession returns null without tokens and makes no request', () async {
    expect(await repository.restoreSession(), isNull);
    expect(adapter.requests, isEmpty);
  });

  test('restoreSession clears tokens when the session is rejected', () async {
    await storage.write(const AuthTokens(access: 'a', refresh: 'r'));
    adapter.responder = (_) async => jsonBody({}, 401);

    expect(await repository.restoreSession(), isNull);
    expect(await storage.read(), isNull);
  });

  test('restoreSession keeps tokens and throws when offline', () async {
    await storage.write(const AuthTokens(access: 'a', refresh: 'r'));
    adapter.responder = (options) async =>
        throw DioException(requestOptions: options, type: DioExceptionType.connectionError);

    await expectLater(repository.restoreSession(), throwsA(isA<NetworkFailure>()));
    expect(await storage.read(), isNotNull);
  });

  test('sign out clears local tokens even if the server is unreachable', () async {
    await storage.write(const AuthTokens(access: 'a', refresh: 'r'));
    adapter.responder = (options) async =>
        throw DioException(requestOptions: options, type: DioExceptionType.connectionError);

    await repository.signOut();

    expect(await storage.read(), isNull);
  });
}
