import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../domain/entities/property.dart';
import '../../providers/property_providers.dart';
import '../../screens/3-Finance/finance_screen.dart' show uploadDocumentForCategory;

class _ChecklistItem {
  final String category;
  final String title;
  final String hint;
  const _ChecklistItem(this.category, this.title, this.hint);
}

const List<_ChecklistItem> _step2Items = [
  _ChecklistItem('lease', 'Tenancy agreement',
      'Rent, span, and the utilities/repairs clauses — one upload resolves the whole income side'),
  _ChecklistItem('expenses', 'Latest management statement',
      'Strata only — cumulative, backfills months of maintenance and sinking fund at once'),
];

List<_ChecklistItem> _step3Items(PropertyStructureType? structureType, bool? hasMortgage) {
  return [
    const _ChecklistItem('tax', 'Assessment tax / land-office tax',
        'Cukai pintu, cukai tanah, or parcel rent'),
    if (structureType != PropertyStructureType.strata)
      const _ChecklistItem('insurance', 'Fire insurance',
          "Landed only — strata's sits inside the MC bill"),
    if (hasMortgage == true)
      const _ChecklistItem('loan', 'Loan interest statement', "The bank's year-end statement"),
  ];
}

/// Steps 2 and 3 of guided registration (spec §6): the two unlock
/// documents, then annual one-offs gated by the property profile. Both
/// fully skippable; [Property.nextSetupStep] tracks how far the landlord
/// got so the property card's "Continue setup" affordance can resume at
/// the right step. [startAtStep] lets a resumed session skip to step 3.
Future<void> showRegistrationDocumentSteps(
  BuildContext context, {
  required Property property,
  int startAtStep = 2,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _RegistrationStepSheet(property: property, step: startAtStep),
  );
}

class _RegistrationStepSheet extends ConsumerStatefulWidget {
  final Property property;
  final int step;

  const _RegistrationStepSheet({required this.property, required this.step});

  @override
  ConsumerState<_RegistrationStepSheet> createState() => _RegistrationStepSheetState();
}

class _RegistrationStepSheetState extends ConsumerState<_RegistrationStepSheet> {
  final Set<String> _uploaded = {};
  String? _uploading;

  Future<void> _upload(String category) async {
    setState(() => _uploading = category);
    await uploadDocumentForCategory(context, ref, propertyId: widget.property.id, category: category);
    if (mounted) {
      setState(() {
        _uploading = null;
        _uploaded.add(category);
      });
    }
  }

  Future<void> _advance() async {
    final controller = ref.read(propertyControllerProvider);
    if (widget.step == 2) {
      final updated = widget.property.copyWith(nextSetupStep: 3);
      await controller.updateProperty(updated);
      if (mounted) {
        Navigator.of(context).pop();
        await showRegistrationDocumentSteps(context, property: updated, startAtStep: 3);
      }
    } else {
      await controller.updateProperty(widget.property.copyWith(nextSetupStep: 0));
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.step == 2
        ? _step2Items
        : _step3Items(widget.property.structureType, widget.property.hasMortgage);
    final title = widget.step == 2 ? 'The two unlock documents' : 'Annual one-offs';
    final subtitle = widget.step == 2
        ? '${widget.property.name} — the tenancy agreement resolves rent; a management statement backfills strata maintenance in one upload. All optional.'
        : "${widget.property.name} — this year's official bills. All optional; add them anytime.";

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Step ${widget.step} of 3',
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: 4),
            Text(title, style: AppTextStyles.headlineMedium),
            const SizedBox(height: 4),
            Text(subtitle, style: AppTextStyles.bodyMedium),
            const SizedBox(height: 16),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('Nothing applies to this property.', style: AppTextStyles.bodyMedium),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.hairline),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final done = _uploaded.contains(item.category);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(item.title, style: AppTextStyles.titleMedium),
                      subtitle: Text(item.hint, style: AppTextStyles.bodySmall),
                      trailing: done
                          ? const Icon(Icons.check_circle_outline, color: AppColors.registry)
                          : _uploading == item.category
                              ? const SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.registry),
                                )
                              : TextButton(
                                  onPressed: _uploading != null ? null : () => _upload(item.category),
                                  child: const Text('Upload'),
                                ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _advance,
                child: Text(
                  widget.step == 2 ? "I'll do this later" : 'Done',
                  style: AppTextStyles.labelLarge.copyWith(color: AppColors.slate),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
