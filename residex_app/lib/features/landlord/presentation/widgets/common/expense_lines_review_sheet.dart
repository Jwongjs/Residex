import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../domain/entities/property.dart';
import '../../../domain/share_basis.dart';
import '../../providers/documind_provider.dart';
import '../../providers/finance_logic.dart' show formatRM;
import '../../providers/property_providers.dart';
import '../../providers/unit_providers.dart';
import 'app_choice_chip.dart';

/// Display labels for the expense-line subtypes. Keys mirror the backend's
/// EXPENSE_SUBTYPE_CATEGORY whitelist exactly — every stored subtype must have
/// an entry here, or the edit dialog's dropdown asserts (zero matching items).
const Map<String, String> expenseSubtypeLabels = {
  'loan_interest': 'Loan interest',
  'loan_principal': 'Loan principal',
  'assessment_tax': 'Assessment tax',
  'quit_rent': 'Quit rent',
  'parcel_rent': 'Parcel rent',
  'maintenance': 'Maintenance / service charge',
  'sinking_fund': 'Sinking fund',
  'management_fee': 'Property management fee',
  'rent_collection': 'Rent collection fee',
  'security_fee': 'Security fee',
  'insurance_premium': 'Insurance premium',
  'upkeep': 'Upkeep / repairs',
  'pest_control': 'Pest control',
  'agent_commission': 'Agent commission',
  'legal_fee': 'Legal fee',
  'stamp_duty': 'Stamp duty',
  'advertising': 'Advertising',
  'sst': 'Service tax (SST)',
  'utilities': 'Utilities',
  'late_penalty': 'Late payment charge',
  'renovation': 'Renovation',
};

/// Post-upload confirmation for extracted expense lines: the human checkpoint
/// that keeps the deterministic engine trustworthy. "Looks right" keeps the
/// extraction as-is; edits are saved through the facts PATCH endpoint.
Future<void> showExpenseLinesReviewSheet(
  BuildContext context, {
  required String docId,
  required String propertyId,
  required List<Map<String, dynamic>> initialLines,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => ExpenseLinesReviewSheet(
      docId: docId,
      propertyId: propertyId,
      initialLines: initialLines,
    ),
  );
}

class ExpenseLinesReviewSheet extends ConsumerStatefulWidget {
  final String docId;
  final String propertyId;
  final List<Map<String, dynamic>> initialLines;

  const ExpenseLinesReviewSheet({
    super.key,
    required this.docId,
    required this.propertyId,
    required this.initialLines,
  });

  @override
  ConsumerState<ExpenseLinesReviewSheet> createState() =>
      _ExpenseLinesReviewSheetState();
}

