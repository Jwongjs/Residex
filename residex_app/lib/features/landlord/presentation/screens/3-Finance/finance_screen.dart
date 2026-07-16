import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/theme/app_dimensions.dart';
import '../../../domain/entities/finance_summary.dart';
import '../../providers/documind_provider.dart';
import '../../providers/finance_logic.dart';
import '../../providers/finance_providers.dart';
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
  final result = await FilePicker.platform.pickFiles(type: FileType.any);
  if (result == null) return;
  final picked = result.files.single;
  if (!isAllowedUploadFilename(picked.name) || picked.path == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only PDF files are supported.')),
      );
    }
    return;
  }
  try {
    final uploadAction = ref.read(uploadDocumentActionProvider);
    final uploaded = await uploadAction(
      propertyId: propertyId,
      category: category,
      file: File(picked.path!),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(uploadFactSummary(category, uploaded.extractedFacts) ??
            'Document uploaded.'),
      ));
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
            _buildYearChips(ref, year, yearsAsync.value ?? [year]),
            const SizedBox(height: 16),
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

  Widget _buildYearChips(WidgetRef ref, int selected, List<int> years) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: years.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final year = years[index];
          final isSelected = year == selected;
          return ChoiceChip(
            label: Text('$year'),
            selected: isSelected,
            selectedColor: AppColors.registry,
            labelStyle: AppTextStyles.labelLarge.copyWith(
              color: isSelected ? Colors.white : AppColors.ink,
            ),
            onSelected: (_) =>
                ref.read(financeYearProvider.notifier).state = year,
          );
        },
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
      _buildHeadlinePanel(context, summary),
      const SizedBox(height: 20),
      ...summary.properties.map(
        (block) => _buildPropertyBlock(context, ref, summary, block),
      ),
    ];
  }

  Widget _buildHeadlinePanel(BuildContext context, FinanceSummary summary) {
    final totals = summary.totals;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
        boxShadow: AppShadows.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _headlineRow('Received Rent', totals.receivedRent),
          if (totals.derivedRent > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'includes ${formatRM(totals.derivedRent)} backfilled from lease terms',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textMuted),
              ),
            ),
          _headlineRow('Direct Expenses', totals.directExpenses),
          const Divider(height: 20, color: AppColors.hairline),
          _headlineRow('Net P/L', totals.netPl, emphasized: true),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Statutory Rental Income',
                        style: AppTextStyles.labelLarge),
                    Text(
                      totals.statutoryNote,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              Text(formatRM(totals.statutoryRentalIncome),
                  style: AppTextStyles.titleLarge),
              IconButton(
                icon: const Icon(Icons.info_outline,
                    size: 20, color: AppColors.textMuted),
                tooltip: 'Assumptions and caveats',
                onPressed: () => _showCaveats(context, summary.caveats),
              ),
            ],
          ),
        ],
      ),
    );
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
              'Missing for ${summary.year} — figures may be incomplete',
              style:
                  AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: missing
                  .map((category) => ActionChip(
                        avatar: const Icon(Icons.upload_file_outlined,
                            size: 16, color: AppColors.registry),
                        label: Text(
                          financeCategoryLabels[category] ?? category,
                          style: AppTextStyles.labelSmall,
                        ),
                        onPressed: () => uploadDocumentForCategory(
                          context,
                          ref,
                          propertyId: block.propertyId,
                          category: category,
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
