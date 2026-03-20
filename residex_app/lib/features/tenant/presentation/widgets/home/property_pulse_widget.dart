 import 'package:flutter/material.dart';
  import 'package:google_fonts/google_fonts.dart';
  import '../../../../../core/theme/app_colors.dart';
  import '../../../../../core/theme/app_text_styles.dart';
  import '../../../../../core/widgets/glass_card.dart';

  class PropertyPulseWidget extends StatelessWidget {
    final VoidCallback onOpenDetail;

    const PropertyPulseWidget({
      super.key,
      required this.onOpenDetail,
    });

    @override
    Widget build(BuildContext context) {
      return GlassCard(
        padding: const EdgeInsets.all(20),
        gradient: LinearGradient(
          colors: [
            AppColors.blue500.withValues(alpha: 0.05),
            AppColors.cyan500.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderColor: AppColors.blue500.withValues(alpha: 0.2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Header ──────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.blue500.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.blue500.withValues(alpha: 0.2)),
                      ),
                      child: const Icon(
                        Icons.monitor_heart,
                        color: AppColors.blue400,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Property Pulse',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'HEALTH SCORE',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: onOpenDetail,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Score hero ───────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.blue500.withValues(alpha: 0.4),
                        width: 3),
                    color: AppColors.blue500.withValues(alpha: 0.08),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.blue500.withValues(alpha: 0.25),
                          blurRadius: 18),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '87',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EXCELLENT',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppColors.cyan400,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your home is in great shape.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── 4 vital cards ────────────────────────────────────
            Row(
              children: [
                _buildVital('BILLS', 'All Paid', AppColors.cyan400),
                const SizedBox(width: 8),
                _buildVital('TICKETS', '2 Open', AppColors.amber500),
                const SizedBox(width: 8),
                _buildVital('CHORES', '92%', Colors.white),
                const SizedBox(width: 8),
                _buildVital('RENT', 'Due 5d', AppColors.slate400),
              ],
            ),

            const SizedBox(height: 12),

            // ── Divider ──────────────────────────────────────────
            Container(height: 1, color: Colors.white.withValues(alpha: 0.05)),

            const SizedBox(height: 12),

            // ── AI insight preview ───────────────────────────────
            GestureDetector(
              onTap: onOpenDetail,
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.amber500,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.amber500.withValues(alpha: 0.5),
                            blurRadius: 8),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Electricity Spike Detected',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Usage up 40% vs last month',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.amber500.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.amber500.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'ALERT',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.amber500,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
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

    Widget _buildVital(String label, String value, Color valueColor) {
      return Expanded(
        child: Container(
          padding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: AppColors.slate500,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
