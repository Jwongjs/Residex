import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/shared/presentation/screens/auth/login_screen.dart';
import '../../features/shared/presentation/screens/auth/register_screen.dart';
import '../../features/tenant/presentation/screens/bills/bill_dashboard_screen.dart';
import '../../features/tenant/presentation/screens/bills/bill_summary_screen.dart';
import '../../features/tenant/presentation/screens/bills/you_owe_screen.dart';
import '../../features/tenant/presentation/screens/bills/owed_to_you_screen.dart';
import '../../features/shared/presentation/screens/auth/new_splash_screen.dart';
import '../../features/tenant/presentation/screens/bills/group_bills_screen.dart';
import '../../features/tenant/presentation/screens/home/sync_hub_screen.dart';
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
import '../../features/tenant/presentation/screens/home/tenant_dashboard_screen.dart';
import '../../features/shared/domain/entities/users/app_user.dart';
import '../../features/tenant/presentation/screens/ai/rex_interface_screen.dart';
import '../../features/tenant/presentation/screens/ai/lease_sentinel_screen.dart';
import '../../features/shared/presentation/screens/community/community_board_screen.dart';
import '../../features/tenant/presentation/screens/tools/support_center_screen.dart';
import '../../features/tenant/presentation/screens/scores/score_detail_screen.dart';
import '../../features/tenant/presentation/screens/tools/rental_resume_screen.dart';
import '../../features/tenant/presentation/screens/tools/harmony_hub_screen.dart';
import '../../features/tenant/presentation/screens/chores/chore_scheduler_screen.dart';
import '../../features/tenant/presentation/screens/tools/credit_bridge_screen.dart';
import '../../features/tenant/presentation/screens/move_in/ghost_overlay_screen.dart';
import '../../features/tenant/presentation/screens/tools/property_pulse_detail_screen.dart';
import '../../features/tenant/presentation/screens/tools/rulebook_screen.dart';
import '../../features/tenant/presentation/screens/ai/fairfix_auditor_screen.dart';
import '../../features/tenant/presentation/screens/ai/lazy_logger_screen.dart';
import '../../features/shared/presentation/screens/gamification/gamification_hub_screen.dart';
import '../../features/shared/presentation/screens/maintenance/maintenance_list_screen.dart';
import '../../features/tenant/presentation/screens/tools/liquidity_screen.dart';
import '../../features/shared/presentation/screens/maintenance/create_ticket_screen.dart';
import '../../features/shared/presentation/screens/maintenance/ticket_detail_screen.dart';
import '../../features/tenant/presentation/screens/honor/honor_history_screen.dart';
import '../../features/shared/presentation/screens/users/profile_screen.dart';
import '../../features/shared/presentation/screens/users/profile_editor_screen.dart';
import 'nav_direction.dart';
import '../../features/tenant/presentation/screens/move_in/move_in_session_screen.dart';
import '../../features/tenant/presentation/screens/move_in/stewardship_protocol_screen.dart';
import '../widgets/tenants_shell.dart';
import '../../features/shared/domain/entities/groups/app_group.dart'; 
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
    static const String dashboard = '/dashboard';
    static const String selectMembers = '/select-members';
    static const String newBillOptions = '/new-bill-options';
    static const String scanCamera = '/scan-camera';
    static const String editReceipt = '/edit-receipt';
    static const String assignItems = '/assign-items';
    static const String paymentMethodChoice = '/payment-method-choice';
    static const String selectSinglePayment = '/select-single-payment';
    static const String assignPaymentMethods = '/assign-payment-methods';
    static const String billSummary = '/bill-summary';
    static const String youOwe = '/you-owe';
    static const String owedToYou = '/owed-to-you';
    static const String paymentHistory = '/payment-history';
    static const String myBills = '/my-bills';
    static const String groupBills = '/group-bills';
    static const String syncHub = '/sync-hub';
    static const String landlordDashboard = '/landlord-dashboard';
    static const String tenantDashboard = '/tenant-dashboard';
    static const String rexInterface = '/rex-interface';
    static const String leaseSentinel = '/lease-sentinel';
    static const String fairfixAuditor = '/fairfix-auditor';
    static const String community = '/community';
    static const String supportCenter = '/support-center';
    static const String paymentBreakdown = '/payment-breakdown';
    static const String propertyPulse = '/property-pulse';
    static const String landlordMaintenance = '/landlord-maintenance';
    static const String leaseSentinelLandlord = '/lease-sentinel-landlord';
    static const String lazyLogger = '/lazy-logger';
    static const String scoreDetail = '/score-detail';
    static const String rentalResume = '/rental-resume';
    static const String harmonyHub = '/harmony-hub';
    static const String choreScheduler = '/chore-scheduler';
    static const String creditBridge = '/credit-bridge';
    static const String ghostOverlay = '/ghost-mode';
    static const String moveInSession = '/move-in-session';
    static const String gamificationHub = '/gamification-hub';
    static const String rulebook = '/rulebook';
    static const String liquidity = '/liquidity';
    static const String maintenance = '/maintenance';
    static const String maintenanceCreate = '/maintenance/create';
    static const String maintenanceDetail = '/maintenance/detail';
    static const String honorHistory = '/honor-history';
    static const String stewardshipProtocol = '/stewardship-protocol';
    static const String profile = '/profile';
    static const String profileEditor = '/profile-editor';
    
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

        // Already logged in + on auth screen → skip to dashboard
        if (isLoggedIn && isOnAuthRoute) {
          return user.role == UserRole.landlord
              ? AppRoutes.landlordDashboard
              : AppRoutes.syncHub;
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
          path: '/bill-summary/:billId',
          builder: (context, state) {
            final billId = state.pathParameters['billId']!;
            return BillSummaryScreen(billId: billId);
          },
        ),
  
      GoRoute(
        path: AppRoutes.youOwe,
        pageBuilder: (context, state) => buildPageWithSlideTransition(
          context: context,
          state: state,
          child: const YouOweScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.owedToYou,
        pageBuilder: (context, state) => buildPageWithSlideTransition(
          context: context,
          state: state,
          child: const OwedToYouScreen(),
        ),
      ),
      
      GoRoute(
        path: AppRoutes.groupBills,
        pageBuilder: (context, state) {
          final group = state.extra as AppGroup;
          return buildPageWithSlideTransition(
            context: context,
            state: state,
            child: GroupBillsScreen(group: group),
          );
        },
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
    path: AppRoutes.propertyPulse,
    pageBuilder: (context, state) => buildPageWithSlideTransition(
      context: context,
      state: state,
      child: const PropertyPulseDetailScreen(),
      
    ),
  ),
  GoRoute(
    path: AppRoutes.landlordMaintenance,
    pageBuilder: (context, state) => buildPageWithSlideTransition(
      context: context,
      state: state,
      child: const _PlaceholderScreen(title: 'Maintenance'),
      
    ),
  ),
  GoRoute(
    path: AppRoutes.lazyLogger,
    pageBuilder: (context, state) => buildPageWithSlideTransition(
      context: context,
      state: state,
      child: const LazyLoggerScreen(),
      
    ),
  ),
  GoRoute(
    path: AppRoutes.leaseSentinelLandlord,
    pageBuilder: (context, state) => buildPageWithSlideTransition(
      context: context,
      state: state,
      child: const _PlaceholderScreen(title: 'Lease Sentinel'),
      
    ),
  ),

      
      GoRoute(
     path: AppRoutes.rexInterface,
     pageBuilder: (context, state) {
       final extra = state.extra;
       final initialContext = extra is String ? extra : null;
       final voiceInput = extra is Map ? extra['voiceInput'] as String? : null;
       return buildPageWithSlideTransition(
         context: context,
         state: state,
         child: RexInterfaceScreen(
           initialContext: initialContext,
           initialVoiceInput: voiceInput,
         ),
       );
     },
   ),
   
      GoRoute(
        path: AppRoutes.leaseSentinel,
        pageBuilder: (context, state) => buildPageWithSlideTransition(
          context: context,
          state: state,
          child: const LeaseSentinelScreen(),
          
        ),
      ),
      GoRoute(
        path: AppRoutes.fairfixAuditor,
        pageBuilder: (context, state) => buildPageWithSlideTransition(
          context: context,
          state: state,
          child: const FairFixAuditorScreen(),
          
        ),
      ),

      

      GoRoute(
        path: AppRoutes.paymentBreakdown,
        pageBuilder: (context, state) => buildPageWithSlideTransition(
          context: context,
          state: state,
          child: const BillDashboardScreen(), // Existing bills dashboard
          
        ),
      ),

      
      GoRoute(
        path: AppRoutes.scoreDetail,
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return buildPageWithSlideTransition(
            context: context,
            state: state,
            child: ScoreDetailScreen(
              fiscalScore: extra?['fiscalScore'] ?? 850,
              harmonyScore: extra?['harmonyScore'] ?? 750,
              initialTab: extra?['tab'] == 'harmony' ? ScoreTab.harmony : ScoreTab.fiscal,
            ),
            
          );
        },
      ),

      GoRoute(
        path: AppRoutes.rentalResume,
        pageBuilder: (context, state) {
          final user = state.extra as AppUser? ?? AppUser(
            id: 'user1',
            name: 'Ali Rahman',
            avatarInitials: 'AL',
            role: UserRole.tenant,
            fiscalScore: 850,
            honorLevel: HonorLevel.neutral,
            trustFactor: 1.0,
            syncState: SyncState.synced,
          );
          return buildPageWithSlideTransition(
            context: context,
            state: state,
            child: RentalResumeScreen(user: user),
            
          );
        },
      ),

      GoRoute(
        path: AppRoutes.harmonyHub,
        pageBuilder: (context, state) {
          final honorLevel = state.extra as int? ?? 2;
          return buildPageWithSlideTransition(
            context: context,
            state: state,
            child: HarmonyHubScreen(honorLevel: honorLevel),
            
          );
        },
      ),

      GoRoute(
        path: AppRoutes.choreScheduler,
        pageBuilder: (context, state) => buildPageWithSlideTransition(
          context: context,
          state: state,
          child: const ChoreSchedulerScreen(),
          
        ),
      ),

      GoRoute(
        path: AppRoutes.creditBridge,
        pageBuilder: (context, state) => buildPageWithSlideTransition(
          context: context,
          state: state,
          child: const CreditBridgeScreen(),
          
        ),
      ),

      GoRoute(
        path: AppRoutes.ghostOverlay,
        pageBuilder: (context, state) => buildPageWithSlideTransition(
          context: context,
          state: state,
          child: const GhostOverlayScreen(),
          
        ),
      ),

      GoRoute(
        path: AppRoutes.moveInSession,
        pageBuilder: (context, state) => buildPageWithSlideTransition(
          context: context,
          state: state,
          child: const MoveInSessionScreen(),
          
        ),
      ),

      GoRoute(
        path: AppRoutes.gamificationHub,
        pageBuilder: (context, state) => buildPageWithSlideTransition(
          context: context,
          state: state,
          child: const GamificationHubScreen(),
          
        ),
      ),

      GoRoute(
        path: AppRoutes.rulebook,
        pageBuilder: (context, state) => buildPageWithSlideTransition(
          context: context,
          state: state,
          child: const RulebookScreen(),
          
        ),
      ),

      GoRoute(
        path: AppRoutes.liquidity,
        pageBuilder: (context, state) => buildPageWithSlideTransition(
          context: context,
          state: state,
          child: const LiquidityScreen(),
          
        ),
      ),

      GoRoute(
        path: AppRoutes.maintenance,
        pageBuilder: (context, state) => buildPageWithSlideTransition(
          context: context,
          state: state,
          child: const MaintenanceListScreen(),
          
        ),
      ),

      GoRoute(
        path: AppRoutes.maintenanceCreate,
        pageBuilder: (context, state) => buildPageWithSlideTransition(
          context: context,
          state: state,
          child: const CreateTicketScreen(),
          
        ),
      ),

      GoRoute(
        path: AppRoutes.maintenanceDetail,
        pageBuilder: (context, state) {
          final ticket = state.extra as MockTicket;
          return buildPageWithSlideTransition(
            context: context,
            state: state,
            child: TicketDetailScreen(ticket: ticket),
          );
        },
      ),

      GoRoute(
        path: AppRoutes.honorHistory,
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return buildPageWithSlideTransition(
            context: context,
            state: state,
            child: HonorHistoryScreen(
              honorLevel: extra?['honorLevel'] ?? 2,
              trustFactor: (extra?['trustFactor'] as num?)?.toDouble() ?? 0.85,
            ),
            
          );
        },
      ),

      GoRoute(
        path: AppRoutes.stewardshipProtocol,
        pageBuilder: (context, state) => buildPageWithSlideTransition(
          context: context,
          state: state,
          child: const StewardshipProtocolScreen(),
          
        ),
      ),

      GoRoute(
        path: AppRoutes.profile,
        pageBuilder: (context, state) {
          final user = state.extra as AppUser? ?? AppUser(
            id: 'user1',
            name: 'User',
            avatarInitials: 'US',
            role: UserRole.tenant,
            fiscalScore: 850,
            honorLevel: HonorLevel.neutral,
            trustFactor: 0.85,
            syncState: SyncState.synced,
          );
          return buildPageWithSlideTransition(
            context: context,
            state: state,
            child: ProfileScreen(user: user),
            
          );
        },
      ),

      GoRoute(
        path: AppRoutes.profileEditor,
        pageBuilder: (context, state) {
          final user = state.extra as AppUser? ?? AppUser(
            id: 'user1',
            name: 'User',
            avatarInitials: 'US',
          );
          return buildPageWithSlideTransition(
            context: context,
            state: state,
            child: ProfileEditorScreen(appUser: user),
            
          );
        },
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

      ShellRoute(
   builder: (context, state, child) => TenantShell(
     child: child,
     state: state,
   ),
   routes: [
     GoRoute(
       path: AppRoutes.tenantDashboard,
       pageBuilder: (context, state) => buildPageWithSlideTransition(
         context: context,
         state: state,
         child: const TenantDashboardScreen(),
       ),
     ),
     GoRoute(
       path: AppRoutes.dashboard,
       pageBuilder: (context, state) => buildPageWithSlideTransition(
         context: context,
         state: state,
         child: const BillDashboardScreen(),
       ),
     ),
     GoRoute(
       path: AppRoutes.syncHub,
       pageBuilder: (context, state) => buildPageWithSlideTransition(
         context: context,
         state: state,
         child: const SyncHubScreen(userName: 'User'),
       ),
     ),
     GoRoute(
       path: AppRoutes.supportCenter,
       pageBuilder: (context, state) => buildPageWithSlideTransition(
         context: context,
         state: state,
         child: const SupportCenterScreen(),
       ),
     ),
     GoRoute(
       path: AppRoutes.community,
       pageBuilder: (context, state) => buildPageWithSlideTransition(
         context: context,
         state: state,
         child: const CommunityBoardScreen(),
       ),
     ),
   ],
 ),

    ], // routes
    ); // GoRouter
  }); // appRouterProvide

  // Placeholder screen for routes not yet implemented
  class _PlaceholderScreen extends StatelessWidget {
    final String title;

    const _PlaceholderScreen({required this.title});

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          title: Text(title),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.construction, size: 64),
              const SizedBox(height: 16),
              Text(
                '$title Screen',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Coming Soon'),
            ],
          ),
        ),
      );
    }
  }
  
