import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../domain/entities/property.dart';
import '../../providers/property_providers.dart';

/// Stage D (spec §8): "pre-fill, then confirm." Call this right after a
/// document upload completes; it opens the confirm sheet only when the
/// facts carry both a liability answer and its supporting quote -- an
/// unconfirmed extraction is never enough to set Property.utilitiesPaidBy
/// on its own.
Future<void> maybeShowUtilitiesLiabilityConfirm(
  BuildContext context,
  WidgetRef ref, {
  required String propertyId,
  required String category,
  required Map<String, dynamic>? extractedFacts,
}) async {
  if (category != 'lease' || extractedFacts == null) return;
  final liability = extractedFacts['utilities_liability'];
  final quote = extractedFacts['utilities_clause_quote'];
  if (liability is! String ||
      (liability != 'tenant' && liability != 'landlord') ||
      quote is! String ||
      quote.isEmpty) {
    return;
  }
  final property = await ref.read(propertyByIdProvider(propertyId).future);
  if (property == null || !context.mounted) return;
  await showUtilitiesLiabilityConfirmSheet(
    context,
    property: property,
    liability: liability,
    clauseRef: extractedFacts['utilities_clause_ref'] as String?,
    quote: quote,
  );
}

Future<void> showUtilitiesLiabilityConfirmSheet(
  BuildContext context, {
  required Property property,
  required String liability,
  String? clauseRef,
  required String quote,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _UtilitiesLiabilityConfirmSheet(
      property: property,
      liability: liability,
      clauseRef: clauseRef,
      quote: quote,
    ),
  );
}

class _UtilitiesLiabilityConfirmSheet extends ConsumerStatefulWidget {
  final Property property;
  final String liability;
  final String? clauseRef;
  final String quote;

  const _UtilitiesLiabilityConfirmSheet({
    required this.property,
    required this.liability,
    this.clauseRef,
    required this.quote,
  });

  @override
  ConsumerState<_UtilitiesLiabilityConfirmSheet> createState() =>
      _UtilitiesLiabilityConfirmSheetState();
}

class _UtilitiesLiabilityConfirmSheetState
    extends ConsumerState<_UtilitiesLiabilityConfirmSheet> {
  bool _saving = false;

  Future<void> _confirm(String finalLiability) async {
    setState(() => _saving = true);
    try {
      final controller = ref.read(propertyControllerProvider);
      await controller.updateProperty(
        widget.property.copyWith(utilitiesPaidBy: finalLiability),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(finalLiability == 'tenant'
              ? "Noted — tenant pays utilities."
              : "Noted — you pay utilities."),
        ));
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
    final who = widget.liability == 'tenant' ? 'the tenant pays' : 'you pay';
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your agreement says $who for utilities',
              style: AppTextStyles.headlineMedium),
          if (widget.clauseRef != null) ...[
            const SizedBox(height: 4),
            Text(widget.clauseRef!,
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted)),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Text('"${widget.quote}"',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                  fontStyle: FontStyle.italic,
                )),
          ),
          const SizedBox(height: 8),
          Text(
            'This decides whether utility charges on your statements count as a deduction.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Text("I'll confirm later"),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => _confirm(widget.liability == 'tenant' ? 'landlord' : 'tenant'),
                  child: const Text("That's not right"),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saving ? null : () => _confirm(widget.liability),
                  child: Text(_saving ? 'Saving...' : 'Correct'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
