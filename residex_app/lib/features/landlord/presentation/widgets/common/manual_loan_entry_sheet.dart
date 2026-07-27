import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../providers/documind_provider.dart';
import '../../providers/finance_logic.dart' show formatRM, monthAbbrev;

/// Add/edit form + list for a property whose loan figures are keyed in by
/// hand rather than uploaded (`loanInputMethod == 'manual'`). Opened as a
/// bottom sheet from the finance tab. Purely an input surface — the engine
/// (not this widget) recomputes the year's figures once an entry lands.
class ManualLoanEntrySheet extends ConsumerStatefulWidget {
  final String propertyId;
  final int year;
  final String cadence;

  const ManualLoanEntrySheet({
    super.key,
    required this.propertyId,
    required this.year,
    required this.cadence,
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

  @override
  void dispose() {
    _interestController.dispose();
    _principalController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final interest = double.tryParse(_interestController.text.trim()) ?? 0;
    final principal = double.tryParse(_principalController.text.trim()) ?? 0;
    setState(() => _saving = true);
    try {
      await ref.read(recordManualLoanEntryActionProvider)(
        propertyId: widget.propertyId,
        year: widget.year,
        cadence: widget.cadence,
        interestPaid: interest,
        principalPaid: principal,
        month: widget.cadence == 'monthly' ? _month : null,
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

  Future<void> _remove(int? month) async {
    try {
      await ref.read(deleteManualLoanEntryActionProvider)(
        propertyId: widget.propertyId,
        year: widget.year,
        month: month,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove entry: $e')),
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
    final isMonthly = widget.cadence == 'monthly';

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add loan figures — ${widget.year}',
                  style: AppTextStyles.titleLarge),
              const SizedBox(height: 16),
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
                decoration:
                    const InputDecoration(labelText: 'Principal paid (RM)'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: const Text('Save'),
                ),
              ),
              const SizedBox(height: 20),
              const Divider(height: 1, color: AppColors.hairline),
              const SizedBox(height: 12),
              Text('Recorded entries', style: AppTextStyles.titleMedium),
              const SizedBox(height: 8),
              entriesAsync.when(
                data: (entries) {
                  if (entries.isEmpty) {
                    return Text(
                      'No manual entries yet for ${widget.year}.',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textMuted),
                    );
                  }
                  return Column(
                    children: [
                      for (final entry in entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry['month'] != null
                                      ? monthAbbrev[(entry['month'] as int) - 1]
                                      : '${widget.year}',
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
                                onPressed: () =>
                                    _remove(entry['month'] as int?),
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
                      child:
                          CircularProgressIndicator(color: AppColors.registry)),
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
    );
  }
}
