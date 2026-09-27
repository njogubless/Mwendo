import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/notifications/notifications_service.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/application/session_controller.dart';
import 'features/reminders/application/reminders_controller.dart';

class MwendoApp extends ConsumerStatefulWidget {
  const MwendoApp({super.key});

  @override
  ConsumerState<MwendoApp> createState() => _MwendoAppState();
}

class _MwendoAppState extends ConsumerState<MwendoApp> {
  @override
  void initState() {
    super.initState();
    final router = ref.read(routerProvider);
    final notifications = ref.read(notificationsServiceProvider)..onOpen = router.go;
    // Opened by tapping a reminder while the app was closed: go where it points once signed in.
    unawaited(
      notifications
          .init()
          .then((_) async {
            final route = await notifications.takeLaunchRoute();
            if (route != null) router.go(route);
          })
          .catchError((Object _) {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    if (session is SignedIn) {
      ref.watch(reminderSyncProvider);
    }
    ref.listen(sessionControllerProvider, (_, next) {
      // Reminders belong to the signed-in person.
      if (next is SignedOut) unawaited(ref.read(notificationsServiceProvider).cancelAll().catchError((Object _) {}));
    });
    return MaterialApp.router(
      title: 'Mwendo',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
