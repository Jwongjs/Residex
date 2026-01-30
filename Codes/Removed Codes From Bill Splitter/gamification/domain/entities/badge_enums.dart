import 'package:flutter/material.dart';
 /// Badge shape types matching reference design
  enum BadgeType {
    shield,
    lightning,
    diamond,
    star,
    trophy,
  }

  /// Tier determines the gradient colors and rarity
  enum TrophyTier {
    bronze,
    silver,
    gold,
    platinum,
  }

  /// Extension to get tier colors
  extension TrophyTierColors on TrophyTier {
    /// Primary gradient colors for this tier
    List<Color> get gradientColors {
      switch (this) {
        case TrophyTier.platinum:
          return const [
            Color(0xFF22d3ee), // Cyan 400
            Color(0xFF3b82f6), // Blue 500
            Color(0xFF6366f1), // Indigo 500
          ];
        case TrophyTier.gold:
          return const [
            Color(0xFFfcd34d), // Yellow 300
            Color(0xFFd97706), // Amber 600
            Color(0xFFb45309), // Amber 700
          ];
        case TrophyTier.silver:
          return const [
            Color(0xFFf1f5f9), // Slate 100
            Color(0xFF94a3b8), // Slate 400
            Color(0xFF475569), // Slate 600
          ];
        case TrophyTier.bronze:
          return const [
            Color(0xFFfed7aa), // Orange 200
            Color(0xFFc2410c), // Orange 700
            Color(0xFF7c2d12), // Orange 900
          ];
      }
    }

    /// Glow color for shadows
    Color get glowColor {
      switch (this) {
        case TrophyTier.platinum:
          return const Color(0xFF22d3ee).withValues(alpha:0.4);
        case TrophyTier.gold:
          return const Color(0xFFfbbf24).withValues(alpha:0.4);
        case TrophyTier.silver:
          return const Color(0xFFcbd5e1).withValues(alpha:0.4);
        case TrophyTier.bronze:
          return const Color(0xFFc2410c).withValues(alpha:0.4);
      }
    }

    /// Stroke color for outline
    Color get strokeColor {
      switch (this) {
        case TrophyTier.platinum:
          return const Color(0xFFa5f3fc);
        case TrophyTier.gold:
          return const Color(0xFFfcd34d);
        case TrophyTier.silver:
          return const Color(0xFFe2e8f0);
        case TrophyTier.bronze:
          return const Color(0xFFfdba74);
      }
    }

    /// Whether this tier should show sparkles
    bool get hasSparkles {
      return this == TrophyTier.gold || this == TrophyTier.platinum;
    }
  }

