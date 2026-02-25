import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/landlord/presentation/screens/landlord_home_screen.dart';
import '../../features/tenant/presentation/screens/tenant_dashboard_screen.dart';
import '../../features/shared/presentation/screens/splash_screen.dart';
import '../../features/shared/presentation/screens/welcome_screen.dart';
import '../../features/shared/presentation/screens/login_screen.dart';
import '../../features/shared/presentation/screens/register_screen.dart';
import '../providers/auth_provider.dart';

class AppRouter {
  // Route names
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String register = '/register';
  static const String landlordHome = '/landlord';
  static const String tenantHome = '/tenant';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
        );
      
      case welcome:
        return MaterialPageRoute(
          builder: (_) => const WelcomeScreen(),
        );
      
      case login:
        return _createSlideRoute(const LoginScreen());
      
      case register:
        return _createSlideRoute(const RegisterScreen());
      
      case landlordHome:
        return MaterialPageRoute(
          builder: (_) => const AuthGuard(
            child: LandlordHomeScreen(),
            requiredRole: 'landlord',
          ),
        );
      
      // case tenantHome:
      //   return MaterialPageRoute(
      //     builder: (_) => const AuthGuard(
      //       child: TenantDashboardScreen(),
      //       requiredRole: 'tenant',
      //     ),
      //   );
      
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: const Color(0xFF0a0a12),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Route not found',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No route defined for ${settings.name}',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(_).pushReplacementNamed(welcome);
                    },
                    child: const Text('Go to Home'),
                  ),
                ],
              ),
            ),
          ),
        );
    }
  }

  /// Create slide transition for auth screens
  static Route _createSlideRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;

        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }
}

/// Auth Guard Widget - Protects routes that require authentication
class AuthGuard extends ConsumerWidget {
  final Widget child;
  final String requiredRole;

  const AuthGuard({
    super.key,
    required this.child,
    required this.requiredRole,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          // Not authenticated, redirect to welcome
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(context, AppRouter.welcome);
          });
          return const Scaffold(
            backgroundColor: Color(0xFF0a0a12),
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF06B6D4)),
              ),
            ),
          );
        }

        // Check user role matches required role
        return FutureBuilder<String?>(
          future: ref.read(authServiceProvider).getUserRole(user.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Color(0xFF0a0a12),
                body: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF06B6D4)),
                  ),
                ),
              );
            }

            if (snapshot.hasError || snapshot.data != requiredRole) {
              // Wrong role, redirect to correct home
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final userRole = snapshot.data;
                if (userRole == 'landlord') {
                  Navigator.pushReplacementNamed(context, AppRouter.landlordHome);
                } else if (userRole == 'tenant') {
                  Navigator.pushReplacementNamed(context, AppRouter.tenantHome);
                } else {
                  Navigator.pushReplacementNamed(context, AppRouter.welcome);
                }
              });
              return const Scaffold(
                backgroundColor: Color(0xFF0a0a12),
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // Authenticated with correct role
            return child;
          },
        );
      },
      loading: () => const Scaffold(
        backgroundColor: Color(0xFF0a0a12),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF06B6D4)),
          ),
        ),
      ),
      error: (error, stack) => Scaffold(
        backgroundColor: const Color(0xFF0a0a12),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Authentication Error',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, AppRouter.welcome);
                },
                child: const Text('Go to Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}