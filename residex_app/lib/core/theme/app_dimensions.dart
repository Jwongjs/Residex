import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppRadius {
  static const double small = 12.0;       // rounded-xl
  static const double medium = 24.0;      // rounded-[1.5rem]
  static const double large = 32.0;       // rounded-[2rem]
  static const double xl = 40.0;          // rounded-[2.5rem]

  static BorderRadius get smallRadius => BorderRadius.circular(small);
  static BorderRadius get mediumRadius => BorderRadius.circular(medium);
  static BorderRadius get largeRadius => BorderRadius.circular(large);
  static BorderRadius get xlRadius => BorderRadius.circular(xl);
}

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

class AppDimensions {
    // Padding
    static const double paddingSmall = 8.0;
    static const double paddingMedium = 16.0;
    static const double paddingLarge = 24.0;
    static const double paddingXLarge = 32.0;

    // Margins
    static const double marginSmall = 8.0;
    static const double marginMedium = 16.0;
    static const double marginLarge = 24.0;

    // Icon sizes
    static const double iconSmall = 16.0;
    static const double iconMedium = 24.0;
    static const double iconLarge = 32.0;

    // Button heights
    static const double buttonHeightSmall = 40.0;
    static const double buttonHeightMedium = 48.0;
    static const double buttonHeightLarge = 56.0;
  }

class AppShadows {
  static List<BoxShadow> blueGlow = [
    BoxShadow(
      color: AppColors.syncedBlue.withValues(alpha: 0.5),
      blurRadius: 100,
      spreadRadius: -10,
    ),
  ];

  static List<BoxShadow> purpleGlow = [
    BoxShadow(
      color: AppColors.purple500.withValues(alpha: 0.3),
      blurRadius: 30,
      spreadRadius: -10,
    ),
  ];
}