import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../domain/entities/finance_summary.dart';
import '../../providers/finance_logic.dart';
import '../../providers/finance_providers.dart';
import '../../providers/documind_provider.dart';
import '../../widgets/common/finance_year_picker.dart';
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
    ref.watch(financeSummaryProvider(_year));
    final yearsAsync = ref.watch(financeYearsProvider);

    ref.listen<AsyncValue<FinanceSummary>>(
      financeSummaryProvider(_year),
      (previous, next) {
        next.whenData((summary) {
          setState(() {
            _displayedUnit = _resolveUnit(summary);
            _displayedYear = _year;
          });
        });
      },
    );

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
              child: FinanceYearButton(
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
          Text(widget.propertyName, style: AppTextStyles.bodyMedium),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Row(
              children: [
                Expanded(
                    child: Text('Net contribution',
                        style: AppTextStyles.labelLarge)),
                Text(formatRM(_displayedUnit.contribution),
                    style: AppTextStyles.displayMedium),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Monthly income', style: AppTextStyles.titleMedium),
          const SizedBox(height: 8),
          _buildMonthStrip(_displayedUnit),
          const SizedBox(height: 8),
          _buildLegend(),
          if (_displayedUnit.missingInvoiceMonths.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildMissingInvoices(context, ref, _displayedUnit),
          ],
          if (_displayedUnit.expenseLines.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Expenses', style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            ..._displayedUnit.expenseLines
                .map((line) => _buildExpenseLine(context, line)),
          ],
        ],
      ),
    );
  }

  Color _sourceColor(String source) {
    switch (source) {
      case 'actual':
        return AppColors.registry;
      case 'derived':
        return AppColors.catUpkeep;
      case 'unpaid':
        return AppColors.sealRed;
      default:
        return AppColors.hairline;
    }
  }

  Widget _buildMonthStrip(UnitFinance unit) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: unit.months.map((month) {
        final color = _sourceColor(month.source);
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: month.source == 'vacant'
              ? null
              : () => _handleMonthTap(context, ref, month),
          child: Container(
            width: 74,
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
                Text(
                  month.source == 'vacant'
                      ? '—'
                      : month.source == 'unpaid'
                          ? 'UNPAID'
                          : formatRM(month.amount),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: month.source == 'unpaid' ? AppColors.sealRed : null,
                    fontWeight: month.source == 'unpaid' ? FontWeight.w600 : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _monthKey(int year, int month) => '$year-${month.toString().padLeft(2, '0')}';

  Future<void> _handleMonthTap(
      BuildContext context, WidgetRef ref, MonthIncome month) async {
    final monthLabel = '${monthAbbrev[month.month - 1]} $_displayedYear';
    if (month.source == 'unpaid') {
      await _showClearUnpaidSheet(context, ref, month, monthLabel);
    } else {
      await _showMarkUnpaidSheet(context, ref, month, monthLabel);
    }
  }

  Future<void> _showMarkUnpaidSheet(BuildContext context, WidgetRef ref,
      MonthIncome month, String monthLabel) async {
    final controller = TextEditingController();
    try {
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: AppColors.paper,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        isScrollControlled: true,
        builder: (sheetContext) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: 24 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mark $monthLabel as no payment received',
                  style: AppTextStyles.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration:
                    const InputDecoration(hintText: 'Reason (optional)'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  child: const Text('Mark as unpaid'),
                ),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true || !context.mounted) return;
      final action = ref.read(setPaymentExceptionActionProvider);
      try {
        await action(
          propertyId: widget.propertyId,
          unitId: widget.unit.unitId,
          month: _monthKey(_displayedYear, month.month),
          reason:
              controller.text.trim().isEmpty ? null : controller.text.trim(),
        );
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to mark month: $e')));
        }
      }
    } finally {
      controller.dispose();
    }
  }

  Future<void> _showClearUnpaidSheet(BuildContext context, WidgetRef ref,
      MonthIncome month, String monthLabel) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$monthLabel is marked as no payment received',
                  style: AppTextStyles.titleLarge),
              if (month.reason != null && month.reason!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(month.reason!, style: AppTextStyles.bodyMedium),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  child: const Text('Clear mark'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final action = ref.read(clearPaymentExceptionActionProvider);
    try {
      await action(
        propertyId: widget.propertyId,
        unitId: widget.unit.unitId,
        month: _monthKey(_displayedYear, month.month),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to clear mark: $e')));
      }
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
        item(AppColors.sealRed, 'Unpaid'),
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

  Widget _buildExpenseLine(BuildContext context, ExpenseLine line) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.hairline),
      ),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.description_outlined,
            size: 20, color: AppColors.registry),
        title: Text(
            line.description ??
                (financeCategoryLabels[line.category] ?? line.category),
            style: AppTextStyles.titleMedium),
        subtitle: line.date != null
            ? Text(line.date!, style: AppTextStyles.bodySmall)
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(formatRM(line.amount), style: AppTextStyles.titleMedium),
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.textMuted),
          ],
        ),
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => DocumentViewerScreen(
              propertyId: widget.propertyId,
              docId: line.docId,
              filename: line.description ??
                  (financeCategoryLabels[line.category] ?? line.category),
              page: null,
            ),
          ));
        },
      ),
    );
  }
}
