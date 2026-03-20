import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';

/// Occupancy or progress bar with glow effect
/// 
/// Usage:
/// ```dart
/// ProgressBar(
///   label: 'Occupancy',
///   value: 3,
///   maxValue: 4,
///   unit: 'Units',
/// )
/// ```
class ProgressBar extends StatelessWidget {
  final String label;
  final int value;
  final int maxValue;
  final String? unit;
  final Color? color;

  const ProgressBar({
    super.key,
    required this.label,
    required this.value,
    required this.maxValue,
    this.unit,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progressColor = color ?? AppColors.primary;
    final percentage = value / maxValue;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label.toUpperCase(),
                style: AppTextStyles.label.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '$value/$maxValue${unit != null ? ' $unit' : ''}',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: percentage,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: progressColor,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: progressColor.withOpacity(0.5),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}