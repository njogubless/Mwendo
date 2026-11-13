import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mwendo/core/notifications/notifications_service.dart';
import 'package:mwendo/core/notifications/reminder.dart';
import 'package:mwendo/core/theme/app_theme.dart';
import 'package:mwendo/features/auth/data/auth_repository_impl.dart';
import 'package:mwendo/features/auth/domain/auth_repository.dart';

class _NoSessionAuth extends Mock implements AuthRepository {}

/// Records notifications instead of touching the platform plugin.
class FakeNotificationsService implements NotificationsService {
  FakeNotificationsService({this.grant = true});

  final bool grant;
  List<Reminder> scheduled = [];
  final shown = <Reminder>[];
  int permissionRequests = 0;

  @override
  bool get isSupported => true;
  @override
  set onOpen(void Function(String route)? handler) {}
  @override
  Future<void> init() async {}
  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return grant;
  }

  @override
  Future<void> replaceScheduled(List<Reminder> reminders) async => scheduled = reminders;
  @override
  Future<void> showNow(Reminder reminder) async => shown.add(reminder);
  @override
  Future<void> cancelAll() async => scheduled = [];
  @override
  Future<String?> takeLaunchRoute() async => null;
}

/// Pumps a screen inside ProviderScope + themed MaterialApp at phone size.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
  Size size = const Size(390, 1400),
  NotificationsService? notifications,
  AuthRepository? auth,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // In-memory secure storage (guide dismissals, server choice) instead of the platform plugin.
  FlutterSecureStorage.setMockInitialValues({});
  final signedOut = _NoSessionAuth();
  when(signedOut.restoreSession).thenAnswer((_) async => null);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authRepositoryProvider.overrideWithValue(auth ?? signedOut),
        notificationsServiceProvider.overrideWithValue(notifications ?? FakeNotificationsService()),
        ...overrides,
      ],
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(body: screen),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}
