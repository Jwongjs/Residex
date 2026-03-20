import 'package:flutter/material.dart';

  class GridOverlay extends StatelessWidget {
    final double opacity;

    const GridOverlay({super.key, required this.opacity});

    @override
    Widget build(BuildContext context) {
      return Positioned.fill(
        child: CustomPaint(
          painter: _GridPainter(opacity: opacity),
        ),
      );
    }
  }

  class _GridPainter extends CustomPainter {
    final double opacity;

    _GridPainter({required this.opacity});

    @override
    void paint(Canvas canvas, Size size) {
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: opacity * 0.05)
        ..strokeWidth = 1;

      // Draw vertical lines every 20 pixels
      for (double x = 0; x < size.width; x += 20) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }

      // Draw horizontal lines every 20 pixels
      for (double y = 0; y < size.height; y += 20) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    }

    @override
    bool shouldRepaint(_GridPainter oldDelegate) => oldDelegate.opacity != opacity;
  }