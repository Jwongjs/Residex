import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../domain/entities/finance_summary.dart';
import '../../providers/finance_logic.dart';
import '../../providers/finance_providers.dart';
import '../../widgets/common/finance_year_picker.dart';
import '../../widgets/common/rent_payment_sheets.dart';
import '../../widgets/common/share_badge.dart';
import '../2-Documind/document_viewer_screen.dart';
import 'finance_screen.dart' show uploadDocumentForCategory;

/// Month-by-month drill-down for one unit (or the whole-property line):
/// income strip, its expense lines (tappable to the source PDF), and a
/// one-tap invoice upload for months with no record. Switching the year in
/// the app bar re-fetches this property's summary for that year and
/// re-resolves this unit from it.
class UnitFinanceDetailScreen extends ConsumerStatefulWidget {
  final String propertyId;
  final String propertyName;
  final UnitFinance unit;
  final int year;

  const UnitFinanceDetailScreen({
    super.key,
    required this.propertyId,
    required this.propertyName,
    required this.unit,
    required this.year,
  });

  @override
  ConsumerState<UnitFinanceDetailScreen> createState() =>
      _UnitFinanceDetailScreenState();
}

class _UnitFinanceDetailScreenState
    extends ConsumerState<UnitFinanceDetailScreen> {
  late int _year;
  late int _displayedYear;
  late UnitFinance _displayedUnit;

  @override
  void initState() {
    super.initState();
    _year = widget.year;
    _displayedYear = widget.year;
    _displayedUnit = widget.unit;
  }

  UnitFinance _resolveUnit(FinanceSummary summary) {
    final block = summary.properties.firstWhere(
      (p) => p.propertyId == widget.propertyId,
      orElse: () => PropertyFinance(
        propertyId: widget.propertyId,
        name: widget.propertyName,
        receivedRent: 0,
        derivedRent: 0,
        directExpenses: 0,
        rentalIncomeOrLoss: 0,
      ),
    );
    return block.units.firstWhere(
      (u) => u.unitId == widget.unit.unitId,
      orElse: () => UnitFinance(
        unitId: widget.unit.unitId,
        label: widget.unit.label,
        rentedMonths: 0,
        contribution: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(financeSummaryProvider(_year));
    final yearsAsync = ref.watch(financeYearsProvider);

    // Derived directly from the current AsyncValue rather than from
    // ref.listen's change notifications: financeSummaryProvider is a
    // non-autoDispose family, so revisiting an already-cached year delivers
    // AsyncData with no state *transition* to listen for, and a
    // listen-only update would leave _displayedUnit/_displayedYear frozen
    // on whatever year was last freshly fetched.
    summaryAsync.whenData((summary) {
      _displayedUnit = _resolveUnit(summary);
      _displayedYear = _year;
    });

    ref.listen<AsyncValue<FinanceSummary>>(
      financeSummaryProvider(_year),
      (previous, next) {
        if (next.hasError && !next.isLoading && _year != _displayedYear) {
          final failedYear = _year;
          setState(() => _year = _displayedYear);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Couldn't load $failedYear — check your connection and try again.")),
            );
          }
        }
      },
    );

    final isSwitchingYear = _year != _displayedYear && summaryAsync.isLoading;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        title: Text('${_displayedUnit.label} — $_displayedYear',
            style: AppTextStyles.titleLarge),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: isSwitchingYear
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.registry,
                      ),
                    )
                  : FinanceYearButton(
                      selected: _displayedYear,
                      years: yearsAsync.value ?? [_year],
                      onChanged: (y) => setState(() => _year = y),
                    ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(widget.propertyName, style: AppTextStyles.bodyMedium),
              ),
              if (_displayedUnit.ownershipShare < 1.0)
                ShareBadge(
                  text: '${(_displayedUnit.ownershipShare * 100).toStringAsFixed(0)}'
                      '% share',
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildNetContributionAccordion(context, _displayedUnit, _displayedYear),
          const SizedBox(height: 12),
          _buildStatutoryAccordion(context, _displayedUnit, _displayedYear),
          const SizedBox(height: 20),
          Text(_monthStripHeading(_displayedUnit),
              style: AppTextStyles.titleMedium),
          const SizedBox(height: 8),
          _buildMonthStrip(_displayedUnit),
          const SizedBox(height: 8),
          _buildLegend(),
          if (_displayedUnit.missingInvoiceMonths.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildMissingInvoices(context, ref, _displayedUnit),
          ],
        ],
      ),
    );
  }

  /// Rental Profit/Loss and Statutory income are two separate dropdowns (user
  /// request). They differ in which lines count:
  ///  - Rental Profit/Loss subtracts everything the landlord actually paid
  ///    (penalties, principal and first-letting costs included), so those are
  ///    shown normally here and only tenant-paid lines are struck out.
  ///  - Statutory income subtracts only LHDN-deductible lines, so
  ///    penalties/capital/first-letting costs are struck out here.
  Widget _buildNetContributionAccordion(
      BuildContext context, UnitFinance unit, int year) {
    return _breakdownAccordion(
      context,
      title: 'Rental Profit/Loss',
      total: unit.contribution,
      gross: unit.grossIncome,
      fullGross: unit.fullGrossIncome,
      expensesLabel: 'Direct expenses',
      expensesTotal: landlordPaidExpenseTotal(unit.expenseLines),
      lines: unit.expenseLines,
      exclusionNote: _netExclusionNote,
      emptyNote: 'No direct expenses recorded for $year',
      caption: "Contributes to this property's Rental Income.",
    );
  }

  Widget _buildStatutoryAccordion(
      BuildContext context, UnitFinance unit, int year) {
    return _breakdownAccordion(
      context,
      title: 'Statutory income',
      total: unit.statutoryContribution,
      gross: unit.grossIncome,
      fullGross: unit.fullGrossIncome,
      expensesLabel: 'Deductible expenses',
      expensesTotal: deductibleExpenseTotal(unit.expenseLines),
      lines: unit.expenseLines,
      exclusionNote: expenseExclusionNote,
      emptyNote: 'No deductible expenses recorded — equals your gross income.',
      caption: "Contributes to this property's Statutory Income. "
          'Only LHDN-deductible expenses reduce this figure.',
    );
  }

  /// A line is kept out of the Rental Profit/Loss total only when the landlord
  /// does not pay it (tenant-borne utilities). Penalties, principal and
  /// first-letting costs are all real money out, so they are NOT excluded here.
  String? _netExclusionNote(ExpenseLine line) {
    if (line.paidByLandlord) return null;
    return line.subtype == 'utilities'
        ? 'Tenant pays — excluded'
        : 'Not paid by you — excluded';
  }

  Widget _breakdownAccordion(
    BuildContext context, {
    required String title,
    required double total,
    required double gross,
    required double? fullGross,
    required String expensesLabel,
    required double expensesTotal,
    required List<ExpenseLine> lines,
    required String? Function(ExpenseLine) exclusionNote,
    required String emptyNote,
    String? caption,
  }) {
    final hasLines = lines.isNotEmpty;
    final totalColor = total < 0 ? AppColors.sealRed : AppColors.deedGreen;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            shape: const Border(),
            collapsedShape: const Border(),
            iconColor: AppColors.textMuted,
            collapsedIconColor: AppColors.textMuted,
            maintainState: true,
            initiallyExpanded: false,
            title: Row(
              children: [
                Expanded(child: Text(title, style: AppTextStyles.labelLarge)),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(formatRM(total),
                        style: AppTextStyles.displayMedium.copyWith(color: totalColor)),
                  ),
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 1, color: AppColors.hairline),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text('Gross income', style: AppTextStyles.labelLarge),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatRM(gross),
                              style: GoogleFonts.ibmPlexMono(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            // Percentage derived from the figure pair, exactly
                            // as the expense rows below do it — the panel never
                            // reads an ownership-share field, so this stays
                            // correct if share ever moves to the unit.
                            if (fullGross != null && fullGross > 0) ...[
                              const SizedBox(height: 2),
                              Text(
                                'your ${((gross / fullGross) * 100).toStringAsFixed(0)}% '
                                'of ${formatRM(fullGross)}',
                                style: AppTextStyles.labelSmall
                                    .copyWith(color: AppColors.textMuted),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (hasLines) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(expensesLabel, style: AppTextStyles.labelLarge),
                          ),
                          Text(
                            '−${formatRM(expensesTotal)}',
                            style: AppTextStyles.titleMedium.copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                      ..._buildGroupedExpenseLines(context, lines, exclusionNote: exclusionNote),
                    ] else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          emptyNote,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                        ),
                      ),
                    if (caption != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        caption,
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
                      ),
                    ],
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: AppColors.hairline),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              formatRM(total),
                              style: AppTextStyles.displayMedium.copyWith(color: totalColor),
                            ),
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
      ),
    );
  }

  /// Direct expenses split by cadence: monthly strata charges under a
  /// per-month separator (Jan → Dec), then semi-annual, annual and one-off
  /// charges each under their own section label. Duplicates are already
  /// collapsed by the backend fold, so this is pure display shaping.
  List<Widget> _buildGroupedExpenseLines(
      BuildContext context, List<ExpenseLine> lines,
      {required String? Function(ExpenseLine) exclusionNote}) {
    final grouped = groupDirectExpenses(lines);
    final widgets = <Widget>[];

    for (final group in grouped.monthly) {
      widgets.add(_expenseSectionHeader(
        group.month != null ? monthAbbrev[group.month! - 1] : 'Undated',
      ));
      widgets.addAll(group.lines
          .map((line) => _buildExpenseLineRow(context, line, exclusionNote)));
    }
    _addExpenseSection(context, widgets, 'Semi-annual', grouped.semiAnnual, exclusionNote);
    _addExpenseSection(context, widgets, 'Annual', grouped.annual, exclusionNote);
    _addExpenseSection(context, widgets, 'One-off', grouped.other, exclusionNote);

    return widgets;
  }

  void _addExpenseSection(BuildContext context, List<Widget> widgets,
      String label, List<ExpenseLine> lines,
      String? Function(ExpenseLine) exclusionNote) {
    if (lines.isEmpty) return;
    widgets.add(_expenseSectionHeader(label));
    widgets.addAll(lines.map((line) => _buildExpenseLineRow(context, line, exclusionNote)));
  }

  Widget _expenseSectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: Row(
        children: [
          Text(
            text.toUpperCase(),
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Divider(height: 1, color: AppColors.hairline)),
        ],
      ),
    );
  }

  Widget _buildExpenseLineRow(BuildContext context, ExpenseLine line,
      String? Function(ExpenseLine) exclusionNoteFn) {
    final label = line.description ?? (financeCategoryLabels[line.category] ?? line.category);
    final exclusionNote = exclusionNoteFn(line);
    final excluded = exclusionNote != null;
    final primaryColor = excluded ? AppColors.textMuted : AppColors.textPrimary;
    return InkWell(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => DocumentViewerScreen(
            propertyId: widget.propertyId,
            docId: line.docId,
            filename: label,
            page: null,
          ),
        ));
      },
      child: Padding(
        padding: const EdgeInsets.only(left: 12, top: 6, bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: excluded ? AppColors.textMuted : null,
                    ),
                  ),
                  if (line.date != null) ...[
                    const SizedBox(height: 2),
                    Text(formatExpenseDate(line.date!),
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                  ],
                  if (exclusionNote != null) ...[
                    const SizedBox(height: 2),
                    Text(exclusionNote,
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatRM(line.amount),
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 12,
                    color: primaryColor,
                    decoration: excluded ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (line.fullAmount != null && line.fullAmount! > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    'your ${((line.amount / line.fullAmount!) * 100).toStringAsFixed(0)}% '
                    'of ${formatRM(line.fullAmount!)}',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _sourceColor(MonthIncome month) {
    switch (month.source) {
      case 'actual':
        return AppColors.registry;
      case 'derived':
        return AppColors.catUpkeep;
      case 'unpaid':
        return month.paymentState == 'written_off' ? AppColors.textMuted : AppColors.sealRed;
      default:
        return AppColors.hairline;
    }
  }

  /// "Monthly income", plus the share qualifier when the engine scaled these
  /// rows. Cells render the scaled amount, so the heading is what tells the
  /// landlord which figure they are looking at. The percentage comes from the
  /// row's own figure pair, never from an ownership-share field.
  String _monthStripHeading(UnitFinance unit) {
    for (final month in unit.months) {
      final full = month.fullAmount;
      if (full != null && full > 0) {
        final pct = ((month.amount / full) * 100).toStringAsFixed(0);
        return 'Monthly income · your $pct% share';
      }
    }
    return 'Monthly income';
  }

  Widget _buildMonthStrip(UnitFinance unit) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const cellMinWidth = 104.0;
        const gap = 8.0;
        final columns = ((constraints.maxWidth + gap) / (cellMinWidth + gap))
            .floor()
            .clamp(3, 6);
        final cellWidth = (constraints.maxWidth - (columns - 1) * gap) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: unit.months.map((month) {
            final color = _sourceColor(month);
            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: month.source == 'vacant'
                  ? null
                  : () => _handleMonthTap(context, ref, month),
              child: Container(
                width: cellWidth,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration:
                              BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(monthAbbrev[month.month - 1],
                            style: AppTextStyles.labelSmall),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          month.source == 'vacant'
                              ? '—'
                              : month.source == 'unpaid'
                                  ? (month.paymentState == 'written_off' ? 'WRITTEN OFF' : 'OUTSTANDING')
                                  : formatRM(month.amount),
                          maxLines: 1,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: month.source == 'unpaid' ? _sourceColor(month) : null,
                            fontWeight: month.source == 'unpaid' ? FontWeight.w600 : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  String _monthKey(int year, int month) => '$year-${month.toString().padLeft(2, '0')}';

  Future<void> _handleMonthTap(
      BuildContext context, WidgetRef ref, MonthIncome month) async {
    final monthLabel = '${monthAbbrev[month.month - 1]} $_displayedYear';
    if (month.source == 'unpaid') {
      await showManageUnpaidSheet(
        context, ref,
        propertyId: widget.propertyId, unitId: widget.unit.unitId,
        month: _monthKey(_displayedYear, month.month), monthLabel: monthLabel,
        paymentState: month.paymentState ?? 'outstanding',
        reason: month.reason, billedAmount: month.billedAmount,
        fullBilledAmount: month.fullBilledAmount,
        grossIncome: _displayedUnit.grossIncome,
        fullGrossIncome: _displayedUnit.fullGrossIncome,
      );
    } else {
      await showMarkUnpaidSheet(
        context, ref,
        propertyId: widget.propertyId, unitId: widget.unit.unitId,
        month: _monthKey(_displayedYear, month.month), monthLabel: monthLabel,
      );
    }
  }

  Widget _buildLegend() {
    Widget item(Color color, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(label, style: AppTextStyles.labelSmall),
          ],
        );
    return Wrap(
      spacing: 16,
      children: [
        item(AppColors.registry, 'Invoiced'),
        item(AppColors.catUpkeep, 'From lease terms'),
        item(AppColors.sealRed, 'Outstanding'),
        item(AppColors.textMuted, 'Written off'),
        item(AppColors.hairline, 'No record'),
      ],
    );
  }

  Widget _buildMissingInvoices(
      BuildContext context, WidgetRef ref, UnitFinance unit) {
    final names =
        unit.missingInvoiceMonths.map((m) => monthAbbrev[m - 1]).join(', ');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long_outlined,
              size: 20, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text('No invoice recorded for $names',
                style: AppTextStyles.bodyMedium),
          ),
          TextButton(
            onPressed: () => uploadDocumentForCategory(
              context,
              ref,
              propertyId: widget.propertyId,
              category: 'rental_invoice',
            ),
            child: const Text('Add invoice'),
          ),
        ],
      ),
    );
  }

}
