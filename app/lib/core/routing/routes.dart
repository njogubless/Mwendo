/// Route paths. Use these constants/builders instead of string literals.
abstract final class Routes {
  static const splash = '/splash';
  static const welcome = '/welcome';
  static const signIn = '/auth/sign-in';
  static const register = '/auth/register';
  static const forgotPassword = '/auth/forgot';
  static const onboarding = '/onboarding';

  /// The onboarding generator for existing users ("Suggest routines for me").
  static const suggestRoutines = '/suggest-routines';

  static const today = '/today';
  static const routines = '/routines';
  static const goals = '/goals';
  static const insights = '/insights';
  static const profile = '/profile';

  static String adapt(String instanceId) => '/today/adapt/$instanceId';
  static String routine(String id) => '/routines/$id';
  static String goal(String id) => '/goals/$id';

  static const devGallery = '/dev/gallery';

  static const public = {welcome, signIn, register, forgotPassword};
}
