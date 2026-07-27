import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/theme/app_dimensions.dart';
import '../../../domain/entities/finance_summary.dart';
import '../../providers/finance_logic.dart';

/// Global summary panel for the Finance tab: a hero card anchoring net P/L
/// (with a monthly-shape sparkline), two recessed secondary cards for
/// received/expenses, and a footer statutory-income row on paper.
class FinanceSummaryPanel extends StatelessWidget {
  final FinanceSummary summary;
  final VoidCallback onShowCaveats;

  const FinanceSummaryPanel({
    super.key,
    required this.summary,
    required this.onShowCaveats,
  });

  static TextStyle get _cardHeaderStyle => AppTextStyles.labelSmall.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AppColors.textSecondary,
      );

  @override
  Widget build(BuildContext context) {
    final totals = summary.totals;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 560;
            final heroCard = _HeroCard(
              summary: summary,
              headerStyle: _cardHeaderStyle,
            );
            final receivedCard = _SecondaryCard(
              label: 'TOTAL RECEIVED',
              value: totals.receivedRent,
              headerStyle: _cardHeaderStyle,
            );
            final expensesCard = _SecondaryCard(
              label: 'TOTAL EXPENSES',
              value: totals.landlordExpenses,
              headerStyle: _cardHeaderStyle,
            );

            if (wide) {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 2, child: heroCard),
                    const SizedBox(width: 12),
                    Expanded(child: receivedCard),
                    const SizedBox(width: 12),
                    Expanded(child: expensesCard),
                  ],
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heroCard,
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: receivedCard),
                    const SizedBox(width: 12),
                    Expanded(child: expensesCard),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _StatutoryRow(summary: summary, onShowCaveats: onShowCaveats),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final FinanceSummary summary;
  final TextStyle headerStyle;

  const _HeroCard({required this.summary, required this.headerStyle});

  @override
  Widget build(BuildContext context) {
    final totals = summary.totals;
    final netColor = totals.netPl < 0 ? AppColors.sealRed : AppColors.deedGreen;
    final series = monthlyNetSeries(summary);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: AppColors.hairline),
          boxShadow: AppShadows.cardShadow,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: AppColors.registry),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('TOTAL NET P/L · ${summary.year}', style: headerStyle),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          formatRM(totals.netPl),
                          style: AppTextStyles.displayLarge.copyWith(color: netColor),
                        ),
                      ),
                      if (series.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 28,
                          width: double.infinity,
                          child: LineChart(
                            LineChartData(
                              gridData: const FlGridData(show: false),
                              titlesData: const FlTitlesData(show: false),
                              borderData: FlBorderData(show: false),
                              lineTouchData: const LineTouchData(enabled: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: [
                                    for (var i = 0; i < series.length; i++)
                                      FlSpot(i.toDouble(), series[i]),
                                  ],
                                  isCurved: true,
                                  curveSmoothness: 0.35,
                                  preventCurveOverShooting: true,
                                  barWidth: 1.5,
                                  color: netColor,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(show: false),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryCard extends StatelessWidget {
  final String label;
  final double value;
  final TextStyle headerStyle;

  const _SecondaryCard({
    required this.label,
    required this.value,
    required this.headerStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: headerStyle),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatRM(value),
              style: GoogleFonts.ibmPlexMono(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatutoryRow extends StatelessWidget {
  final FinanceSummary summary;
  final VoidCallback onShowCaveats;

  const _StatutoryRow({required this.summary, required this.onShowCaveats});

  String _missingNames() {
    final names = <String>[];
    for (final id in summary.missingCategories.keys) {
      for (final property in summary.properties) {
        if (property.propertyId == id) {
          names.add(property.name);
          break;
        }
      }
    }
    if (names.isEmpty) return '';
    if (names.length <= 2) return names.join(', ');
    final remaining = names.length - 2;
    return '${names.take(2).join(', ')} and $remaining more';
  }

  @override
  Widget build(BuildContext context) {
    final totals = summary.totals;
    final provisional = summary.properties.any((p) => !p.complete);
    final statutoryLabel = provisional
        ? 'Current Statutory Rental Income'
        : 'Statutory Rental Income';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                statutoryLabel,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textMuted,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(formatRM(totals.statutoryRentalIncome), style: AppTextStyles.titleMedium),
            IconButton(
              icon: const Icon(Icons.info_outline, size: 18, color: AppColors.textMuted),
              tooltip: 'Assumptions and caveats',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: onShowCaveats,
            ),
          ],
        ),
        if (summary.missingCategories.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.warning),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Records missing for ${_missingNames()}',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                    softWrap: true,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
