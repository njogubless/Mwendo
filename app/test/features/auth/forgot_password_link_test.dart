import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mwendo/core/config/backend.dart';
import 'package:mwendo/features/auth/domain/auth_repository.dart';
import 'package:mwendo/features/auth/presentation/forgot_password_screen.dart';

import '../../helpers/pump_screen.dart';

class _MockAuth extends Mock implements AuthRepository {}

void main() {
  late _MockAuth auth;

  setUp(() {
    auth = _MockAuth();
    when(auth.restoreSession).thenAnswer((_) async => null);
    when(() => auth.requestPasswordReset(any())).thenAnswer((_) async {});
  });

  Future<void> pump(WidgetTester tester, Backend backend) => pumpScreen(
    tester,
    const ForgotPasswordScreen(),
    auth: auth,
    overrides: [backendProvider.overrideWithValue(backend)],
  );

  testWidgets('Firebase: sends a reset link and asks for no code', (tester) async {
    await pump(tester, Backend.firebase);
    await tester.enterText(find.byType(TextField), 'amani@example.com');
    await tester.tap(find.text('Send link'));
    await tester.pumpAndSettle();

    verify(() => auth.requestPasswordReset('amani@example.com')).called(1);
    expect(find.textContaining('a reset link is on its way'), findsOneWidget);
    expect(find.text('6-digit code'), findsNothing);
    expect(find.text('Back to sign in'), findsOneWidget);
  });

  testWidgets('Django: keeps the 6-digit code step', (tester) async {
    await pump(tester, Backend.django);
    await tester.enterText(find.byType(TextField), 'amani@example.com');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    expect(find.text('6-digit code'), findsOneWidget);
    expect(find.text('Set new password'), findsOneWidget);
  });
}
