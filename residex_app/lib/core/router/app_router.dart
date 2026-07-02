import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/shared/presentation/screens/auth/login_screen.dart';
import '../../features/shared/presentation/screens/auth/register_screen.dart';
import '../../features/shared/presentation/screens/auth/new_splash_screen.dart';
import '../../features/landlord/presentation/screens/landlord_home_screen.dart';
import '../../features/landlord/presentation/screens/1-Command/landlord_command_screen.dart';
import '../../features/landlord/presentation/screens/2-Finance/landlord_finance_screen.dart';
import '../../features/landlord/presentation/screens/3-REX/landlord_rex_ai_screen.dart';
import '../../features/landlord/presentation/screens/3-REX/rex_ai_main_menu_screen.dart';
import '../../features/landlord/presentation/screens/4-Portfolio/landlord_portfolio_screen.dart';
import '../../features/landlord/presentation/screens/5-Community/landlord_community_screen.dart';
import '../../features/landlord/presentation/screens/1-Command/sub/landlord_system_health_screen.dart';
import '../../features/landlord/presentation/screens/1-Command/sub/landlord_maintenance_screen.dart';
import '../../features/landlord/presentation/screens/3-REX/sub/documind_screen.dart';
import '../../features/landlord/presentation/screens/3-REX/sub/lease_generator_screen.dart';
import '../../features/landlord/presentation/screens/3-REX/sub/maintenance_ai_screen.dart';
import '../../features/landlord/presentation/screens/3-REX/sub/revenue_analytics_screen.dart';
import '../../features/landlord/presentation/screens/4-Portfolio/sub/tenant_list_screen.dart';
import '../../features/landlord/presentation/screens/4-Portfolio/sub/tenant_score_detail_screen.dart';
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
    
    // Landlord routes
    static const String landlordCommand = '/landlord-command';
    static const String landlordFinance = '/landlord-finance';
    static const String landlordRexAI = '/landlord-rex-ai';
    static const String landlordRexMainMenu = '/landlord-rex-menu';
    static const String landlordPortfolio = '/landlord-portfolio';
    static const String landlordCommunityScreen = '/landlord-community';
    static const String landlordSystemHealth = '/landlord-system-health';
    static const String landlordMaintenanceConsole = '/landlord-maintenance-console';
    static const String landlordDocuMind = '/landlord-documind';
    static const String landlordLeaseGenerator = '/landlord-lease-generator';
    static const String landlordMaintenanceAI = '/landlord-maintenance-ai';
    static const String landlordRevenueAnalytics = '/landlord-revenue-analytics';
    static const String landlordTenantList = '/landlord-tenant-list';
    static const String landlordTenantScoreDetail = '/landlord-tenant-score-detail';
  }

  /// Custom page transition with slide animation
  CustomTransitionPage<T> buildPageWithSlideTransition<T>({
   required BuildContext context,
   required GoRouterState state,
   required Widget child,
 }) {

  final _enterBegin = NavDirection.slideFromRight
       ? const Offset(1.0, 0)
       : const Offset(-1.0, 0);
   final _exitEnd = NavDirection.slideFromRight
       ? const Offset(-0.3, 0)
       : const Offset(0.3, 0);
   NavDirection.slideFromRight = true; // reset so all future pushes default to right

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

       final exitAnim = CurvedAnimation(
         parent: secondaryAnimation,
         curve: smoothCurve,
       );

       return SlideTransition(
         position: Tween<Offset>(
           begin: Offset.zero,
           end: _exitEnd,
         ).animate(exitAnim),
         child: SlideTransition(
           position: Tween<Offset>(
             begin: _enterBegin,
             end: Offset.zero,
           ).animate(enterAnim),
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

    // Re-run redirect whenever auth state changes
    ref.listen<AsyncValue<AppUser?>>(authStateProvider, (_, __) {
      notifier.notify();
    });

    return GoRouter(
      initialLocation: AppRoutes.splash,
      refreshListenable: notifier,
      redirect: (context, state) {
        // Dev bypass — allow direct navigation without Firebase auth
        final devRole = ref.read(devBypassProvider);
        if (devRole != null) return null;

        final authState = ref.read(authStateProvider);

        // Still loading Firebase — stay on current screen (splash shows)
        if (authState.isLoading) return null;

        final user = authState.value;
        final isLoggedIn = user != null;
        final loc = state.matchedLocation;

        final isOnAuthRoute = loc == AppRoutes.splash ||
                              loc == AppRoutes.login ||
                              loc == AppRoutes.register;

        // Not logged in + trying to access app → redirect to login
        if (!isLoggedIn && !isOnAuthRoute) return AppRoutes.login;

        // Already logged in + on auth screen → skip to landlord dashboard
        if (isLoggedIn && isOnAuthRoute) {
          return AppRoutes.landlordDashboard;
        }

        return null; // No redirect needed
      },
      routes: [
      // Splash screen with fade transition
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
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.register,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const RegisterScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
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

      // ══════════════════════════════════════════════════════════════════
      // LANDLORD ROUTES
      // ══════════════════════════════════════════════════════════════════

      GoRoute(
        path: AppRoutes.landlordCommand,
        pageBuilder: (context, state) => buildPageWithSlideTransition(
          context: context,
          state: state,
          child: const LandlordCommandScreen(),
        ),
      ),

      GoRoute(
        path: AppRoutes.landlordFinance,
        pageBuilder: (context, state) => buildPageWithSlideTransition(
          context: context,
          state: state,
          child: const LandlordFinanceScreen(),
        ),
      ),

      GoRoute(
        path: AppRoutes.landlordRexAI,
        pageBuilder: (context, state) => buildPageWithSlideTransition(
          context: context,
          state: state,
          child: const LandlordRexAIScreen(),
        ),
      ),

      GoRoute(
        path: AppRoutes.landlordRexMainMenu,
        pageBuilder: (context, state) => buildPageWithSlideTransition(
          context: context,
          state: state,
          child: const RexAIMainMenuScreen(),
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

      GoRoute(
        path: AppRoutes.landlordCommunityScreen,
        pageBuilder: (context, state) => buildPageWithSlideTransition(
          context: context,
          state: state,
          child: const LandlordCommunityScreen(),
        ),
      ),

      GoRoute(
        path: AppRoutes.landlordSystemHealth,
        pageBuilder: (context, state) {
          final healthScore = state.extra as int? ?? 85;
          return buildPageWithSlideTransition(
            context: context,
            state: state,
            child: LandlordSystemHealthScreen(healthScore: healthScore),
          );
        },
      ),

      GoRoute(
        path: AppRoutes.landlordMaintenanceConsole,
        pageBuilder: (context, state) => buildPageWithSlideTransition(
          context: context,
          state: state,
          child: const LandlordMaintenanceScreen(),
        ),
      ),

      GoRoute(
        path: AppRoutes.landlordDocuMind,
        pageBuilder: (context, state) => buildPageWithSlideTransition(
          context: context,
          state: state,
          child: const DocuMindScreen(),
        ),
      ),

      GoRoute(
        path: AppRoutes.landlordLeaseGenerator,
        pageBuilder: (context, state) => buildPageWithSlideTransition(
          context: context,
          state: state,
          child: const LeaseGeneratorScreen(),
        ),
      ),

      GoRoute(
        path: AppRoutes.landlordMaintenanceAI,
        pageBuilder: (context, state) => buildPageWithSlideTransition(
          context: context,
          state: state,
          child: const MaintenanceAIScreen(),
        ),
      ),

      GoRoute(
        path: AppRoutes.landlordRevenueAnalytics,
        pageBuilder: (context, state) => buildPageWithSlideTransition(
          context: context,
          state: state,
          child: const RevenueAnalyticsScreen(),
        ),
      ),

      GoRoute(
        path: AppRoutes.landlordTenantList,
        pageBuilder: (context, state) {
          final propertyId = state.extra as String?;
          return buildPageWithSlideTransition(
            context: context,
            state: state,
            child: TenantListScreen(propertyId: propertyId),
          );
        },
      ),

      GoRoute(
        path: AppRoutes.landlordTenantScoreDetail,
        pageBuilder: (context, state) {
          final tenant = state.extra as Tenant;
          return buildPageWithSlideTransition(
            context: context,
            state: state,
            child: TenantScoreDetailScreen(tenant: tenant),
          );
        },
      ),


    ], // routes
    ); // GoRouter
  }); // appRouterProvide

