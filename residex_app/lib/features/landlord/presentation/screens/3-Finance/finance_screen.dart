import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../domain/entities/finance_summary.dart';
import '../../../domain/entities/property.dart';
import '../../providers/documind_provider.dart';
import '../../providers/finance_logic.dart';
import '../../providers/finance_providers.dart';
import '../../providers/property_providers.dart';
import '../../widgets/common/document_nudge_banner.dart';
import '../../widgets/common/expense_lines_review_sheet.dart';
import '../../widgets/common/manual_loan_entry_sheet.dart';
import '../../widgets/common/missing_documents_sheet.dart';
import '../../widgets/common/utilities_liability_confirm_sheet.dart';
import '../../widgets/common/upload_source_sheet.dart';
import '../../widgets/common/finance_summary_panel.dart';
import '../../widgets/common/finance_year_picker.dart';
import '../../widgets/common/rent_payment_sheets.dart';
import '../../widgets/common/document_categories.dart' show isAllowedUploadFilename;
import '../2-Documind/documind_upload_summary.dart';
import 'unit_finance_detail_screen.dart';

/// Shared upload affordance: pick a PDF and file it under [category] for
/// [propertyId], property-wide. Reused by the drill-down screen and the
/// guided checklist. Returns whether a document was actually uploaded —
/// false if the user backed out of the picker, the file was rejected, or
/// the upload failed.
Future<bool> uploadDocumentForCategory(
  BuildContext context,
  WidgetRef ref, {
  required String propertyId,
  required String category,
}) async {
  final picked = await showUploadSourceSheet(context);
  if (picked == null) return false;
  if (!isAllowedUploadFilename(picked.name)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only PDF, JPG or PNG files are supported.')),
      );
    }
    return false;
  }
  try {
    final uploadAction = ref.read(uploadDocumentActionProvider);
    final uploaded = await uploadAction(
      propertyId: propertyId,
      category: category,
      file: File(picked.path),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(uploadFactSummary(category, uploaded.extractedFacts) ??
            'Document uploaded.'),
      ));
      final lines = uploaded.extractedFacts?['expense_lines'];
      if (category == 'expenses' && lines is List && lines.isNotEmpty) {
        await showExpenseLinesReviewSheet(
          context,
          docId: uploaded.docId,
          initialLines: [
            for (final line in lines)
              if (line is Map) Map<String, dynamic>.from(line),
          ],
        );
      }
      if (context.mounted) {
        await maybeShowUtilitiesLiabilityConfirm(
          context, ref,
          propertyId: propertyId,
          category: category,
          extractedFacts: uploaded.extractedFacts,
        );
      }
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
    return false;
  }
}

