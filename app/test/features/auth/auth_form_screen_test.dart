import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mwendo/core/errors/app_failure.dart';
import 'package:mwendo/core/theme/app_theme.dart';
import 'package:mwendo/core/utils/device_timezone.dart';
import 'package:mwendo/features/auth/data/auth_repository_impl.dart';
import 'package:mwendo/features/auth/domain/auth_repository.dart';
import 'package:mwendo/features/auth/domain/user.dart';
import 'package:mwendo/features/auth/presentation/auth_form_screen.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repository;

  setUp(() {
    repository = _MockAuthRepository();
    when(() => repository.restoreSession()).thenAnswer((_) async => null);
  });

  Future<void> pump(WidgetTester tester, AuthMode mode) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
          deviceTimezoneProvider.overrideWith((ref) async => 'Africa/Nairobi'),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: AuthFormScreen(mode: mode),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('validates locally before calling the server', (tester) async {
    await pump(tester, AuthMode.signIn);

    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(find.text('Please enter your email.'), findsOneWidget);
    expect(find.text('Please enter your password.'), findsOneWidget);
    verifyNever(
      () => repository.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets('register sends the device time zone and shows server field errors inline', (tester) async {
    when(
      () => repository.register(
        email: any(named: 'email'),
        password: any(named: 'password'),
        displayName: any(named: 'displayName'),
        timezone: any(named: 'timezone'),
      ),
    ).thenThrow(
      const ValidationFailure(
        userMessage: 'Some details need another look.',
        fieldErrors: {
          'email': ['An account with this email already exists.'],
        },
      ),
    );
    await pump(tester, AuthMode.register);

    await tester.enterText(find.widgetWithText(TextFormField, 'What should we call you?'), 'Zawadi');
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'zawadi@example.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'steady-river-42');
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('An account with this email already exists.'), findsOneWidget);
    verify(
      () => repository.register(
        email: 'zawadi@example.com',
        password: 'steady-river-42',
        displayName: 'Zawadi',
        timezone: 'Africa/Nairobi',
      ),
    ).called(1);
  });

  testWidgets('non-field failures show a calm general message', (tester) async {
    when(
      () => repository.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(const NetworkFailure());
    await pump(tester, AuthMode.signIn);

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'zawadi@example.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'whatever');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.textContaining("couldn't reach Mwendo"), findsOneWidget);
  });

  testWidgets('successful sign in updates the session', (tester) async {
    when(
      () => repository.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer(
      (_) async => const User(
        id: '1',
        email: 'zawadi@example.com',
        displayName: 'Zawadi',
        timezone: 'UTC',
        dayStartTime: Duration(hours: 4),
        isOnboarded: false,
      ),
    );
    await pump(tester, AuthMode.signIn);

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), ' zawadi@example.com ');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'pw');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    verify(() => repository.signIn(email: 'zawadi@example.com', password: 'pw')).called(1);
  });
}
