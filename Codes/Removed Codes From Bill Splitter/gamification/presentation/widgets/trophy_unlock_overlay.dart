import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:splitlah_app/core/widgets/grid_overlay.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/badge_widget/badge_widget.dart';
import '../../domain/entities/achievement.dart';
import '../../domain/entities/badge_enums.dart';
import 'dart:math';

  class TrophyUnlockOverlay extends StatefulWidget {
    final Achievement achievement;
    final VoidCallback onDismiss;

    const TrophyUnlockOverlay({
      super.key,
      required this.achievement,
      required this.onDismiss,
    });

    /// Show the trophy unlock overlay
    static void show(BuildContext context, Achievement achievement) {
      // Haptic feedback
      HapticFeedback.heavyImpact();

      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.9),
        builder: (context) => TrophyUnlockOverlay(
          achievement: achievement,
          onDismiss: () => Navigator.of(context).pop(),
        ),
      );

      // Auto-dismiss after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      });
    }

    @override
    State<TrophyUnlockOverlay> createState() => _TrophyUnlockOverlayState();
  }

  class _TrophyUnlockOverlayState extends State<TrophyUnlockOverlay>
      with SingleTickerProviderStateMixin {
    late AnimationController _controller;
    late Animation<double> _scaleAnimation;
    late Animation<double> _fadeAnimation;
    late Animation<double> _glowAnimation;

    @override
    void initState() {
      super.initState();

      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500),
      );

      _scaleAnimation = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.2).chain(
            CurveTween(curve: Curves.easeOutBack),
          ),
          weight: 60,
        ),
        TweenSequenceItem(
          tween: Tween(begin: 1.2, end: 1.0).chain(
            CurveTween(curve: Curves.easeInOut),
          ),
          weight: 40,
        ),
      ]).animate(_controller);

      _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
        ),
      );

      _glowAnimation = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.0),
          weight: 50,
        ),
        TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.7),
          weight: 50,
        ),
      ]).animate(_controller);

      _controller.forward();
    }

    @override
    void dispose() {
      _controller.dispose();
      super.dispose();
    }

    @override
    Widget build(BuildContext context) {
      return GestureDetector(
        onTap: widget.onDismiss,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(child: GridOverlay(opacity: 0.03),
                    ),
                    // Particle burst effect
                    Opacity(
                      opacity: _fadeAnimation.value,
                      child: ParticlesPoolWidget(
                        tier: widget.achievement.tier,
                        size: MediaQuery.of(context).size.width,
                        particleCount: 50,
                      ),
                    ),

                    // Glow effect
                    Opacity(
                      opacity: _glowAnimation.value * 0.6,
                      child: Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: widget.achievement.tier.glowColor,
                              blurRadius: 100,
                              spreadRadius: 50,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Main content
                    Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Opacity(
                        opacity: _fadeAnimation.value,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // "ACHIEVEMENT UNLOCKED" label
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: widget.achievement.tier.strokeColor
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: widget.achievement.tier.strokeColor,
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                'ACHIEVEMENT UNLOCKED',
                                style: TextStyle(
                                  color: widget.achievement.tier.strokeColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 3,
                                ),
                              ),
                            ).animate().shimmer(
                              duration: 1500.ms,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),

                            const SizedBox(height: 32),

                            // Badge
                            BadgeWidget(
                              type: widget.achievement.badgeType,
                              tier: widget.achievement.tier,
                              size: BadgeSize.xl,
                              enableAnimations: true,
                            ),

                            const SizedBox(height: 32),

                            // Achievement title
                            Text(
                              widget.achievement.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                              textAlign: TextAlign.center,
                            ).animate().shimmer(
                              duration: 2000.ms,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),

                            const SizedBox(height: 12),

                            // Achievement description
                            Container(
                              constraints: const BoxConstraints(maxWidth: 300),
                              child: Text(
                                widget.achievement.description,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 16,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Rarity indicator
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.slate900.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.diamond,
                                    size: 16,
                                    color: widget.achievement.tier.strokeColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${widget.achievement.rarityLabel} • ${widget.achievement.rarityPercent}% have this',
                                    style: TextStyle(
                                      color: widget.achievement.tier.strokeColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 32),

                            // Tap to dismiss hint
                            Text(
                              'Tap anywhere to continue',
                              style: TextStyle(
                                color: AppColors.textMuted.withValues(alpha: 0.6),
                                fontSize: 12,
                                letterSpacing: 1,
                              ),
                            ).animate(onPlay: (controller) => controller.repeat())
                                .fadeIn(duration: 800.ms)
                                .then()
                                .fadeOut(duration: 800.ms),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    }
  }

  /// Wrapper widget for particle burst effect
  class ParticlesPoolWidget extends StatelessWidget {
    final TrophyTier tier;
    final double size;
    final int particleCount;

    const ParticlesPoolWidget({
      super.key,
      required this.tier,
      required this.size,
      required this.particleCount,
    });

    @override
    Widget build(BuildContext context) {
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: ParticlesPainter(
            tier: tier,
            particleCount: particleCount,
          ),
        ),
      );
    }
  }

  /// Simple particle painter for trophy unlock effect
  class ParticlesPainter extends CustomPainter {
    final TrophyTier tier;
    final int particleCount;

    ParticlesPainter({
      required this.tier,
      required this.particleCount,
    });

    @override
    void paint(Canvas canvas, Size size) {
      final paint = Paint()..style = PaintingStyle.fill;
      final center = Offset(size.width / 2, size.height / 2);
      final colors = tier.gradientColors;

      for (int i = 0; i < particleCount; i++) {
        final angle = (i / particleCount) * 2 * pi;
        final distance = 100.0 + (i % 3) * 50;
        final x = center.dx + distance * cos(angle);
        final y = center.dy + distance * sin(angle);

        paint.color = colors[i % colors.length].withValues(alpha: 0.6);
        canvas.drawCircle(Offset(x, y), 3.0, paint);
      }
    }

    @override
    bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
  }