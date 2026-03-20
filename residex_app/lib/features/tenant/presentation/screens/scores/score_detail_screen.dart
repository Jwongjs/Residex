import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';

enum ScoreTab { fiscal, harmony }

class ScoreDetailScreen extends StatefulWidget {
  final int fiscalScore;
  final int harmonyScore;
  final ScoreTab initialTab;

  const ScoreDetailScreen({
    super.key,
    required this.fiscalScore,
    required this.harmonyScore,
    this.initialTab = ScoreTab.fiscal,
  });

  @override
  State<ScoreDetailScreen> createState() => _ScoreDetailScreenState();
}

class _ScoreDetailScreenState extends State<ScoreDetailScreen>
    with SingleTickerProviderStateMixin {
  late ScoreTab _activeTab;
  late AnimationController _animController;
  late Animation<double> _progressAnim;

  // Privacy state
  String _visibility = 'HOUSE';
  bool _anonymousReviews = true;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _progressAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _switchTab(ScoreTab tab) {
    if (tab == _activeTab) return;
    setState(() => _activeTab = tab);
    _animController.reset();
    _animController.forward();
  }

  _ScoreData get _data => _activeTab == ScoreTab.fiscal
      ? _ScoreData(
          score: widget.fiscalScore,
          title: 'Fiscal Score',
          desc: 'Measures financial reliability and payment habits.',
          primaryColor: AppColors.cyan400,
          secondaryColor: AppColors.blue500,
          glowColor: AppColors.blue500,
          history: [750, 780, 810, 825, 830, 850],
          breakdown: [
            _BreakdownItem('Payment Punctuality', '40%', 95, AppColors.cyan500),
            _BreakdownItem('Consistency Streaks', '25%', 80, AppColors.blue500),
            _BreakdownItem('Contribution Fairness', '20%', 100, AppColors.indigo500),
            _BreakdownItem('Method Reliability', '10%', 90, AppColors.emerald500),
            _BreakdownItem('Historical Trend', '5%', 70, AppColors.slate500),
          ],
          tips: [
            'Maintain a 3-month streak of paying within 1 hour.',
            'Verify payments faster to boost reliability score.',
          ],
        )
      : _ScoreData(
          score: widget.harmonyScore,
          title: 'Harmony Score',
          desc: 'Reflects household responsibility and social standing.',
          primaryColor: const Color(0xFFE879F9), // fuchsia-400
          secondaryColor: AppColors.purple500,
          glowColor: AppColors.purple500,
          history: [600, 650, 700, 720, 780, 800],
          breakdown: [
            _BreakdownItem('Chore Completion', '35%', 85, const Color(0xFFD946EF)),
            _BreakdownItem('Housemate Ratings', '30%', 92, AppColors.purple500),
            _BreakdownItem('Rule Adherence', '20%', 98, AppColors.pink500),
            _BreakdownItem('Tenure Stability', '10%', 100, AppColors.indigo500),
            _BreakdownItem('Community Contrib.', '5%', 60, AppColors.rose500),
          ],
          tips: [
            'Complete 5 chores in a row without reminders.',
            'Host a community event to boost contribution.',
          ],
        );

  _Tier _getTier(int score) {
    if (score >= 900) return _Tier('PERFECT', AppColors.emerald400);
    if (score >= 800) return _Tier('EXCELLENT', AppColors.cyan400);
    if (score >= 700) return _Tier('GOOD', AppColors.blue400);
    if (score >= 600) return _Tier('FAIR', AppColors.amber500);
    return _Tier('POOR', AppColors.rose500);
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final tier = _getTier(data.score);

    return Scaffold(
      backgroundColor: const Color(0xFF02040A),
      body: Stack(
        children: [
          // Dynamic background glow
          AnimatedContainer(
            duration: const Duration(milliseconds: 700),
            height: 600,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.2,
                colors: [
                  (_activeTab == ScoreTab.fiscal
                          ? AppColors.blue600
                          : AppColors.purple500)
                      .withValues(alpha: 0.25),
                  const Color(0xFF02040A),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _backButton(context),
                      Text(
                        'REPUTATION',
                        style: AppTextStyles.sectionLabel.copyWith(
                          fontSize: 14,
                          letterSpacing: 4,
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 40, height: 40),
                    ],
                  ),
                ),

                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        // Tab switcher
                        _buildTabSwitcher(),
                        const SizedBox(height: 32),

                        // Speedometer
                        _buildSpeedometer(data, tier),
                        const SizedBox(height: 32),

                        // Breakdown
                        _buildBreakdown(data),
                        const SizedBox(height: 24),

                        // History
                        _buildHistory(data),
                        const SizedBox(height: 24),

                        // Tips
                        _buildTips(data),
                        const SizedBox(height: 24),

                        // Privacy
                        _buildPrivacy(),
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

  Widget _backButton(BuildContext context) {
    return GestureDetector(
      onTap: () => context.pop(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: const Icon(Icons.arrow_back, color: AppColors.slate400, size: 20),
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          _tabButton('FISCAL', ScoreTab.fiscal, Icons.show_chart, AppColors.cyan500),
          _tabButton('HARMONY', ScoreTab.harmony, Icons.shield_outlined, const Color(0xFFD946EF)),
        ],
      ),
    );
  }

  Widget _tabButton(String label, ScoreTab tab, IconData icon, Color activeColor) {
    final isActive = _activeTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchTab(tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isActive
                ? [BoxShadow(color: activeColor.withValues(alpha: 0.2), blurRadius: 12)]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isActive ? Colors.white : AppColors.slate500),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: isActive ? Colors.white : AppColors.slate500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedometer(_ScoreData data, _Tier tier) {
    return Column(
      children: [
        SizedBox(
          width: 280,
          height: 280,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background glow
              AnimatedContainer(
                duration: const Duration(milliseconds: 700),
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: data.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 80,
                    ),
                  ],
                ),
              ),

              // The gauge
              AnimatedBuilder(
                animation: _progressAnim,
                builder: (context, child) {
                  return CustomPaint(
                    size: const Size(256, 256),
                    painter: _ScoreGaugePainter(
                      progress: (data.score / 1000).clamp(0.0, 1.0) * _progressAnim.value,
                      primaryColor: data.primaryColor,
                      secondaryColor: data.secondaryColor,
                    ),
                  );
                },
              ),

              // Center readout
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tier.label,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      color: data.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.score.toString(),
                    style: GoogleFonts.inter(
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -3,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Text(
                      'POINTS',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          data.desc,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.slate400,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdown(_ScoreData data) {
    final borderColor = _activeTab == ScoreTab.fiscal
        ? AppColors.cyan500.withValues(alpha: 0.3)
        : const Color(0xFFD946EF).withValues(alpha: 0.3);

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.slate900.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.trending_up, size: 16, color: data.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'SCORE BREAKDOWN',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ...data.breakdown.map((item) => _buildBreakdownItem(item)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreakdownItem(_BreakdownItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '${item.weight} WEIGHT',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: AppColors.slate500,
                    ),
                  ),
                ],
              ),
              Text(
                '${item.value}/100',
                style: GoogleFonts.robotoMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          AnimatedBuilder(
            animation: _progressAnim,
            builder: (context, child) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 6,
                  child: Stack(
                    children: [
                      Container(color: AppColors.slate800),
                      FractionallySizedBox(
                        widthFactor: (item.value / 100) * _progressAnim.value,
                        child: Container(
                          decoration: BoxDecoration(
                            color: item.color,
                            boxShadow: [
                              BoxShadow(
                                color: item.color.withValues(alpha: 0.5),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHistory(_ScoreData data) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.slate900.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '6 MONTH TREND',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 128,
                child: AnimatedBuilder(
                  animation: _progressAnim,
                  builder: (context, child) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(data.history.length, (i) {
                        final hPercent = (data.history[i] / 1000) * 100;
                        final barColor = _activeTab == ScoreTab.fiscal
                            ? AppColors.cyan500
                            : const Color(0xFFD946EF);
                        return Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 700),
                                width: 8,
                                height: (hPercent * 1.1) * _progressAnim.value,
                                decoration: BoxDecoration(
                                  color: barColor.withValues(
                                    alpha: 0.3 + (i * 0.1).clamp(0.0, 0.7),
                                  ),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'M${i + 1}',
                                style: GoogleFonts.inter(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.slate500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTips(_ScoreData data) {
    final borderColor = _activeTab == ScoreTab.fiscal
        ? AppColors.cyan500.withValues(alpha: 0.3)
        : const Color(0xFFD946EF).withValues(alpha: 0.3);
    final bgColor = _activeTab == ScoreTab.fiscal
        ? AppColors.cyan500.withValues(alpha: 0.1)
        : const Color(0xFFD946EF).withValues(alpha: 0.1);
    final dotColor = _activeTab == ScoreTab.fiscal
        ? AppColors.cyan400
        : const Color(0xFFE879F9);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt, size: 16, color: data.primaryColor),
              const SizedBox(width: 8),
              Text(
                'BOOST YOUR SCORE',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...data.tips.map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tip,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildPrivacy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: Colors.white.withValues(alpha: 0.05)),
        const SizedBox(height: 24),
        Row(
          children: [
            const Icon(Icons.lock_outline, size: 16, color: AppColors.slate400),
            const SizedBox(width: 8),
            Text(
              'PRIVACY & VISIBILITY',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Visibility toggle
        _privacyRow(
          icon: _visibility == 'PUBLIC'
              ? Icons.public
              : _visibility == 'HOUSE'
                  ? Icons.people_outline
                  : Icons.visibility_off_outlined,
          title: 'Score Visibility',
          subtitle: _visibility,
          trailing: GestureDetector(
            onTap: () {
              setState(() {
                _visibility = _visibility == 'PUBLIC'
                    ? 'HOUSE'
                    : _visibility == 'HOUSE'
                        ? 'PRIVATE'
                        : 'PUBLIC';
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'CHANGE',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Anonymous toggle
        _privacyRow(
          icon: Icons.info_outline,
          title: 'Anonymous Reviews',
          subtitle: _anonymousReviews ? 'ENABLED' : 'DISABLED',
          trailing: GestureDetector(
            onTap: () => setState(() => _anonymousReviews = !_anonymousReviews),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40,
              height: 24,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: _anonymousReviews ? AppColors.emerald500 : AppColors.slate700,
                borderRadius: BorderRadius.circular(12),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: _anonymousReviews ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        Text(
          'Your Fiscal Score is portable and can be used for future rental applications. Harmony Score remains private to your household unless shared.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 9,
            color: AppColors.slate500,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _privacyRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: AppColors.slate400),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: AppColors.slate500,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

// ─────────────────────────────────
// 270° GAUGE PAINTER
// ─────────────────────────────────
class _ScoreGaugePainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color secondaryColor;

  _ScoreGaugePainter({
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 16;
    const strokeWidth = 16.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 270° arc starting at 135° (bottom-left)
    const startAngle = 135 * (pi / 180);
    const sweepAngle = 270 * (pi / 180);

    // RPM ticks
    for (int i = 0; i <= 40; i++) {
      final angle = 135 + (i / 40) * 270;
      final isMajor = i % 5 == 0;
      final rad = angle * (pi / 180);
      final rInner = isMajor ? radius - 15 : radius - 10;
      final rOuter = radius + 5;
      canvas.drawLine(
        Offset(center.dx + rInner * cos(rad), center.dy + rInner * sin(rad)),
        Offset(center.dx + rOuter * cos(rad), center.dy + rOuter * sin(rad)),
        Paint()
          ..color = Colors.white.withValues(alpha: isMajor ? 0.4 : 0.1)
          ..strokeWidth = isMajor ? 2 : 1,
      );
    }

    // Background track
    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    if (progress > 0) {
      // Glow
      canvas.drawArc(
        rect,
        startAngle,
        sweepAngle * progress,
        false,
        Paint()
          ..color = primaryColor.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + 8
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );

      // Progress arc
      canvas.drawArc(
        rect,
        startAngle,
        sweepAngle * progress,
        false,
        Paint()
          ..shader = SweepGradient(
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
  bool shouldRepaint(_ScoreGaugePainter old) =>
      old.progress != progress ||
      old.primaryColor != primaryColor ||
      old.secondaryColor != secondaryColor;
}

// ─────────────────────────────────
// DATA MODELS
// ─────────────────────────────────
class _ScoreData {
  final int score;
  final String title;
  final String desc;
  final Color primaryColor;
  final Color secondaryColor;
  final Color glowColor;
  final List<int> history;
  final List<_BreakdownItem> breakdown;
  final List<String> tips;

  _ScoreData({
    required this.score,
    required this.title,
    required this.desc,
    required this.primaryColor,
    required this.secondaryColor,
    required this.glowColor,
    required this.history,
    required this.breakdown,
    required this.tips,
  });
}

class _BreakdownItem {
  final String label;
  final String weight;
  final int value;
  final Color color;

  _BreakdownItem(this.label, this.weight, this.value, this.color);
}

class _Tier {
  final String label;
  final Color color;

  _Tier(this.label, this.color);
}
