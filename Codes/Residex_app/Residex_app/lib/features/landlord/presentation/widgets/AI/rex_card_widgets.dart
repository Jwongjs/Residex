// lib/features/landlord/presentation/widgets/common/rex_card_widgets.dart
import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';

/// Warning Shot Card (Protocol Breach)
class RexWarningCard extends StatelessWidget {
  final Map<String, dynamic> cardData;

  const RexWarningCard({
    super.key,
    required this.cardData,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.orange.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.camera_alt,
                size: 16,
                color: AppColors.orange,
              ),
              const SizedBox(width: 8),
              Text(
                'PROTOCOL BREACH',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.orange,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Description
          Text(
            "A housemate has flagged '${cardData['chore']}'. Visual evidence was provided. Remediation window is closing.",
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Rectify (${cardData['timeLeft']})',
                    style: AppTextStyles.label.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                  side: BorderSide(
                    color: Colors.white.withOpacity(0.1),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Analyze',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Final Straw Card (Tribunal Triggered)
class RexFinalStrawCard extends StatelessWidget {
  final Map<String, dynamic> cardData;

  const RexFinalStrawCard({
    super.key,
    required this.cardData,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.error.withOpacity(0.4),
        ),
      ),
      child: Stack(
        children: [
          // Background icon
          Positioned(
            top: 0,
            right: 0,
            child: Icon(
              Icons.gavel,
              size: 60,
              color: AppColors.error.withOpacity(0.1),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.gavel,
                    size: 16,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'TRIBUNAL TRIGGERED',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Description
              Text(
                "Pattern Detected: ${cardData['count']} Unresolved Disputes. A motion for 'Persistent Negligence' has been automatically filed.",
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 16),

              // Action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error.withOpacity(0.2),
                    foregroundColor: AppColors.error,
                    side: BorderSide(
                      color: AppColors.error.withOpacity(0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Access Evidence Log',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Jury Duty Card (Negligence Vote)
class RexJuryDutyCard extends StatelessWidget {
  final Map<String, dynamic> cardData;

  const RexJuryDutyCard({
    super.key,
    required this.cardData,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.slate800,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.balance,
                size: 16,
                color: AppColors.purple,
              ),
              const SizedBox(width: 8),
              Text(
                'NEGLIGENCE VOTE',
                style: AppTextStyles.label.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Description
          Text(
            "${cardData['accused']} has failed ${cardData['failCount']} protocols this cycle. Do you verify a Stewardship Strike?",
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 16),

          // Vote buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error.withOpacity(0.2),
                    foregroundColor: AppColors.error,
                    side: BorderSide(
                      color: AppColors.error.withOpacity(0.3),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Vote Yes',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success.withOpacity(0.2),
                    foregroundColor: AppColors.success,
                    side: BorderSide(
                      color: AppColors.success.withOpacity(0.3),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Vote No',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}