/// Route paths as constants so screens can navigate without magic
/// strings. Kept in its own file (rather than inside app_router.dart)
/// so feature screens can reference route paths without importing the
/// router itself — app_router.dart importing today_screen.dart (to
/// build routes) while today_screen.dart also imports app_router.dart
/// (for these constants) would be a circular import.
abstract class AppRoutes {
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const onboarding = '/onboarding';
  static const today = '/today';
  static const goals = '/goals';
  static const subcategories = '/subcategories';
  static const settings = '/settings';
  static const life = '/life';
  static const history = '/history';
  static const insights = '/insights';
}
