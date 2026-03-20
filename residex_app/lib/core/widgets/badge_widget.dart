import 'package:flutter/material.dart';

enum BadgeType { trophy, shield, lightning, diamond, star }

enum BadgeTier { bronze, silver, gold, platinum }

class BadgeWidget extends StatelessWidget {
  final BadgeType type;
  final BadgeTier tier;
  final double size;
  final bool showGlow;

  const BadgeWidget({
    super.key,
    required this.type,
    required this.tier,
    this.size = 48,
    this.showGlow = true,
  });

  Gradient _getTierGradient() {
    switch (tier) {
      case BadgeTier.bronze:
        return const LinearGradient(
          colors: [Color(0xFFCD7F32), Color(0xFF8B4513)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case BadgeTier.silver:
        return const LinearGradient(
          colors: [Color(0xFFC0C0C0), Color(0xFF808080)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case BadgeTier.gold:
        return const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case BadgeTier.platinum:
        return const LinearGradient(
          colors: [Color(0xFFE5E4E2), Color(0xFFB0C4DE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  Color _getGlowColor() {
    switch (tier) {
      case BadgeTier.bronze:
        return const Color(0xFFCD7F32);
      case BadgeTier.silver:
        return const Color(0xFFC0C0C0);
      case BadgeTier.gold:
        return const Color(0xFFFFD700);
      case BadgeTier.platinum:
        return const Color(0xFFE5E4E2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow effect
        if (showGlow)
          Container(
            width: size * 1.5,
            height: size * 1.5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _getGlowColor().withValues(alpha: 0.4),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
          ),

        // Badge
        CustomPaint(
          size: Size(size, size),
          painter: _BadgePainter(
            type: type,
            gradient: _getTierGradient(),
          ),
        ),

        // Shine overlay
        CustomPaint(
          size: Size(size, size),
          painter: _ShinePainter(),
        ),
      ],
    );
  }
}

class _BadgePainter extends CustomPainter {
  final BadgeType type;
  final Gradient gradient;

  _BadgePainter({required this.type, required this.gradient});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      )
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = _getBadgePath(size);
    canvas.drawPath(path, paint);
    canvas.drawPath(path, strokePaint);
  }

  Path _getBadgePath(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final path = Path();

    switch (type) {
      case BadgeType.trophy:
        // Inverted triangle
        path.moveTo(center.dx, size.height * 0.8);
        path.lineTo(size.width * 0.2, size.height * 0.2);
        path.lineTo(size.width * 0.8, size.height * 0.2);
        path.close();
        break;

      case BadgeType.shield:
        // Shield shape
        path.moveTo(center.dx, size.height * 0.1);
        path.lineTo(size.width * 0.8, size.height * 0.3);
        path.lineTo(size.width * 0.8, size.height * 0.6);
        path.lineTo(center.dx, size.height * 0.9);
        path.lineTo(size.width * 0.2, size.height * 0.6);
        path.lineTo(size.width * 0.2, size.height * 0.3);
        path.close();
        break;

      case BadgeType.lightning:
        // Lightning bolt
        path.moveTo(center.dx + size.width * 0.1, size.height * 0.1);
        path.lineTo(center.dx - size.width * 0.1, center.dy);
        path.lineTo(center.dx + size.width * 0.05, center.dy);
        path.lineTo(center.dx - size.width * 0.1, size.height * 0.9);
        path.lineTo(center.dx + size.width * 0.1, center.dy + size.height * 0.1);
        path.lineTo(center.dx - size.width * 0.05, center.dy + size.height * 0.1);
        path.close();
        break;

      case BadgeType.diamond:
        // Diamond shape
        path.moveTo(center.dx, size.height * 0.1);
        path.lineTo(size.width * 0.8, center.dy);
        path.lineTo(center.dx, size.height * 0.9);
        path.lineTo(size.width * 0.2, center.dy);
        path.close();
        break;

      case BadgeType.star:
        // 5-point star
        const points = 5;
        final angle = (3.14159 * 2) / points;
        final outerRadius = size.width * 0.4;
        final innerRadius = size.width * 0.2;

        for (int i = 0; i < points * 2; i++) {
          final radius = i.isEven ? outerRadius : innerRadius;
          final x = center.dx + radius * Math.cos(i * angle / 2 - 3.14159 / 2);
          final y = center.dy + radius * Math.sin(i * angle / 2 - 3.14159 / 2);

          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        break;
    }

    return path;
  }

  @override
  bool shouldRepaint(_BadgePainter oldDelegate) => false;
}

class _ShinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.3),
          Colors.transparent,
        ],
        stops: const [0.3, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width * 0.6, 0);
    path.lineTo(0, size.height * 0.6);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ShinePainter oldDelegate) => false;
}

// Helper class for Math functions
class Math {
  static double cos(double radians) => radians.cos();
  static double sin(double radians) => radians.sin();
}

extension on double {
  double cos() => (this * 180 / 3.14159).toRadians().cos();
  double sin() => (this * 180 / 3.14159).toRadians().sin();
  double toRadians() => this * 3.14159 / 180;
}