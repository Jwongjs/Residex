import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/glass_card.dart';

class LedgerSummaryCards extends StatelessWidget {
  final int outstandingCount;
  final double outstandingAmount;
  final int settledCount;
  final double settledAmount;

  const LedgerSummaryCards({
    super.key,
    required this.outstandingCount,
    required this.outstandingAmount,
    required this.settledCount,
    required this.settledAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Outstanding Card
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.all(12.0),
            gradient: LinearGradient(
              colors: [
                AppColors.error.withValues(alpha: 0.1),
                AppColors.orange.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderColor: AppColors.error.withValues(alpha: 0.3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon and Label Row
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'OUTSTANDING',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Amount
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'RM ${outstandingAmount.toStringAsFixed(2)}',
                    style: AppTextStyles.displayMedium.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                      fontSize: 24,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Bill count
                Text(
                  '$outstandingCount ${outstandingCount == 1 ? 'bill' : 'bills'}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16.0),
        // Settled Card
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.all(12.0),
            gradient: LinearGradient(
              colors: [
                AppColors.success.withValues(alpha: 0.1),
                AppColors.primaryCyan.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderColor: AppColors.success.withValues(alpha: 0.3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon and Label Row
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_outline,
                        color: AppColors.success,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'SETTLED',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Amount
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'RM ${settledAmount.toStringAsFixed(2)}',
                    style: AppTextStyles.displayMedium.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Bill count
                Text(
                  '$settledCount ${settledCount == 1 ? 'bill' : 'bills'}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
