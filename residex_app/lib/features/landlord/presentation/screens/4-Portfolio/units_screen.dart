import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../domain/entities/unit.dart';
import '../../providers/unit_providers.dart';
import '../../providers/documind_provider.dart';
import '../../providers/property_providers.dart';

/// Lists and manages the individual units within a property: each unit's
/// label, monthly rent, and occupied/vacant status.
class UnitsScreen extends ConsumerWidget {
  final String propertyId;
  final String propertyName;

  const UnitsScreen({
    super.key,
    required this.propertyId,
    required this.propertyName,
  });

  Future<void> _addUnit(BuildContext context, WidgetRef ref, int currentCount) async {
    final controller = ref.read(unitControllerProvider);
    try {
      await controller.createUnit(Unit(
        id: '',
        propertyId: propertyId,
        label: 'Unit ${currentCount + 1}',
        monthlyRent: 0,
        isOccupied: false,
        createdAt: DateTime.now(),
      ));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add unit: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _confirmDeleteUnit(BuildContext context, WidgetRef ref, Unit unit) async {
    // Count documents assigned to this unit so the dialog can explain what
    // happens to them. A count failure must never block unit deletion.
    int assignedDocCount = 0;
    try {
      final listDocuments = ref.read(listDocumentsUseCaseProvider);
      final docs = await listDocuments(
        propertyId: propertyId,
      );
      assignedDocCount = docs.where((doc) => doc.unitId == unit.id).length;
    } catch (_) {
      assignedDocCount = 0;
    }

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
            const SizedBox(width: 12),
            Text('Delete Unit', style: AppTextStyles.titleMedium),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete this unit?', style: AppTextStyles.bodyMedium),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                '${unit.label} · RM ${unit.monthlyRent.toStringAsFixed(0)}/mo',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (assignedDocCount > 0) ...[
              const SizedBox(height: 12),
              Text(
                '$assignedDocCount document${assignedDocCount == 1 ? '' : 's'} assigned to this unit will be kept as property-wide documents.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'This action cannot be undone.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: AppTextStyles.labelLarge.copyWith(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Delete', style: AppTextStyles.labelLarge.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final controller = ref.read(unitControllerProvider);
      try {
        // Always unassign before deleting: the display count above can be 0
        // due to a failed fetch, but the unit may still own documents. The
        // endpoint is idempotent and cheap when there are none — gating it on
        // the count would risk orphaning docs with a stale unit_id.
        final unassignDocuments = ref.read(unassignUnitDocumentsActionProvider);
        await unassignDocuments(propertyId: propertyId, unitId: unit.id);
        await controller.deleteUnit(propertyId, unit.id);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete unit: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  Future<void> _editUnit(BuildContext context, WidgetRef ref, Unit unit,
      double propertyShare) async {
    final labelController = TextEditingController(text: unit.label);
    final initialShareText =
        ((unit.ownershipShare ?? propertyShare) * 100).toStringAsFixed(0);
    final shareController = TextEditingController(text: initialShareText);
    // Shown up front when co-ownership is already in play here — either the
    // property is co-owned, or this unit already carries its own share.
    // Otherwise it stays behind an affordance so a landlord who owns
    // everything outright never has to think about it.
    var showShare = propertyShare < 1.0 || unit.ownershipShare != null;
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Edit Unit', style: AppTextStyles.titleMedium),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: labelController,
                  decoration: const InputDecoration(labelText: 'Label'),
                  validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                if (showShare)
                  TextFormField(
                    controller: shareController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'My share of this unit (%)',
                      hintText: '100 if you own this unit outright',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      final parsed = double.tryParse(v);
                      if (parsed == null) return 'Must be a number';
                      // Message and rule agree: anything above 0 up to 100 is
                      // accepted, so a fractional share like 0.5% is valid.
                      if (parsed <= 0 || parsed > 100) {
                        return 'Between 0 and 100';
                      }
                      return null;
                    },
                  )
                else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => setDialogState(() => showShare = true),
                      child: Text(
                        'Set a different share for this unit',
                        style: AppTextStyles.labelLarge
                            .copyWith(color: AppColors.registry),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: AppTextStyles.labelLarge.copyWith(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.registry),
              child: Text('Save',
                  style: AppTextStyles.labelLarge.copyWith(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      final controller = ref.read(unitControllerProvider);
      try {
        await controller.updateUnit(unit.copyWith(
          label: labelController.text.trim(),
          // Only write a share the landlord actually edited. An untouched
          // field passes the existing value straight through, whatever it is.
          //
          // This matters most for a unit that has never had its own share: on
          // a co-owned property the field is SHOWN and prefilled with the
          // property's share, so writing it unconditionally would pin an
          // inheriting unit to the property's CURRENT share on any unrelated
          // edit — a rename, a rent correction. That is invisible at the time
          // and wrong later, when the property's share moves and the pinned
          // unit stops following it; copyWith cannot restore null from any
          // screen in the app.
          //
          // It also preserves precision: a stored 0.333 prefills as "33", so
          // re-parsing an untouched field would silently round it to 0.33.
          ownershipShare: showShare && shareController.text != initialShareText
              ? double.parse(shareController.text) / 100.0
              : unit.ownershipShare,
        ));
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update unit: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  Future<void> _toggleOccupied(BuildContext context, WidgetRef ref, Unit unit) async {
    final controller = ref.read(unitControllerProvider);
    try {
      await controller.updateUnit(unit.copyWith(isOccupied: !unit.isOccupied));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update unit: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsAsync = ref.watch(unitsForPropertyStreamProvider(propertyId));
    // Watched, not read: the dialog needs this resolved when it opens, and
    // this screen is otherwise the only thing that would ever load it.
    final propertyShare =
        ref.watch(propertyByIdProvider(propertyId)).value?.ownershipShare ?? 1.0;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text(propertyName, style: AppTextStyles.titleMedium),
        backgroundColor: AppColors.paper,
      ),
      body: unitsAsync.when(
        data: (units) {
          return Column(
            children: [
              Expanded(
                child: units.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'No units yet.',
                                style: AppTextStyles.bodyMedium
                                    .copyWith(color: AppColors.textMuted),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Rent and occupancy are tracked per unit, so this '
                                'property is left out of portfolio stats until it '
                                'has one. For a single-dwelling home, add one unit '
                                'representing the whole property.',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: units.length,
                        itemBuilder: (context, index) {
                          final unit = units[index];
                          return Card(
                            color: AppColors.card,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: AppColors.hairline),
                            ),
                            child: ListTile(
                              title: Text(unit.label, style: AppTextStyles.bodyLarge),
                              subtitle: Text(
                                '${(((unit.ownershipShare ?? propertyShare) * 100)).toStringAsFixed(0)}% share',
                                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                              ),
                              onTap: () =>
                                  _editUnit(context, ref, unit, propertyShare),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Tooltip(
                                    message: 'Unit occupancy status',
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          unit.isOccupied ? 'OCCUPIED' : 'VACANT',
                                          style: AppTextStyles.labelSmall.copyWith(
                                            fontSize: 9,
                                            letterSpacing: 0.5,
                                            fontWeight: FontWeight.w600,
                                            color: unit.isOccupied
                                                ? AppColors.registry
                                                : AppColors.textMuted,
                                          ),
                                        ),
                                        Switch(
                                          value: unit.isOccupied,
                                          activeColor: AppColors.registry,
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          onChanged: (_) =>
                                              _toggleOccupied(context, ref, unit),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline, color: AppColors.error),
                                    onPressed: () => _confirmDeleteUnit(context, ref, unit),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: () => _addUnit(context, ref, units.length),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Unit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.registry,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.registry)),
        error: (error, stack) => Center(
          child: Text('Failed to load units: $error', style: AppTextStyles.bodyMedium),
        ),
      ),
    );
  }
}
