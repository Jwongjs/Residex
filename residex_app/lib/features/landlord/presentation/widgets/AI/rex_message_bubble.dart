// lib/features/landlord/presentation/widgets/common/rex_message_bubble.dart
import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../providers/landlord_rex_ai_provider.dart';
import 'rex_card_widgets.dart';

/// Message bubble for Rex AI chat
class RexMessageBubble extends StatelessWidget {
  final RexMessage message;

  const RexMessageBubble({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == 'USER';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isUser
                ? AppColors.primary
                : AppColors.surfaceLight,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(24),
              topRight: const Radius.circular(24),
              bottomLeft: Radius.circular(isUser ? 24 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 24),
            ),
            border: isUser
                ? null
                : Border.all(
                    color: Colors.white.withOpacity(0.1),
                  ),
            boxShadow: [
              if (isUser)
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 12,
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rex icon (for Rex messages only)
              if (!isUser)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildRexIcon(),
                ),

              // Message text
              Text(
                message.text,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isUser ? Colors.white : AppColors.textPrimary,
                  height: 1.4,
                ),
              ),

              // Special cards for certain message types
              if (message.cardData != null) ...[
                const SizedBox(height: 12),
                _buildCard(message),
              ],

              // Action button for actionRequired type
              if (message.type == MessageType.actionRequired) ...[
                const SizedBox(height: 12),
                _buildActionButton(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRexIcon() {
    IconData icon;
    Color color;

    switch (message.type) {
      case MessageType.warning:
        icon = Icons.shield;
        color = AppColors.warning;
        break;
      case MessageType.actionRequired:
        icon = Icons.description_outlined;
        color = AppColors.error;
        break;
      case MessageType.cardWarningShot:
      case MessageType.cardFinalStraw:
      case MessageType.cardJuryDuty:
        icon = Icons.warning_amber;
        color = AppColors.orange;
        break;
      default:
        icon = Icons.smart_toy_outlined;
        color = AppColors.purple;
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.background,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Icon(
        icon,
        size: 14,
        color: color,
      ),
    );
  }

  Widget _buildCard(RexMessage message) {
    switch (message.type) {
      case MessageType.cardWarningShot:
        return RexWarningCard(cardData: message.cardData!);
      case MessageType.cardFinalStraw:
        return RexFinalStrawCard(cardData: message.cardData!);
      case MessageType.cardJuryDuty:
        return RexJuryDutyCard(cardData: message.cardData!);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildActionButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          style: BorderStyle.solid,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.attach_file,
            size: 14,
            color: AppColors.purple,
          ),
          const SizedBox(width: 8),
          Text(
            'Upload Evidence',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.purple,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}