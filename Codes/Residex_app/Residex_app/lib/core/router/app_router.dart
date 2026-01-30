import 'package:flutter/material.dart';
import 'package:residex_app/features/landlord/presentation/screens/landlord_home_screen.dart';

/// Centralized Navigation Router
/// 
/// Benefits:
/// - Type-safe navigation
/// - Deep linking support
/// - Easy to add auth guards
/// - Single place to manage all routes

class AppRouter {
  // Route names
  static const String landlordHome = '/landlord';
  static const String tenantHome = '/tenant';
  static const String login = '/login';
  
  // Generate routes
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case landlordHome:
        return MaterialPageRoute(
          builder: (_) => const LandlordHomeScreen(),
        );
      // case tenantHome:
      //   return MaterialPageRoute(
      //     builder: (_) => const TenantHomeScreen(),
      //   );
      default:
        return MaterialPageRoute(
          builder: (_) => const LandlordHomeScreen(),
        );
    }
  }
  
  // Navigation helpers
  static void toLandlordHome(BuildContext context) {
    Navigator.pushReplacementNamed(context, landlordHome);
  }
  
  static void toTenantHome(BuildContext context) {
    Navigator.pushReplacementNamed(context, tenantHome);
  }
}