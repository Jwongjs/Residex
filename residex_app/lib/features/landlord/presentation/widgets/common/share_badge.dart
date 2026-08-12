import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';

/// The one way an ownership share is labelled anywhere in the app: on the
/// property card, on a unit row, and at the top of the unit drill-down.
///
/// This is a label for a *scope* — "which share applies to everything you are
/// looking at". It is deliberately distinct from the "your N% of RM X"
/// sub-labels beneath individual figures, which explain one figure's
/// arithmetic and are derived from the figure pair rather than from a share
/// field. The two do different jobs and correctly appear side by side.
class ShareBadge extends StatelessWidget {
  const ShareBadge({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Text(text, style: AppTextStyles.labelSmall),
    );
  }
}
