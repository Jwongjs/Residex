import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../../../features/gamification/domain/entities/badge_enums.dart';
import 'badge_painter.dart';
import '../../utils/performance_tier.dart';
import '../../utils/particles_pool.dart';

enum BadgeSize {
  sm(32),
  md(48),
  lg(64),
  xl(128);

  final double pixels;
  const BadgeSize(this.pixels);
}

class BadgeWidget extends StatefulWidget {
  final BadgeType type;
  final TrophyTier tier;
  final BadgeSize size;
  final bool enableAnimations;
  final VoidCallback? onTap;
  final bool enableTapFeedback;
  final double? rarityPercent; // STEP 1.8 - For rarity indicator

  const BadgeWidget({
    Key? key,
    required this.type,
    required this.tier,
    this.size = BadgeSize.md,
    this.enableAnimations = true,
    this.onTap,
    this.enableTapFeedback = true,
    this.rarityPercent, // STEP 1.8
  }) : super(key: key);

  @override
  State<BadgeWidget> createState() => _BadgeWidgetState();
}

class _BadgeWidgetState extends State<BadgeWidget>
    with TickerProviderStateMixin {
  static int _badgeInstanceCount = 0;
  late AnimationController _floatController;
  late AnimationController _glowController;
  late AnimationController _shineController;
  late AnimationController _rotationController;
  late AnimationController _tapController;

  late Animation<double> _floatAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _shineAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _tapAnimation; // STEP 1.6
  bool _isShowcasing = false;  // RESTORE this
  BadgePerformanceConfig? _perfConfig;  // RESTORE this
  

  @override
  void initState() {
    super.initState();
    _badgeInstanceCount++;
    _loadPerformanceConfig();

    if (widget.enableAnimations) {
      // Float animation (subtle bobbing)
      _floatController = AnimationController(
        duration: const Duration(milliseconds: 3000),
        vsync: this,
      );
      _floatAnimation = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
      );
      _floatController.repeat();

      // Glow pulse
      _glowController = AnimationController(
        duration: const Duration(milliseconds: 2000),
        vsync: this,
      );
      _glowAnimation = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
      );
      _glowController.repeat();

      // Shimmer/shine effect
      _shineController = AnimationController(
        duration: const Duration(milliseconds: 2500),
        vsync: this,
      );
      _shineAnimation = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _shineController, curve: Curves.linear),
      );
      _shineController.repeat(reverse: false);

      // Subtle rotation for Platinum
      if (widget.tier == TrophyTier.platinum) {
        _rotationController = AnimationController(
          duration: const Duration(milliseconds: 8000),
          vsync: this,
        );
        _rotationAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(
          CurvedAnimation(parent: _rotationController, curve: Curves.easeInOut),
        );
        _rotationController.repeat(reverse: true);
      }

      // STEP 1.6: Tap/press animation controller
      _tapController = AnimationController(
        duration: const Duration(milliseconds: 100),
        vsync: this,
      );
      _tapAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
        CurvedAnimation(parent: _tapController, curve: Curves.easeOut),
      );
    }
  }

  @override
  void dispose() {
    if (widget.enableAnimations) {
      _floatController.dispose();
      _glowController.dispose();
      _shineController.dispose();
      if (widget.tier == TrophyTier.platinum) {
        _rotationController.dispose();
      }
      _tapController.dispose();
    }

    _badgeInstanceCount--;
    if (_badgeInstanceCount == 0) {
      // STEP 1.11: Clear all caches when last badge disposed
      BadgePainter.clearCache();
      ParticlePool.clearAll(); 
    }
    super.dispose();
  }

  Future<void> _loadPerformanceConfig() async {
    final tier = await PerformanceManager.getDeviceTier();
    if (mounted) {
      setState(() => _perfConfig = BadgePerformanceConfig.forTier(tier));
    }
  }

  // STEP 1.6: Tap interaction handlers
  void _handleTapDown(TapDownDetails details) {
    if (!widget.enableTapFeedback) return;
    HapticFeedback.lightImpact();
    _tapController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    if (!widget.enableTapFeedback) return;
    _tapController.reverse();
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    if (!widget.enableTapFeedback) return;
    _tapController.reverse();
  }

  void _handleLongPress() {
    if (!widget.enableTapFeedback) return;
    HapticFeedback.mediumImpact();
    setState(() => _isShowcasing = true);

    // Auto-dismiss showcase after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _isShowcasing = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Disable animations if widget setting is off OR device is low-end
    final shouldDisableAnimations = !widget.enableAnimations ||
        (_perfConfig?.disableAnimations ?? false);

    if (shouldDisableAnimations) {
      return _buildStaticBadge();
    }

    // STEP 1.6: Wrap with GestureDetector for tap/long-press
    // Main badge widget
  final badgeWidget = GestureDetector(
    onTapDown: _handleTapDown,
    onTapUp: _handleTapUp,
    onTapCancel: _handleTapCancel,
    onLongPress: _handleLongPress,
    child: RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([
          if (_perfConfig?.enableFloatAnimation ?? true) _floatController,
          _glowController,
          if (_perfConfig?.enableShineEffect ?? true) _shineController,
          if (widget.tier == TrophyTier.platinum &&
              (_perfConfig?.enableRotation ?? true)) _rotationController,
          _tapController,
        ]),
        builder: (context, child) {
          final floatOffset = (_perfConfig?.enableFloatAnimation ?? true)
              ? math.sin(_floatAnimation.value * 2 * math.pi) * 3
              : 0.0;
          final rotation = (widget.tier == TrophyTier.platinum &&
                           (_perfConfig?.enableRotation ?? true))
              ? _rotationAnimation.value
              : 0.0;
          final scale = _tapAnimation.value;

          return Transform.scale(
            scale: scale,
            child: Transform.translate(
              offset: Offset(0, floatOffset),
              child: Transform.rotate(
                angle: rotation,
                child: SizedBox(
                  width: widget.size.pixels,
                  height: widget.size.pixels,
                  child: Stack(
                    children: [
                      RepaintBoundary(
                        child: Center(
                          child: CustomPaint(
                            size: Size(widget.size.pixels * 0.85, widget.size.pixels * 0.85),
                            painter: BadgePainter(
                              type: widget.type,
                              tier: widget.tier,
                              animationValue: _glowAnimation.value,
                              shineValue: _shineAnimation.value,
                            ),
                            willChange: true,
                          ),
                        ),
                      ),
                      if (widget.tier.hasSparkles)
                        RepaintBoundary(
                          child: Stack(children: _buildSparkles()),
                        ),
                      if (widget.rarityPercent != null)
                        _buildRarityIndicator(),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );

  // If showcasing, overlay the showcase view
  if (_isShowcasing) {
    return Stack(
      children: [
        badgeWidget,
        _buildShowcaseOverlay(context),
      ],
    );
  }

  return badgeWidget;
  }

  Widget _buildStaticBadge() {
    return SizedBox(
      width: widget.size.pixels,
      height: widget.size.pixels,
      child: Center(
        child: CustomPaint(
          size: Size(widget.size.pixels * 0.85, widget.size.pixels * 0.85),
          painter: BadgePainter(
            type: widget.type,
            tier: widget.tier,
            animationValue: 0.5,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSparkles() {
    return [
      Positioned(
        top: widget.size.pixels * 0.12,
        right: widget.size.pixels * 0.18,
        child: _Sparkle(
          color: widget.tier.gradientColors.first,
          size: widget.size.pixels * 0.08,
          delay: 0.0,
        ),
      ),
      Positioned(
        bottom: widget.size.pixels * 0.18,
        left: widget.size.pixels * 0.15,
        child: _Sparkle(
          color: widget.tier.gradientColors.last,
          size: widget.size.pixels * 0.06,
          delay: 0.5,
        ),
      ),
      Positioned(
        top: widget.size.pixels * 0.35,
        left: widget.size.pixels * 0.08,
        child: _Sparkle(
          color: widget.tier.gradientColors[1],
          size: widget.size.pixels * 0.07,
          delay: 1.0,
        ),
      ),
      if (widget.tier == TrophyTier.platinum) ...[
        Positioned(
          top: widget.size.pixels * 0.2,
          left: widget.size.pixels * 0.5,
          child: _Sparkle(
            color: const Color(0xFF22d3ee),
            size: widget.size.pixels * 0.05,
            delay: 0.3,
          ),
        ),
        Positioned(
          bottom: widget.size.pixels * 0.3,
          right: widget.size.pixels * 0.12,
          child: _Sparkle(
            color: const Color(0xFF6366f1),
            size: widget.size.pixels * 0.06,
            delay: 0.7,
          ),
        ),
      ],
    ];
  }

  // STEP 1.8: Build rarity indicator
  Widget _buildRarityIndicator() {
    if (widget.rarityPercent == null) return const SizedBox.shrink();

    final rarity = widget.rarityPercent!;
    final (color, text) = switch (rarity) {
      < 5 => (const Color(0xFFFFD700), "LEGENDARY"),
      < 15 => (const Color(0xFFA855F7), "EPIC"),
      < 40 => (const Color(0xFF06B6D4), "RARE"),
      _ => (const Color(0xFF94A3B8), "COMMON"),
    };

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color, width: 1),
          ),
          child: Text(
            "$text ${rarity.toStringAsFixed(1)}%",
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShowcaseOverlay(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () {
          setState(() => _isShowcasing = false);
        },
        child: Container(
          color: Colors.black.withValues(alpha: 0.85),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Large badge display
                Transform.scale(
                  scale: 2.5,
                  child: BadgeWidget(
                    type: widget.type,
                    tier: widget.tier,
                    size: widget.size,
                    rarityPercent: widget.rarityPercent,
                    enableAnimations: true,
                    enableTapFeedback: false, // Disable tap in showcase
                  ),
                ),

                const SizedBox(height: 48),

                // Badge tier name
                Text(
                  widget.tier.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: widget.tier.gradientColors.first,
                    letterSpacing: 4,
                    shadows: [
                      Shadow(
                        color: widget.tier.glowColor,
                        blurRadius: 20,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Badge type name
                Text(
                  _getBadgeTypeName(widget.type),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),

                const SizedBox(height: 24),

                // Rarity display
                if (widget.rarityPercent != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: widget.tier.gradientColors,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: widget.tier.glowColor,
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Text(
                      '${widget.rarityPercent!.toStringAsFixed(1)}% Rarity',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

                // Tap to dismiss hint
                Text(
                  'TAP ANYWHERE TO CLOSE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.5),
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getBadgeTypeName(BadgeType type) {
    return switch (type) {
      BadgeType.shield => 'SHIELD',
      BadgeType.lightning => 'LIGHTNING',
      BadgeType.diamond => 'DIAMOND',
      BadgeType.star => 'STAR',
      BadgeType.trophy => 'TROPHY',
    };
  }

  
}

class _Sparkle extends StatefulWidget {
  final Color color;
  final double size;
  final double delay;

  const _Sparkle({
    required this.color,
    required this.size,
    this.delay = 0,
  });

  @override
  State<_Sparkle> createState() => _SparkleState();
}

class _SparkleState extends State<_Sparkle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;

  // STEP 1.5: Trail system for Gold badges
  final List<Offset> _trailPositions = [];
  Offset _currentPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.3), weight: 60),
    ]).animate(_controller);

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 1.2), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 0.8), weight: 50),
    ]).animate(_controller);

    // STEP 1.5: Update trail positions on animation
    _controller.addListener(_updateTrail);

    Future.delayed(Duration(milliseconds: (widget.delay * 1000).toInt()), () {
      if (mounted) {
        _controller.repeat();
      }
    });
  }

  // STEP 1.5: Trail update logic
  void _updateTrail() {
    if (mounted) {
      setState(() {
        _trailPositions.insert(0, _currentPosition);
        if (_trailPositions.length > 5) {
          _trailPositions.removeLast();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_updateTrail);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    widget.color,
                    widget.color.withValues(alpha: 0),
                  ],
                  stops: const [0.3, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.6),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
