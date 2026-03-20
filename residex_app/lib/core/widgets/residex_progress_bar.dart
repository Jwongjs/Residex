import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ResidexProgressBar extends StatefulWidget {
  final double progress; // 0.0 to 1.0
  final Gradient gradient;
  final double height;
  final bool showPercentage;
  final bool animated;

  const ResidexProgressBar({
    super.key,
    required this.progress,
    required this.gradient,
    this.height = 8,
    this.showPercentage = false,
    this.animated = true,
  });

  @override
  State<ResidexProgressBar> createState() => _ResidexProgressBarState();
}

class _ResidexProgressBarState extends State<ResidexProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = Tween<double>(begin: 0.0, end: widget.progress).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    if (widget.animated) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(ResidexProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.progress,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Stack(
            children: [
              // Background track
              Container(
                height: widget.height,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(widget.height / 2),
                ),
              ),

              // Progress fill
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Container(
                    height: widget.height,
                    width: MediaQuery.of(context).size.width * _animation.value,
                    decoration: BoxDecoration(
                      gradient: widget.gradient,
                      borderRadius: BorderRadius.circular(widget.height / 2),
                      boxShadow: [
                        BoxShadow(
                          color: widget.gradient.colors.first
                              .withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        if (widget.showPercentage) ...[
          const SizedBox(width: 12),
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Text(
                '${(_animation.value * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}