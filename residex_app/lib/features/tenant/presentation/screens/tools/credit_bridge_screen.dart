import 'dart:math';
  import 'dart:ui';
  import 'package:flutter/material.dart';                                                                                                                                                                                                                                      import 'package:go_router/go_router.dart';
  import 'package:google_fonts/google_fonts.dart';
  import '../../../../../core/theme/app_colors.dart';

  // ── Mock data ──────────────────────────────────────────────────────────────

  const _mockScore = 680;
  const _mockScoreMin = 300;
  const _mockScoreMax = 850;

  String _getTier(int score) {
    if (score >= 750) return 'Excellent';
    if (score >= 700) return 'Good';
    if (score >= 650) return 'Fair';
    if (score >= 530) return 'Low';
    return 'Weak';
  }

  Color _getTierColor(int score) {
    if (score >= 750) return const Color(0xFF10B981);
    if (score >= 700) return const Color(0xFF4ADE80);
    if (score >= 650) return const Color(0xFFEAB308);
    if (score >= 530) return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
  }

  class _StreakMonth {
    final String label;
    final bool paid;
    final bool isCurrent;
    _StreakMonth(this.label, {this.paid = false, this.isCurrent = false});
  }

  class _LedgerEntry {
    final String title;
    final String subtitle;
    final String status;
    final bool success;
    _LedgerEntry(this.title, this.subtitle, this.status, {this.success = true});
  }

  final _streakMonths = [
    _StreakMonth('Oct', paid: true),
    _StreakMonth('Nov', paid: true),
    _StreakMonth('Dec', paid: true),
    _StreakMonth('Jan', paid: true),
    _StreakMonth('Feb', isCurrent: true),
    _StreakMonth('Mar'),
  ];

  final _ledgerEntries = [
    _LedgerEntry('January Rent — RM 800', 'Submitted via DuitNow • Jan 1, 2026', '0 Arrears'),
    _LedgerEntry('December Rent — RM 800', 'Submitted via DuitNow • Dec 1, 2025', '0 Arrears'),
    _LedgerEntry('November Rent — RM 800', 'Submitted via DuitNow • Nov 1, 2025', '0 Arrears'),
    _LedgerEntry('October Rent — RM 800', 'Submitted via DuitNow • Oct 3, 2025', '2-Day Late', success: false),
  ];

  // ── Screen ─────────────────────────────────────────────────────────────────

  class CreditBridgeScreen extends StatefulWidget {
    const CreditBridgeScreen({super.key});

    @override
    State<CreditBridgeScreen> createState() => _CreditBridgeScreenState();
  }

  class _CreditBridgeScreenState extends State<CreditBridgeScreen> {
    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: AppColors.deepSpace,
        body: Stack(
          children: [
            // Background glow
            Positioned(
              top: 0, left: 0, right: 0, height: 500,
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.2,
                    colors: [AppColors.cyan500.withValues(alpha: 0.12), AppColors.deepSpace],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          _buildHeroGauge(),
                          const SizedBox(height: 28),
                          _buildStreak(),
                          const SizedBox(height: 28),
                          _buildLedger(),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ── HEADER ───────────────────────────────────────────────────────────────

    Widget _buildHeader() {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05), shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, size: 20, color: AppColors.slate400),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CREDIT BRIDGE',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 3, color: Colors.white)),
                  Text('CTOS eTR INTEGRATION',
                      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2, color: AppColors.cyan500)),
                ],
              ),
            ),
            // CTOS badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.cyan500.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.cyan500.withValues(alpha: 0.3)),
              ),
              child: Text('CTOS',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1, color: AppColors.cyan400)),
            ),
          ],
        ),
      );
    }

    // ── HERO GAUGE ───────────────────────────────────────────────────────────

    Widget _buildHeroGauge() {
      final tierColor = _getTierColor(_mockScore);
      final tier = _getTier(_mockScore);

      return Container(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          children: [
            // Gauge with score overlaid inside
            SizedBox(
              width: double.infinity,
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // The gauge arc
                  Positioned.fill(
                    child: _CTOSGauge(
                      score: _mockScore,
                      minScore: _mockScoreMin,
                      maxScore: _mockScoreMax,
                    ),
                  ),
                  // Score + tier centered inside arc
                  Positioned(
                    bottom: 50,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$_mockScore',
                            style: GoogleFonts.inter(fontSize: 48, fontWeight: FontWeight.w900,
                                color: tierColor, letterSpacing: -3, height: 1.0)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: tierColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: tierColor.withValues(alpha: 0.3)),
                          ),
                          child: Text('$tier Credit Risk',
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700,
                                  color: tierColor, letterSpacing: 0.5)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Reporting line
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 6, height: 6,
                    decoration: BoxDecoration(color: AppColors.emerald500, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: AppColors.emerald500.withValues(alpha: 0.5), blurRadius: 4)])),
                const SizedBox(width: 8),
                Text('Reporting to CTOS & Experian',
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.slate400, letterSpacing: 0.5)),
              ],
            ),
          ],
        ),
      );
    }

    // ── STREAK ───────────────────────────────────────────────────────────────

    Widget _buildStreak() {
      final paidCount = _streakMonths.where((m) => m.paid).length;

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text('🔥', style: GoogleFonts.inter(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CTOS eTR STREAK',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2, color: AppColors.slate400)),
                      Text('$paidCount Months On-Time',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.emerald500.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.emerald500.withValues(alpha: 0.3)),
                  ),
                  child: Text('+$paidCount pts',
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.emerald400)),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Month steps
            Row(
              children: _streakMonths.asMap().entries.map((entry) {
                final i = entry.key;
                final month = entry.value;
                final isLast = i == _streakMonths.length - 1;

                return Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            // Circle
                            Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                color: month.paid
                                    ? AppColors.emerald500
                                    : month.isCurrent
                                        ? AppColors.cyan500.withValues(alpha: 0.2)
                                        : AppColors.slate800,
                                shape: BoxShape.circle,
                                border: month.isCurrent
                                    ? Border.all(color: AppColors.cyan500, width: 2)
                                    : null,
                                boxShadow: month.isCurrent
                                    ? [BoxShadow(color: AppColors.cyan500.withValues(alpha: 0.4), blurRadius: 8)]
                                    : month.paid
                                        ? [BoxShadow(color: AppColors.emerald500.withValues(alpha: 0.3), blurRadius: 6)]
                                        : null,
                              ),
                              child: month.paid
                                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                                  : month.isCurrent
                                      ? const Icon(Icons.circle, size: 8, color: AppColors.cyan400)
                                      : null,
                            ),
                            const SizedBox(height: 6),
                            Text(month.label,
                                style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700,
                                    color: month.paid || month.isCurrent ? Colors.white : AppColors.slate600)),
                          ],
                        ),
                      ),
                      // Connector line (not after last)
                      if (!isLast)
                        Container(
                          width: 1, height: 1,
                          color: Colors.transparent,
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Motivation text
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.cyan500.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cyan500.withValues(alpha: 0.15)),
              ),
              child: Text(
                'Pay February rent on time to push your score into the "Good" bracket.',
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.cyan400, height: 1.5),
              ),
            ),
          ],
        ),
      );
    }

    // ── LEDGER ───────────────────────────────────────────────────────────────

    Widget _buildLedger() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text('eTR SUBMISSION LEDGER',
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2, color: AppColors.slate500)),
          ),
          const SizedBox(height: 12),
          ..._ledgerEntries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildLedgerItem(entry),
          )),
        ],
      );
    }

    Widget _buildLedgerItem(_LedgerEntry entry) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppColors.cyan500.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cyan500.withValues(alpha: 0.15)),
              ),
              child: const Icon(Icons.sync_rounded, size: 18, color: AppColors.cyan400),
            ),
            const SizedBox(width: 14),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.title,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(entry.subtitle,
                      style: GoogleFonts.inter(fontSize: 10, color: AppColors.slate500)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: entry.success
                    ? AppColors.emerald500.withValues(alpha: 0.1)
                    : AppColors.amber500.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: entry.success
                      ? AppColors.emerald500.withValues(alpha: 0.3)
                      : AppColors.amber500.withValues(alpha: 0.3),
                ),
              ),
              child: Text(entry.status,
                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900,
                      color: entry.success ? AppColors.emerald400 : AppColors.amber500)),
            ),
          ],
        ),
      );
    }
  }

  // ── CTOS GAUGE WIDGET ──────────────────────────────────────────────────────

  class _CTOSGauge extends StatefulWidget {
    final int score;
    final int minScore;
    final int maxScore;

    const _CTOSGauge({
      required this.score,
      required this.minScore,
      required this.maxScore,
    });

    @override
    State<_CTOSGauge> createState() => _CTOSGaugeState();
  }

  class _CTOSGaugeState extends State<_CTOSGauge> with SingleTickerProviderStateMixin {
    late AnimationController _controller;
    late Animation<double> _animation;

    @override
    void initState() {
      super.initState();
      _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
      _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
      _controller.forward();
    }

    @override
    void dispose() {
      _controller.dispose();
      super.dispose();
    }

    @override
    Widget build(BuildContext context) {
      return AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          return CustomPaint(
            painter: _CTOSGaugePainter(
              progress: ((widget.score - widget.minScore) / (widget.maxScore - widget.minScore)).clamp(0.0, 1.0) * _animation.value,
            ),
            size: Size.infinite,
          );
        },
      );
    }
  }

  class _CTOSGaugePainter extends CustomPainter {
    final double progress;
    _CTOSGaugePainter({required this.progress});

    @override
    void paint(Canvas canvas, Size size) {
      const strokeWidth = 14.0;
      const startAngleDeg = 150.0;
      const sweepAngleDeg = 240.0;
      const startAngle = startAngleDeg * (pi / 180);
      const sweepAngle = sweepAngleDeg * (pi / 180);

      final cx = size.width / 2;
      final cy = size.height * 0.6;
      final radius = min(size.width / 2, size.height * 0.55) - strokeWidth / 2 - 4;
      final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

      // Color brackets with proportional arc spans (range 300-850 = 550)
      // Weak: 300-529 = 230/550, Low: 530-649 = 120/550, Fair: 650-699 = 50/550, Good: 700-749 = 50/550, Excellent: 750-850 = 100/550
      final brackets = [
        (const Color(0xFFEF4444), 230 / 550), // Red - Weak
        (const Color(0xFFF97316), 120 / 550), // Orange - Low
        (const Color(0xFFEAB308), 50 / 550),  // Yellow - Fair
        (const Color(0xFF4ADE80), 50 / 550),  // Light green - Good
        (const Color(0xFF10B981), 100 / 550), // Dark green - Excellent
      ];

      // Draw bracket segments (background track)
      double currentAngle = startAngle;
      for (final (color, fraction) in brackets) {
        final segSweep = sweepAngle * fraction;
        canvas.drawArc(
          rect, currentAngle, segSweep, false,
          Paint()
            ..color = color.withValues(alpha: 0.15)
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeCap = StrokeCap.butt,
        );
        currentAngle += segSweep;
      }

      // Round ends on the full track
      canvas.drawArc(
        rect, startAngle, 0.01, false,
        Paint()
          ..color = const Color(0xFFEF4444).withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawArc(
        rect, startAngle + sweepAngle - 0.01, 0.01, false,
        Paint()
          ..color = const Color(0xFF10B981).withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );

      if (progress > 0) {
        // Active arc (lit segments up to progress point)
        double activeAngle = startAngle;
        double remaining = sweepAngle * progress;
        for (final (color, fraction) in brackets) {
          if (remaining <= 0) break;
          final segSweep = sweepAngle * fraction;
          final drawSweep = min(remaining, segSweep);

          // Glow
          canvas.drawArc(
            rect, activeAngle, drawSweep, false,
            Paint()
              ..color = color.withValues(alpha: 0.25)
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth + 8
              ..strokeCap = StrokeCap.butt
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
          );

          // Solid
          canvas.drawArc(
            rect, activeAngle, drawSweep, false,
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeCap = StrokeCap.butt,
          );

          activeAngle += drawSweep;
          remaining -= drawSweep;
        }

        // Round cap at start
        canvas.drawArc(
          rect, startAngle, 0.01, false,
          Paint()
            ..color = const Color(0xFFEF4444)
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeCap = StrokeCap.round,
        );

        // Needle dot at tip
        final tipAngle = startAngle + sweepAngle * progress;
        final tipX = cx + radius * cos(tipAngle);
        final tipY = cy + radius * sin(tipAngle);

        // Outer glow
        canvas.drawCircle(
          Offset(tipX, tipY), 8,
          Paint()..color = Colors.white.withValues(alpha: 0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
        // White dot
        canvas.drawCircle(
          Offset(tipX, tipY), 5,
          Paint()..color = Colors.white,
        );
      }

      // Scale labels
      final labels = [('300', startAngle), ('850', startAngle + sweepAngle)];
      for (final (text, angle) in labels) {
        final lx = cx + (radius + 22) * cos(angle);
        final ly = cy + (radius + 22) * sin(angle);
        final tp = TextPainter(
          text: TextSpan(text: text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.3))),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(lx - tp.width / 2, ly - tp.height / 2));
      }
    }

    @override
    bool shouldRepaint(_CTOSGaugePainter old) => old.progress != progress;
  }
