import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';

/// Single expense category progress bar
/// 
/// Usage:
/// ```dart
/// ExpenseProgressItem(
///   label: 'Maintenance',
///   amount: 2400.0,
///   percentage: 45.0,
///   color: AppColors.error,
/// )
/// ```
class ExpenseProgressItem extends StatelessWidget {
  final String label;
  final double amount;
  final double percentage; // 0-100
  final Color color;

  const ExpenseProgressItem({
    super.key,
    required this.label,
    required this.amount,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Label and amount
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textMuted,
              ),
            ),
            Text(
              'RM ${amount.toStringAsFixed(0)}',
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textMuted,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),

        const SizedBox(height: 6),

        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.slate800.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              FractionallySizedBox(
                widthFactor: percentage / 100,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}