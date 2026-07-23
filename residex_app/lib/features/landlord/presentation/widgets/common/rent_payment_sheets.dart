import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../providers/documind_provider.dart';
import 'app_choice_chip.dart';

/// Mark a month as no payment received, choosing outstanding (still being
/// chased) or written_off (given up on) up front (spec's three rent
/// states, §2). Shared by the unit drill-down and the year-level rent
/// issues list so both surfaces offer the identical action.
Future<void> showMarkUnpaidSheet(
  BuildContext context,
  WidgetRef ref, {
  required String propertyId,
  required String? unitId,
  required String month,
  required String monthLabel,
}) async {
  final controller = TextEditingController();
  String state = 'outstanding';
  try {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: 24 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mark $monthLabel as no payment received', style: AppTextStyles.titleLarge),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  AppChoiceChip(
                    label: 'Outstanding — still chasing',
                    selected: state == 'outstanding',
                    onSelected: (_) => setSheetState(() => state = 'outstanding'),
                  ),
                  AppChoiceChip(
                    label: 'Written off — given up',
                    selected: state == 'written_off',
                    onSelected: (_) => setSheetState(() => state = 'written_off'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: 'Reason (optional)'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final action = ref.read(setPaymentExceptionActionProvider);
    try {
      await action(
        propertyId: propertyId,
        unitId: unitId,
        month: month,
        reason: controller.text.trim().isEmpty ? null : controller.text.trim(),
        state: state,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to mark month: $e')));
      }
    }
  } finally {
    controller.dispose();
  }
}

/// Manage an already-marked month: clear it, escalate outstanding to
/// written_off, or record a written-off month's recovery.
Future<void> showManageUnpaidSheet(
  BuildContext context,
  WidgetRef ref, {
  required String propertyId,
  required String? unitId,
  required String month,
  required String monthLabel,
  required String paymentState,
  String? reason,
  double? billedAmount,
}) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              paymentState == 'written_off'
                  ? '$monthLabel is written off as unrecoverable'
                  : '$monthLabel is marked outstanding',
              style: AppTextStyles.titleLarge,
            ),
            if (reason != null && reason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(reason, style: AppTextStyles.bodyMedium),
            ],
            const SizedBox(height: 16),
            if (paymentState == 'outstanding')
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(sheetContext).pop('write_off'),
                  child: const Text('Mark as written off'),
                ),
              ),
            if (paymentState == 'written_off') ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(sheetContext).pop('recover'),
                  child: const Text('Record a recovery'),
                ),
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(sheetContext).pop('clear'),
                child: const Text('Clear mark'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (action == null || !context.mounted) return;
  if (action == 'clear') {
    try {
      await ref.read(clearPaymentExceptionActionProvider)(
        propertyId: propertyId, unitId: unitId, month: month,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to clear mark: $e')));
      }
    }
  } else if (action == 'write_off') {
    try {
      await ref.read(setPaymentExceptionActionProvider)(
        propertyId: propertyId, unitId: unitId, month: month,
        reason: reason, state: 'written_off',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to write off: $e')));
      }
    }
  } else if (action == 'recover' && context.mounted) {
    await _showRecoverSheet(
      context, ref,
      propertyId: propertyId, unitId: unitId, originalMonth: month, monthLabel: monthLabel,
      defaultAmount: billedAmount,
    );
  }
}

Future<void> _showRecoverSheet(
  BuildContext context,
  WidgetRef ref, {
  required String propertyId,
  required String? unitId,
  required String originalMonth,
  required String monthLabel,
  double? defaultAmount,
}) async {
  final amountController = TextEditingController(
    text: defaultAmount != null ? defaultAmount.toStringAsFixed(2) : '',
  );
  final yearController = TextEditingController(text: '${DateTime.now().year}');
  try {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: 24 + MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Record recovery for $monthLabel', style: AppTextStyles.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Booked as its own line in the year the money arrived — $monthLabel stays frozen.',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount received (RM)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: yearController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Year received'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(sheetContext).pop(true),
                child: const Text('Record recovery'),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final amount = double.tryParse(amountController.text.trim());
    final receivedYear = int.tryParse(yearController.text.trim());
    if (amount == null || amount <= 0 || receivedYear == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Enter a valid amount and year.')));
      }
      return;
    }
    try {
      await ref.read(recordRentRecoveryActionProvider)(
        propertyId: propertyId, unitId: unitId,
        originalMonth: originalMonth, amount: amount, receivedYear: receivedYear,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to record recovery: $e')));
      }
    }
  } finally {
    amountController.dispose();
    yearController.dispose();
  }
}
