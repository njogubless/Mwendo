import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mwendo/core/errors/app_failure.dart';
import 'package:mwendo/core/network/session_events.dart';
import 'package:mwendo/features/auth/application/session_controller.dart';
import 'package:mwendo/features/auth/data/auth_repository_impl.dart';
import 'package:mwendo/features/auth/domain/auth_repository.dart';
import 'package:mwendo/features/auth/domain/user.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

const _user = User(
  id: '1',
  email: 'zawadi@example.com',
  displayName: 'Zawadi',
  timezone: 'Africa/Nairobi',
  dayStartTime: Duration(hours: 4),
  isOnboarded: false,
);

void main() {
  late _MockAuthRepository repository;
  late ProviderContainer container;

  ProviderContainer create() {
    final c = ProviderContainer(overrides: [authRepositoryProvider.overrideWithValue(repository)]);
    addTearDown(c.dispose);
    return c;
  }

  Future<SessionState> settle() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    return container.read(sessionControllerProvider);
  }

  setUp(() => repository = _MockAuthRepository());

  test('restores a stored session', () async {
    when(() => repository.restoreSession()).thenAnswer((_) async => _user);
    container = create();

    expect(container.read(sessionControllerProvider), isA<SessionRestoring>());
    expect(await settle(), isA<SignedIn>().having((s) => s.user, 'user', _user));
  });

  test('no stored session means signed out', () async {
    when(() => repository.restoreSession()).thenAnswer((_) async => null);
    container = create();
    container.read(sessionControllerProvider);

    expect(await settle(), isA<SignedOut>());
  });

  test('offline at launch keeps the user on an unavailable state, not signed out', () async {
    when(() => repository.restoreSession()).thenThrow(const NetworkFailure());
    container = create();
    container.read(sessionControllerProvider);

    expect(await settle(), isA<SessionUnavailable>());
  });

  test('sign in success and failure', () async {
    when(() => repository.restoreSession()).thenAnswer((_) async => null);
    when(() => repository.signIn(email: 'x@y.z', password: 'bad')).thenThrow(const UnauthorizedFailure());
    when(() => repository.signIn(email: 'x@y.z', password: 'good')).thenAnswer((_) async => _user);
    container = create();
    container.read(sessionControllerProvider);
    await settle();
    final controller = container.read(sessionControllerProvider.notifier);

    await expectLater(controller.signIn(email: 'x@y.z', password: 'bad'), throwsA(isA<UnauthorizedFailure>()));
    expect(container.read(sessionControllerProvider), isA<SignedOut>());

    await controller.signIn(email: 'x@y.z', password: 'good');
    expect(container.read(sessionControllerProvider), isA<SignedIn>());
  });

  test('expiry event from the network layer signs the user out with a reason', () async {
    when(() => repository.restoreSession()).thenAnswer((_) async => _user);
    container = create();
    container.read(sessionControllerProvider);
    await settle();

    container.read(sessionEventsProvider).notifyExpired();
    final state = await settle();

    expect(state, isA<SignedOut>().having((s) => s.reason, 'reason', isNotNull));
  });

  test('sign out clears the session', () async {
    when(() => repository.restoreSession()).thenAnswer((_) async => _user);
    when(() => repository.signOut()).thenAnswer((_) async {});
    container = create();
    container.read(sessionControllerProvider);
    await settle();

    await container.read(sessionControllerProvider.notifier).signOut();

    expect(container.read(sessionControllerProvider), isA<SignedOut>());
    verify(() => repository.signOut()).called(1);
  });
}
