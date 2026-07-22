import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../domain/entities/finance_summary.dart';
import '../../providers/documind_provider.dart';
import '../../providers/finance_logic.dart';
import '../../providers/finance_providers.dart';
import '../../widgets/common/expense_lines_review_sheet.dart';
import '../../widgets/common/upload_source_sheet.dart';
import '../../widgets/common/finance_ledger_strip.dart';
import '../../widgets/common/finance_year_picker.dart';
import '../2-Documind/documind_screen.dart' show isAllowedUploadFilename;
import '../2-Documind/documind_upload_summary.dart';
import 'unit_finance_detail_screen.dart';

/// Shared upload affordance: pick a PDF and file it under [category] for
/// [propertyId], property-wide. Reused by the drill-down screen and the
/// guided checklist.
Future<void> uploadDocumentForCategory(
  BuildContext context,
  WidgetRef ref, {
  required String propertyId,
  required String category,
}) async {
  final picked = await showUploadSourceSheet(context);
  if (picked == null) return;
  if (!isAllowedUploadFilename(picked.name)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only PDF, JPG or PNG files are supported.')),
      );
    }
    return;
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
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
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
      FinanceLedgerStrip(
        summary: summary,
        onShowCaveats: () => _showCaveats(context, summary.caveats),
      ),
      const SizedBox(height: 20),
      ...summary.properties.map(
        (block) => _buildPropertyBlock(context, ref, summary, block),
      ),
    ];
  }

  Widget _headlineRow(String label, double value, {bool emphasized = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.labelLarge)),
          Text(
            formatRM(value),
            style: emphasized
                ? AppTextStyles.displayMedium
                : AppTextStyles.titleMedium,
          ),
        ],
      ),
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

  Widget _buildCoverageStrip(
      BuildContext context, WidgetRef ref, PropertyFinance block) {
    return SizedBox(
      height: 28,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: block.coverage.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final yearCoverage = block.coverage[index];
          final complete = yearCoverage.missing.isEmpty;
          final color = complete ? AppColors.deedGreen : AppColors.catUpkeep;
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () =>
                ref.read(financeYearProvider.notifier).state = yearCoverage.year,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    complete ? Icons.check_circle_outline : Icons.error_outline,
                    size: 13,
                    color: color,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    complete
                        ? '${yearCoverage.year}'
                        : '${yearCoverage.year} · ${yearCoverage.missing.length} missing',
                    style: AppTextStyles.labelSmall.copyWith(color: color),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPropertyBlock(BuildContext context, WidgetRef ref,
      FinanceSummary summary, PropertyFinance block) {
    final missing = summary.missingCategories[block.propertyId] ?? const [];
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
          if (block.coverage.isNotEmpty) ...[
            _buildCoverageStrip(context, ref, block),
            const SizedBox(height: 10),
          ],
          _headlineRow('Received Rent', block.receivedRent),
          _headlineRow('Direct Expenses', block.directExpenses),
          _headlineRow('Rental Income/Loss', block.rentalIncomeOrLoss,
              emphasized: true),
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
                        const SizedBox(width: 10),
                        Text(formatRM(unit.contribution),
                            style: AppTextStyles.titleMedium),
                        const Icon(Icons.chevron_right,
                            size: 18, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                )),
          ],
          if (missing.isNotEmpty) ...[
            const Divider(height: 20, color: AppColors.hairline),
            Text(
              topMissingDocumentBanner(summary.year, missing) ??
                  'Missing for ${summary.year} — figures may be incomplete',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: rankMissingDocuments(missing)
                  .map((category) => ActionChip(
                        avatar: const Icon(Icons.upload_file_outlined,
                            size: 16, color: AppColors.registry),
                        label: Text(
                          coverageLabels[category] ?? category,
                          style: AppTextStyles.labelSmall,
                        ),
                        onPressed: () => uploadDocumentForCategory(
                          context,
                          ref,
                          propertyId: block.propertyId,
                          category: uploadCategoryFor(category),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
