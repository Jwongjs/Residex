import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../providers/documind_provider.dart';
import '../../providers/finance_logic.dart' show formatRM;

/// Display labels for the expense-line subtypes. Keys mirror the backend's
/// EXPENSE_SUBTYPE_CATEGORY whitelist exactly.
const Map<String, String> expenseSubtypeLabels = {
  'loan_interest': 'Loan interest',
  'assessment_tax': 'Assessment tax',
  'quit_rent': 'Quit rent',
  'parcel_rent': 'Parcel rent',
  'maintenance': 'Maintenance / service charge',
  'sinking_fund': 'Sinking fund',
  'insurance_premium': 'Insurance premium',
  'upkeep': 'Upkeep / repairs',
};

/// Post-upload confirmation for extracted expense lines: the human checkpoint
/// that keeps the deterministic engine trustworthy. "Looks right" keeps the
/// extraction as-is; edits are saved through the facts PATCH endpoint.
Future<void> showExpenseLinesReviewSheet(
  BuildContext context, {
  required String docId,
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
      initialLines: initialLines,
    ),
  );
}

class ExpenseLinesReviewSheet extends ConsumerStatefulWidget {
  final String docId;
  final List<Map<String, dynamic>> initialLines;

  const ExpenseLinesReviewSheet({
    super.key,
    required this.docId,
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
              items: [
                for (final entry in expenseSubtypeLabels.entries)
                  DropdownMenuItem(
                      value: entry.key, child: Text(entry.value)),
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
