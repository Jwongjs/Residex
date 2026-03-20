import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

class ToastNotification extends StatelessWidget {
  final String message;
  final bool isSuccess;
  final VoidCallback onDismiss;

  const ToastNotification({
    super.key,
    required this.message,
    this.isSuccess = true,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(minWidth: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha:0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.5),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSuccess
                    ? AppColors.success.withValues(alpha:0.2)
                    : AppColors.info.withValues(alpha:0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isSuccess ? Icons.check : Icons.info_outline,
                color: isSuccess ? AppColors.success : AppColors.info,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                message,
                style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDismiss,
              child: Icon(
                Icons.close,
                color: AppColors.textMuted,
                size: 14,
              ),
            ),
          ],
        ),
      )
          .animate()
          .fadeIn(duration: 300.ms)
          .slideY(begin: -0.5, end: 0, curve: Curves.easeOut),
    );
  }
}

// Toast overlay helper
class ToastOverlay {
  static OverlayEntry? _currentEntry;

  static void show(
    BuildContext context,
    String message, {
    bool isSuccess = true,
    Duration duration = const Duration(seconds: 3),
  }) {
    _currentEntry?.remove();

    _currentEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        child: Center(
          child: ToastNotification(
            message: message,
            isSuccess: isSuccess,
            onDismiss: () {
              _currentEntry?.remove();
              _currentEntry = null;
            },
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_currentEntry!);

    Future.delayed(duration, () {
      _currentEntry?.remove();
      _currentEntry = null;
    });
  }
}
