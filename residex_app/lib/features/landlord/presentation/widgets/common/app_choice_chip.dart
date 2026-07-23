import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';

/// [ChoiceChip] with explicit selected-state colors. The app theme's
/// [ColorScheme] only sets primary/secondary/surface/error, so Material 3's
/// default selected-chip styling falls back to `onSecondary` (black) on top
/// of `secondary` (dark teal) — unreadable. This widget sets the selected
/// background and label color directly instead of patching the theme.
class AppChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const AppChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      backgroundColor: AppColors.card,
      selectedColor: AppColors.registry,
      side: BorderSide(color: selected ? AppColors.registry : AppColors.hairline),
      labelStyle: AppTextStyles.bodyMedium.copyWith(
        color: selected ? Colors.white : AppColors.textPrimary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}
