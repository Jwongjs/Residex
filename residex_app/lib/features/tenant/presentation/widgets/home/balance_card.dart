import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';

/// Balance Cards Widget - Displays Fiscal Score and Harmony Score
/// Two cards side by side with animated speedometer gauges
class BalanceCards extends StatelessWidget {
  final int fiscalScore;
  final int harmonyScore;
  final VoidCallback? onFiscalTap;
  final VoidCallback? onHarmonyTap;

  const BalanceCards({
    super.key,
    required this.fiscalScore,
    required this.harmonyScore,
    this.onFiscalTap,
    this.onHarmonyTap,
  });

  String _getScoreTier(int score) {
    if (score >= 900) return 'PERFECT';
    if (score >= 800) return 'EXCELLENT';
    if (score >= 700) return 'GOOD';
    if (score >= 600) return 'FAIR';
    return 'POOR';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ========================================
        // FISCAL SCORE CARD (Cyan/Blue themed)
        // ========================================
        Expanded(
          child: _ScoreCard(
            label: 'CREDIT\nBRIDGE',
            score: fiscalScore,
            maxScore: 1000,
            tier: _getScoreTier(fiscalScore),
            icon: Icons.trending_up_rounded,
            primaryColor: AppColors.primaryCyan,
            secondaryColor: AppColors.blue500,
            cardGradient: LinearGradient(
              colors: [
                AppColors.primaryCyan.withValues(alpha: 0.1),
                AppColors.blue500.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderColor: AppColors.primaryCyan.withValues(alpha: 0.3),
            onTap: onFiscalTap,
          ),
        ),

        const SizedBox(width: 16),

        // ========================================
        // HARMONY SCORE CARD (Purple themed)
        // ========================================
        Expanded(
          child: _ScoreCard(
            label: 'HARMONY',
            score: harmonyScore,
            maxScore: 1000,
            tier: _getScoreTier(harmonyScore),
            icon: Icons.shield_outlined,
            primaryColor: AppColors.purple500,
            secondaryColor: AppColors.pink,
            cardGradient: LinearGradient(
              colors: [
                AppColors.purple500.withValues(alpha: 0.1),
                AppColors.pink.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderColor: AppColors.purple500.withValues(alpha: 0.3),
            onTap: onHarmonyTap,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// SCORE CARD SHELL (with press animation)
// ─────────────────────────────────────────────
class _ScoreCard extends StatefulWidget {
  final String label;
  final int score;
  final int maxScore;
  final String tier;
  final IconData icon;
  final Color primaryColor;
  final Color secondaryColor;
  final LinearGradient cardGradient;
  final Color borderColor;
  final VoidCallback? onTap;

  const _ScoreCard({
    required this.label,
    required this.score,
    required this.maxScore,
    required this.tier,
    required this.icon,
    required this.primaryColor,
    required this.secondaryColor,
    required this.cardGradient,
    required this.borderColor,
    this.onTap,
  });

  @override
  State<_ScoreCard> createState() => _ScoreCardState();
}

class _ScoreCardState extends State<_ScoreCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            gradient: widget.cardGradient,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: widget.borderColor, width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                color: Colors.transparent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Label row (icon + text)
                    Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: widget.primaryColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(widget.icon, color: widget.primaryColor, size: 13),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.label,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textMuted,
                              fontSize: 9,
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Speedometer gauge WITH score overlaid inside
                    _SpeedometerGauge(
                      score: widget.score,
                      maxScore: widget.maxScore,
                      tier: widget.tier,
                      primaryColor: widget.primaryColor,
                      secondaryColor: widget.secondaryColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SPEEDOMETER GAUGE WIDGET (animated, score inside arc)
// ─────────────────────────────────────────────
class _SpeedometerGauge extends StatefulWidget {
  final int score;
  final int maxScore;
  final String tier;
  final Color primaryColor;
  final Color secondaryColor;

  const _SpeedometerGauge({
    required this.score,
    required this.maxScore,
    required this.tier,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  State<_SpeedometerGauge> createState() => _SpeedometerGaugeState();
}

class _SpeedometerGaugeState extends State<_SpeedometerGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _SpeedometerGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = w * 0.9; // Taller to accommodate 240° arc + text inside
        return SizedBox(
          width: w,
          height: h,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The animated gauge arc
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return CustomPaint(
                      size: Size(w, w * 0.9),
                      painter: _SpeedometerPainter(
                        progress: (widget.score / widget.maxScore).clamp(0.0, 1.0) * _animation.value,
                        primaryColor: widget.primaryColor,
                        secondaryColor: widget.secondaryColor,
                      ),
                    );
                  },
                ),
              ),

              // Score number + tier label centered inside the arc
              Positioned(
                left: 0,
                right: 0,
                bottom: h * 0.35,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Score number
                    AnimatedBuilder(
                      animation: _animation,
                      builder: (context, child) {
                        final displayScore = (widget.score * _animation.value).round();
                        return Text(
                          displayScore.toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: widget.primaryColor,
                            height: 1.0,
                            letterSpacing: -1,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 2),
                    // Tier label
                    Text(
                      widget.tier,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: widget.primaryColor.withValues(alpha: 0.7),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// SPEEDOMETER CUSTOM PAINTER (240° arc)
// ─────────────────────────────────────────────
class _SpeedometerPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color secondaryColor;

  const _SpeedometerPainter({
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 6.0;

    // 240° arc, starting at 150° (bottom-left area)
    const startAngleDeg = 150.0;
    const sweepAngleDeg = 240.0;
    const startAngle = startAngleDeg * (pi / 180);
    const sweepAngle = sweepAngleDeg * (pi / 180);

    // Center the arc horizontally, position vertically so it fills nicely
    final centerX = size.width / 2;
    final centerY = size.height * 0.55;
    final center = Offset(centerX, centerY);
    final radius = size.width / 2 - strokeWidth / 2 - 4;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background track
    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = primaryColor.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    if (progress > 0) {
      final p = progress.clamp(0.0, 1.0);

      // Glow layer
      canvas.drawArc(
        rect,
        startAngle,
        sweepAngle * p,
        false,
        Paint()
          ..color = primaryColor.withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + 6
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      // Drop shadow glow at the arc tip
      final tipAngle = startAngle + sweepAngle * p;
      final tipX = centerX + radius * cos(tipAngle);
      final tipY = centerY + radius * sin(tipAngle);
      canvas.drawCircle(
        Offset(tipX, tipY),
        4,
        Paint()
          ..color = primaryColor.withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );

      // Gradient progress arc
      canvas.drawArc(
        rect,
        startAngle,
        sweepAngle * p,
        false,
        Paint()
          ..shader = SweepGradient(
            center: Alignment.center,
            startAngle: startAngle,
            endAngle: startAngle + sweepAngle,
            colors: [primaryColor, secondaryColor],
          ).createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_SpeedometerPainter old) =>
      old.progress != progress ||
      old.primaryColor != primaryColor ||
      old.secondaryColor != secondaryColor;
}
