import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';

/// Compact missing-documents nudge shown on a property block, replacing the
/// old bulleted per-category list. Both actions open the missing-documents
/// sheet (see `missing_documents_sheet.dart`).
class DocumentNudgeBanner extends StatelessWidget {
  final int count;
  final int year;
  final VoidCallback onUpload;
  final VoidCallback onMarkUnavailable;

  /// Non-null only when a loan document is among the missing ones — loan
  /// figures can be keyed in by hand, unlike every other category.
  final VoidCallback? onEnterManually;

  const DocumentNudgeBanner({
    super.key,
    required this.count,
    required this.year,
    required this.onUpload,
    required this.onMarkUnavailable,
    this.onEnterManually,
  });

  @override
  Widget build(BuildContext context) {
    final message = '$count document${count == 1 ? '' : 's'} needed for $year';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.hairline),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final icon = const Icon(Icons.info_outline, size: 18, color: AppColors.warning);
          final text = Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodyMedium,
              maxLines: 2,
              softWrap: true,
            ),
          );
          final uploadButton = FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.registry,
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: AppTextStyles.labelSmall,
            ),
            onPressed: onUpload,
            child: const Text('Upload documents'),
          );
          final markUnavailableButton = TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textMuted,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: onMarkUnavailable,
            child: const Text('Mark unavailable'),
          );
          final enterManuallyButton = onEnterManually == null
              ? null
              : TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.registry,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: onEnterManually,
                  child: const Text('Enter figures manually'),
                );

          // With three buttons, no fixed pixel breakpoint reliably avoids an
          // overflow — a Row's non-flex children get unbounded width, so a
          // long third label can overflow even a "wide" viewport. A Wrap
          // sizes to the bounded width it's given and wraps onto a second
          // line instead of overflowing, so the three-button case always
          // uses the stacked layout with a Wrap for the actions.
          if (enterManuallyButton != null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [icon, const SizedBox(width: 8), text]),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    uploadButton,
                    enterManuallyButton,
                    markUnavailableButton,
                  ],
                ),
              ],
            );
          }

          if (constraints.maxWidth >= 340) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                icon,
                const SizedBox(width: 8),
                text,
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [uploadButton, markUnavailableButton],
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [icon, const SizedBox(width: 8), text]),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [uploadButton, markUnavailableButton],
              ),
            ],
          );
        },
      ),
    );
  }
}
