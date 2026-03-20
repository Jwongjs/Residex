import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/domain/entities/users/app_user.dart';
import '../../../../../core/theme/app_text_styles.dart';

  class Header extends StatelessWidget {
    final AppUser currentUser;
    final VoidCallback onNotificationTap;
    final VoidCallback onHealthTap;

    const Header({
      super.key,
      required this.currentUser,
      required this.onNotificationTap,
      required this.onHealthTap,
    });

    @override
    Widget build(BuildContext context) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Command Center Title
          Row(
            children: [
              Icon(Icons.grid_view_rounded, color: AppColors.primaryCyan, size: 20),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Command Center',
                    style: AppTextStyles.h3.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'RESIDENT OVERVIEW',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primaryCyan,
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // User Info Row
          Row(
            children: [
              // User Avatar - tappable to profile
              GestureDetector(
                onTap: () => context.push('/profile', extra: currentUser),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.primaryCyan, AppColors.purple500],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      currentUser.avatarInitials,
                      style: AppTextStyles.h3.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // User Name and Badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentUser.name,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.h3.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryCyan.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getHonorLevelBadge(currentUser.honorLevel),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.primaryCyan,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.local_fire_department_rounded,
                          color: AppColors.orange500, size: 13),
                        const SizedBox(width: 4),
                        Text(
                          '12',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Health Icon
              GestureDetector(
                onTap: onHealthTap,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.monitor_heart_outlined,
                    color: AppColors.primaryCyan,
                    size: 18,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Notification Icon
              GestureDetector(
                onTap: onNotificationTap,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.notifications_outlined,
                    color: AppColors.textPrimary,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Dashboard Label and New Invoice Button
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'USER DASHBOARD',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentUser.name,
                    style: AppTextStyles.headlineMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              GestureDetector(
                  onTap: () => context.push('/support-center'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.blue500.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.blue500.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.blue500.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.headset_mic_rounded,
                            color: AppColors.blue500, size: 15),
                        const SizedBox(width: 5),
                        Text(
                          'Report',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.blue500,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      );
    }

    String _getHonorLevelBadge(HonorLevel level) {
      switch (level) {
        case HonorLevel.paragon:
          return 'PARAGON';
        case HonorLevel.exemplary:
          return 'EXEMPLARY';
        case HonorLevel.trusted:
          return 'TRUSTED';
        case HonorLevel.neutral:
          return 'PLATINUM'; // Default for display
        case HonorLevel.rehabilitation:
          return 'REHABILITATION';
        case HonorLevel.restricted:
          return 'RESTRICTED';
      }
    }
  }
