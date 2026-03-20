import 'dart:ui';
  import 'package:flutter/material.dart';
  import '../theme/app_dimensions.dart';

  class GlassCard extends StatelessWidget {
    final Widget child;
    final double? width;
    final double? height;
    final EdgeInsets? padding;
    final EdgeInsets? margin;  // ✅ ADD margin parameter
    final BorderRadius? borderRadius;
    final bool showGlow;
    final Gradient? glowGradient;
    final Gradient? gradient;  // ✅ ADD gradient parameter for card background
    final Color? borderColor;  // ✅ ADD borderColor parameter
    final double opacity;

    const GlassCard({
      super.key,
      required this.child,
      this.width,
      this.height,
      this.padding = const EdgeInsets.all(24),
      this.margin,  // ✅ ADD margin
      this.borderRadius,
      this.showGlow = false,
      this.glowGradient,
      this.gradient,  // ✅ ADD gradient
      this.borderColor,  // ✅ ADD borderColor
      this.opacity = 0.05,
    });

    @override
    Widget build(BuildContext context) {
      final radius = borderRadius ?? AppRadius.xlRadius;

      Widget card = Container(
        margin: margin,  // ✅ ADD margin
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              width: width,
              height: height,
              padding: padding,
              decoration: BoxDecoration(
                // ✅ USE gradient if provided, otherwise use solid color
                color: gradient == null ? Colors.white.withValues(alpha: opacity) : null,
                gradient: gradient,  // ✅ ADD gradient support
                borderRadius: radius,
                border: Border.all(
                  // ✅ USE borderColor if provided, otherwise use default
                  color: borderColor ?? Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: child,
            ),
          ),
        ),
      );

      if (showGlow && glowGradient != null) {
        return Stack(
          children: [
            // Glow layer
            Container(
              width: width,
              height: height,
              margin: margin,  // ✅ ADD margin to glow layer too
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: glowGradient,
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Container(color: Colors.transparent),
              ),
            ),
            // Card layer
            card,
          ],
        );
      }

      return card;
    }
  }