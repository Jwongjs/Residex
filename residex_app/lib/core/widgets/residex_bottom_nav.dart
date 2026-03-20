import 'package:flutter/material.dart';                                                                                           
import 'package:lucide_icons/lucide_icons.dart';                                                                                    import '../theme/app_colors.dart';
import '../../features/shared/domain/entities/users/app_user.dart';
import '../router/nav_direction.dart';

  /// Unified bottom navigation bar for Residex app
  /// Simple icon-only design with center emphasis
  class ResidexBottomNav extends StatelessWidget {
    final String currentRoute;
    final UserRole role;
    final Function(String) onNavigate;

    const ResidexBottomNav({
      super.key,
      required this.currentRoute,
      required this.role,
      required this.onNavigate,
    });

    @override
    Widget build(BuildContext context) {
      final tabs = _getTabsForRole(role);
      final currentIndex = _getCurrentIndex(tabs, currentRoute);

      return Container(
        height: 80,
        decoration: BoxDecoration(
          color: AppColors.deepSpace,
          border: Border(
            top: BorderSide(
              color: Colors.white.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(tabs.length, (index) {
            final tab = tabs[index];
            final isActive = index == currentIndex;
            final isCenter = index == 2; // Center tab (Rex AI)

            if (isCenter) {
              return _buildCenterIcon(
                tab: tab,
                isActive: isActive,
                 onTap: () {
             NavDirection.slideFromRight = index >= currentIndex;
             onNavigate(tab.route);
           },
              );
            }

            return _buildNavIcon(
              tab: tab,
              isActive: isActive,
               onTap: () {
             NavDirection.slideFromRight = index >= currentIndex;
             onNavigate(tab.route);
           },
            );
          }),
        ),
      );
    }

    Widget _buildNavIcon({
      required NavTab tab,
      required bool isActive,
      required VoidCallback onTap,
    }) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 60,
          height: 80,
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AppColors.cyan500.withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              tab.icon,
              size: 26,
              color: isActive ? AppColors.cyan500 : AppColors.textTertiary,
            ),
          ),
        ),
      );
    }

    Widget _buildCenterIcon({
      required NavTab tab,
      required bool isActive,
      required VoidCallback onTap,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 60,
          height: 80,
          alignment: Alignment.center,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.deepSpace,
              border: Border.all(
                color: isActive
                    ? AppColors.cyan500.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.1),
                width: 2,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AppColors.cyan500.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              LucideIcons.radio,
              size: 26,
              color: isActive ? AppColors.cyan500 : AppColors.textTertiary,
            ),
          ),
        ),
      );
    }

    List<NavTab> _getTabsForRole(UserRole role) {
      if (role == UserRole.tenant) {
        return [
          NavTab(
            icon: LucideIcons.grid,
            route: '/tenant-dashboard',
            color: AppColors.blue500,
          ),
          NavTab(
            icon: LucideIcons.dollarSign,
            route: '/dashboard',
            color: AppColors.blue500,
          ),
          NavTab(
            icon: LucideIcons.radio,
            route: '/sync-hub',
            color: AppColors.blue500,
          ),
          NavTab(
            icon: LucideIcons.wrench,
            route: '/support-center',
            color: AppColors.blue500,
          ),
          NavTab(
            icon: LucideIcons.users,
            route: '/community',
            color: AppColors.blue500,
          ),
        ];
      } else {
        // Landlord tabs
        return [
          NavTab(
            icon: LucideIcons.layoutDashboard,
            route: '/landlord-command',
            color: AppColors.blue500,
          ),
          NavTab(
            icon: LucideIcons.trendingUp,
            route: '/landlord-finance',
            color: AppColors.blue500,
          ),
          NavTab(
            icon: LucideIcons.radio,
            route: '/landlord-rex-ai',
            color: AppColors.blue500,
          ),
          NavTab(
            icon: LucideIcons.building2,
            route: '/landlord-portfolio',
            color: AppColors.blue500,
          ),
          NavTab(
            icon: LucideIcons.users,
            route: '/landlord-community',
            color: AppColors.blue500,
          ),
        ];
      }
    }

    int _getCurrentIndex(List<NavTab> tabs, String route) {
      final index = tabs.indexWhere((tab) => tab.route == route);
      return index != -1 ? index : 0;
    }
  }

  /// Navigation tab configuration
  class NavTab {
    final IconData icon;
    final String route;
    final Color color;

    const NavTab({
      required this.icon,
      required this.route,
      required this.color,
    });
  }