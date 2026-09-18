import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../domain/entities/finance_summary.dart';
import '../../../domain/entities/property.dart';
import '../../providers/documind_provider.dart';
import '../../providers/finance_logic.dart' show formatRM, monthAbbrev;
import '../../providers/finance_providers.dart';
import '../../providers/property_providers.dart';
import 'app_choice_chip.dart';

/// Add/edit form + list for a property whose loan figures are keyed in by
/// hand rather than uploaded. Opened from the finance panel's loan figures
/// row. Purely an input surface — the engine (not this widget) recomputes
/// the year's figures once an entry lands.
///
/// When [units] is non-empty, the sheet lets the landlord scope each entry
/// to "Whole property" or a specific unit, and mark/unmark a unit as having
/// no loan at all (excluding it from the manual-loan completeness check).
class ManualLoanEntrySheet extends ConsumerStatefulWidget {
  final String propertyId;
  final int year;

  /// Null until the landlord has chosen one — the sheet then asks and persists
  /// it to the property, so the question is posed when it is meaningful rather
  /// than during registration.
  final String? cadence;

  /// Decides the loan's real-world scope: a landed title carries one loan
  /// however many rooms are let, while each strata unit is separately titled
  /// and separately mortgaged. Null (some commercial) leaves both open.
  final PropertyStructureType? structureType;

  final List<UnitFinance> units;

  const ManualLoanEntrySheet({
    super.key,
    required this.propertyId,
    required this.year,
    required this.cadence,
    required this.structureType,
    required this.units,
  });

  @override
  ConsumerState<ManualLoanEntrySheet> createState() =>
      _ManualLoanEntrySheetState();
}

class _ManualLoanEntrySheetState extends ConsumerState<ManualLoanEntrySheet> {
  final _interestController = TextEditingController();
  final _principalController = TextEditingController();
  int _month = 1;
  bool _saving = false;
  String? _selectedUnitId;
  String? _cadence;

  /// The (unitId, month, hasEntry) key whose booked figures are currently
  /// loaded into the fields. Guards `_prefillFor` so it only overwrites the
  /// controllers when this key actually changes — this runs from `build`,
  /// and the sheet rebuilds on provider changes it does not control (e.g.
  /// after a save invalidates `manualLoanEntriesProvider`), so an
  /// unconditional write would fight the landlord's in-progress typing.
  ///
  /// `hasEntry` (whether a booked entry existed for the scope, not just the
  /// scope itself) is part of the key so a delete that leaves the scope
  /// unchanged but removes its entry still clears the fields: without it,
  /// the guard would see an unchanged scope after the delete's refetch and
  /// skip the write, leaving the deleted figures on screen.
  ({String? unitId, int? month, bool hasEntry})? _prefilledScope;

  /// The (unitId, month) scope the sheet is currently working in — the exact
  /// key an entry is booked under, and the exact key `_save` writes to.
  /// Single source of truth: recomputing `_cadence == 'monthly' ? _month :
  /// null` independently in multiple places is exactly how scope could drift
  /// between what's shown and what's saved, which is the data-loss vector
  /// this widget exists to close off.
  ({String? unitId, int? month}) get _currentScope =>
      (unitId: _selectedUnitId, month: _cadence == 'monthly' ? _month : null);

  @override
  void initState() {
    super.initState();
    _cadence = widget.cadence;
    // The strata per-unit default selection is derived in build() from the
    // *live* units list (financeSummaryProvider), not from widget.units —
    // widget.units can be a frozen/stale snapshot from a caller (see
    // build()'s `units` local and the comment above it).
  }

