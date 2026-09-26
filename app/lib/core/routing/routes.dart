/// Route paths. Use these constants instead of string literals.
abstract final class Routes {
  static const splash = '/splash';
  static const welcome = '/welcome';
  static const signIn = '/auth/sign-in';
  static const register = '/auth/register';

  static const today = '/today';
  static const routines = '/routines';
  static const goals = '/goals';
  static const insights = '/insights';
  static const profile = '/profile';

  static const devGallery = '/dev/gallery';

  static const public = {welcome, signIn, register};
}
