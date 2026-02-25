import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_theme.dart';

/// Landlord Rating Modal for approving maintenance work
class LandlordRatingModal extends StatefulWidget {
  final String ticketTitle;
  final VoidCallback onClose;
  final Function(int rating, String feedback) onSubmit;

  const LandlordRatingModal({
    super.key,
    required this.ticketTitle,
    required this.onClose,
    required this.onSubmit,
  });

  @override
  State<LandlordRatingModal> createState() => _LandlordRatingModalState();
}

class _LandlordRatingModalState extends State<LandlordRatingModal> {
  int _rating = 0;
  final TextEditingController _feedbackController = TextEditingController();

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(32),
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textMuted.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Rate Work Quality',
                        style: AppTextStyles.heading2.copyWith(
                          fontSize: 20,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: widget.onClose,
                      icon: Icon(
                        Icons.close,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.ticketTitle,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Colors.white12),

          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // Star rating
                Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final starIndex = index + 1;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _rating = starIndex;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(
                                _rating >= starIndex
                                    ? Icons.star
                                    : Icons.star_border,
                                color: _rating >= starIndex
                                    ? AppColors.warning
                                    : AppColors.textMuted,
                                size: 48,
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 16),
                      if (_rating > 0)
                        Text(
                          _getRatingLabel(_rating),
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: AppColors.warning,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Feedback section
                Text(
                  'FEEDBACK (OPTIONAL)',
                  style: AppTextStyles.label.copyWith(
                    fontSize: 10,
                    color: AppColors.textMuted,
                    letterSpacing: 2,
                  ),
                ),

                const SizedBox(height: 12),

                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: TextField(
                    controller: _feedbackController,
                    maxLines: 5,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Share your experience with the repair quality...',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textMuted,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Quick feedback chips
                Text(
                  'QUICK FEEDBACK',
                  style: AppTextStyles.label.copyWith(
                    fontSize: 10,
                    color: AppColors.textMuted,
                    letterSpacing: 2,
                  ),
                ),

                const SizedBox(height: 12),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFeedbackChip('Excellent work'),
                    _buildFeedbackChip('On time'),
                    _buildFeedbackChip('Professional'),
                    _buildFeedbackChip('Clean workspace'),
                    _buildFeedbackChip('Good communication'),
                    _buildFeedbackChip('Will hire again'),
                  ],
                ),
              ],
            ),
          ),

          // Submit button
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            child: ElevatedButton(
              onPressed: _rating > 0
                  ? () {
                      widget.onSubmit(
                        _rating,
                        _feedbackController.text.isEmpty
                            ? 'No feedback provided'
                            : _feedbackController.text,
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.slate800,
                disabledForegroundColor: AppColors.textMuted,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                'Submit Rating',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackChip(String label) {
    return GestureDetector(
      onTap: () {
        final currentText = _feedbackController.text;
        if (currentText.isEmpty) {
          _feedbackController.text = label;
        } else {
          _feedbackController.text = '$currentText, $label';
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: AppColors.slate800,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }
}