  @override
  void dispose() {
    _interestController.dispose();
    _principalController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final interest = double.tryParse(_interestController.text.trim()) ?? 0;
    final principal = double.tryParse(_principalController.text.trim()) ?? 0;
    final scope = _currentScope;
    setState(() => _saving = true);
    try {
      await ref.read(recordManualLoanEntryActionProvider)(
        propertyId: widget.propertyId,
        year: widget.year,
        cadence: _cadence ?? 'annual',
        interestPaid: interest,
        principalPaid: principal,
        month: scope.month,
        unitId: scope.unitId,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save loan figures: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Persists the landlord's cadence choice to the property so the question
  /// is asked once and not re-asked on later visits to this sheet.
  Future<void> _chooseCadence(String cadence) async {
    setState(() => _cadence = cadence);
    final property =
        await ref.read(propertyByIdProvider(widget.propertyId).future);
    if (property == null) return;
    await ref
        .read(propertyControllerProvider)
        .updateProperty(property.copyWith(loanInputCadence: cadence));
  }

  /// The booked entry for the scope currently selected in the sheet. An entry
  /// is keyed by (unit_id, month), exactly as _save writes it.
  Map<String, dynamic>? _entryForCurrentScope(List<Map<String, dynamic>> entries) {
    final scope = _currentScope;
    for (final entry in entries) {
      final entryMonth = (entry['month'] as num?)?.toInt();
      if (entry['unit_id'] == scope.unitId && entryMonth == scope.month) {
        return entry;
      }
    }
    return null;
  }

  /// Load the booked figures into the fields so Modify opens ready to correct.
  /// Without this, _save's `?? 0` writes zero over whichever field the
  /// landlord did not retype. Only writes when the (unitId, month, hasEntry)
  /// key differs from the last one prefilled, so it neither fights the
  /// landlord's typing on an unrelated rebuild nor gets stuck showing stale
  /// figures once a save (or a delete) invalidates the entries provider.
  void _prefillFor(List<Map<String, dynamic>> entries) {
    final scope = _currentScope;
    final entry = _entryForCurrentScope(entries);
    final key = (unitId: scope.unitId, month: scope.month, hasEntry: entry != null);
    if (_prefilledScope == key) return;
    _prefilledScope = key;

    final interest = (entry?['interest_paid'] as num?)?.toDouble();
    final principal = (entry?['principal_paid'] as num?)?.toDouble();
    final nextInterest = interest == null ? '' : _formatAmountForInput(interest);
    final nextPrincipal =
        principal == null ? '' : _formatAmountForInput(principal);
    if (_interestController.text != nextInterest) {
      _interestController.text = nextInterest;
    }
    if (_principalController.text != nextPrincipal) {
      _principalController.text = nextPrincipal;
    }
  }

  Future<void> _remove(int? month) async {
    try {
      await ref.read(deleteManualLoanEntryActionProvider)(
        propertyId: widget.propertyId,
        year: widget.year,
        month: month,
        unitId: _selectedUnitId,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove entry: $e')),
        );
      }
    }
  }

  Future<void> _setExemption() async {
    final unitId = _selectedUnitId;
    if (unitId == null) return;
    try {
      await ref.read(setUnitLoanExemptionActionProvider)(
        propertyId: widget.propertyId,
        unitId: unitId,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update loan status: $e')),
        );
      }
    }
  }

  Future<void> _clearExemption() async {
    final unitId = _selectedUnitId;
    if (unitId == null) return;
    try {
      await ref.read(clearUnitLoanExemptionActionProvider)(
        propertyId: widget.propertyId,
        unitId: unitId,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update loan status: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(
      manualLoanEntriesProvider(
          (propertyId: widget.propertyId, year: widget.year)),
    );
    final isMonthly = _cadence == 'monthly';

    final summaryAsync = ref.watch(financeSummaryProvider(widget.year));
    final units = summaryAsync.maybeWhen(
      data: (summary) {
        for (final p in summary.properties) {
          if (p.propertyId == widget.propertyId) {
            return p.units.where((u) => u.unitId != null).toList();
          }
        }
        return widget.units;
      },
      orElse: () => widget.units,
    );

    // Landed = one title, one loan, whatever the room count. Strata = one loan
    // per separately-titled unit. Only an unknown structure keeps both open.
    final perUnitLoans =
        widget.structureType == PropertyStructureType.strata && units.isNotEmpty;
    final unknownStructure = widget.structureType == null && units.isNotEmpty;
    final showScope = perUnitLoans || unknownStructure;

    // Strata properties never allow "Whole property" — default (and, if the
    // live list changed under us, re-anchor) the selection to a real unit
    // from the *live* list, not the frozen widget.units a caller passed in.
    // This also guards DropdownButton's own assertion, which throws if
    // `value` has no matching item.
    if (perUnitLoans &&
        (_selectedUnitId == null ||
            !units.any((u) => u.unitId == _selectedUnitId))) {
      _selectedUnitId = units.first.unitId;
    }

    // Prefill from the booked entry for the now-resolved scope. Must run
    // after _selectedUnitId is finalized above — an entry is keyed by
    // (unit_id, month), so prefilling any earlier would look up the wrong
    // scope for a strata property (whose selection is re-anchored to the
    // first live unit right above) and open Modify blank.
    //
    // Sourced from entriesAsync.value (riverpod's safe nullable getter,
    // `_value?.$1` — non-null exactly when hasValue is true), the same
    // signal Save's onPressed below is gated on — not from
    // asData/asData?.value, which is null during a refresh (in-flight or
    // failed) even though hasValue (and .value) still carry the last
    // resolved value in that state. Using different signals for the two
    // gates previously let them disagree: after a failed refresh that
    // carried a prior value, Save was live (hasValue true) but prefill was
    // skipped (asData null), so switching the scope left the *previous*
    // scope's stale figures in the fields with Save enabled to write them
    // onto the new scope.
    //
    // Only once entries have actually resolved at least once: entriesAsync
    // starts in a loading state on first build (.value is null then), and
    // calling _prefillFor with a placeholder empty list at that point would
    // record the current key as "already prefilled" — permanently blocking
    // the real write once the future resolves with the booked figures.
    final entriesData = entriesAsync.value;
    if (entriesData != null) {
      _prefillFor(entriesData);
    }

    // Modify is now this sheet's primary entry point (the panel row shows it
    // beside real figures), so the title must say which job is actually
    // happening for the current scope rather than always claiming "Add".
    final hasEntryForScope =
        entriesData != null && _entryForCurrentScope(entriesData) != null;

    UnitFinance? selectedUnit;
    if (_selectedUnitId != null) {
      for (final u in units) {
        if (u.unitId == _selectedUnitId) {
          selectedUnit = u;
          break;
        }
      }
    }

    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    hasEntryForScope
                        ? 'Modify loan figures · ${widget.year}'
                        : 'Add loan figures · ${widget.year}',
                    style: AppTextStyles.titleLarge),
                if (_cadence == null) ...[
                  const SizedBox(height: 16),
                  Text('One annual figure, or monthly instalments?',
                      style: AppTextStyles.labelLarge
                          .copyWith(color: AppColors.textMuted)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      AppChoiceChip(
                        label: 'One annual figure',
                        selected: false,
                        onSelected: (_) => _chooseCadence('annual'),
                      ),
                      AppChoiceChip(
                        label: 'Monthly instalments',
                        selected: false,
                        onSelected: (_) => _chooseCadence('monthly'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                if (showScope) ...[
                  Text('SCOPE',
                      style: AppTextStyles.labelSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppColors.textSecondary,
                      )),
                  const SizedBox(height: 6),
                  DropdownButton<String?>(
                    value: _selectedUnitId,
                    isExpanded: true,
                    items: [
                      if (!perUnitLoans)
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Whole property'),
                        ),
                      for (final u in units)
                        DropdownMenuItem<String?>(
                          value: u.unitId,
                          child: Text(u.label),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _selectedUnitId = value),
                  ),
                  const SizedBox(height: 12),
                ],
                if (isMonthly) ...[
                  Text('MONTH',
                      style: AppTextStyles.labelSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppColors.textSecondary,
                      )),
                  const SizedBox(height: 6),
                  DropdownButton<int>(
                    value: _month,
                    isExpanded: true,
                    items: [
                      for (var m = 1; m <= 12; m++)
                        DropdownMenuItem(
                            value: m, child: Text(monthAbbrev[m - 1])),
                    ],
                    onChanged: (m) => setState(() => _month = m ?? _month),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_cadence != null) ...[
                  TextFormField(
                    key: const Key('manual-loan-interest'),
                    controller: _interestController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Interest paid (RM)'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: const Key('manual-loan-principal'),
                    controller: _principalController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Principal paid (RM)'),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      // Gated on hasValue, not on entriesData/asData: hasValue
                      // stays true through a *refresh* that fails as long as
                      // a value was previously known (Riverpod preserves the
                      // last good value across the AsyncLoading/AsyncError
                      // that follows an invalidate), so a transient refetch
                      // error doesn't strand a landlord who can already see
                      // their booked figures from re-saving them. It's only
                      // false when no value has ever resolved — first load
                      // still pending, or the very first load having failed
                      // — which is the case that would actually zero a
                      // figure, since the fields have nothing real in them.
                      onPressed:
                          (_saving || !entriesAsync.hasValue) ? null : _save,
                      child: const Text('Save'),
                    ),
                  ),
                  if (!entriesAsync.hasValue) ...[
                    const SizedBox(height: 6),
                    Text(
                      entriesAsync.hasError
                          ? "Can't save yet: couldn't load the existing "
                              'entries. Pull down to refresh on the Finance '
                              'tab, then reopen this sheet.'
                          : 'Loading existing entries before you can save…',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ],
                if (selectedUnit != null) ...[
                  const SizedBox(height: 12),
                  if (selectedUnit.loanStatus == 'no_loan')
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.hairline),
                          ),
                          child: Text(
                            'No loan on this unit',
                            style: AppTextStyles.labelSmall
                                .copyWith(color: AppColors.textMuted),
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _clearExemption,
                          child: const Text('Undo'),
                        ),
                      ],
                    )
                  else
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _setExemption,
                        icon: const Icon(Icons.block_outlined,
                            size: 18, color: AppColors.textSecondary),
                        label: Text('No loan here',
                            style: AppTextStyles.labelLarge
                                .copyWith(color: AppColors.textSecondary)),
                      ),
                    ),
                ],
                const SizedBox(height: 20),
                const Divider(height: 1, color: AppColors.hairline),
                const SizedBox(height: 12),
                Text('Recorded entries', style: AppTextStyles.titleMedium),
                const SizedBox(height: 8),
                entriesAsync.when(
                  // Without this, riverpod 3.1.0's default (skipError:
                  // false) dispatches to `error:` whenever hasError &&
                  // !skipError, even when hasValue is also true — so a
                  // refresh that fails after a value was already known
                  // rendered "Couldn't load existing entries." directly
                  // beneath prefilled fields and an enabled Save, which
                  // contradicts them. skipError: true keeps this on the
                  // `data:` branch (showing the last-known entries) whenever
                  // a prior value survives the failed refresh, matching what
                  // Save and the prefill above already trust.
                  skipError: true,
                  data: (entries) {
                    final scoped = entries
                        .where((entry) => entry['unit_id'] == _selectedUnitId)
                        .toList();
                    if (scoped.isEmpty) {
                      return Text(
                        'No manual entries yet for ${widget.year}.',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textMuted),
                      );
                    }
                    return Column(
                      children: [
                        for (final entry in scoped)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _entryLabel(entry, units),
                                    style: AppTextStyles.bodyMedium,
                                  ),
                                ),
                                Text(
                                  'Interest ${formatRM((entry['interest_paid'] as num?)?.toDouble() ?? 0)}',
                                  style: AppTextStyles.labelSmall,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Principal ${formatRM((entry['principal_paid'] as num?)?.toDouble() ?? 0)}',
                                  style: AppTextStyles.labelSmall,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 18, color: AppColors.sealRed),
                                  onPressed: () => _remove(
                                      (entry['month'] as num?)?.toInt()),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.registry)),
                  ),
                  error: (error, _) => Text(
                    "Couldn't load existing entries.",
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// [units] must be the *live* list from build() (financeSummaryProvider),
  /// not widget.units — a caller's frozen snapshot can omit or rename units
  /// relative to what's actually current, per the same staleness hazard the
  /// selection default above guards against.
  String _entryLabel(Map<String, dynamic> entry, List<UnitFinance> units) {
    final period = entry['month'] != null
        ? monthAbbrev[(entry['month'] as num).toInt() - 1]
        : '${widget.year}';
    final unitId = entry['unit_id'] as String?;
    if (unitId == null) return 'Whole property · $period';
    for (final u in units) {
      if (u.unitId == unitId) return '${u.label} · $period';
    }
    return period;
  }
}

/// Formats a booked amount the way a landlord would type it into the field —
/// no trailing `.0` for a whole number (so Modify shows `8200`, not
/// `8200.0`), and never a thousands separator: `_save` round-trips whatever
/// this writes through `double.tryParse`, which returns null on a comma and
/// would silently save 0.
String _formatAmountForInput(double value) {
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}
