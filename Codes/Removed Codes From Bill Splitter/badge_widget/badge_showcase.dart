import 'package:flutter/material.dart';
  import '../../../features/gamification/domain/entities/badge_enums.dart';
  import 'badge_widget.dart';

  class BadgeShowcase extends StatefulWidget {
    final BadgeType type;
    final TrophyTier tier;
    final String title;
    final String description;
    final double? rarityPercent;
    final VoidCallback onDismiss;

    const BadgeShowcase({
      Key? key,
      required this.type,
      required this.tier,
      required this.title,
      required this.description,
      required this.onDismiss,
      this.rarityPercent,
    }) : super(key: key);

    @override
    State<BadgeShowcase> createState() => _BadgeShowcaseState();
  }

  class _BadgeShowcaseState extends State<BadgeShowcase>
      with SingleTickerProviderStateMixin {
    late AnimationController _controller;
    late Animation<double> _scaleAnimation;
    late Animation<Offset> _slideAnimation;

    @override
    void initState() {
      super.initState();
      _controller = AnimationController(
        duration: const Duration(milliseconds: 1200),
        vsync: this,
      );

      _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
        ),
      );

      _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
        ),
      );

      _controller.forward();
      Future.delayed(const Duration(seconds: 3), widget.onDismiss);
    }

    @override
    void dispose() {
      _controller.dispose();
      super.dispose();
    }

    @override
    Widget build(BuildContext context) {
      return GestureDetector(
        onTap: widget.onDismiss,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Container(
              color: Colors.black.withValues(alpha:0.85 * _controller.value),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Transform.scale(
                      scale: _scaleAnimation.value,
                      child: BadgeWidget(
                        type: widget.type,
                        tier: widget.tier,
                        size: BadgeSize.xl,
                        rarityPercent: widget.rarityPercent,
                      ),
                    ),
                    const SizedBox(height: 32),
                    SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _controller,
                        child: Column(
                          children: [
                            Text(
                              widget.title,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: widget.tier.gradientColors.first,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 40),
                              child: Text(
                                widget.description,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                            if (widget.rarityPercent != null) ...[
                              const SizedBox(height: 20),
                              Text(
                                'Earned by ${widget.rarityPercent!.toStringAsFixed(1)}% of users',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white54,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
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
      );
    }
  }

  // Helper function to show the badge showcase
  void showBadgeShowcase({
    required BuildContext context,
    required BadgeType type,
    required TrophyTier tier,
    required String title,
    required String description,
    double? rarityPercent,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (context) => BadgeShowcase(
        type: type,
        tier: tier,
        title: title,
        description: description,
        rarityPercent: rarityPercent,
        onDismiss: () => Navigator.of(context).pop(),
      ),
    );
  }