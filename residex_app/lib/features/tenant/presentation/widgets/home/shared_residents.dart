import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../../../shared/domain/entities/users/app_user.dart';

  class SharedResidents extends StatelessWidget {
    final List<AppUser> residents;

    const SharedResidents({
      super.key,
      required this.residents,
    });

    @override
    Widget build(BuildContext context) {
      return GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people_outline_rounded,
                  color: AppColors.textMuted, size: 16),
                const SizedBox(width: 8),
                Text(
                  'SHARED RESIDENTS',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Residents List
            ...residents.map((resident) => _buildResidentItem(resident)).toList(),
          ],
        ),
      );
    }

    Widget _buildResidentItem(AppUser resident) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _getGradientColors(resident.honorLevel),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  resident.avatarInitials,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Name
            Expanded(
              child: Text(
                resident.name,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // Level and Points
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'LVL ${_getLevel(resident.honorLevel)}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primaryCyan,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${resident.fiscalScore}PTS',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    List<Color> _getGradientColors(HonorLevel level) {
      switch (level) {
        case HonorLevel.paragon:
          return [const Color(0xFFA855F7), const Color(0xFF8B5CF6)]; // Purple
        case HonorLevel.exemplary:
          return [const Color(0xFFF59E0B), const Color(0xFFEF4444)]; // Orange
        case HonorLevel.trusted:
          return [const Color(0xFF10B981), const Color(0xFF059669)]; // Green
        default:
          return [AppColors.primaryCyan, AppColors.blue500]; // Cyan
      }
    }

    int _getLevel(HonorLevel level) {
      switch (level) {
        case HonorLevel.paragon:
          return 9;
        case HonorLevel.exemplary:
          return 7;
        case HonorLevel.trusted:
          return 8;
        default:
          return 2;
      }
    }
  }
