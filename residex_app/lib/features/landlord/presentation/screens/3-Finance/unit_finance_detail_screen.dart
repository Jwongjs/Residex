import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../domain/entities/finance_summary.dart';
import '../../providers/finance_logic.dart';
import '../2-Documind/document_viewer_screen.dart';
import 'finance_screen.dart' show uploadDocumentForCategory;

/// Month-by-month drill-down for one unit (or the whole-property line):
/// income strip, its expense lines (tappable to the source PDF), and a
/// one-tap invoice upload for months with no record.
class UnitFinanceDetailScreen extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        title: Text('${unit.label} — $year', style: AppTextStyles.titleLarge),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(propertyName, style: AppTextStyles.bodyMedium),
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
                Text(formatRM(unit.contribution),
                    style: AppTextStyles.displayMedium),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Monthly income', style: AppTextStyles.titleMedium),
          const SizedBox(height: 8),
          _buildMonthStrip(),
          const SizedBox(height: 8),
          _buildLegend(),
          if (unit.missingInvoiceMonths.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildMissingInvoices(context, ref),
          ],
          if (unit.expenseLines.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Expenses', style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            ...unit.expenseLines.map((line) => _buildExpenseLine(context, line)),
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
      default:
        return AppColors.hairline;
    }
  }

  Widget _buildMonthStrip() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: unit.months.map((month) {
        final color = _sourceColor(month.source);
        return Container(
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
                month.source == 'vacant' ? '—' : formatRM(month.amount),
                style: AppTextStyles.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      }).toList(),
    );
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
        item(AppColors.hairline, 'No record'),
      ],
    );
  }

  Widget _buildMissingInvoices(BuildContext context, WidgetRef ref) {
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
              propertyId: propertyId,
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
              propertyId: propertyId,
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
