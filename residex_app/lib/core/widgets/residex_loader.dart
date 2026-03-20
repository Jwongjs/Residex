import 'package:flutter/material.dart';

class ResidexLoader extends StatefulWidget {
  final double size;
  final Color color1;
  final Color color2;

  const ResidexLoader({
    super.key,
    this.size = 100.0,
    this.color1 = const Color(0xFF005C97), // Brand Blue Light
    this.color2 = const Color(0xFF363795), // Brand Blue Dark
  });

  @override
  _ResidexLoaderState createState() => _ResidexLoaderState();
}

class _ResidexLoaderState extends State<ResidexLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _splitMove;
  late Animation<double> _particleScatter;
  late Animation<double> _particleBounceY;
  late Animation<double> _reformScale;
  late Animation<double> _sheenOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    // 1. Split Phase
    _splitMove = Tween<double>(begin: 0.0, end: 15.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.25, curve: Curves.easeOutBack),
      ),
    );

    // 2. Sheen Phase
    _sheenOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.15, curve: Curves.easeIn),
      ),
    );

    // 3. Scatter Outwards
    _particleScatter = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.6, curve: Curves.easeOut),
      ),
    );

    // 4. Gravity Bounce (Physics)
    _particleBounceY = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.8, curve: Curves.bounceOut),
      ),
    );

    // 5. Reform Pop
    _reformScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.85, 0.95, curve: Curves.elasticOut),
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
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _SplitCoinPainter(
              animationValue: _controller.value,
              splitMove: _splitMove.value,
              particleScatter: _particleScatter.value,
              particleBounceY: _particleBounceY.value,
              reformScale: _reformScale.value,
              sheenOpacity: _sheenOpacity.value,
              color1: widget.color1,
              color2: widget.color2,
            ),
          );
        },
      ),
    );
  }
}

class _SplitCoinPainter extends CustomPainter {
  final double animationValue;
  final double splitMove;
  final double particleScatter;
  final double particleBounceY;
  final double reformScale;
  final double sheenOpacity;
  final Color color1;
  final Color color2;

  _SplitCoinPainter({
    required this.animationValue,
    required this.splitMove,
    required this.particleScatter,
    required this.particleBounceY,
    required this.reformScale,
    required this.sheenOpacity,
    required this.color1,
    required this.color2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final Paint coinPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color1, color2],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final Paint shadowPaint = Paint()
      ..color = color2.withValues(alpha:0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    // --- WHOLE / SPLIT PHASE ---
    if (animationValue < 0.25 || animationValue > 0.85) {
      double scale = (animationValue > 0.85) ? reformScale : 1.0;
      
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(scale);
      canvas.translate(-center.dx, -center.dy);

      // Shadow
      canvas.drawCircle(center.translate(0, 5), radius, shadowPaint);

      Path topHalf = Path()..moveTo(0, 0)..lineTo(size.width, 0)..lineTo(0, size.height)..close();
      Path bottomHalf = Path()..moveTo(size.width, 0)..lineTo(size.width, size.height)..lineTo(0, size.height)..close();

      // Top Half
      canvas.save();
      canvas.translate(-splitMove, -splitMove);
      canvas.clipPath(topHalf);
      canvas.drawCircle(center, radius, coinPaint);
      _drawCurrency(canvas, center, size);
      _drawSheen(canvas, size);
      canvas.restore();

      // Bottom Half
      canvas.save();
      canvas.translate(splitMove, splitMove);
      canvas.clipPath(bottomHalf);
      canvas.drawCircle(center, radius, coinPaint);
      _drawCurrency(canvas, center, size);
      canvas.restore();
      
      canvas.restore();
    }

    // --- PARTICLES PHASE ---
    if (animationValue >= 0.25 && animationValue <= 0.85) {
      double particleRadius = radius / 3.5;
      double maxScatter = radius * 1.2;
      double maxDrop = radius * 0.8;

      final List<Offset> particleOffsets = [
        const Offset(-1, -1), const Offset(1, -1),
        const Offset(-1, 1), const Offset(1, 1),
      ];

      for (var dir in particleOffsets) {
        double dx = center.dx + (dir.dx * particleRadius) + (dir.dx * particleScatter * maxScatter);
        double dy = center.dy + (dir.dy * particleRadius) + (particleBounceY * maxDrop);

        canvas.drawCircle(Offset(dx, dy + 5), particleRadius, shadowPaint);
        canvas.drawCircle(Offset(dx, dy), particleRadius, coinPaint);
        _drawMiniSymbol(canvas, Offset(dx, dy), particleRadius);
      }
    }
  }

  void _drawCurrency(Canvas canvas, Offset center, Size size) {
    TextPainter tp = TextPainter(
      text: TextSpan(text: '\$', style: TextStyle(color: Colors.white, fontSize: size.width * 0.55, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  void _drawMiniSymbol(Canvas canvas, Offset pos, double rad) {
    TextPainter tp = TextPainter(
      text: TextSpan(text: '\$', style: TextStyle(color: Colors.white.withValues(alpha:0.9), fontSize: rad * 1.2, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(pos.dx - tp.width/2, pos.dy - tp.height/2));
  }
  
  void _drawSheen(Canvas canvas, Size size) {
    if (sheenOpacity <= 0) return;
    final Paint sheenPaint = Paint()
      ..shader = LinearGradient(colors: [Colors.white.withValues(alpha:0), Colors.white.withValues(alpha:0.4), Colors.white.withValues(alpha:0)]).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    double sheenPos = (animationValue * 5 * size.width) - (size.width * 1.5);
    canvas.save();
    canvas.translate(sheenPos, 0);
    canvas.skew(-0.4, 0);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width / 2, size.height), sheenPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}