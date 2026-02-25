import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../core/theme/app_theme.dart';

/// Rex AI Main Menu - "Sync Hub" inspired interface
/// Shows animated core with function panels
class RexAIMainMenuScreen extends ConsumerStatefulWidget {
  const RexAIMainMenuScreen({super.key});

  @override
  ConsumerState<RexAIMainMenuScreen> createState() => _RexAIMainMenuScreenState();
}

class _RexAIMainMenuScreenState extends ConsumerState<RexAIMainMenuScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Ambient gradient background
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 500,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.5,
                  colors: [
                    AppColors.primary.withOpacity(0.5),
                    AppColors.background,
                    AppColors.background,
                  ],
                ),
              ),
            ),
          ),

          // Bottom gradient
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.4,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.primary.withOpacity(0.1),
                  ],
                ),
              ),
            ),
          ),

          // Scrollable content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 120),
              child: Column(
                children: [
                  // Hero section with animated core
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.45,
                    child: _buildAnimatedCore(),
                  ),

                  // Function panels grid
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildFunctionGrid(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedCore() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // The Reactor Core
          Stack(
            alignment: Alignment.center,
            children: [
              // Deep core pulse
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withOpacity(0.2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.4 + (_controller.value * 0.2)),
                          blurRadius: 60,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Tech rings
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _controller.value * 2 * math.pi,
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                    ),
                  );
                },
              ),

              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: -_controller.value * 1.5 * math.pi,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.accent.withOpacity(0.4),
                          width: 1,
                          strokeAlign: BorderSide.strokeAlignOutside,
                        ),
                      ),
                      child: DashPathCircle(
                        color: AppColors.accent.withOpacity(0.4),
                        dashWidth: 4,
                        dashSpace: 8,
                      ),
                    ),
                  );
                },
              ),

              // Center logo/icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.accent,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.5),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.smart_toy_outlined,
                  size: 50,
                  color: Colors.white,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Status text
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Text(
                'SYSTEM ONLINE',
                style: AppTextStyles.heading2.copyWith(
                  fontSize: 22,
                  letterSpacing: 8,
                  color: AppColors.primary,
                  shadows: [
                    Shadow(
                      color: AppColors.primary.withOpacity(0.5),
                      blurRadius: 20,
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 8),

          // Subtitle
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 30,
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withOpacity(0.4),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'A.I. NEURAL CORE',
                  style: AppTextStyles.label.copyWith(
                    fontSize: 9,
                    color: Colors.white.withOpacity(0.4),
                    letterSpacing: 5,
                  ),
                ),
              ),
              Container(
                width: 30,
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.4),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFunctionGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.85,
      children: [
        _buildGlassCard(
          label: 'Revenue',
          value: 'RM 14.5k',
          subValue: '+8.4% Projected',
          icon: Icons.trending_up,
          accentColor: AppColors.success,
          progress: 0.85,
          onTap: () {
            // Navigate to Rex AI Financial Officer context
            Navigator.pushReplacementNamed(
              context,
              '/landlord/rex-ai',
              arguments: 'Financial Officer',
            );
          },
        ),
        _buildGlassCard(
          label: 'Maintenance',
          value: '3 Alerts',
          subValue: 'Action Required',
          icon: Icons.build,
          accentColor: AppColors.warning,
          progress: 0.45,
          onTap: () {
            // Navigate to Rex AI Maintenance Chief context
            Navigator.pushReplacementNamed(
              context,
              '/landlord/rex-ai',
              arguments: 'Maintenance Chief',
            );
          },
        ),
        _buildGlassCard(
          label: 'Lease Generator',
          value: 'Contract',
          subValue: 'AI Draft Tool',
          icon: Icons.file_copy_outlined,
          accentColor: AppColors.purple,
          progress: 1.0,
          onTap: () {
            // Navigate to Rex AI Lease Generator context
            Navigator.pushReplacementNamed(
              context,
              '/landlord/rex-ai',
              arguments: 'Contract Guardian',
            );
          },
        ),
        _buildGlassCard(
          label: 'Lazy Logger',
          value: 'Indexer',
          subValue: 'AI Document Scan',
          icon: Icons.document_scanner_outlined,
          accentColor: AppColors.accent,
          progress: 1.0,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Lazy Logger - Coming Soon'),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildGlassCard({
    required String label,
    required String value,
    required String subValue,
    required IconData icon,
    required Color accentColor,
    required double progress,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accentColor.withOpacity(0.2),
              accentColor.withOpacity(0.05),
              Colors.transparent,
            ],
          ),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: accentColor.withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.2),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Icon and highlight dot
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    icon,
                    size: 28,
                    color: accentColor,
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accentColor,
                      boxShadow: [
                        BoxShadow(
                          color: accentColor,
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Value
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: AppTextStyles.displayLarge.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                      letterSpacing: -1,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: AppTextStyles.label.copyWith(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),

              // Progress and subvalue
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subValue,
                    style: AppTextStyles.label.copyWith(
                      fontSize: 9,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppColors.slate800.withOpacity(0.5),
                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter for dashed circle
class DashPathCircle extends StatelessWidget {
  final Color color;
  final double dashWidth;
  final double dashSpace;

  const DashPathCircle({
    super.key,
    required this.color,
    this.dashWidth = 4,
    this.dashSpace = 4,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashCirclePainter(
        color: color,
        dashWidth: dashWidth,
        dashSpace: dashSpace,
      ),
    );
  }
}

class _DashCirclePainter extends CustomPainter {
  final Color color;
  final double dashWidth;
  final double dashSpace;

  _DashCirclePainter({
    required this.color,
    required this.dashWidth,
    required this.dashSpace,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final radius = size.width / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final circumference = 2 * math.pi * radius;
    final dashCount = (circumference / (dashWidth + dashSpace)).floor();

    for (var i = 0; i < dashCount; i++) {
      final angle = (i * (dashWidth + dashSpace) / radius);
      final startAngle = angle;
      final sweepAngle = dashWidth / radius;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
