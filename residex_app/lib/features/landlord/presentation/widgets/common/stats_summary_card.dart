import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';

/// Two-column stat summary card (e.g., Collected vs Pending)
/// 
/// Usage:
/// ```dart
/// StatsSummaryCard(
///   leftLabel: 'Collected',
///   leftValue: 'RM 13.8k',
///   leftIcon: Icons.trending_up,
///   leftColor: AppColors.success,
///   rightLabel: 'Pending',
///   rightValue: 'RM 450',
///   rightIcon: Icons.trending_down,
///   rightColor: AppColors.error,
/// )
/// ```
class StatsSummaryCard extends StatelessWidget {
  final String leftLabel;
  final String leftValue;
  final IconData leftIcon;
  final Color leftColor;
  final String rightLabel;
  final String rightValue;
  final IconData rightIcon;
  final Color rightColor;

  const StatsSummaryCard({
    super.key,
    required this.leftLabel,
    required this.leftValue,
    required this.leftIcon,
    required this.leftColor,
    required this.rightLabel,
    required this.rightValue,
    required this.rightIcon,
    required this.rightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: Row(
        children: [
          // Left stat
          Expanded(
            child: _buildStatColumn(
              label: leftLabel,
              value: leftValue,
              icon: leftIcon,
              color: leftColor,
            ),
          ),

          // Divider
          Container(
            width: 1,
            height: 60,
            color: Colors.white.withOpacity(0.1),
          ),

          // Right stat
          Expanded(
            child: _buildStatColumn(
              label: rightLabel,
              value: rightValue,
              icon: rightIcon,
              color: rightColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        // Icon badge
        Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.3),
            ),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label.toUpperCase(),
          style: AppTextStyles.label.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.headlineMedium.copyWith(
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
