import 'package:flutter/material.dart';
 import 'package:go_router/go_router.dart';
 import '../theme/app_colors.dart';
 import 'residex_bottom_nav.dart';
 import '../../features/shared/domain/entities/users/app_user.dart';

 class TenantShell extends StatelessWidget {
   final Widget child;
   final GoRouterState state;

   const TenantShell({
     super.key,
     required this.child,
     required this.state,
   });

   @override
   Widget build(BuildContext context) {
     return Scaffold(
       backgroundColor: AppColors.deepSpace,
       body: child,
       bottomNavigationBar: ResidexBottomNav(
         currentRoute: state.uri.path,
         role: UserRole.tenant,
         onNavigate: (route) => context.go(route),
       ),
     );
   }
 }