import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../domain/entities/finance_summary.dart';
import '../../providers/finance_logic.dart';

/// Portfolio headline: figures sit directly on the paper background,
/// deed-title-block style — no card. Property blocks below stay enclosed
/// white cards, so the contrast reads as "this is the summary".
class FinanceLedgerStrip extends StatelessWidget {
  final FinanceSummary summary;
  final VoidCallback onShowCaveats;

  const FinanceLedgerStrip({
    super.key,
    required this.summary,
    required this.onShowCaveats,
  });

  @override
  Widget build(BuildContext context) {
    final totals = summary.totals;
    final netColor = totals.netPl < 0 ? AppColors.sealRed : AppColors.deedGreen;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Net P/L · ${summary.year}', style: AppTextStyles.labelSmall),
                    const SizedBox(height: 2),
                    Text(
                      formatRM(totals.netPl),
                      style: AppTextStyles.displayLarge.copyWith(color: netColor),
                    ),
                    if (totals.derivedRent > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        'includes ${formatRM(totals.derivedRent)} backfilled from lease terms',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _ledgerColumn('RECEIVED', totals.receivedRent),
              const SizedBox(width: 16),
              _ledgerColumn('EXPENSES', totals.directExpenses),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.hairline),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Statutory rental income', style: AppTextStyles.labelLarge),
                    Text(totals.statutoryNote,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ),
              Text(formatRM(totals.statutoryRentalIncome), style: AppTextStyles.titleLarge),
              IconButton(
                icon: const Icon(Icons.info_outline, size: 20, color: AppColors.textMuted),
                tooltip: 'Assumptions and caveats',
                onPressed: onShowCaveats,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ledgerColumn(String label, double value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted, letterSpacing: 0.8),
        ),
        const SizedBox(height: 3),
        Text(
          formatRM(value),
          style: GoogleFonts.ibmPlexMono(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