class _ExpenseLinesReviewSheetState
    extends ConsumerState<ExpenseLinesReviewSheet> {
  late List<Map<String, dynamic>> _lines;
  bool _dirty = false;
  bool _saving = false;

  /// Null until the property resolves. Once set it is the chip's selection,
  /// and it starts at the resolved default so the landlord confirms rather
  /// than answers.
  String? _basis;
  bool _savingBasis = false;

  Future<void> _setBasis(String basis) async {
    if (basis == _basis) return; // confirming the pre-set answer writes nothing
    final previous = _basis;
    setState(() {
      _basis = basis;
      _savingBasis = true;
    });
    try {
      await ref.read(setDocumentShareBasisActionProvider)(
        docId: widget.docId,
        shareBasis: basis,
      );
      if (mounted) setState(() => _savingBasis = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _basis = previous;
          _savingBasis = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saving failed: $e')),
        );
      }
    }
  }

  Widget _buildBasisChip(Property property) {
    // 'expenses': this sheet only ever opens for an expenses upload (see the
    // gate in uploadDocumentForCategory), and that category is not one a
    // landlord can except — so it resolves to the property default, which is
    // exactly why this per-document answer exists.
    _basis ??= resolveShareBasis(property: property, category: 'expenses');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text('These amounts are:',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.slate)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            AppChoiceChip(
              label: 'At the full property amount',
              selected: _basis == shareBasisFull,
              onSelected: (_) {
                if (!_savingBasis) _setBasis(shareBasisFull);
              },
            ),
            AppChoiceChip(
              label: 'Already split to my share',
              selected: _basis == shareBasisMine,
              onSelected: (_) {
                if (!_savingBasis) _setBasis(shareBasisMine);
              },
            ),
          ],
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _lines = [
      for (final line in widget.initialLines) Map<String, dynamic>.from(line),
    ];
  }

  double get _total {
    var sum = 0.0;
    for (final line in _lines) {
      final amount = line['amount'];
      if (amount is num) sum += amount;
    }
    return sum;
  }

  Future<void> _editLine(int index) async {
    final edited = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ExpenseLineEditDialog(line: _lines[index]),
    );
    if (edited != null) {
      setState(() {
        _lines[index] = edited;
        _dirty = true;
      });
    }
  }

  Future<void> _deleteLine(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove this expense?'),
        content: const Text(
            'It will no longer count toward your figures. This is for '
            'duplicates or charges that were waived.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() {
        _lines.removeAt(index);
        _dirty = true;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(updateExpenseLinesActionProvider)(
        docId: widget.docId,
        lines: _lines,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense lines updated.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saving failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Review extracted expenses',
              style: AppTextStyles.headlineMedium),
          const SizedBox(height: 4),
          Text(
            '${_lines.length} line(s), ${formatRM(_total)} total. '
            'Tap a line to correct it.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.slate),
          ),
          const SizedBox(height: 12),
          Builder(builder: (context) {
            final property =
                ref.watch(propertyByIdProvider(widget.propertyId)).value;
            if (property == null) return const SizedBox.shrink();
            final unitShares = (ref
                        .watch(unitsForPropertyStreamProvider(widget.propertyId))
                        .value ??
                    const [])
                .map((u) => u.ownershipShare);
            if (!shareApplies(
                propertyShare: property.ownershipShare, unitShares: unitShares)) {
              return const SizedBox.shrink();
            }
            return _buildBasisChip(property);
          }),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _lines.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: AppColors.hairline),
              itemBuilder: (context, index) {
                final line = _lines[index];
                final subtype = line['subtype'] as String? ?? '';
                final amount = line['amount'];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(expenseSubtypeLabels[subtype] ?? subtype,
                      style: AppTextStyles.bodyLarge),
                  subtitle: (line['description'] is String)
                      ? Text(line['description'] as String,
                          maxLines: 1, overflow: TextOverflow.ellipsis)
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(amount is num ? formatRM(amount.toDouble()) : '—',
                          style: AppTextStyles.bodyLarge),
                      const SizedBox(width: 8),
                      const Icon(Icons.edit_outlined, size: 18),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        tooltip: 'Remove expense',
                        onPressed: _saving ? null : () => _deleteLine(index),
                      ),
                    ],
                  ),
                  onTap: _saving ? null : () => _editLine(index),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Looks right'),
              ),
              const SizedBox(width: 8),
              if (_dirty)
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving...' : 'Save changes'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExpenseLineEditDialog extends StatefulWidget {
  final Map<String, dynamic> line;

  const _ExpenseLineEditDialog({required this.line});

  @override
  State<_ExpenseLineEditDialog> createState() => _ExpenseLineEditDialogState();
}

class _ExpenseLineEditDialogState extends State<_ExpenseLineEditDialog> {
  late String _subtype;
  late final TextEditingController _description;
  late final TextEditingController _amount;
  late final TextEditingController _year;

  @override
  void initState() {
    super.initState();
    _subtype = widget.line['subtype'] as String? ?? 'maintenance';
    _description = TextEditingController(
        text: widget.line['description'] as String? ?? '');
    final amount = widget.line['amount'];
    _amount = TextEditingController(
        text: amount is num ? amount.toStringAsFixed(2) : '');
    final year = widget.line['period_year'];
    _year = TextEditingController(text: year is int ? '$year' : '');
  }

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    _year.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit expense line'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _subtype,
              decoration: const InputDecoration(labelText: 'Type'),
              // Guarantee the current value always has exactly one item — a
              // subtype the label map doesn't know (a future/unknown one)
              // would otherwise assert. Its raw key is shown as a fallback.
              items: [
                for (final key in {...expenseSubtypeLabels.keys, _subtype})
                  DropdownMenuItem(
                      value: key,
                      child: Text(expenseSubtypeLabels[key] ?? key)),
              ],
              onChanged: (value) =>
                  setState(() => _subtype = value ?? _subtype),
            ),
            TextField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount (RM)'),
            ),
            TextField(
              controller: _year,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Year'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final amount = double.tryParse(_amount.text.trim());
            if (amount == null) return; // amount is the one required field
            final updated = Map<String, dynamic>.from(widget.line);
            updated['subtype'] = _subtype;
            updated['amount'] = amount;
            final description = _description.text.trim();
            if (description.isEmpty) {
              updated.remove('description');
            } else {
              updated['description'] = description;
            }
            final year = int.tryParse(_year.text.trim());
            if (year == null) {
              updated.remove('period_year');
            } else {
              updated['period_year'] = year;
            }
            Navigator.pop(context, updated);
          },
          child: const Text('Done'),
        ),
      ],
    );
  }
}
