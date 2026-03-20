import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimensions.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../../domain/entities/bills/bill.dart';

class BillHeaderCard extends StatelessWidget {
  final Bill bill;

  const BillHeaderCard({
    super.key,
    required this.bill,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMMM yyyy');
    final isOverdue = bill.dueDate != null &&
                      DateTime.now().isAfter(bill.dueDate!) &&
                      !bill.isSettled;

    return GlassCard(
      padding: const EdgeInsets.all(AppDimensions.paddingLarge),
      gradient: LinearGradient(
        colors: [
          bill.category.backgroundColor.withValues(alpha: 0.2),
          bill.category.color.withValues(alpha: 0.05),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderColor: bill.category.color.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category Icon & Name
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bill.category.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: bill.category.color.withValues(alpha: 0.5),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: bill.category.color.withValues(alpha: 0.3),
                      blurRadius: 16,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Icon(
                  bill.category.icon,
                  color: bill.category.color,
                  size: 32,
                ),
              ),
              const SizedBox(width: AppDimensions.paddingMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bill.category.name.toUpperCase(),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: bill.category.color,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bill.title,
                      style: AppTextStyles.h3.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.paddingLarge),

          // Provider
          if (bill.provider.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.business_rounded,
                  color: AppColors.textTertiary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  bill.provider,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingSmall),
          ],

          // Due Date
          Row(
            children: [
              Icon(
                isOverdue
                    ? Icons.warning_rounded
                    : Icons.calendar_today_rounded,
                color: isOverdue ? AppColors.red500 : AppColors.textTertiary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                bill.dueDate != null
                    ? (isOverdue
                        ? 'Overdue: ${dateFormat.format(bill.dueDate!)}'
                        : 'Due: ${dateFormat.format(bill.dueDate!)}')
                    : 'No due date',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isOverdue
                      ? AppColors.red500
                      : AppColors.textSecondary,
                  fontWeight: isOverdue ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.paddingLarge),

          // Divider
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.0),
                  Colors.white.withValues(alpha: 0.2),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppDimensions.paddingLarge),

          // Total Amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'RM ${bill.totalAmount.toStringAsFixed(2)}',
                style: AppTextStyles.h2.copyWith(
                  color: bill.category.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          // Outstanding Amount (if not fully settled)
          if (!bill.isSettled) ...[
            const SizedBox(height: AppDimensions.paddingSmall),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Outstanding',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                Text(
                  'RM ${bill.outstandingAmount.toStringAsFixed(2)}',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.red500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
