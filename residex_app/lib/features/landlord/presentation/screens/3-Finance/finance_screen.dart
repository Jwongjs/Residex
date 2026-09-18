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
import '../../widgets/common/share_badge.dart';
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
          propertyId: propertyId,
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
          // Bare invalidate on the family (no args), same pattern the action
          // providers below already use on financeSummaryProvider: retries
          // every property/year combination currently mounted, not just one.
          ref.invalidate(manualLoanEntriesProvider);
          ref.invalidate(allManualLoanEntriesProvider);
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
                'Upload rent invoices, tax bills, loan statements and receipts. '
                'The numbers compute themselves.',
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
    final property = ref.watch(propertyByIdProvider(block.propertyId)).value;
    final missing = summary.missingCategories[block.propertyId] ?? const [];
    // 'loan' nudges like any other category: a mortgaged property with no
    // figures booked by either route genuinely is missing a document.
    // Both loan routes are always available, so the panel row — the
    // discoverable manual route — is shown for any mortgaged property.
    final showManualLoan = property?.hasMortgage == true;
    // Every share rendered under this card. The property's own is always in
    // the set: it is what a building-wide loan or quit rent is scaled by, so
    // a property at 50% whose units are all owned outright still says so.
    final shares = <double>{
      block.ownershipShare,
      ...block.units.map((u) => u.ownershipShare),
    };
    final lowestShare = shares.reduce((a, b) => a < b ? a : b);
    final highestShare = shares.reduce((a, b) => a > b ? a : b);
    final sharesVary = lowestShare != highestShare;
    final showShare = lowestShare < 1.0;
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
              if (showShare)
                ShareBadge(
                  text: sharesVary
                      ? '${(lowestShare * 100).toStringAsFixed(0)}–'
                          '${(highestShare * 100).toStringAsFixed(0)}% share'
                      : '${(lowestShare * 100).toStringAsFixed(0)}% share',
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
          if (showManualLoan) ...[
            const SizedBox(height: 8),
            _buildLoanFiguresRow(context, ref, block, property, summary.year),
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
                        if (unit.ownershipShare < 1.0) ...[
                          ShareBadge(
                            text: '${(unit.ownershipShare * 100).toStringAsFixed(0)}'
                                '% share',
                          ),
                          const SizedBox(width: 8),
                        ],
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
              // No onEnterManually: the nudge is about missing documents, and
              // the manual route already has a permanent home in the loan
              // figures row below. Offering it here too made the same choice
              // read two different ways on one screen.
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
                          '${coverageLabels[category] ?? category} · acknowledged unavailable',
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

  /// 'YYYY-MM' -> ('March 2027'). Returns null for anything unparseable, so a
  /// bad stored value degrades to "not settled" rather than rendering garbage
  /// — matching the backend's _loan_expected_for, which treats a malformed
  /// value as unset.
  static ({int year, int month})? _parseSettled(String? value) {
    if (value == null || value.length < 7) return null;
    final year = int.tryParse(value.substring(0, 4));
    final month = int.tryParse(value.substring(5, 7));
    if (year == null || month == null || month < 1 || month > 12) return null;
    return (year: year, month: month);
  }

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  /// Both the empty and populated states use this so the control never reads
  /// "Mortgage paid off?" on a property that already has a date (which
  /// happens in the *settlement year and earlier*, where the block still
  /// behaves normally).
  static String _settlementLabel(({int year, int month})? settled) =>
      settled == null
          ? 'Mortgage paid off?'
          : 'Mortgage settled · ${_monthNames[settled.month - 1]} ${settled.year}';

  /// Reads the raw booked entries rather than the loan expense lines. This
  /// was once a deliberate carve-out against the engine scaling every
  /// expense line by ownership share uniformly; now that the engine exempts
  /// loan interest and principal from that scaling (see `_line_share` in
  /// `finance_engine.py`), this row simply agrees with the engine rather
  /// than working around it — it still reads the raw booked entries because
  /// its job is letting the landlord verify what they typed, not because the
  /// expense lines would show a different number.
  Widget _buildLoanFiguresRow(BuildContext context, WidgetRef ref,
      PropertyFinance block, Property? property, int year) {
    final entriesAsync = ref.watch(manualLoanEntriesProvider(
        (propertyId: block.propertyId, year: year)));

    // Still resolving and nothing cached yet. The control's presence must
    // not depend on a network call completing — this request has no timeout
    // and pull-to-refresh is the only retry path — so it stays on screen,
    // just disabled, rather than disappearing into a blank gap for the rest
    // of the session if the request stalls.
    final isInitialLoading = entriesAsync.isLoading && !entriesAsync.hasValue;

    // Presence of a booked entry is what matters, not whether its amounts
    // happen to be nonzero: interest>0||principal>0 also read "errored" and
    // "booked as 0/0" (the sheet allows a 0/0 save) as "nothing booked",
    // which is wrong for the booked-zero case. Sourced from
    // entriesAsync.value (riverpod's safe nullable getter, non-null exactly
    // when hasValue is true) rather than asData?.value, which is null
    // during a refresh — in-flight or failed — even when a prior value is
    // still known: reading asData here made a failed *refresh* look
    // identical to "nothing ever booked", collapsing the whole figures
    // block to the disabled Add affordance below and hiding figures the app
    // still knows, even though the sheet's own Save (see
    // manual_loan_entry_sheet.dart) would still accept a save in that state.
    final entries = entriesAsync.value ?? const <Map<String, dynamic>>[];
    double sum(String key) => entries.fold<double>(
        0, (total, e) => total + ((e[key] as num?)?.toDouble() ?? 0));
    final interest = sum('interest_paid');
    final principal = sum('principal_paid');
    final hasFigures = entries.isNotEmpty;

    // A load that has *never* resolved is treated the same as still-loading:
    // the sheet's own Save button is gated on manualLoanEntriesProvider
    // having resolved at least once, and a fetch that has never succeeded
    // never will resolve on its own — Riverpod's automatic retries exhaust
    // within roughly a minute, after which pull-to-refresh here is the only
    // way forward. Opening the sheet at that point would walk the landlord
    // into a form they cannot submit, so the control stays visible but
    // disabled rather than inviting the tap.
    //
    // Narrowed to !hasValue: an error on a *refresh* that carried a prior
    // value must not land here, since hasFigures (above) is still true in
    // that case and the sheet's Save is still usable (matching hasValue) —
    // disabling the control there would block a working save over a
    // transient refetch failure the landlord doesn't need to do anything
    // about.
    final isUnusable =
        isInitialLoading || (entriesAsync.hasError && !entriesAsync.hasValue);

    final settled = _parseSettled(property?.mortgageSettledOn);
    // The settled *state* replaces the block only for years after the
    // settlement year. The settlement year and every year before it still
    // expect figures, so they keep the normal block with the settled date as
    // a quiet line beneath.
    if (settled != null && year > settled.year) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 32, color: AppColors.hairline),
          Row(
            children: [
              const Icon(Icons.check_circle_outline,
                  size: 16, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Mortgage settled · ${_monthNames[settled.month - 1]} ${settled.year}',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textMuted),
                ),
              ),
              if (property != null)
                TextButton(
                  onPressed: () => _openSettlementSheet(context, ref, property),
                  child: Text('Change', style: AppTextStyles.labelLarge),
                ),
            ],
          ),
        ],
      );
    }

    if (!hasFigures) {
      // Stacked, not side by side: "Add loan figures" is the frequent,
      // primary action and needs its full label legible, while the
      // settlement question is rare and one-time. Cramming both into one
      // row starved whichever label lost the width fight on narrow screens.
      // Matches the populated state's placement below.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 32, color: AppColors.hairline),
          Opacity(
            opacity: isUnusable ? 0.5 : 1.0,
            child: TextButton.icon(
              onPressed: isUnusable
                  ? null
                  : () => _openManualLoanSheet(context, block, property, year),
              icon: const Icon(Icons.add, size: 18, color: AppColors.registry),
              label: Text('Add loan figures', style: AppTextStyles.labelLarge),
            ),
          ),
          if (property != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => _openSettlementSheet(context, ref, property),
                child: Text(
                  _settlementLabel(settled),
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.textMuted),
                ),
              ),
            ),
        ],
      );
    }

    final completenessLine =
        _buildLoanCompletenessLine(property, block, entries, year);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32, color: AppColors.hairline),
        Row(
          children: [
            Expanded(
              child: Text('Loan figures · $year',
                  style: AppTextStyles.titleMedium),
            ),
            // Trailing edge of the title row: read together with the label it
            // modifies, clear of the amounts, and where the panel already puts
            // row-level actions.
            TextButton.icon(
              onPressed: () =>
                  _openManualLoanSheet(context, block, property, year),
              icon: const Icon(Icons.edit_outlined,
                  size: 16, color: AppColors.registry),
              label: Text('Modify', style: AppTextStyles.labelLarge),
            ),
          ],
        ),
        _loanFigureLine('Interest', interest),
        _loanFigureLine('Principal', principal),
        if (completenessLine != null) completenessLine,
        if (property != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _openSettlementSheet(context, ref, property),
              child: Text(
                _settlementLabel(settled),
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textMuted),
              ),
            ),
          ),
      ],
    );
  }

  /// Records (or corrects, or clears) the month the mortgage was repaid.
  ///
  /// Two sheets rather than one 12×N list: a flat month-year list would be
  /// hundreds of rows. Mirrors _pickTrackFromYear's modal-list pattern so a
  /// landlord meets the same interaction twice, not two inventions.
  Future<void> _openSettlementSheet(
      BuildContext context, WidgetRef ref, Property property) async {
    final currentYear = DateTime.now().year;
    final earliest = property.trackFromYear ?? 2000;
    final existing = _parseSettled(property.mortgageSettledOn);
    const clear = -1; // sentinel: distinguishes "clear it" from a dismissed sheet

    final year = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('When was the mortgage repaid?',
                  style: AppTextStyles.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Past years keep their loan figures. You just stop being '
                'asked from this point on.',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (existing != null)
                      ListTile(
                        leading: const Icon(Icons.undo,
                            color: AppColors.textMuted),
                        title: Text('Still paying it off',
                            style: AppTextStyles.bodyLarge),
                        onTap: () => Navigator.of(sheetContext).pop(clear),
                      ),
                    for (var y = currentYear; y >= earliest; y--)
                      ListTile(
                        title: Text('$y', style: AppTextStyles.bodyLarge),
                        trailing: existing?.year == y
                            ? const Icon(Icons.check, color: AppColors.registry)
                            : null,
                        onTap: () => Navigator.of(sheetContext).pop(y),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (year == null) return; // dismissed
    if (year == clear) {
      // withMortgageSettledOn, never copyWith: copyWith coalesces `?? this`,
      // so copyWith(mortgageSettledOn: null) would silently keep the old date.
      await _saveSettlement(ref, property.withMortgageSettledOn(null));
      return;
    }

    if (!context.mounted) return;
    final month = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Which month in $year?', style: AppTextStyles.titleLarge),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (var m = 1; m <= 12; m++)
                      ListTile(
                        title: Text(_monthNames[m - 1],
                            style: AppTextStyles.bodyLarge),
                        trailing:
                            existing?.year == year && existing?.month == m
                                ? const Icon(Icons.check,
                                    color: AppColors.registry)
                                : null,
                        onTap: () => Navigator.of(sheetContext).pop(m),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (month == null) return; // dismissed at the second step — nothing written
    await _saveSettlement(
      ref,
      property.withMortgageSettledOn(
        '$year-${month.toString().padLeft(2, '0')}',
      ),
    );
  }

  /// Persist a settlement change and refresh the finance summary with it.
  ///
  /// `updateProperty` invalidates only the property providers. The settlement
  /// date is also an *engine* input — it decides whether `loan` is still
  /// expected — so without invalidating the summary the loan block (which
  /// reads the property directly) updates instantly while the nudge above it
  /// keeps counting the loan document as outstanding. The screen then shows
  /// two statements that contradict each other until a pull-to-refresh.
  /// Every other finance-affecting write in `documind_provider.dart` already
  /// invalidates the summary; this path is the one that did not.
  Future<void> _saveSettlement(WidgetRef ref, Property updated) async {
    await ref.read(propertyControllerProvider).updateProperty(updated);
    ref.invalidate(financeSummaryProvider);
  }

  /// A quiet completeness sub-line under the figures block. `manualLoanIncomplete`
  /// goes true the instant a booked entry stops covering the whole cadence or
  /// unit list — one missing month out of twelve, or one unit out of three —
  /// while the figures block above it can otherwise look clean and complete.
  /// This is the only place that gap becomes visible; it names it concretely
  /// (how many months/units are actually in) rather than a bare "incomplete".
  ///
  /// `block.units[].loanStatus` is read here rather than re-deriving
  /// completeness from [entries] independently, so this line can never
  /// disagree with the backend's own `manualLoanIncomplete` computation.
  Widget? _buildLoanCompletenessLine(
    Property? property,
    PropertyFinance block,
    List<Map<String, dynamic>> entries,
    int year,
  ) {
    if (!block.manualLoanIncomplete) return null;

    final trackedUnits =
        block.units.where((u) => u.loanStatus != null).toList();

    String message;
    if (trackedUnits.length > 1) {
      final resolved =
          trackedUnits.where((u) => u.loanStatus != 'incomplete').length;
      message = '$resolved of ${trackedUnits.length} units recorded for $year';
    } else if ((property?.loanInputCadence ?? 'annual') == 'monthly') {
      final scopeUnitId =
          trackedUnits.isNotEmpty ? trackedUnits.first.unitId : null;
      final recordedMonths = entries
          .where((e) => e['unit_id'] == scopeUnitId && e['month'] != null)
          .map((e) => (e['month'] as num).toInt())
          .toSet()
          .length;
      final now = DateTime.now();
      // The backend requires only *elapsed* months (finance_engine.py's
      // _months_in_scope), and settlement adds a third bound. A hardcoded 12
      // told a landlord in March they were 3 of 12 done when the backend
      // considered them complete.
      var monthsInScope = year < now.year ? 12 : (year > now.year ? 0 : now.month);
      final settled = _parseSettled(property?.mortgageSettledOn);
      // A cap, never an override. The backend takes the *intersection* of
      // both bounds: _months_in_scope stops at the elapsed month, then
      // _loan_expected_for drops months past the settled one. The settlement
      // picker offers all 12 months of the current year, so a landlord can
      // pick a month still in the future — overriding to settled.month there
      // would read "2 of 11" in August against a backend that wants 8, which
      // is the same class of mismatch the hardcoded 12 used to cause.
      if (settled != null && year == settled.year) {
        monthsInScope = monthsInScope < settled.month ? monthsInScope : settled.month;
      }
      message = '$recordedMonths of $monthsInScope months recorded for $year';
    } else {
      message = 'Some $year loan figures are still missing';
    }

    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(message,
                style:
                    AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted)),
          ),
        ],
      ),
    );
  }

  Widget _loanFigureLine(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textMuted)),
          ),
          Text(formatRM(amount), style: AppTextStyles.bodySmall),
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
        Text('Rent payment issues · $year', style: AppTextStyles.titleMedium),
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
              fullBilledAmount: month.fullBilledAmount,
              grossIncome: unit.grossIncome,
              fullGrossIncome: unit.fullGrossIncome,
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
                    child: Text('${unit.label} · $monthLabel', style: AppTextStyles.bodyMedium),
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
