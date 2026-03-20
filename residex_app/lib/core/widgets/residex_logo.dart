import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../../features/shared/domain/entities/users/app_user.dart';

class ResidexLogo extends StatefulWidget {
    final double size;
    final SyncState syncState;
    final bool animate;
    final double archProgress;
    final double diamondScale;
    final double diamondAngle;

    const ResidexLogo({
      super.key,
      this.size = 120,
      this.syncState = SyncState.synced,
      this.animate = true,
      this.archProgress = 1.0,
      this.diamondScale = 1.0,
      this.diamondAngle = 0.0,
    });

  @override
  State<ResidexLogo> createState() => _ResidexLogoState();
}

class _ResidexLogoState extends State<ResidexLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (widget.animate) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getStateColor() {
    switch (widget.syncState) {
      case SyncState.synced:
        return AppColors.syncedBlue;
      case SyncState.drifting:
        return AppColors.driftingAmber;
      case SyncState.outOfSync:
        return AppColors.outOfSyncRose;
    }
  }

  Gradient _getStateGradient() {
    switch (widget.syncState) {
      case SyncState.synced:
        return AppGradients.synced;
      case SyncState.drifting:
        return AppGradients.drifting;
      case SyncState.outOfSync:
        return AppGradients.outOfSync;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow effect
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _getStateColor().withValues(alpha: 0.3),
                  Colors.transparent,
                ],
              ),
            ),
          )
              .animate(onPlay: (controller) => controller.repeat())
              .scale(
                duration: 2.seconds,
                begin: const Offset(0.8, 0.8),
                end: const Offset(1.2, 1.2),
                curve: Curves.easeInOut,
              )
              .then()
              .scale(
                duration: 2.seconds,
                begin: const Offset(1.2, 1.2),
                end: const Offset(0.8, 0.8),
                curve: Curves.easeInOut,
              ),

          // Diamond shape with arch
          CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _LogoPainter(
                gradient: _getStateGradient(),
                animationValue: _controller.value,
                archProgress: widget.archProgress,
                diamondScale: widget.diamondScale,
                diamondAngle: widget.diamondAngle,
              ),
            ),

          // Sparkle overlays
          if (widget.animate)
            Positioned(
              top: widget.size * 0.15,
              right: widget.size * 0.15,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              )
                  .animate(onPlay: (controller) => controller.repeat())
                  .fadeIn(duration: 0.8.seconds)
                  .then()
                  .fadeOut(duration: 0.8.seconds),
            ),
        ],
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
   final Gradient gradient;
   final double animationValue;
   final double archProgress;      // 0.0 = nothing drawn, 1.0 = full arch
   final double diamondScale;      // 0.0 = invisible, 1.0 = full size
   final double diamondAngle;      // radians: starts at -pi/4, ends at 0

   _LogoPainter({
     required this.gradient,
     required this.animationValue,
     this.archProgress = 1.0,
     this.diamondScale = 1.0,
     this.diamondAngle = 0.0,
   });                                                       

    @override                                                                                                                         
  void paint(Canvas canvas, Size size) {                                                                                                final paint = Paint()                                                                                                           
      ..shader = gradient.createShader(                                                                                             
        Rect.fromLTWH(0, 0, size.width, size.height),                                                                               
      )
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..shader = gradient.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.15
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);

    // Arch geometry
      final archRadius = size.width * 0.35;
      final archCenter = Offset(center.dx, center.dy - (size.width * 0.10));


    // Calculate end points of the arc
    final leftEndX = archCenter.dx - archRadius;
    final rightEndX = archCenter.dx + archRadius;
    final arcY = archCenter.dy;

    // Length of vertical extensions
    final extensionLength = size.width * 0.35; // ADJUST THIS VALUE

    // Create path for arch with extensions
    final archPath = Path();

    // Start with left vertical extension
    archPath.moveTo(leftEndX, arcY);
    archPath.lineTo(leftEndX, arcY + extensionLength);

    // Add the 180° arc
    archPath.addArc(
      Rect.fromCircle(center: archCenter, radius: archRadius),
      3.14159,
      3.14159,
    );

    // Add right vertical extension
    archPath.lineTo(rightEndX, arcY + extensionLength);

     if (archProgress >= 1.0) {
        canvas.drawPath(archPath, strokePaint);
      } else {
        for (final metric in archPath.computeMetrics()) {
          canvas.drawPath(metric.extractPath(0, metric.length * archProgress), strokePaint);
        }
      }


    // Draw diamond
    final diamondSize = size.width * 0.18;
    final diamondCenter = Offset(
      center.dx,
      center.dy + (size.width * -0.1),
    );

    final diamondPath = Path();
    diamondPath.moveTo(diamondCenter.dx, diamondCenter.dy - diamondSize);
    diamondPath.lineTo(diamondCenter.dx + diamondSize, diamondCenter.dy);
    diamondPath.lineTo(diamondCenter.dx, diamondCenter.dy + diamondSize);
    diamondPath.lineTo(diamondCenter.dx - diamondSize, diamondCenter.dy);
    diamondPath.close();

    canvas.save();
    canvas.translate(diamondCenter.dx, diamondCenter.dy);
    canvas.rotate(diamondAngle);
    canvas.scale(diamondScale);
    canvas.translate(-diamondCenter.dx, -diamondCenter.dy);
    canvas.drawPath(diamondPath, paint);
    canvas.restore();
  }

    @override
    bool shouldRepaint(_LogoPainter oldDelegate) {
      return oldDelegate.animationValue != animationValue ||
          oldDelegate.archProgress != archProgress ||
          oldDelegate.diamondScale != diamondScale ||
          oldDelegate.diamondAngle != diamondAngle;
    }
  }