import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_gradients.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../../../../core/widgets/residex_logo.dart';
import '../../../../shared/domain/entities/users/app_user.dart';
import '../../../../../core/router/app_router.dart';
import '../../../../../core/widgets/residex_bottom_nav.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';


class SyncHubScreen extends StatefulWidget {
  final SyncState syncState;
  final String userName;

  const SyncHubScreen({
    super.key,
    this.syncState = SyncState.synced,
    required this.userName,
  });

  @override
   State<SyncHubScreen> createState() => _SyncHubScreenState();
}

  class _SyncHubScreenState extends State<SyncHubScreen> {


  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _getSyncMessage() {
    return switch (widget.syncState) {
      SyncState.synced => 'Everything is in harmony',
      SyncState.drifting => 'Minor issues detected',
      SyncState.outOfSync => 'Action required',
    };
  }

   Color _getBackgroundColor() {
    return switch (widget.syncState) {
      SyncState.synced => AppColors.deepSpace,
      SyncState.drifting => const Color(0xFF0a0604),
      SyncState.outOfSync => const Color(0xFF0d0304),
    };
  }

   @override
   void initState() {
    super.initState();
  }





  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _getBackgroundColor(),
      body: Stack(
        children: [
          // Particle system background
          const Positioned.fill(
            child: _ParticleField(),
          ),

          // Radial gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: widget.syncState == SyncState.synced
                    ? AppGradients.syncedBackground
                    : null,
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Column(
                children: [
                  const SizedBox(height: 40),


                  // HERO SECTION - The Living Core with Tech Rings
  SizedBox(
    height: 350,
    child: Stack(
      alignment: Alignment.center,
      children: [
        // 1. Deep Core Pulse (behind everything)
        Container(
          width: 128,
          height: 128,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.syncState == SyncState.synced
                ? AppColors.deepSpace.withValues(alpha: 0.2)
                : AppColors.rose500.withValues(alpha: 0.2),
          ),
        ).animate(onPlay: (controller) => controller.repeat())
          .fadeIn(duration: 2.seconds)
          .then()
          .fadeOut(duration: 2.seconds),

        // 2. Tech Rings (Jarvis Interface)
        // Ring 1: Outer (260px, 20s clockwise)
        Container(
          width: 260,
          height: 260,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.indigo500.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
        ).animate(onPlay: (controller) => controller.repeat())
          .rotate(duration: 20.seconds, curve: Curves.linear),

        // Ring 2: Middle (200px, 15s counter-clockwise)
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.cyan500.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
        ).animate(onPlay: (controller) => controller.repeat())
          .rotate(
            duration: 15.seconds,
            curve: Curves.linear,
            begin: 1.0,
            end: 0.0, // Reverse
          ),

        // Ring 3: Inner (140px, pulsing)
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.indigo500.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
        ).animate(onPlay: (controller) => controller.repeat())
          .fadeIn(duration: 2.seconds)
          .then()
          .fadeOut(duration: 2.seconds),


        GestureDetector(
           onTap: () => context.go(AppRoutes.rexInterface),

          child: ResidexLogo(
            size: 110,
            syncState: widget.syncState,
            animate: true,
          ),
        ),
      ],
    ),
  ),

  const SizedBox(height: 24),

  // Status Text (Updated style)
  Column(
    children: [
      Text(
        _getSyncStatusText().toUpperCase(),
        style: TextStyle(
          fontSize: 25,
          fontWeight: FontWeight.w900,
          color: _getStateColor(),
          letterSpacing: 4,
          height: 1.0,
        ),
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Colors.white],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'A.I. NEURAL CORE',
            style: TextStyle(
              fontSize: 8,
              fontFamily: 'monospace',
              color: Colors.white.withValues(alpha: 0.4),
              letterSpacing: 3,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 32,
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, Colors.transparent],
              ),
            ),
          ),
        ],
      ),
    ],
  ),
  const SizedBox(height: 32),

  // Chat Bubble - Quick Access to Rex
  Center(
    child: GestureDetector(
      onTap: () {
        context.go(AppRoutes.rexInterface);
      },
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.cyan500.withValues(alpha: 0.3),
              AppColors.purple500.withValues(alpha: 0.3),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.cyan500.withValues(alpha: 0.4),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.cyan500.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          Icons.chat_bubble_outline_rounded,
          color: AppColors.cyan400,
          size: 28,
        ),
      ).animate(onPlay: (controller) => controller.repeat())
        .fadeIn(duration: 2.seconds)
        .then()
        .fadeOut(duration: 2.seconds),
    ),
  ),

  const SizedBox(height: 32),

    // Glass Cards Grid (2x2)
    Padding(
  padding: const EdgeInsets.symmetric(horizontal: 0),
  child: GridView.count(
    crossAxisCount: 2,
    mainAxisSpacing: 12,
    childAspectRatio: 1.0,
    crossAxisSpacing: 12,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    children: [
      _GlassMetricCard(
        label: 'PAYABLES',
        value: 'RM 600',
        subValue: 'Due in 3 days',
        icon: Icons.warning_amber_rounded,
        accentColor: AppColors.rose500,
        progress: 75,
        onTap: () => context.go(AppRoutes.rexInterface, extra: 'Fiscal Analyst'),
      ),
      _GlassMetricCard(
        label: 'PROTOCOL',
        value: 'Level 2',
        subValue: 'Your Turn: Trash',
        icon: Icons.auto_awesome,
        accentColor: AppColors.indigo500,
        progress: 40,
        onTap: () => context.go(AppRoutes.rexInterface, extra: 'Harmony Engine'),
      ),
      _GlassMetricCard(
        label: 'DAMAGE SCAN',
        value: 'FairFix',
        subValue: 'AI Assessment',
        icon: Icons.search_rounded,
        accentColor: AppColors.cyan500,
        progress: 100,
        onTap: () => context.go(AppRoutes.fairfixAuditor),
      ),
      _GlassMetricCard(
        label: 'LEGAL CORE',
        value: 'Sentinel',
        subValue: 'Contract Analysis',
        icon: Icons.description_rounded,
        accentColor: AppColors.purple500,
        progress: 100,
        onTap: () => context.go(AppRoutes.leaseSentinel),
                          ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

  }

             // Edge glow overlay — appears when Rex is listening

  String _getSyncStatusText() {
    return switch (widget.syncState) {
      SyncState.synced => 'Sync Active',
      SyncState.drifting => 'Calibration Needed',
      SyncState.outOfSync => 'Critical Drift',
    };
  }

  Color _getStateColor() {
    return switch (widget.syncState) {
      SyncState.synced => AppColors.syncedBlue,
      SyncState.drifting => AppColors.driftingAmber,
      SyncState.outOfSync => AppColors.outOfSyncRose,
    };
  }
}

class _GlassMetricCard extends StatelessWidget {
    final String label;
    final String value;
    final String subValue;
    final IconData icon;
    final Color accentColor;
    final double progress;
    final VoidCallback onTap;

    const _GlassMetricCard({
      required this.label,
      required this.value,
      required this.subValue,
      required this.icon,
      required this.accentColor,
      required this.progress,
      required this.onTap,
    });

    @override
    Widget build(BuildContext context) {
      return GestureDetector(
        onTap: onTap,
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          opacity: 0.08,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Icon + dot
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    icon,
                    color: accentColor,
                    size: 26,
                  ),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ).animate(onPlay: (controller) => controller.repeat())
                    .fadeIn(duration: 1.seconds)
                    .then()
                    .fadeOut(duration: 1.seconds),
                ],
              ),

              const Spacer(),

              // Big metric value
              Text(
                value,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.0,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 4),

              // Label
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.5,
                ),
              ),

              const SizedBox(height: 8),

              // Subvalue
              Text(
                subValue,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textTertiary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 8),

              // Progress bar
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress / 100,
                  child: Container(
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

class _ParticleField extends StatefulWidget {
  const _ParticleField();

  @override
  State<_ParticleField> createState() => _ParticleFieldState();
}

class _ParticleFieldState extends State<_ParticleField>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();

    // Generate 200 particles
    _particles = List.generate(
      200,
      (i) => _Particle(
        angle: (i / 200) * 2 * math.pi,
        radius: 50 + (i % 3) * 80,
        speed: 0.2 + (i % 5) * 0.1,
        size: 1.0 + (i % 3),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _ParticlePainter(
            particles: _particles,
            animationValue: _controller.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _Particle {
  final double angle;
  final double radius;
  final double speed;
  final double size;

  _Particle({
    required this.angle,
    required this.radius,
    required this.speed,
    required this.size,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double animationValue;

  _ParticlePainter({
    required this.particles,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    for (final particle in particles) {
      final currentAngle = particle.angle + (animationValue * particle.speed * 2 * math.pi);
      final x = center.dx + particle.radius * math.cos(currentAngle);
      final y = center.dy + particle.radius * math.sin(currentAngle);

      canvas.drawCircle(Offset(x, y), particle.size, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) => true;
}
