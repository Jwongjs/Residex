import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimensions.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../../domain/entities/bills/bill.dart';
import '../../../domain/entities/bills/bill_enums.dart';

class BillListItem extends StatelessWidget {
  final Bill bill;
  final String currentUserId;
  final VoidCallback onTap;

  const BillListItem({
    super.key,
    required this.bill,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final userStatus = bill.getPaymentStatusForUser(currentUserId);
    final userShare = bill.participantShares[currentUserId] ?? 0.0;
    final dateFormat = DateFormat('dd MMM yyyy');

    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(AppDimensions.paddingMedium),
        margin: const EdgeInsets.only(bottom: AppDimensions.paddingSmall),
        child: Row(
          children: [
            // Category Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: bill.category.backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: bill.category.color.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                bill.category.icon,
                color: bill.category.color,
                size: 24,
              ),
            ),
            const SizedBox(width: AppDimensions.paddingMedium),
            // Bill Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          bill.title,
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _buildStatusBadge(userStatus),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    bill.provider.isNotEmpty ? bill.provider : bill.category.name.toUpperCase(),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        bill.dueDate != null
                            ? 'Due: ${dateFormat.format(bill.dueDate!)}'
                            : 'No due date',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                       const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Your share: RM ${userShare.toStringAsFixed(2)}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.cyan500,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(PaymentStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: status.backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: status.color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        status.label,
        style: AppTextStyles.bodySmall.copyWith(
          color: status.color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}
