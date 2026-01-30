import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../features/gamification/domain/entities/badge_enums.dart';

  class BadgePainter extends CustomPainter {
    static final Map<String, Path> _pathCache = {};
    final BadgeType type;
    final TrophyTier tier;
    final double animationValue;
    final double shineValue;  // ← ADD separate shine animation value

    // 0.0 to 1.0 for animations

    BadgePainter({
      required this.type,
      required this.tier,
      this.animationValue = 0.0,
      this.shineValue = 0.0,  // ← ADD with default
    });

    @override
    void paint(Canvas canvas, Size size) {
      final path = _getPathForType(size);

      // LAYER 1: Outer glow (pulsing)
      final outerGlowIntensity = 0.6 + (math.sin(animationValue * 2 * math.pi) * 0.4);
      final outerGlow = Paint()
        ..color = tier.glowColor.withValues(alpha:outerGlowIntensity * 0.8)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 16 * outerGlowIntensity);
      canvas.drawPath(path, outerGlow);

 // LAYER 1B: Mid glow (offset pulse, creates "breathing" effect)
      final midGlowIntensity = 0.6 + (math.sin((animationValue + 0.15) * 2 * math.pi) * 0.4);
      final midGlow = Paint()
        ..color = tier.gradientColors[1].withValues(alpha:midGlowIntensity * 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * midGlowIntensity);
      canvas.drawPath(path, midGlow);
 // LAYER 1C: Inner edge (fast pulse, creates sharpness)
      final edgeGlowIntensity = 0.4 + (math.sin(animationValue * 4 * math.pi) * 0.6);
      final edgeGlow = Paint()
        ..color = tier.strokeColor.withValues(alpha:edgeGlowIntensity * 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawPath(path, edgeGlow);
      // LAYER 2: Shadow for depth
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha:0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.save();
      canvas.translate(0, 2);
      canvas.drawPath(path, shadowPaint);
      canvas.restore();

      // LAYER 3: Base gradient fill
      final gradientPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: tier.gradientColors,
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, gradientPaint);

      // LAYER 4: Inner shadow for depth
      final innerShadowPaint = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.8,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha:0.2),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..blendMode = BlendMode.multiply;
      canvas.drawPath(path, innerShadowPaint);

      // LAYER 5: Top highlight/shine
      final shinePosition = shineValue; // Moves from 0 to 1
      final shinePaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment(-1.0 + (shinePosition * 2), -1.0),
          end: Alignment(1.0 + (shinePosition * 2), 1.0),
          colors: [
            Colors.transparent,
            Colors.white.withValues(alpha:0.3),
            Colors.white.withValues(alpha:0.6),
            Colors.white.withValues(alpha:0.3),
            Colors.transparent,
          ],
          stops: const [0.0, 0.4, 0.5, 0.6, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..blendMode = BlendMode.overlay;
      canvas.drawPath(path, shinePaint);

      // LAYER 5A: PLATINUM HOLOGRAPHIC SHIMMER
        if (tier == TrophyTier.platinum) {
          final hueShift = (animationValue * 360).toInt() % 360;
          final holographicColor = HSVColor.fromAHSV(
            0.3,
            hueShift.toDouble(),
            0.7,
            1.0,
          ).toColor();

          final shimmerPaint = Paint()
            ..shader = LinearGradient(
              begin: Alignment(-1.0 + (shineValue * 2), -1.0),
              end: Alignment(1.0 + (shineValue * 2), 1.0),
              colors: [
                Colors.transparent,
                holographicColor.withValues(alpha: 0.3),
                Colors.white.withValues(alpha: 0.6),
                holographicColor.withValues(alpha: 0.3),
                Colors.transparent,
              ],
              stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
            ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
            ..blendMode = BlendMode.overlay;

          canvas.drawPath(path, shimmerPaint);
        }

        // LAYER 5B: PLATINUM ENERGY FIELD (Step 1.5)
        if (tier == TrophyTier.platinum) {
          final hexagonPath = _createHexagonPath(size);
          final rotationAngle = -animationValue * 2 * math.pi; // Counter-rotation

          canvas.save();
          canvas.translate(size.width / 2, size.height / 2);
          canvas.rotate(rotationAngle);
          canvas.translate(-size.width / 2, -size.height / 2);

          final energyPaint = Paint()
            ..shader = LinearGradient(
              colors: [
                const Color(0xFF06B6D4).withValues(alpha: 0.2), // Cyan
                const Color(0xFF3B82F6).withValues(alpha: 0.2), // Blue
              ],
            ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0;

          canvas.drawPath(hexagonPath, energyPaint);
          canvas.restore();
        }

      // LAYER 6: Stroke outline
      final strokePaint = Paint()
        ..color = tier.strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, strokePaint);

      // LAYER 7: Inner highlight stroke
      final innerStrokePaint = Paint()
        ..color = Colors.white.withValues(alpha:0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round;
      final innerPath = Path()..addPath(path, Offset.zero);
      canvas.drawPath(innerPath, innerStrokePaint);

      // LAYER 8: Badge type icon/detail
      _drawBadgeDetail(canvas, size, type, tier);
    }

    void _drawBadgeDetail(Canvas canvas, Size size, BadgeType type, TrophyTier tier) {

  // Tier-responsive colors
      final baseColor = Colors.black.withValues(alpha:tier == TrophyTier.platinum ? 0.3 : 0.2);
      final metallicColor = tier.gradientColors[1].withValues(alpha:0.4);
      final shineIntensity = 0.5 + (math.sin(animationValue * 2 * math.pi) * 0.5);

      switch (type) {
        case BadgeType.shield: _drawShieldDetails(canvas, size, tier, baseColor, metallicColor, shineIntensity);
        case BadgeType.lightning: _drawLightningDetails(canvas, size, tier, baseColor, metallicColor, shineIntensity);
        case BadgeType.diamond: _drawDiamondDetails(canvas, size, tier, baseColor, metallicColor, shineIntensity);
        case BadgeType.star: _drawStarDetails(canvas, size, tier, baseColor, metallicColor, shineIntensity);
        case BadgeType.trophy: _drawTrophyDetails(canvas, size, tier, baseColor, metallicColor, shineIntensity);
      }
    }

    void _drawShieldDetails(Canvas canvas, Size size, TrophyTier tier, Color baseColor, Color metallicColor, double shineIntensity) { 
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    switch (tier) {
      case TrophyTier.bronze:
        // Simple cross emblem
        final crossPaint = Paint()
          ..color = baseColor
          ..strokeWidth = size.width * 0.04
          ..style = PaintingStyle.stroke;
        canvas.drawLine(
          Offset(centerX, centerY - size.height * 0.12),
          Offset(centerX, centerY + size.height * 0.12),
          crossPaint,
        );
        canvas.drawLine(
          Offset(centerX - size.width * 0.12, centerY),
          Offset(centerX + size.width * 0.12, centerY),
          crossPaint,
        );
        break;

      case TrophyTier.silver:
        // Heraldic crest (3 vertical sections)
        final crestPaint = Paint()
          ..color = baseColor
          ..style = PaintingStyle.fill;

        // Left section
        canvas.drawRect(
          Rect.fromLTWH(centerX - size.width * 0.15, centerY - size.height * 0.1,
                        size.width * 0.04, size.height * 0.2),
          crestPaint,
        );
        // Center section (taller)
        canvas.drawRect(
          Rect.fromLTWH(centerX - size.width * 0.02, centerY - size.height * 0.15,
                        size.width * 0.04, size.height * 0.3),
          crestPaint,
        );
        // Right section
        canvas.drawRect(
          Rect.fromLTWH(centerX + size.width * 0.11, centerY - size.height * 0.1,
                        size.width * 0.04, size.height * 0.2),
          crestPaint,
        );

        // Add metallic highlights
        final highlightPaint = Paint()
          ..color = metallicColor
          ..style = PaintingStyle.fill;
        canvas.drawRect(
          Rect.fromLTWH(centerX - size.width * 0.02, centerY - size.height * 0.15,
                        size.width * 0.02, size.height * 0.3),
          highlightPaint,
        );
        break;

      case TrophyTier.gold:
        // Royal crest with crown
        final crownPaint = Paint()
          ..color = metallicColor
          ..style = PaintingStyle.fill;

        // Crown base
        final crownPath = Path();
        crownPath.moveTo(centerX - size.width * 0.15, centerY - size.height * 0.05);
        crownPath.lineTo(centerX - size.width * 0.1, centerY - size.height * 0.15);
        crownPath.lineTo(centerX - size.width * 0.05, centerY - size.height * 0.08);
        crownPath.lineTo(centerX, centerY - size.height * 0.18);
        crownPath.lineTo(centerX + size.width * 0.05, centerY - size.height * 0.08);
        crownPath.lineTo(centerX + size.width * 0.1, centerY - size.height * 0.15);
        crownPath.lineTo(centerX + size.width * 0.15, centerY - size.height * 0.05);
        crownPath.lineTo(centerX - size.width * 0.15, centerY - size.height * 0.05);
        crownPath.close();
        canvas.drawPath(crownPath, crownPaint);

        // Shield emblem below
        canvas.drawCircle(
          Offset(centerX, centerY + size.height * 0.05),
          size.width * 0.08,
          Paint()..color = baseColor,
        );

        // Animated sparkle
        final sparklePaint = Paint()
          ..color = Colors.white.withValues(alpha:0.6 * shineIntensity)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset(centerX + size.width * 0.12, centerY - size.height * 0.12),
          size.width * 0.02 * shineIntensity,
          sparklePaint,
        );
        break;

      case TrophyTier.platinum:
        // Futuristic hexagonal grid with energy lines
        final hexPaint = Paint()
          ..color = metallicColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;

        // Draw hexagonal pattern
        final hexRadius = size.width * 0.08;
        for (int i = 0; i < 6; i++) {
          final angle = (i * math.pi / 3);
          final startX = centerX + hexRadius * math.cos(angle);
          final startY = centerY + hexRadius * math.sin(angle);
          final endX = centerX + hexRadius * math.cos(angle + math.pi / 3);
          final endY = centerY + hexRadius * math.sin(angle + math.pi / 3);
          canvas.drawLine(Offset(startX, startY), Offset(endX, endY), hexPaint);
        }

        // Energy lines radiating from center
        final energyPaint = Paint()
          ..color = Color(0xFF22d3ee).withValues(alpha:0.4 * shineIntensity)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;

        for (int i = 0; i < 4; i++) {
          final angle = (i * math.pi / 2) + (animationValue * math.pi * 2);
          canvas.drawLine(
            Offset(centerX, centerY),
            Offset(centerX + hexRadius * 0.7 * math.cos(angle),
                   centerY + hexRadius * 0.7 * math.sin(angle)),
            energyPaint,
          );
        }
        break;
    }
  }

  // Lightning badge tier-responsive details
  void _drawLightningDetails(Canvas canvas, Size size, TrophyTier tier, Color baseColor, Color metallicColor, double shineIntensity) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    switch (tier) {
      case TrophyTier.bronze:
        // Single bold zigzag
        final boltPaint = Paint()
          ..color = baseColor
          ..strokeWidth = size.width * 0.05
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.miter;

        final boltPath = Path();
        boltPath.moveTo(centerX, centerY - size.height * 0.15);
        boltPath.lineTo(centerX + size.width * 0.08, centerY);
        boltPath.lineTo(centerX - size.width * 0.08, centerY + size.height * 0.15);
        canvas.drawPath(boltPath, boltPaint);
        break;

      case TrophyTier.silver:
        // Triple interlaced strikes
        final boltPaint = Paint()
          ..color = baseColor
          ..strokeWidth = size.width * 0.03
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        // Center bolt
        final centerBolt = Path();
        centerBolt.moveTo(centerX, centerY - size.height * 0.15);
        centerBolt.lineTo(centerX + size.width * 0.05, centerY);
        centerBolt.lineTo(centerX - size.width * 0.05, centerY + size.height * 0.15);
        canvas.drawPath(centerBolt, boltPaint);

        // Left bolt
        final leftBolt = Path();
        leftBolt.moveTo(centerX - size.width * 0.08, centerY - size.height * 0.12);
        leftBolt.lineTo(centerX - size.width * 0.03, centerY);
        leftBolt.lineTo(centerX - size.width * 0.1, centerY + size.height * 0.12);
        canvas.drawPath(leftBolt, Paint()..color = metallicColor..strokeWidth = size.width * 0.02..style = PaintingStyle.stroke);   

        // Right bolt
        final rightBolt = Path();
        rightBolt.moveTo(centerX + size.width * 0.08, centerY - size.height * 0.12);
        rightBolt.lineTo(centerX + size.width * 0.03, centerY);
        rightBolt.lineTo(centerX + size.width * 0.1, centerY + size.height * 0.12);
        canvas.drawPath(rightBolt, Paint()..color = metallicColor..strokeWidth = size.width * 0.02..style = PaintingStyle.stroke);  
        break;

      case TrophyTier.gold:
        // Lightning with electrical arcing
        final mainBoltPaint = Paint()
          ..color = metallicColor
          ..strokeWidth = size.width * 0.04
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        final mainBolt = Path();
        mainBolt.moveTo(centerX, centerY - size.height * 0.18);
        mainBolt.lineTo(centerX + size.width * 0.08, centerY - size.height * 0.05);
        mainBolt.lineTo(centerX + size.width * 0.03, centerY);
        mainBolt.lineTo(centerX + size.width * 0.1, centerY + size.height * 0.05);
        mainBolt.lineTo(centerX - size.width * 0.05, centerY + size.height * 0.18);
        canvas.drawPath(mainBolt, mainBoltPaint);

        // Electrical arcs (animated)
        final arcPaint = Paint()
          ..color = Colors.white.withValues(alpha:0.5 * shineIntensity)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;

        for (int i = 0; i < 3; i++) {
          final offsetX = (i - 1) * size.width * 0.04;
          final arcPath = Path();
          arcPath.moveTo(centerX + offsetX, centerY - size.height * 0.1);
          arcPath.quadraticBezierTo(
            centerX + offsetX + size.width * 0.05,
            centerY,
            centerX + offsetX,
            centerY + size.height * 0.1,
          );
          canvas.drawPath(arcPath, arcPaint);
        }
        break;

      case TrophyTier.platinum:
        // Plasma glow with crackling energy
        final plasmaPaint = Paint()
          ..color = Color(0xFF6366f1).withValues(alpha:0.6 * shineIntensity)
          ..strokeWidth = size.width * 0.06
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8);

        final plasmaBolt = Path();
        plasmaBolt.moveTo(centerX, centerY - size.height * 0.2);
        plasmaBolt.lineTo(centerX + size.width * 0.1, centerY);
        plasmaBolt.lineTo(centerX - size.width * 0.1, centerY + size.height * 0.2);
        canvas.drawPath(plasmaBolt, plasmaPaint);

        // Inner core
        final corePaint = Paint()
          ..color = Color(0xFF22d3ee)
          ..strokeWidth = size.width * 0.03
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        canvas.drawPath(plasmaBolt, corePaint);

        // Crackling particles
        final particlePaint = Paint()
          ..color = Colors.white.withValues(alpha:0.8 * shineIntensity)
          ..style = PaintingStyle.fill;

        for (int i = 0; i < 5; i++) {
          final particleAngle = (i * math.pi * 2 / 5) + (animationValue * math.pi * 2);
          final particleRadius = size.width * 0.15;
          canvas.drawCircle(
            Offset(centerX + particleRadius * math.cos(particleAngle),
                   centerY + particleRadius * math.sin(particleAngle)),
            size.width * 0.015,
            particlePaint,
          );
        }
        break;
    }
  }

  // Diamond badge tier-responsive details
  void _drawDiamondDetails(Canvas canvas, Size size, TrophyTier tier, Color baseColor, Color metallicColor, double shineIntensity) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    switch (tier) {
      case TrophyTier.bronze:
        // 4-facet gem (simple cross)
        final facetPaint = Paint()
          ..color = baseColor
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;

        canvas.drawLine(
          Offset(centerX, centerY - size.height * 0.12),
          Offset(centerX, centerY + size.height * 0.12),
          facetPaint,
        );
        canvas.drawLine(
          Offset(centerX - size.width * 0.12, centerY),
          Offset(centerX + size.width * 0.12, centerY),
          facetPaint,
        );
        break;

      case TrophyTier.silver:
        // 8-facet brilliant cut
        final facetPaint = Paint()
          ..color = baseColor
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke;

        // Main cross
        canvas.drawLine(
          Offset(centerX, centerY - size.height * 0.15),
          Offset(centerX, centerY + size.height * 0.15),
          facetPaint,
        );
        canvas.drawLine(
          Offset(centerX - size.width * 0.15, centerY),
          Offset(centerX + size.width * 0.15, centerY),
          facetPaint,
        );

        // Diagonal facets
        final diagonalLength = size.width * 0.1;
        final angles = [math.pi / 4, 3 * math.pi / 4, 5 * math.pi / 4, 7 * math.pi / 4];
        for (final angle in angles) {
          canvas.drawLine(
            Offset(centerX, centerY),
            Offset(centerX + diagonalLength * math.cos(angle),
                   centerY + diagonalLength * math.sin(angle)),
            facetPaint,
          );
        }

        // Metallic highlights
        final highlightPaint = Paint()
          ..color = metallicColor
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;
        canvas.drawLine(
          Offset(centerX - size.width * 0.05, centerY - size.height * 0.05),
          Offset(centerX + size.width * 0.05, centerY + size.height * 0.05),
          highlightPaint,
        );
        break;

      case TrophyTier.gold:
        // Multi-layer facets with light beams
        final facetPaint = Paint()
          ..color = baseColor
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;

        // Inner facets
        for (int layer = 1; layer <= 3; layer++) {
          final radius = size.width * 0.05 * layer;
          for (int i = 0; i < 8; i++) {
            final angle = (i * math.pi / 4);
            canvas.drawLine(
              Offset(centerX, centerY),
              Offset(centerX + radius * math.cos(angle),
                     centerY + radius * math.sin(angle)),
              facetPaint,
            );
          }
        }

        // Light beams (animated)
        final beamPaint = Paint()
          ..color = Colors.white.withValues(alpha:0.4 * shineIntensity)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4);

        for (int i = 0; i < 4; i++) {
          final angle = (i * math.pi / 2) + (animationValue * math.pi / 4);
          canvas.drawLine(
            Offset(centerX, centerY),
            Offset(centerX + size.width * 0.2 * math.cos(angle),
                   centerY + size.height * 0.2 * math.sin(angle)),
            beamPaint,
          );
        }
        break;

      case TrophyTier.platinum:
        // Prismatic rainbow refraction
        final colors = [
          Color(0xFFFF0000), // Red
          Color(0xFFFFA500), // Orange
          Color(0xFFFFFF00), // Yellow
          Color(0xFF00FF00), // Green
          Color(0xFF0000FF), // Blue
          Color(0xFF4B0082), // Indigo
          Color(0xFF9400D3), // Violet
        ];

        // Draw rainbow refractions
        for (int i = 0; i < colors.length; i++) {
          final angle = (i * math.pi * 2 / colors.length) + (animationValue * math.pi * 2);
          final beamPaint = Paint()
            ..color = colors[i].withValues(alpha:0.3 * shineIntensity)
            ..strokeWidth = 3
            ..style = PaintingStyle.stroke
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6);

          canvas.drawLine(
            Offset(centerX, centerY),
            Offset(centerX + size.width * 0.18 * math.cos(angle),
                   centerY + size.height * 0.18 * math.sin(angle)),
            beamPaint,
          );
        }

        // Central brilliant facets
        final corePaint = Paint()
          ..color = metallicColor
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;

        for (int i = 0; i < 12; i++) {
          final angle = (i * math.pi / 6);
          canvas.drawLine(
            Offset(centerX, centerY),
            Offset(centerX + size.width * 0.08 * math.cos(angle),
                   centerY + size.height * 0.08 * math.sin(angle)),
            corePaint,
          );
        }
        break;
    }
  }

  // Star badge tier-responsive details
  void _drawStarDetails(Canvas canvas, Size size, TrophyTier tier, Color baseColor, Color metallicColor, double shineIntensity) {   
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    switch (tier) {
      case TrophyTier.bronze:
        // 5-pointed outline with center dot
        final outlinePaint = Paint()
          ..color = baseColor
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;

        final starRadius = size.width * 0.1;
        final starPath = Path();
        for (int i = 0; i < 5; i++) {
          final angle = (i * 2 * math.pi / 5) - (math.pi / 2);
          final x = centerX + starRadius * math.cos(angle);
          final y = centerY + starRadius * math.sin(angle);
          if (i == 0) {
            starPath.moveTo(x, y);
          } else {
            starPath.lineTo(x, y);
          }
        }
        starPath.close();
        canvas.drawPath(starPath, outlinePaint);

        // Center dot
        canvas.drawCircle(
          Offset(centerX, centerY),
          size.width * 0.02,
          Paint()..color = baseColor..style = PaintingStyle.fill,
        );
        break;

      case TrophyTier.silver:
        // Filled star with radiating points
        final starPaint = Paint()
          ..color = baseColor
          ..style = PaintingStyle.fill;

        final starRadius = size.width * 0.12;
        final starPath = Path();
        for (int i = 0; i < 5; i++) {
          final angle = (i * 2 * math.pi / 5) - (math.pi / 2);
          final x = centerX + starRadius * math.cos(angle);
          final y = centerY + starRadius * math.sin(angle);
          if (i == 0) {
            starPath.moveTo(x, y);
          } else {
            starPath.lineTo(x, y);
          }
        }
        starPath.close();
        canvas.drawPath(starPath, starPaint);

        // Radiating points
        final rayPaint = Paint()
          ..color = metallicColor
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;

        for (int i = 0; i < 5; i++) {
          final angle = (i * 2 * math.pi / 5) - (math.pi / 2);
          final innerRadius = starRadius * 0.6;
          final outerRadius = starRadius * 1.3;
          canvas.drawLine(
            Offset(centerX + innerRadius * math.cos(angle),
                   centerY + innerRadius * math.sin(angle)),
            Offset(centerX + outerRadius * math.cos(angle),
                   centerY + outerRadius * math.sin(angle)),
            rayPaint,
          );
        }
        break;

      case TrophyTier.gold:
        // Star with 10 orbiting mini-stars
        final mainStarPaint = Paint()
          ..color = metallicColor
          ..style = PaintingStyle.fill;

        final mainRadius = size.width * 0.08;
        final mainPath = Path();
        for (int i = 0; i < 5; i++) {
          final angle = (i * 2 * math.pi / 5) - (math.pi / 2);
          final x = centerX + mainRadius * math.cos(angle);
          final y = centerY + mainRadius * math.sin(angle);
          if (i == 0) {
            mainPath.moveTo(x, y);
          } else {
            mainPath.lineTo(x, y);
          }
        }
        mainPath.close();
        canvas.drawPath(mainPath, mainStarPaint);

        // Orbiting mini-stars (animated)
        final miniStarPaint = Paint()
          ..color = Colors.white.withValues(alpha:0.7 * shineIntensity)
          ..style = PaintingStyle.fill;

        final orbitRadius = size.width * 0.15;
        for (int i = 0; i < 10; i++) {
          final angle = (i * 2 * math.pi / 10) + (animationValue * math.pi * 2);
          final miniRadius = size.width * 0.015;
          final miniX = centerX + orbitRadius * math.cos(angle);
          final miniY = centerY + orbitRadius * math.sin(angle);

          // Draw tiny star
          canvas.drawCircle(Offset(miniX, miniY), miniRadius, miniStarPaint);
        }
        break;

      case TrophyTier.platinum:
        // Celestial star with rotating constellation
        final centerStarPaint = Paint()
          ..color = Color(0xFF22d3ee)
          ..style = PaintingStyle.fill
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8);

        canvas.drawCircle(Offset(centerX, centerY), size.width * 0.08, centerStarPaint);

        // Bright core
        final corePaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(centerX, centerY), size.width * 0.04, corePaint);

        // Rotating constellation pattern
        final constellationPaint = Paint()
          ..color = Color(0xFF6366f1).withValues(alpha:0.8 * shineIntensity)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;

        final constellationRadius = size.width * 0.18;
        final rotationAngle = animationValue * math.pi * 2;

        // Draw constellation points and connections
        final points = <Offset>[];
        for (int i = 0; i < 8; i++) {
          final angle = (i * math.pi / 4) + rotationAngle;
          final x = centerX + constellationRadius * math.cos(angle);
          final y = centerY + constellationRadius * math.sin(angle);
          points.add(Offset(x, y));

          // Draw star point
          canvas.drawCircle(Offset(x, y), size.width * 0.012, corePaint);
        }

        // Connect constellation points
        for (int i = 0; i < points.length; i++) {
          canvas.drawLine(
            points[i],
            points[(i + 1) % points.length],
            constellationPaint,
          );
        }

        // Draw lines from center to constellation
        for (final point in points) {
          canvas.drawLine(
            Offset(centerX, centerY),
            point,
            Paint()
              ..color = Color(0xFF22d3ee).withValues(alpha:0.2 * shineIntensity)
              ..strokeWidth = 1
              ..style = PaintingStyle.stroke,
          );
        }
        break;
    }
  }

  // Trophy badge tier-responsive details
  void _drawTrophyDetails(Canvas canvas, Size size, TrophyTier tier, Color baseColor, Color metallicColor, double shineIntensity) { 
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    switch (tier) {
      case TrophyTier.bronze:
        // Simple cup silhouette
        final cupPaint = Paint()
          ..color = baseColor
          ..style = PaintingStyle.fill;

        final cupPath = Path();
        cupPath.moveTo(centerX - size.width * 0.08, centerY - size.height * 0.05);
        cupPath.lineTo(centerX - size.width * 0.06, centerY + size.height * 0.05);
        cupPath.lineTo(centerX + size.width * 0.06, centerY + size.height * 0.05);
        cupPath.lineTo(centerX + size.width * 0.08, centerY - size.height * 0.05);
        cupPath.close();
        canvas.drawPath(cupPath, cupPaint);

        // Base
        canvas.drawRect(
          Rect.fromLTWH(centerX - size.width * 0.1, centerY + size.height * 0.05,
                        size.width * 0.2, size.height * 0.02),
          cupPaint,
        );
        break;

      case TrophyTier.silver:
        // Trophy with laurel wreath
        final trophyPaint = Paint()
          ..color = baseColor
          ..style = PaintingStyle.fill;

        // Cup
        final cupPath = Path();
        cupPath.moveTo(centerX - size.width * 0.08, centerY - size.height * 0.08);
        cupPath.lineTo(centerX - size.width * 0.05, centerY + size.height * 0.03);
        cupPath.lineTo(centerX + size.width * 0.05, centerY + size.height * 0.03);
        cupPath.lineTo(centerX + size.width * 0.08, centerY - size.height * 0.08);
        cupPath.close();
        canvas.drawPath(cupPath, trophyPaint);

        // Laurel wreath (simplified as arcs)
        final wreathPaint = Paint()
          ..color = metallicColor
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;

        // Left wreath
        final leftWreath = Path();
        leftWreath.moveTo(centerX - size.width * 0.12, centerY + size.height * 0.08);
        leftWreath.quadraticBezierTo(
          centerX - size.width * 0.15, centerY - size.height * 0.05,
          centerX - size.width * 0.1, centerY - size.height * 0.12,
        );
        canvas.drawPath(leftWreath, wreathPaint);

        // Right wreath
        final rightWreath = Path();
        rightWreath.moveTo(centerX + size.width * 0.12, centerY + size.height * 0.08);
        rightWreath.quadraticBezierTo(
          centerX + size.width * 0.15, centerY - size.height * 0.05,
          centerX + size.width * 0.1, centerY - size.height * 0.12,
        );
        canvas.drawPath(rightWreath, wreathPaint);
        break;

      case TrophyTier.gold:
        // Winner's cup with "1st" banner
        final cupPaint = Paint()
          ..color = metallicColor
          ..style = PaintingStyle.fill;

        // Trophy cup
        final cupPath = Path();
        cupPath.moveTo(centerX - size.width * 0.1, centerY - size.height * 0.1);
        cupPath.lineTo(centerX - size.width * 0.06, centerY + size.height * 0.05);
        cupPath.lineTo(centerX + size.width * 0.06, centerY + size.height * 0.05);
        cupPath.lineTo(centerX + size.width * 0.1, centerY - size.height * 0.1);
        cupPath.close();
        canvas.drawPath(cupPath, cupPaint);

        // Banner
        final bannerPaint = Paint()
          ..color = baseColor
          ..style = PaintingStyle.fill;

        final bannerPath = Path();
        bannerPath.moveTo(centerX - size.width * 0.12, centerY - size.height * 0.05);
        bannerPath.lineTo(centerX + size.width * 0.12, centerY - size.height * 0.05);
        bannerPath.lineTo(centerX + size.width * 0.12, centerY + size.height * 0.02);
        bannerPath.lineTo(centerX + size.width * 0.1, centerY + size.height * 0.04);
        bannerPath.lineTo(centerX - size.width * 0.1, centerY + size.height * 0.04);
        bannerPath.lineTo(centerX - size.width * 0.12, centerY + size.height * 0.02);
        bannerPath.close();
        canvas.drawPath(bannerPath, bannerPaint);

        // Shine effect on cup
        final shinePaint = Paint()
          ..color = Colors.white.withValues(alpha:0.6 * shineIntensity)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;
        canvas.drawLine(
          Offset(centerX - size.width * 0.08, centerY - size.height * 0.08),
          Offset(centerX - size.width * 0.05, centerY + size.height * 0.02),
          shinePaint,
        );
        break;

      case TrophyTier.platinum:
        // Legendary chalice with glowing runes
        final chalicePaint = Paint()
          ..color = Color(0xFF6366f1)
          ..style = PaintingStyle.fill
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6);

        // Chalice cup
        final cupPath = Path();
        cupPath.moveTo(centerX - size.width * 0.12, centerY - size.height * 0.12);
        cupPath.quadraticBezierTo(
          centerX - size.width * 0.14, centerY,
          centerX - size.width * 0.06, centerY + size.height * 0.08,
        );
        cupPath.lineTo(centerX + size.width * 0.06, centerY + size.height * 0.08);
        cupPath.quadraticBezierTo(
          centerX + size.width * 0.14, centerY,
          centerX + size.width * 0.12, centerY - size.height * 0.12,
        );
        cupPath.close();
        canvas.drawPath(cupPath, chalicePaint);

        // Inner glow
        final glowPaint = Paint()
          ..color = Color(0xFF22d3ee).withValues(alpha:0.8)
          ..style = PaintingStyle.fill;
        canvas.drawPath(cupPath, glowPaint);

        // Glowing runes (simplified as mystical symbols)
        final runePaint = Paint()
          ..color = Colors.white.withValues(alpha:0.9 * shineIntensity)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;

        // Draw mystical rune patterns
        for (int i = 0; i < 3; i++) {
          final runeY = centerY - size.height * 0.08 + (i * size.height * 0.06);
          final runeAngle = (i * math.pi / 3) + (animationValue * math.pi * 2);

          // Circular rune
          canvas.drawArc(
            Rect.fromCenter(
              center: Offset(centerX, runeY),
              width: size.width * 0.04,
              height: size.width * 0.04,
            ),
            runeAngle,
            math.pi,
            false,
            runePaint,
          );
        }

        // Energy emanation from top
        final energyPaint = Paint()
          ..color = Color(0xFF22d3ee).withValues(alpha:0.4 * shineIntensity)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8);

        for (int i = 0; i < 5; i++) {
          final angle = (i * math.pi * 2 / 5) + (animationValue * math.pi * 2) - (math.pi / 2);
          canvas.drawLine(
            Offset(centerX, centerY - size.height * 0.12),
            Offset(centerX + size.width * 0.1 * math.cos(angle),
                   centerY - size.height * 0.12 + size.height * 0.15 * math.sin(angle)),
            energyPaint,
          );
        }
        break;
    }
  }

    Path _getPathForType(Size size) {
    // Create cache key based on type and size
    final key = '${type.name}_${size.width.toStringAsFixed(1)}_${size.height.toStringAsFixed(1)}';

    // Return cached path if it exists
    if (_pathCache.containsKey(key)) {
      return _pathCache[key]!;
    }

    // Create new path based on type
    final Path path;
    switch (type) {
      case BadgeType.shield:
        path = _createDetailedShieldPath(size.width, size.height);
        break;
      case BadgeType.lightning:
        path = _createDetailedLightningPath(size.width, size.height);
        break;
      case BadgeType.diamond:
        path = _createDetailedDiamondPath(size.width, size.height);
        break;
      case BadgeType.star:
        path = _createDetailedStarPath(size.width, size.height);
        break;
      case BadgeType.trophy:
        path = _createDetailedTrophyPath(size.width, size.height);
        break;
    }

    // Cache the path before returning
    _pathCache[key] = path;
    return path;
  }

  // Clear cache when needed (called from badge_widget dispose)
  static void clearCache() => _pathCache.clear();

    // More detailed/illustrated paths
    Path _createDetailedShieldPath(double w, double h) {
      final path = Path();
      // Top banner
      path.moveTo(w * 0.5, h * 0.05);
      path.lineTo(w * 0.85, h * 0.25);
      path.quadraticBezierTo(w * 0.9, h * 0.3, w * 0.9, h * 0.55);
      path.quadraticBezierTo(w * 0.85, h * 0.8, w * 0.5, h * 0.95);
      path.quadraticBezierTo(w * 0.15, h * 0.8, w * 0.1, h * 0.55);
      path.quadraticBezierTo(w * 0.1, h * 0.3, w * 0.15, h * 0.25);
      path.close();
      return path;
    }

    Path _createDetailedLightningPath(double w, double h) {
      final path = Path();
      path.moveTo(w * 0.55, h * 0.05);
      path.lineTo(w * 0.4, h * 0.42);
      path.lineTo(w * 0.6, h * 0.45);
      path.lineTo(w * 0.5, h * 0.6);
      path.lineTo(w * 0.7, h * 0.62);
      path.lineTo(w * 0.35, h * 0.95);
      path.lineTo(w * 0.5, h * 0.55);
      path.lineTo(w * 0.3, h * 0.52);
      path.lineTo(w * 0.45, h * 0.38);
      path.lineTo(w * 0.25, h * 0.35);
      path.close();
      return path;
    }

    Path _createDetailedDiamondPath(double w, double h) {
      final path = Path();
      // Top facet
      path.moveTo(w * 0.5, h * 0.05);
      path.lineTo(w * 0.75, h * 0.3);
      path.lineTo(w * 0.85, h * 0.45);
      path.lineTo(w * 0.5, h * 0.95);
      path.lineTo(w * 0.15, h * 0.45);
      path.lineTo(w * 0.25, h * 0.3);
      path.close();
      return path;
    }

    Path _createDetailedStarPath(double w, double h) {
      final path = Path();
      const points = 5;
      final outerRadius = w * 0.48;
      final innerRadius = outerRadius * 0.45;
      final center = Offset(w / 2, h / 2);

      for (int i = 0; i < points * 2; i++) {
        final radius = i.isEven ? outerRadius : innerRadius;
        final angle = (i * math.pi / points) - (math.pi / 2);
        final x = center.dx + radius * math.cos(angle);
        final y = center.dy + radius * math.sin(angle);

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      return path;
    }

    Path _createDetailedTrophyPath(double w, double h) {
      final path = Path();

      // Main cup body
      path.moveTo(w * 0.3, h * 0.15);
      path.quadraticBezierTo(w * 0.25, h * 0.35, w * 0.32, h * 0.5);
      path.lineTo(w * 0.38, h * 0.52);
      path.lineTo(w * 0.38, h * 0.65);
      path.lineTo(w * 0.3, h * 0.7);
      path.lineTo(w * 0.3, h * 0.8);
      path.lineTo(w * 0.7, h * 0.8);
      path.lineTo(w * 0.7, h * 0.7);
      path.lineTo(w * 0.62, h * 0.65);
      path.lineTo(w * 0.62, h * 0.52);
      path.lineTo(w * 0.68, h * 0.5);
      path.quadraticBezierTo(w * 0.75, h * 0.35, w * 0.7, h * 0.15);
      path.close();

      // Left handle
      path.moveTo(w * 0.3, h * 0.22);
      path.quadraticBezierTo(w * 0.15, h * 0.27, w * 0.15, h * 0.38);
      path.quadraticBezierTo(w * 0.18, h * 0.43, w * 0.28, h * 0.4);

      // Right handle
      path.moveTo(w * 0.7, h * 0.22);
      path.quadraticBezierTo(w * 0.85, h * 0.27, w * 0.85, h * 0.38);
      path.quadraticBezierTo(w * 0.82, h * 0.43, w * 0.72, h * 0.4);

      return path;
    }

    @override
    bool shouldRepaint(covariant BadgePainter oldDelegate) {
    // Skip repaint if animation change is negligible (< 1%)
    final deltaAnimation = (oldDelegate.animationValue - animationValue).abs();
    if (deltaAnimation < 0.01) return false;

    // Repaint if type, tier, or animation changed significantly
    return oldDelegate.type != type ||
           oldDelegate.tier != tier ||
           deltaAnimation >= 0.01;
  }
  /// Creates hexagonal energy field path for Platinum badges (Step 1.5)
    Path _createHexagonPath(Size size) {
      final path = Path();
      final centerX = size.width / 2;
      final centerY = size.height / 2;
      final radius = size.width * 0.4;

      for (int i = 0; i < 6; i++) {
        final angle = (math.pi / 3) * i - math.pi / 2;
        final x = centerX + radius * math.cos(angle);
        final y = centerY + radius * math.sin(angle);

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      return path;
    }
  }
