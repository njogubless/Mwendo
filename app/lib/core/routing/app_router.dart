import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/session_controller.dart';
import '../../features/auth/presentation/auth_form_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/dev/gallery_screen.dart';
import '../../features/goals/presentation/goals_screen.dart';
import '../../features/insights/presentation/insights_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/routines/presentation/routines_screen.dart';
import '../../features/today/presentation/today_screen.dart';
import '../config/env.dart';
import 'adaptive_shell.dart';
import 'redirect.dart';
import 'routes.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Re-evaluates redirects whenever the session changes, without rebuilding the router.
  final refresh = ValueNotifier<SessionState>(ref.read(sessionControllerProvider));
  ref
    ..listen(sessionControllerProvider, (_, next) => refresh.value = next)
    ..onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    debugLogDiagnostics: kDebugMode,
    redirect: (context, state) => resolveRedirect(
      session: ref.read(sessionControllerProvider),
      location: state.uri.path,
      devToolsEnabled: Env.showDevTools,
    ),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.welcome, builder: (_, _) => const WelcomeScreen()),
      GoRoute(
        path: Routes.signIn,
        builder: (_, _) => const AuthFormScreen(mode: AuthMode.signIn),
      ),
      GoRoute(
        path: Routes.register,
        builder: (_, _) => const AuthFormScreen(mode: AuthMode.register),
      ),
      if (Env.showDevTools) GoRoute(path: Routes.devGallery, builder: (_, _) => const GalleryScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AdaptiveShell(navigationShell: shell),
        branches: [
          _branch(Routes.today, const TodayScreen()),
          _branch(Routes.routines, const RoutinesScreen()),
          _branch(Routes.goals, const GoalsScreen()),
          _branch(Routes.insights, const InsightsScreen()),
          _branch(Routes.profile, const ProfileScreen()),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

StatefulShellBranch _branch(String path, Widget screen) => StatefulShellBranch(
  routes: [
    GoRoute(
      path: path,
      pageBuilder: (_, _) => NoTransitionPage(child: screen),
    ),
  ],
);
