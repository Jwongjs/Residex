import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../screens/3-Finance/finance_screen.dart'
    show uploadDocumentForCategory;

class _ChecklistItem {
  final String category;
  final String title;
  final String hint;
  const _ChecklistItem(this.category, this.title, this.hint);
}

const List<_ChecklistItem> _items = [
  _ChecklistItem('lease', 'Tenancy agreement', 'Rent, deposit and tenancy period'),
  _ChecklistItem('rental_invoice', 'Rent invoice', 'One per month — your income ledger'),
  _ChecklistItem('loan', 'Loan interest statement', "The bank's year-end statement"),
  _ChecklistItem('tax', 'Assessment tax / quit rent bill', 'Cukai pintu, cukai tanah, parcel rent'),
  _ChecklistItem('maintenance', 'Maintenance statement', 'Management fees incl. sinking fund'),
  _ChecklistItem('insurance', 'Insurance policy', 'Fire / houseowner policy schedule'),
];

/// Guided "Add key documents" step after property creation. Fully skippable;
/// uploads are property-wide here (unit scoping stays available later via
/// the Documind tab). The Finance tab's completeness indicator is the
/// persistent follow-up for anything skipped.
Future<void> showGuidedDocumentChecklist(
  BuildContext context, {
  required String propertyId,
  required String propertyName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => GuidedDocumentChecklistSheet(
      propertyId: propertyId,
      propertyName: propertyName,
    ),
  );
}

class GuidedDocumentChecklistSheet extends ConsumerStatefulWidget {
  final String propertyId;
  final String propertyName;

  const GuidedDocumentChecklistSheet({
    super.key,
    required this.propertyId,
    required this.propertyName,
  });

  @override
  ConsumerState<GuidedDocumentChecklistSheet> createState() =>
      _GuidedDocumentChecklistSheetState();
}

class _GuidedDocumentChecklistSheetState
    extends ConsumerState<GuidedDocumentChecklistSheet> {
  final Set<String> _uploaded = {};
  String? _uploading;

  Future<void> _upload(String category) async {
    setState(() => _uploading = category);
    await uploadDocumentForCategory(
      context,
      ref,
      propertyId: widget.propertyId,
      category: category,
    );
    if (mounted) {
      setState(() {
        _uploading = null;
        _uploaded.add(category);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add key documents', style: AppTextStyles.headlineMedium),
            const SizedBox(height: 4),
            Text(
              '${widget.propertyName} — these power the Finance tab and DocuMind. All optional; add them anytime.',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _items.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppColors.hairline),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final done = _uploaded.contains(item.category);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(item.title, style: AppTextStyles.titleMedium),
                    subtitle: Text(item.hint, style: AppTextStyles.bodySmall),
                    trailing: done
                        ? const Icon(Icons.check_circle_outline,
                            color: AppColors.registry)
                        : _uploading == item.category
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.registry),
                              )
                            : TextButton(
                                onPressed: _uploading != null
                                    ? null
                                    : () => _upload(item.category),
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
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  _uploaded.isEmpty ? 'Do this later' : 'Done',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.slate),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
