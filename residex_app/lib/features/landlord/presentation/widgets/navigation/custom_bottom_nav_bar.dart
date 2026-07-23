import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';

/// Navigation tab configuration model
class NavTab {
  final IconData icon;
  final String label;
  final Color color;

  const NavTab({
    required this.icon,
    required this.label,
    required this.color,
  });
}

/// Reusable custom bottom navigation bar.
///
/// Features:
/// - Flat white bar with a top hairline, matching the light Title Deed pages above it
/// - Slate inactive / registry active tab coloring
/// - The active tab is marked by a small dot under its label
class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<NavTab> tabs;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.tabs,
  }) : assert(tabs.length > 0, 'CustomBottomNavBar requires at least 1 tab');

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(tabs.length, (index) {
              final tab = tabs[index];
              return Expanded(
                child: _NavItem(
                  tab: tab,
                  isActive: currentIndex == index,
                  onTap: () => onTap(index),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final NavTab tab;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.registry : AppColors.slate;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tab.icon, size: 24, color: color),
          const SizedBox(height: 4),
          Text(
            tab.label,
            style: AppTextStyles.labelSmall.copyWith(
              color: color,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: isActive ? AppColors.registry : Colors.transparent,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

