import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';

/// Compact `<year> ▾` app-bar control. Tapping opens a bottom sheet listing
/// [years] (newest first); selecting one invokes [onChanged].
class FinanceYearButton extends StatelessWidget {
  final int selected;
  final List<int> years;
  final ValueChanged<int> onChanged;

  const FinanceYearButton({
    super.key,
    required this.selected,
    required this.years,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final picked = await showModalBottomSheet<int>(
          context: context,
          backgroundColor: AppColors.paper,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select year', style: AppTextStyles.titleLarge),
                  const SizedBox(height: 12),
                  ...years.map((year) => ListTile(
                        title: Text('$year', style: AppTextStyles.bodyLarge),
                        trailing: year == selected
                            ? const Icon(Icons.check, color: AppColors.registry)
                            : null,
                        onTap: () => Navigator.of(context).pop(year),
                      )),
                ],
              ),
            ),
          ),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.hairline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$selected', style: AppTextStyles.labelLarge),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
