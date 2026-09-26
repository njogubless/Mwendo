import 'package:flutter_test/flutter_test.dart';
import 'package:mwendo/core/errors/app_failure.dart';
import 'package:mwendo/core/routing/redirect.dart';
import 'package:mwendo/core/routing/routes.dart';
import 'package:mwendo/features/auth/application/session_controller.dart';
import 'package:mwendo/features/auth/domain/user.dart';

const _user = User(
  id: '1',
  email: 'a@b.co',
  displayName: 'A',
  timezone: 'UTC',
  dayStartTime: Duration(hours: 4),
  isOnboarded: true,
);

void main() {
  group('while restoring', () {
    test('everything goes to splash', () {
      expect(resolveRedirect(session: const SessionRestoring(), location: Routes.today), Routes.splash);
      expect(resolveRedirect(session: const SessionRestoring(), location: Routes.splash), isNull);
    });

    test('an unavailable session stays on splash (no forced sign-out)', () {
      expect(
        resolveRedirect(session: const SessionUnavailable(NetworkFailure()), location: Routes.today),
        Routes.splash,
      );
    });
  });

  group('signed out', () {
    test('private routes go to welcome', () {
      expect(resolveRedirect(session: const SignedOut(), location: Routes.today), Routes.welcome);
      expect(resolveRedirect(session: const SignedOut(), location: Routes.splash), Routes.welcome);
    });

    test('public routes are allowed', () {
      for (final route in Routes.public) {
        expect(resolveRedirect(session: const SignedOut(), location: route), isNull);
      }
    });
  });

  group('signed in', () {
    test('splash and public routes go to today', () {
      expect(resolveRedirect(session: const SignedIn(_user), location: Routes.splash), Routes.today);
      expect(resolveRedirect(session: const SignedIn(_user), location: Routes.signIn), Routes.today);
    });

    test('app routes are allowed', () {
      expect(resolveRedirect(session: const SignedIn(_user), location: Routes.routines), isNull);
    });
  });

  test('dev routes are only reachable when dev tools are enabled', () {
    expect(resolveRedirect(session: const SignedOut(), location: Routes.devGallery), Routes.welcome);
    expect(resolveRedirect(session: const SignedOut(), location: Routes.devGallery, devToolsEnabled: true), isNull);
  });
}
