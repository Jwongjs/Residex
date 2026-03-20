import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimensions.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../../../../core/widgets/avatar_widget.dart';
import '../../../domain/entities/bills/bill_enums.dart';

class ParticipantPaymentCard extends StatelessWidget {
  final String userId;
  final String userName;
  final String? userAvatar;
  final double shareAmount;
  final PaymentStatus status;
  final bool isCurrentUser;
  final VoidCallback? onMarkPaid;
  final VoidCallback? onRemind;

  const ParticipantPaymentCard({
    super.key,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.shareAmount,
    required this.status,
    this.isCurrentUser = false,
    this.onMarkPaid,
    this.onRemind,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingSmall),
      gradient: LinearGradient(
        colors: [
          status.backgroundColor.withValues(alpha: 0.1),
          Colors.transparent,
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
      borderColor: status.color.withValues(alpha: 0.2),
      child: Row(
        children: [
          // Avatar
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: status.color,
                width: 2,
              ),
            ),
            child: AvatarWidget(
              initials: userName.split(' ').map((n) => n[0]).take(2).join().toUpperCase(),
              size: 44, // Slightly smaller to account for border
              gradientIndex: userId.hashCode.abs() % 6,
            ),
          ),
          const SizedBox(width: AppDimensions.paddingMedium),

          // User Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      userName,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cyan500.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'YOU',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.cyan500,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'RM ${shareAmount.toStringAsFixed(2)}',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: status.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Status & Action
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: status.backgroundColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: status.color.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  status == PaymentStatus.paid
                      ? Icons.check_circle_rounded
                      : status == PaymentStatus.unpaid
                          ? Icons.cancel_rounded
                          : Icons.schedule_rounded,
                  size: 20,
                  color: status.color,
                ),
              ),
              const SizedBox(height: 8),
              if (status != PaymentStatus.paid && onMarkPaid != null)
                TextButton(
                  onPressed: onMarkPaid,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    backgroundColor: status.color.withValues(alpha: 0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    isCurrentUser ? 'Mark Paid' : 'Remind',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: status.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
