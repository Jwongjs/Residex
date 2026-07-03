import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/shared/presentation/screens/auth/login_screen.dart';
import '../../features/shared/presentation/screens/auth/register_screen.dart';
import '../../features/shared/presentation/screens/auth/new_splash_screen.dart';
import '../../features/landlord/presentation/screens/landlord_home_screen.dart';
import '../../features/landlord/presentation/screens/4-Portfolio/landlord_portfolio_screen.dart';
import '../../features/shared/domain/entities/users/app_user.dart';
import 'nav_direction.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/shared/presentation/providers/auth_providers.dart';

/// Bridges Riverpod auth state to GoRouter's refreshListenable
class _RouterNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// App route names
class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String landlordDashboard = '/landlord-dashboard';
  static const String landlordPortfolio = '/landlord-portfolio';
}

/// Custom page transition with slide animation
CustomTransitionPage<T> buildPageWithSlideTransition<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  final enterBegin = NavDirection.slideFromRight
      ? const Offset(1.0, 0)
      : const Offset(-1.0, 0);
  final exitEnd = NavDirection.slideFromRight
      ? const Offset(-0.3, 0)
      : const Offset(0.3, 0);
  NavDirection.slideFromRight = true;

  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const smoothCurve = Cubic(0.2, 0.8, 0.2, 1.0);
      final enterAnim = CurvedAnimation(
        parent: animation,
        curve: smoothCurve,
        reverseCurve: smoothCurve.flipped,
      );
      final exitAnim = CurvedAnimation(parent: secondaryAnimation, curve: smoothCurve);
      return SlideTransition(
        position: Tween<Offset>(begin: Offset.zero, end: exitEnd).animate(exitAnim),
        child: SlideTransition(
          position: Tween<Offset>(begin: enterBegin, end: Offset.zero).animate(enterAnim),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.5, end: 1.0).animate(enterAnim),
            child: child,
          ),
        ),
      );
    },
  );
}

/// App router configuration
final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier();
  ref.onDispose(notifier.dispose);

  ref.listen<AsyncValue<AppUser?>>(authStateProvider, (_, __) {
    notifier.notify();
  });

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: notifier,
    redirect: (context, state) {
      final devRole = ref.read(devBypassProvider);
      if (devRole != null) return null;

      final authState = ref.read(authStateProvider);
      if (authState.isLoading) return null;

      final user = authState.value;
      final isLoggedIn = user != null;
      final loc = state.matchedLocation;

      final isOnAuthRoute = loc == AppRoutes.splash ||
          loc == AppRoutes.login ||
          loc == AppRoutes.register;

      if (!isLoggedIn && !isOnAuthRoute) return AppRoutes.login;
      if (isLoggedIn && isOnAuthRoute) return AppRoutes.landlordDashboard;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (context, state) => buildPageWithSlideTransition(
          context: context,
          state: state,
          child: const NewSplashScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.register,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const RegisterScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.landlordDashboard,
        pageBuilder: (context, state) => buildPageWithSlideTransition(
          context: context,
          state: state,
          child: const LandlordHomeScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.landlordPortfolio,
        pageBuilder: (context, state) => buildPageWithSlideTransition(
          context: context,
          state: state,
          child: const LandlordPortfolioScreen(),
        ),
      ),
    ],
  );
});
