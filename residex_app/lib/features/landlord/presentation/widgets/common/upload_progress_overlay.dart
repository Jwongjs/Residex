import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';

/// Maps a backend ingestion stage key (plus the client-synthesized 'done')
/// to a landlord-friendly label and a completion percent. Returns a null
/// percent for an unknown stage so callers keep the last known value while
/// still showing a neutral label.
(String, int?) uploadStageDisplay(String stageKey) {
  switch (stageKey) {
    case 'received':
      return ('Received your document', 10);
    case 'reading':
      return ('Reading the document', 30);
    case 'organising':
      return ('Organising the contents', 50);
    case 'indexing':
      return ('Making it searchable', 75);
    case 'details':
      return ('Pulling out the key details', 92);
    case 'done':
      return ('All set', 100);
    default:
      return ('Processing…', null);
  }
}

/// Full-screen dimmed overlay showing staged upload progress: a determinate
/// bar, the current friendly label, a percentage, and a patience note.
class UploadProgressOverlay extends StatelessWidget {
  final Color accentColor;
  final String label;
  final double progress; // 0.0 - 1.0

  const UploadProgressOverlay({
    super.key,
    required this.accentColor,
    required this.label,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(progress.clamp(0.0, 1.0) * 100).toInt()}%',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This can take up to a minute for scanned or photographed '
                'documents. Hang tight.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
