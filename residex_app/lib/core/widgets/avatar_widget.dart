import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../../features/shared/domain/entities/users/app_user.dart';

class AvatarWidget extends StatelessWidget {
  final String initials;
  final double size;
  final int gradientIndex;
  final HonorLevel? honorLevel;
  final bool showHonorBadge;
  final VoidCallback? onTap;

  const AvatarWidget({
    super.key,
    required this.initials,
    this.size = 48,
    this.gradientIndex = 0,
    this.honorLevel,
    this.showHonorBadge = false,
    this.onTap,
  });

    factory AvatarWidget.fromUser({
    Key? key,
    required AppUser user,
    double size = 48,
    bool showHonorBadge = false,
    VoidCallback? onTap,
  }) {
    // Generate a consistent gradient index from user ID
    // This ensures each user always gets the same color
    final gradientIndex = user.id.hashCode.abs() % 6; // 6 gradients available

    return AvatarWidget(
      key: key,
      initials: user.avatarInitials,
      size: size,
      gradientIndex: gradientIndex,
      honorLevel: user.honorLevel,
      showHonorBadge: showHonorBadge,
      onTap: onTap,
    );
  }

  static const List<Gradient> _gradients = [
    LinearGradient(
      colors: [AppColors.cyan500, AppColors.blue600],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    LinearGradient(
      colors: [AppColors.purple500, AppColors.indigo500],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    LinearGradient(
      colors: [AppColors.emerald500, AppColors.cyan500],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    LinearGradient(
      colors: [AppColors.orange500, AppColors.rose500],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    LinearGradient(
      colors: [AppColors.syncedBlue, AppColors.syncedPurple],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    LinearGradient(
      colors: [AppColors.indigo500, AppColors.purple500],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ];

  Gradient _getGradient() {
    return _gradients[gradientIndex % _gradients.length];
  }

  Color _getHonorBadgeColor() {
    if (honorLevel == null) return Colors.transparent;
    switch (honorLevel!) {
      case HonorLevel.restricted:
        return AppColors.outOfSyncRed;
      case HonorLevel.rehabilitation:
        return AppColors.driftingOrange;
      case HonorLevel.neutral:
        return AppColors.textMuted;
      case HonorLevel.trusted:
        return AppColors.cyan500;
      case HonorLevel.exemplary:
        return AppColors.emerald500;
      case HonorLevel.paragon:
        return AppColors.syncedPurple;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Avatar circle
          Container(
            width: size,
            height: size,
             decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _getGradient(),
                border: Border.all(
                  color: (showHonorBadge && honorLevel != null)
                      ? _getHonorBadgeColor()
                      : Colors.white.withValues(alpha: 0.2),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                  if (showHonorBadge && honorLevel != null)
                    BoxShadow(
                      color: _getHonorBadgeColor().withValues(alpha: 0.55),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                ],
              ),
            child: Center(
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),

           // Honor level badge — bottom center pill
            if (showHonorBadge && honorLevel != null)
              Positioned(
                bottom: -9,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: size * 0.12,
                      vertical: size * 0.04,
                    ),
                    decoration: BoxDecoration(
                      color: _getHonorBadgeColor(),
                      borderRadius: BorderRadius.circular(size * 0.2),
                      border: Border.all(
                        color: AppColors.deepSpace,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _getHonorBadgeColor().withValues(alpha: 0.7),
                          blurRadius: 6,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Text(
                      'LV ${honorLevel!.index}',
                      style: TextStyle(
                        fontSize: size * 0.16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}