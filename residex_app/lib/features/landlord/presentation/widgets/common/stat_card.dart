import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';

/// Reusable statistical card with glass morphism effect
/// 
/// Features:
/// - Ambient glow with customizable color
/// - Title, value, and badge
/// - Tap interaction support
/// 
/// Usage:
/// ```dart
/// StatCard(
///   title: 'System Health',
///   value: '87/100',
///   badge: 'Optimal',
///   badgeIcon: Icons.activity,
///   gradientColor: AppColors.primary,
///   onTap: () => navigateToDetails(),
/// )
/// ```
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String badge;
  final IconData badgeIcon;
  final Color gradientColor;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.badge,
    required this.badgeIcon,
    required this.gradientColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface.withOpacity(0.6),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: Colors.white.withOpacity(0.05),
          ),
        ),
        child: Stack(
          children: [
            // Ambient glow
            Positioned(
              top: -24,
              right: -24,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: gradientColor.withOpacity(0.2),
                  boxShadow: [
                    BoxShadow(
                      color: gradientColor.withOpacity(0.3),
                      blurRadius: 40,
                    ),
                  ],
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            value,
                            maxLines: 1,
                            style: AppTextStyles.heading1.copyWith(
                              fontSize: 30,
                              letterSpacing: -1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: gradientColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: gradientColor.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Icon(
                              badgeIcon,
                              size: 12,
                              color: gradientColor.withOpacity(0.8),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                badge.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.label.copyWith(
                                  color: gradientColor.withOpacity(0.9),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}