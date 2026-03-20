import 'package:device_info_plus/device_info_plus.dart';

enum PerformanceTier { low, medium, high }

class PerformanceManager {
  static PerformanceTier? _cachedTier;

  static Future<PerformanceTier> getDeviceTier() async {
    if (_cachedTier != null) return _cachedTier!;

    try {
      final info = await DeviceInfoPlugin().androidInfo;

      // Use device characteristics to estimate performance
      // Check Android version, hardware, and device model
      final sdkInt = info.version.sdkInt;
      final hardware = info.hardware.toLowerCase();
      final model = info.model.toLowerCase();

      // High-end devices: Recent Android versions with good hardware
      if (sdkInt >= 31 || hardware.contains('snapdragon 8') || hardware.contains('exynos 22')) {
        _cachedTier = PerformanceTier.high;
      }
      // Low-end devices: Older Android or budget hardware
      else if (sdkInt < 26 || model.contains('go') || hardware.contains('mt67')) {
        _cachedTier = PerformanceTier.low;
      }
      // Medium-tier: Everything else
      else {
        _cachedTier = PerformanceTier.medium;
      }
    } catch (e) {
      // Fallback to medium tier on error
      _cachedTier = PerformanceTier.medium;
    }

    return _cachedTier!;
  }

  /// Clear cached tier (for testing)
  static void clearCache() {
    _cachedTier = null;
  }
}

class BadgePerformanceConfig {
    final bool enableParticles;
    final int maxParticleCount;
    final bool enableEdgeGlow;
    final bool enableHolographicEffect;
    final int targetFPS;
    final bool disableAnimations;       // ← ADD
    final bool enableFloatAnimation;    // ← ADD
    final bool enableShineEffect;       // ← ADD
    final bool enableRotation;          // ← ADD

    const BadgePerformanceConfig({
      required this.enableParticles,
      required this.maxParticleCount,
      required this.enableEdgeGlow,
      required this.enableHolographicEffect,
      required this.targetFPS,
      required this.disableAnimations,       // ← ADD
      required this.enableFloatAnimation,    // ← ADD
      required this.enableShineEffect,       // ← ADD
      required this.enableRotation,          // ← ADD
    });

  factory BadgePerformanceConfig.forTier(PerformanceTier tier) {
    return switch (tier) {
      PerformanceTier.low => BadgePerformanceConfig(
        enableParticles: false,
        maxParticleCount: 0,
        enableEdgeGlow: false,
        enableHolographicEffect: false,
        targetFPS: 30,
        disableAnimations: true,        // ← ADD - Disable all animations
        enableFloatAnimation: false,    // ← ADD
        enableShineEffect: false,       // ← ADD
        enableRotation: false,          // ← ADD
      ),
      PerformanceTier.medium => BadgePerformanceConfig(
        enableParticles: true,
        maxParticleCount: 15,
        enableEdgeGlow: true,
        enableHolographicEffect: false,
        targetFPS: 60,
        disableAnimations: false,       // ← ADD
        enableFloatAnimation: true,     // ← ADD
        enableShineEffect: true,        // ← ADD
        enableRotation: false,          // ← ADD - No rotation on medium
      ),
      PerformanceTier.high => BadgePerformanceConfig(
        enableParticles: true,
        maxParticleCount: 30,
        enableEdgeGlow: true,
        enableHolographicEffect: true,
        targetFPS: 60,
        disableAnimations: false,       // ← ADD
        enableFloatAnimation: true,     // ← ADD
        enableShineEffect: true,        // ← ADD
        enableRotation: true,           // ← ADD - Full effects on high-end
      ),
    };
  }
}

