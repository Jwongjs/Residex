import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppGradients {
  // === STATE GRADIENTS ===
  static const LinearGradient synced = LinearGradient(
    colors: [AppColors.syncedBlue, AppColors.syncedPurple],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient drifting = LinearGradient(
    colors: [AppColors.driftingAmber, AppColors.driftingOrange],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient outOfSync = LinearGradient(
    colors: [AppColors.outOfSyncRose, AppColors.outOfSyncRed],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // === BUTTON GRADIENTS ===
  static const LinearGradient primaryButton = LinearGradient(
    colors: [AppColors.blue600, AppColors.purple500],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // === RADIAL BACKGROUNDS ===
  static RadialGradient syncedBackground = RadialGradient(
    center: Alignment.topCenter,
    radius: 1.5,
    colors: [
      AppColors.indigo500.withValues(alpha: 0.5),
      AppColors.spaceBase,
      AppColors.deepSpace,
    ],
    stops: [0.0, 0.4, 1.0],
  );
}