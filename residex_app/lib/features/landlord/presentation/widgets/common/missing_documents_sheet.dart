import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../providers/documind_provider.dart';
import '../../providers/finance_logic.dart';
import '../../screens/3-Finance/finance_screen.dart' show uploadDocumentForCategory;

/// Which action the missing-documents sheet's rows perform when tapped —
/// both `DocumentNudgeBanner` buttons open this same sheet, differing only
/// in mode.
enum MissingDocsMode { upload, markUnavailable }

/// Bottom sheet listing every missing category for a property/year, ranked
/// by landlord impact (`rankMissingDocuments`). Each row either opens the
/// upload flow or the mark-unavailable confirmation, depending on [mode].
Future<void> showMissingDocumentsSheet(
  BuildContext context,
  WidgetRef ref, {
  required String propertyId,
  required int year,
  required List<String> missing,
  required MissingDocsMode mode,
}) async {
  final title = mode == MissingDocsMode.upload
      ? 'Upload documents for $year'
      : 'Mark documents unavailable for $year';

  await showModalBottomSheet<void>(
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
            Text(title, style: AppTextStyles.titleLarge),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: rankMissingDocuments(missing).map((category) {
                  final label = coverageLabels[category] ?? category;
                  final note = missingDocumentCostNote(category);
                  return InkWell(
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      if (mode == MissingDocsMode.upload) {
                        await uploadDocumentForCategory(
                          context, ref,
                          propertyId: propertyId,
                          category: uploadCategoryFor(category),
                        );
                      } else {
                        await showMarkUnavailableConfirm(
                          context, ref,
                          propertyId: propertyId,
                          year: year,
                          category: category,
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: AppTextStyles.titleMedium),
                          if (note != null) ...[
                            const SizedBox(height: 2),
                            Text(note, style: AppTextStyles.bodySmall),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Confirms and applies "mark unavailable" for a single missing category —
/// used when the landlord genuinely cannot obtain a document, so the year
/// settles as complete with the gap acknowledged instead of nagging forever.
Future<void> showMarkUnavailableConfirm(
  BuildContext context,
  WidgetRef ref, {
  required String propertyId,
  required int year,
  required String category,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Mark ${coverageLabels[category] ?? category} unavailable for $year?'),
      content: const Text(
        'Use this when you genuinely cannot obtain the document — the year '
        'settles as complete, with this gap acknowledged, instead of nagging '
        'permanently.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Mark unavailable'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await ref.read(setDocumentUnavailableActionProvider)(
      propertyId: propertyId, year: year, category: category,
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to mark unavailable: $e')));
    }
  }
}
