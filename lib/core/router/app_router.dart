import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/auth/presentation/sign_up_screen.dart';
import '../../features/goals/presentation/goals_list_screen.dart';
import '../../features/history/presentation/calendar_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/subcategories/presentation/subcategories_screen.dart';
import '../../features/today/presentation/today_screen.dart';
import 'app_routes.dart';
import 'scaffold_with_nav_bar.dart';

export 'app_routes.dart';

/// Placeholder screens for routes whose real feature isn't built yet.
/// Each one is replaced in its own milestone — keeping them here (rather
/// than leaving the route undefined) lets the router itself be fully
/// wired and testable now.
class _PlaceholderScreen extends StatelessWidget {
  final String label;
  const _PlaceholderScreen(this.label);

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('$label — coming soon')));
  }
}

/// Re-evaluates the router's redirect logic whenever the auth stream
/// emits, without rebuilding the whole router. go_router requires a
/// [Listenable] for this; Riverpod's stream provider doesn't give us
/// one directly, so we bridge it.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    ref.listen(authStateChangesProvider, (_, __) => notifyListeners());
  }
}

/// The root navigator. Routes that should cover the bottom nav bar
/// entirely (sign-in, sign-up, onboarding, and the full-screen Goals
/// management flow) are attached here via `parentNavigatorKey` rather
/// than living inside a tab's own nested navigator.
final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthChangeNotifier(ref);
  ref.onDispose(authNotifier.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.today,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final authState = ref.read(authStateChangesProvider);
      final user = authState.value;
      final isSignedIn = user != null;

      // While the very first auth check is still in flight, don't
      // redirect yet — avoids a flash to the sign-in screen on cold
      // start for an already-authenticated user.
      if (authState.isLoading) return null;

      final isOnAuthScreen =
          state.matchedLocation == AppRoutes.signIn ||
          state.matchedLocation == AppRoutes.signUp;
      final isOnOnboardingScreen =
          state.matchedLocation == AppRoutes.onboarding;

      if (!isSignedIn && !isOnAuthScreen) {
        return AppRoutes.signIn;
      }

      if (isSignedIn && isOnAuthScreen) {
        return AppRoutes.today;
      }

      // A signed-in user who hasn't finished onboarding gets routed
      // there regardless of where they were headed — except away from
      // it once they're done, so a stale deep link back to /onboarding
      // doesn't trap a returning user.
      if (isSignedIn && !user.hasCompletedOnboarding && !isOnOnboardingScreen) {
        return AppRoutes.onboarding;
      }
      if (isSignedIn && user.hasCompletedOnboarding && isOnOnboardingScreen) {
        return AppRoutes.today;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.signIn,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const OnboardingScreen(),
      ),

      // Full-screen goal management, reachable from any tab (e.g. the
      // "Manage goals" button on Today) but deliberately NOT one of the
      // four tabs itself — attaching it to the root navigator makes it
      // cover the bottom nav bar instead of rendering awkwardly on top
      // of a tab's own content with the bar still showing underneath.
      GoRoute(
        path: AppRoutes.goals,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const GoalsListScreen(),
      ),
      GoRoute(
        path: AppRoutes.subcategories,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SubcategoriesScreen(),
      ),

      // The four persistent tabs. Each branch gets its own nested
      // navigator and preserves its own stack/scroll state when the
      // user switches away and back.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ScaffoldWithNavBar(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'today'),
            routes: [
              GoRoute(
                path: AppRoutes.today,
                builder: (context, state) => const TodayScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'life'),
            routes: [
              GoRoute(
                path: AppRoutes.life,
                builder: (context, state) => const _PlaceholderScreen('Life'),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'history'),
            routes: [
              GoRoute(
                path: AppRoutes.history,
                builder: (context, state) => const CalendarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'insights'),
            routes: [
              GoRoute(
                path: AppRoutes.insights,
                builder: (context, state) =>
                    const _PlaceholderScreen('Insights'),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
