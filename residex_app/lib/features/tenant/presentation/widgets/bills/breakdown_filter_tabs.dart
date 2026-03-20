import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../../core/theme/app_theme.dart';

enum BreakdownFilter { all, person, group }

class BreakdownFilterTabs extends StatelessWidget {
  final BreakdownFilter activeFilter;
  final Function(BreakdownFilter) onFilterChanged;

  const BreakdownFilterTabs({
    super.key,
    required this.activeFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
    children: [
      Expanded(
        child: _buildTab(
          filter: BreakdownFilter.all,
          icon: LucideIcons.fileText,
          label: 'Bills',
        ),
      ),
      const SizedBox(width: 4),  // REDUCED from 8 to 4
      Expanded(
        child: _buildTab(
          filter: BreakdownFilter.person,
          icon: LucideIcons.user,
          label: 'People',
        ),
      ),
      const SizedBox(width: 4),  // REDUCED from 8 to 4
      Expanded(
        child: _buildTab(
          filter: BreakdownFilter.group,
          icon: LucideIcons.users,
          label: 'Groups',
        ),
      ),
    ],
  ),
    );
  }

  Widget _buildTab({
    required BreakdownFilter filter,
    required IconData icon,
    required String label,
  }) {
    final isActive = activeFilter == filter;


      return GestureDetector(
    onTap: () => onFilterChanged(filter),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),  // REDUCED padding
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.primaryCyan.withValues(alpha: 0.2)
            : AppColors.slate800.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular( 12),
        border: Border.all(
          color: isActive
              ? AppColors.primaryCyan
              : Colors.white.withValues(alpha: 0.1),
          width: isActive ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,  // ADD THIS
        children: [
          Icon(
            icon,
            size: 14,  // REDUCED from 16
            color: isActive ? AppColors.primaryCyan : AppColors.textSecondary,
          ),
          const SizedBox(width: 6),  // REDUCED from 8
          Flexible(  // ADD THIS
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? AppColors.primaryCyan : AppColors.textSecondary,
                fontSize: 12,  // REDUCED from 13
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,  // ADD THIS
            ),
          ),
        ],
      ),
    ),
  );
  }
}
