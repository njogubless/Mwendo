import '../../features/auth/application/session_controller.dart';
import 'routes.dart';

/// Pure routing guard, unit-tested in isolation from go_router.
///
/// Returns the path to redirect to, or null to allow [location].
String? resolveRedirect({required SessionState session, required String location, bool devToolsEnabled = false}) {
  if (devToolsEnabled && location.startsWith('/dev/')) return null;

  return switch (session) {
    SessionRestoring() || SessionUnavailable() => location == Routes.splash ? null : Routes.splash,
    SignedOut() => Routes.public.contains(location) ? null : Routes.welcome,
    SignedIn(:final user) when !user.isOnboarded => location == Routes.onboarding ? null : Routes.onboarding,
    SignedIn() =>
      location == Routes.splash || location == Routes.onboarding || Routes.public.contains(location)
          ? Routes.today
          : null,
  };
}
