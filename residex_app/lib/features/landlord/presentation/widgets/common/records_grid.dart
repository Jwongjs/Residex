import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../domain/entities/finance_summary.dart';
import '../../providers/finance_logic.dart';
import '../../providers/finance_providers.dart';
import '../../screens/3-Finance/finance_screen.dart' show uploadDocumentForCategory;

enum RecordCellState { present, missing, partial, unavailable }

class RecordCell {
  final RecordCellState state;
  final String? partialLabel; // e.g. "4/12" when partial
  const RecordCell(this.state, {this.partialLabel});
}

/// Maps a Records-grid category code to the raw tax-subtype display labels
/// (`InstallmentGap.label`) that could produce a partial-installment gap
/// for it. Composite/fallback categories (a strata `land_office_tax` slot,
/// or the profile-less generic `tax` bucket) can be satisfied by more than
/// one raw subtype — matching only the composite's own display text would
/// silently show "present" for a real installment gap, since the backend
/// never emits a `land_office_tax`-labeled gap (only 'Assessment tax' /
/// 'Quit rent' / 'Parcel rent' / the 'Property tax' fallback, per
/// `_TAX_LABELS` in `finance_engine.py`).
const Map<String, Set<String>> _installmentLabelsForCategory = {
  'assessment': {'Assessment tax'},
  'quit_rent': {'Quit rent'},
  'parcel_rent': {'Parcel rent'},
  'land_office_tax': {'Quit rent', 'Parcel rent'},
  'tax': {'Assessment tax', 'Quit rent', 'Parcel rent', 'Property tax'},
};

/// Derives one grid cell's state from a year's coverage row. Pure and
/// testable independent of any widget.
RecordCell recordCellFor(YearCoverage coverage, String category) {
  if (coverage.unavailable.contains(category)) {
    return const RecordCell(RecordCellState.unavailable);
  }
  if (category == 'maintenance') {
    final partial = coverage.partialCategories.where((p) => p.category == 'maintenance');
    if (partial.isNotEmpty) {
      final p = partial.first;
      return RecordCell(RecordCellState.partial, partialLabel: '${p.have}/${p.expect}');
    }
  }
  final matchLabels = _installmentLabelsForCategory[category] ?? {coverageLabels[category] ?? category};
  final installmentGap = coverage.partialInstallments.where((g) => matchLabels.contains(g.label));
  if (installmentGap.isNotEmpty) {
    final g = installmentGap.first;
    return RecordCell(RecordCellState.partial, partialLabel: '${g.have}/${g.expect}');
  }
  if (coverage.missing.contains(category)) {
    return const RecordCell(RecordCellState.missing);
  }
  return const RecordCell(RecordCellState.present);
}

/// Year x category records grid (spec §6 Step 3, §9): every tracked year
/// as a row, every expected expense category as a column, an upload
/// button in every empty cell. Reads entirely off the already-computed
/// finance summary — no new fetch beyond [financeSummaryProvider].
class RecordsGridBody extends ConsumerWidget {
  final String propertyId;
  final PropertyFinance property;

  const RecordsGridBody({super.key, required this.propertyId, required this.property});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final years = property.coverage.map((c) => c.year).toList()..sort();
    final categories = property.expectedCategories;
    if (years.isEmpty || categories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Nothing to track yet for ${property.name}.',
            style: AppTextStyles.bodyMedium),
      );
    }
    final coverageByYear = {for (final c in property.coverage) c.year: c};
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          const DataColumn(label: Text('Year')),
          for (final category in categories)
            DataColumn(label: Text(coverageLabels[category] ?? category)),
        ],
        rows: [
          for (final year in years)
            DataRow(cells: [
              DataCell(Text('$year')),
              for (final category in categories)
                DataCell(_buildCell(
                  context, ref, recordCellFor(coverageByYear[year]!, category), category,
                )),
            ]),
        ],
      ),
    );
  }

  Widget _buildCell(BuildContext context, WidgetRef ref, RecordCell cell, String category) {
    switch (cell.state) {
      case RecordCellState.present:
        return const Icon(Icons.check_circle_outline, size: 18, color: AppColors.deedGreen);
      case RecordCellState.unavailable:
        return const Icon(Icons.remove_circle_outline, size: 18, color: AppColors.textMuted);
      case RecordCellState.partial:
        return Text(cell.partialLabel ?? '',
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.catUpkeep));
      case RecordCellState.missing:
        return InkWell(
          onTap: () => uploadDocumentForCategory(
            context, ref,
            propertyId: propertyId,
            category: uploadCategoryFor(category),
          ),
          child: const Icon(Icons.upload_file_outlined, size: 18, color: AppColors.registry),
        );
    }
  }
}

/// Permanent, full-screen home for the grid — the Documents tab's header
/// action (spec §9) pushes this.
class RecordsGridScreen extends ConsumerWidget {
  final String propertyId;
  final String propertyName;

  const RecordsGridScreen({super.key, required this.propertyId, required this.propertyName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(financeSummaryProvider(DateTime.now().year));
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        title: Text('$propertyName — Records', style: AppTextStyles.titleLarge),
      ),
      body: summaryAsync.when(
        data: (summary) {
          final property = summary.properties.firstWhere(
            (p) => p.propertyId == propertyId,
            orElse: () => PropertyFinance(
              propertyId: propertyId, name: propertyName,
              receivedRent: 0, derivedRent: 0, directExpenses: 0, rentalIncomeOrLoss: 0,
            ),
          );
          return RecordsGridBody(propertyId: propertyId, property: property);
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.registry)),
        error: (e, _) => Center(
          child: Text("Couldn't load records.", style: AppTextStyles.bodyMedium),
        ),
      ),
    );
  }
}
