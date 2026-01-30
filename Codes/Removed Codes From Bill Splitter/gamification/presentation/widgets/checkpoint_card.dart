import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/badge_widget/badge_widget.dart';
import '../../../gamification/domain/entities/achievement.dart';
import '../../../gamification/domain/entities/badge_enums.dart';
import 'dart:math' as math;

class CheckpointCard extends StatefulWidget {
  final Achievement achievement;
  final bool isShowcasing;

  const CheckpointCard({
    super.key,
    required this.achievement,
    this.isShowcasing = false,
  });

  @override
  State<CheckpointCard> createState() => _CheckpointCardState();
}

class _CheckpointCardState extends State<CheckpointCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _hoverAnimation;

  double _rotationX = 0.0;
  double _rotationY = 0.0;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _hoverAnimation = CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  void _onPointerMove(PointerEvent event, Size size) {
    // Calculate rotation based on pointer position
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    final dx = event.localPosition.dx - centerX;
    final dy = event.localPosition.dy - centerY;

    setState(() {
      _rotationY = (dx / centerX) * 0.1; // Max 0.1 radians
      _rotationX = -(dy / centerY) * 0.1;
    });
  }

  void _onPointerExit(PointerEvent event) {
    setState(() {
      _rotationX = 0.0;
      _rotationY = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tierColors = widget.achievement.tier.gradientColors;
    final strokeColor = widget.achievement.tier.strokeColor;

    return MouseRegion(
      onEnter: (_) => _hoverController.forward(),
      onExit: (event) {
        _hoverController.reverse();
        _onPointerExit(event);
      },
      child: Listener(
        onPointerMove: (event) {
          final box = context.findRenderObject() as RenderBox?;
          if (box != null) {
            _onPointerMove(event, box.size);
          }
        },
        child: AnimatedBuilder(
          animation: _hoverAnimation,
          builder: (context, child) {
            final scaleValue = 1.0 + (_hoverAnimation.value * 0.05);
            return Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001) // Perspective
                ..rotateX(_rotationX)
                ..rotateY(_rotationY)
                ..scale(scaleValue, scaleValue, scaleValue),
              alignment: Alignment.center,
              child: child,
            );
          },
          child: Container(
            width: 240,
            height: 340,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: strokeColor,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.achievement.tier.glowColor,
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: [
                  // Gradient background
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          tierColors[0].withValues(alpha: 0.2),
                          AppColors.slate900,
                          tierColors.last.withValues(alpha: 0.2),
                        ],
                      ),
                    ),
                  ),

                  // Grid pattern overlay
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.05,
                      child: CustomPaint(
                        painter: _GridPatternPainter(),
                      ),
                    ),
                  ),

                  // Content
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Header bar with status dots
                        _buildHeader(),

                        const SizedBox(height: 16),

                        // Badge image area
                        Expanded(
                          child: Center(
                            child: widget.achievement.isUnlocked
                                ? BadgeWidget(
                                    type: widget.achievement.badgeType,
                                    tier: widget.achievement.tier,
                                    size: BadgeSize.xl,
                                  )
                                : _buildLockedBadge(),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Footer with stats
                        _buildFooter(),
                      ],
                    ),
                  ),

                  // Authentication stamp (if unlocked)
                  if (widget.achievement.isUnlocked)
                    Positioned(
                      top: 20,
                      right: -30,
                      child: Transform.rotate(
                        angle: -0.26, // -15 degrees
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: tierColors.last.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'AUTHENTICATED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // Status dots
        Row(
          children: List.generate(
            3,
            (index) => Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: widget.achievement.isUnlocked
                    ? Colors.green
                    : Colors.grey.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        const Spacer(),
        // Tier label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: widget.achievement.tier.strokeColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: widget.achievement.tier.strokeColor,
              width: 1,
            ),
          ),
          child: Text(
            widget.achievement.tier.name.toUpperCase(),
            style: TextStyle(
              color: widget.achievement.tier.strokeColor,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLockedBadge() {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.slate800.withValues(alpha: 0.5),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.lock,
          size: 60,
          color: Colors.grey.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            widget.achievement.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),

          const SizedBox(height: 4),

          // Description
          Text(
            widget.achievement.description,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 12),

          // Progress bar
          if (!widget.achievement.isUnlocked) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: widget.achievement.progressPercent,
                backgroundColor: AppColors.slate800,
                valueColor: AlwaysStoppedAnimation(
                  widget.achievement.tier.strokeColor,
                ),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${widget.achievement.progress}/${widget.achievement.maxProgress}',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          // Rarity
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.diamond,
                size: 12,
                color: widget.achievement.tier.strokeColor,
              ),
              const SizedBox(width: 4),
              Text(
                '${widget.achievement.rarityLabel} • ${widget.achievement.rarityPercent}%',
                style: TextStyle(
                  color: widget.achievement.tier.strokeColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const gridSize = 20.0;

    // Draw vertical lines
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Draw horizontal lines
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}