/// Finance tab: the engine's numbers rendered per year — headline panel,
/// per-property blocks (mirroring the landlord's reference sheet), unit
/// contribution rows, and the data-completeness indicator. Zero client math.
class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(financeYearProvider);
    final summaryAsync = ref.watch(financeSummaryProvider(year));
    final yearsAsync = ref.watch(financeYearsProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text('Finance', style: AppTextStyles.headlineMedium),
        backgroundColor: AppColors.paper,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: FinanceYearButton(
                selected: year,
                years: yearsAsync.value ?? [year],
                onChanged: (y) => ref.read(financeYearProvider.notifier).state = y,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.registry,
        onRefresh: () async {
          ref.invalidate(financeSummaryProvider(year));
          ref.invalidate(financeYearsProvider);
          await ref.read(financeSummaryProvider(year).future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            ...summaryAsync.when(
              data: (summary) => _buildSummary(context, ref, summary),
              loading: () => const [
                Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(
                      child:
                          CircularProgressIndicator(color: AppColors.registry)),
                ),
              ],
              error: (error, _) => [
                Padding(
                  padding: const EdgeInsets.only(top: 80),
                  child: Text(
                    "Couldn't load your finances. Check your connection and pull to retry.",
                    style: AppTextStyles.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSummary(
      BuildContext context, WidgetRef ref, FinanceSummary summary) {
    final isEmpty = summary.properties.isEmpty ||
        (summary.totals.receivedRent == 0 &&
            summary.totals.directExpenses == 0);
    if (isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 60),
          child: Column(
            children: [
              const Icon(Icons.payments_outlined,
                  size: 48, color: AppColors.textMuted),
              const SizedBox(height: 16),
              Text('No financial documents for ${summary.year}',
                  style: AppTextStyles.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Upload rent invoices, tax bills, loan statements and receipts — the numbers compute themselves.',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ];
    }

    return [
      FinanceSummaryPanel(
        summary: summary,
        onShowCaveats: () => _showCaveats(context, summary.caveats),
      ),
      const SizedBox(height: 20),
      ...summary.properties.map(
        (block) => _buildPropertyBlock(context, ref, summary, block),
      ),
    ];
  }

  Widget _miniStat(String label, double value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppColors.textSecondary,
          ),
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

  void _showCaveats(BuildContext context, List<String> caveats) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Assumptions & caveats', style: AppTextStyles.titleLarge),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: caveats
                      .map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 6),
                                  child: Icon(Icons.circle,
                                      size: 6, color: AppColors.textMuted),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Text(c,
                                        style: AppTextStyles.bodyMedium)),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openManualLoanSheet(
    BuildContext context,
    PropertyFinance block,
    Property? property,
    int year,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ManualLoanEntrySheet(
        propertyId: block.propertyId,
        year: year,
        cadence: property?.loanInputCadence,
        structureType: property?.structureType,
        units: block.units.where((u) => u.unitId != null).toList(),
      ),
    );
  }

  Widget _buildPropertyBlock(BuildContext context, WidgetRef ref,
      FinanceSummary summary, PropertyFinance block) {
    final missing = summary.missingCategories[block.propertyId] ?? const [];
    final property = ref.watch(propertyByIdProvider(block.propertyId)).value;
    final showManualLoan =
        block.manualLoanIncomplete && property?.hasMortgage == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(block.name, style: AppTextStyles.titleLarge)),
              if (block.ownershipShare < 1.0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Text(
                    '${(block.ownershipShare * 100).toStringAsFixed(0)}% share',
                    style: AppTextStyles.labelSmall,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _miniStat('RENTAL INCOME', block.receivedRent)),
              Expanded(child: _miniStat('EXPENSES', block.landlordExpenses)),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.hairline),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text('Net Profit/Loss · ${summary.year}',
                    style: AppTextStyles.labelLarge),
              ),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    formatRM(block.netPl),
                    style: AppTextStyles.displayMedium.copyWith(
                      color: block.netPl < 0 ? AppColors.sealRed : AppColors.deedGreen,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Statutory Income',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                formatRM(block.statutoryContribution ?? block.rentalIncomeOrLoss),
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (block.ownershipShare < 1.0) ...[
            const SizedBox(height: 4),
            Text(
              'Shown at your ${(block.ownershipShare * 100).toStringAsFixed(0)}% share',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
            ),
          ],
          if (!block.complete) ...[
            const SizedBox(height: 4),
            Text(
              '${summary.year} records are incomplete — this is a provisional figure and will change as documents arrive.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
            ),
          ],
          if (showManualLoan) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    _openManualLoanSheet(context, block, property, summary.year),
                icon: const Icon(Icons.add, size: 18, color: AppColors.registry),
                label: Text('Add loan figures', style: AppTextStyles.labelLarge),
              ),
            ),
          ],
          if (block.units.isNotEmpty) ...[
            const Divider(height: 20, color: AppColors.hairline),
            ...block.units.map((unit) => InkWell(
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => UnitFinanceDetailScreen(
                        propertyId: block.propertyId,
                        propertyName: block.name,
                        unit: unit,
                        year: summary.year,
                      ),
                    ));
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.meeting_room_outlined,
                            size: 18, color: AppColors.registry),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(unit.label,
                                style: AppTextStyles.titleMedium)),
                        Text(
                          '${unit.rentedMonths} mo rented',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textMuted),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.chevron_right,
                            size: 18, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                )),
          ],
          _buildRentIssuesSection(context, ref, block, summary.year),
          if (missing.isNotEmpty) ...[
            const Divider(height: 20, color: AppColors.hairline),
            DocumentNudgeBanner(
              count: missing.length,
              year: summary.year,
              onUpload: () => showMissingDocumentsSheet(
                context, ref,
                propertyId: block.propertyId,
                year: summary.year,
                missing: missing,
                mode: MissingDocsMode.upload,
              ),
              onMarkUnavailable: () => showMissingDocumentsSheet(
                context, ref,
                propertyId: block.propertyId,
                year: summary.year,
                missing: missing,
                mode: MissingDocsMode.markUnavailable,
              ),
              onEnterManually: missing.contains('loan')
                  ? () => _openManualLoanSheet(
                      context, block, property, summary.year)
                  : null,
            ),
          ],
          if ((yearCoverageFor(block.coverage, summary.year)?.unavailable ?? const []).isNotEmpty) ...[
            const SizedBox(height: 4),
            ...yearCoverageFor(block.coverage, summary.year)!.unavailable.map((category) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.remove_circle_outline, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${coverageLabels[category] ?? category} — acknowledged unavailable',
                          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
                        ),
                      ),
                      TextButton(
                        onPressed: () => ref.read(clearDocumentUnavailableActionProvider)(
                          propertyId: block.propertyId, year: summary.year, category: category,
                        ),
                        child: const Text('Undo'),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildRentIssuesSection(
      BuildContext context, WidgetRef ref, PropertyFinance block, int year) {
    final issues = <(UnitFinance unit, MonthIncome month)>[];
    for (final unit in block.units) {
      for (final month in unit.months) {
        if (month.source == 'unpaid') {
          issues.add((unit, month));
        }
      }
    }
    if (issues.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 20, color: AppColors.hairline),
        Text('Rent payment issues — $year', style: AppTextStyles.titleMedium),
        const SizedBox(height: 8),
        ...issues.map((issue) {
          final unit = issue.$1;
          final month = issue.$2;
          final monthLabel = '${monthAbbrev[month.month - 1]} $year';
          final isWrittenOff = month.paymentState == 'written_off';
          return InkWell(
            onTap: () => showManageUnpaidSheet(
              context, ref,
              propertyId: block.propertyId, unitId: unit.unitId,
              month: '$year-${month.month.toString().padLeft(2, '0')}',
              monthLabel: monthLabel,
              paymentState: month.paymentState ?? 'outstanding',
              reason: month.reason, billedAmount: month.billedAmount,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(
                    isWrittenOff ? Icons.block_outlined : Icons.error_outline,
                    size: 16,
                    color: isWrittenOff ? AppColors.textMuted : AppColors.sealRed,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${unit.label} — $monthLabel', style: AppTextStyles.bodyMedium),
                  ),
                  Text(
                    isWrittenOff ? 'Written off' : 'Outstanding',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: isWrittenOff ? AppColors.textMuted : AppColors.sealRed,
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
