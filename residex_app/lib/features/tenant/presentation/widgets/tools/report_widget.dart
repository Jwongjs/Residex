import 'package:flutter/material.dart';
  import 'package:lucide_icons/lucide_icons.dart';
  import '../../../../../core/theme/app_colors.dart';
  import '../../../../../core/widgets/glass_card.dart';

  class ReportWidget extends StatelessWidget {
    final VoidCallback onOpenDetail;

    const ReportWidget({
      super.key,
      required this.onOpenDetail,
    });

    @override
    Widget build(BuildContext context) {
      return GestureDetector(
        onTap: onOpenDetail,
        child: GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.orange500.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          LucideIcons.alertCircle,
                          color: AppColors.orange500,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Maintenance',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const Icon(
                    LucideIcons.chevronRight,
                    size: 16,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  _StatusDot(color: AppColors.emerald500),
                  const SizedBox(width: 8),
                  const Text(
                    '2 Resolved',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  _StatusDot(color: AppColors.orange500),
                  const SizedBox(width: 8),
                  const Text(
                    '1 Pending',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
  }

  class _StatusDot extends StatelessWidget {
    final Color color;

    const _StatusDot({required this.color});

    @override
    Widget build(BuildContext context) {
      return Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      );
    }
  }
