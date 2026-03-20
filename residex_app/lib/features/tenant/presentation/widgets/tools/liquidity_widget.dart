import 'package:flutter/material.dart';
  import 'package:lucide_icons/lucide_icons.dart';
  import '../../../../../core/theme/app_colors.dart';
  import '../../../../../core/widgets/glass_card.dart';

  class LiquidityWidget extends StatelessWidget {
    final VoidCallback onOpenDetail;

    const LiquidityWidget({
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
                          color: AppColors.emerald500.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          LucideIcons.droplet,
                          color: AppColors.emerald500,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Group Liquidity',
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

              const SizedBox(height: 16),

              // Liquidity bar
              Row(
                children: [
                  Expanded(
                    flex: 7,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.emerald500,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    flex: 3,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              const Text(
                '70% Balanced',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
