import 'package:flutter/material.dart';

// --- ANIMATION UTILITIES ---

/// Premium iOS-style page transition with slide and fade
class PremiumRoute extends PageRouteBuilder {
  final Widget page;

  PremiumRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Slide from right
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Cubic(0.32, 0.72, 0, 1); // Apple-style ease

            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var offsetAnimation = animation.drive(tween);

            // Subtle parallax fade for the exiting page
            var fadeTween = Tween(begin: 0.0, end: 1.0);
            var fadeAnimation = animation.drive(fadeTween);

            return SlideTransition(
              position: offsetAnimation,
              child: FadeTransition(opacity: fadeAnimation, child: child),
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
          reverseTransitionDuration: const Duration(milliseconds: 500),
        );
}

/// Bouncy micro-interaction button with scale effect - optimized
class BouncyButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const BouncyButton({
    super.key,
    required this.child,
    required this.onTap,
  });

  @override
  State<BouncyButton> createState() => _BouncyButtonState();
}

class _BouncyButtonState extends State<BouncyButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.95,
      upperBound: 1.0,
    );
    _controller.value = 1.0;

    _scale = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.reverse();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.forward();
    widget.onTap();
  }

  void _handleTapCancel() {
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: ScaleTransition(
          scale: _scale,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Staggered list entrance animation - optimized
class StaggeredList extends StatefulWidget {
  final List<Widget> children;

  const StaggeredList({super.key, required this.children});

  @override
  State<StaggeredList> createState() => _StaggeredListState();
}

class _StaggeredListState extends State<StaggeredList>
    with TickerProviderStateMixin {
  final List<AnimationController> _controllers = [];
  final List<Animation<Offset>> _slideAnimations = [];
  final List<Animation<double>> _fadeAnimations = [];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.children.length; i++) {
      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      );
      _controllers.add(controller);

      // Pre-create animations
      _slideAnimations.add(
        Tween<Offset>(
          begin: const Offset(0, 0.2),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: controller,
          curve: const Cubic(0.32, 0.72, 0, 1),
        )),
      );

      _fadeAnimations.add(
        Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: controller,
            curve: Curves.easeOut,
          ),
        ),
      );

      // Stagger delays
      Future.delayed(Duration(milliseconds: i * 50), () {
        if (mounted) controller.forward();
      });
    }
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(widget.children.length, (index) {
        return RepaintBoundary(
          child: FadeTransition(
            opacity: _fadeAnimations[index],
            child: SlideTransition(
              position: _slideAnimations[index],
              child: widget.children[index],
            ),
          ),
        );
      }),
    );
  }
}

 /// Gradient type enum for buttons
  enum GradientType {
    cyan,   // Cyan to Blue gradient (primary)
    purple, // Purple to Fuchsia gradient
  }

  /// Gradient button with bouncy effect - Reference: BalanceCard.tsx
  class GradientButton extends StatefulWidget {
    final String text;
    final IconData? icon;
    final VoidCallback onTap;
    final GradientType gradient;

    const GradientButton({
      super.key,
      required this.text,
      required this.onTap,
      required this.gradient,
      this.icon,
    });

    @override
    State<GradientButton> createState() => _GradientButtonState();
  }

  class _GradientButtonState extends State<GradientButton> {
    bool _isHovered = false;

    @override
  Widget build(BuildContext context) {
    // Define gradients based on type
    final LinearGradient buttonGradient = widget.gradient == GradientType.cyan
        ? const LinearGradient(
            colors: [
              Color(0xFF22D3EE), // cyan-400
              Color(0xFF3B82F6), // blue-500
              Color(0xFF2563EB), // blue-600
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          )
        : const LinearGradient(
            colors: [
              Color(0xFFA855F7), // purple-500
              Color(0xFF9333EA), // purple-600
              Color(0xFFD946EF), // fuchsia-500
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          );

    final Color shadowColor = widget.gradient == GradientType.cyan
        ? const Color(0xFF22D3EE) // cyan
        : const Color(0xFFA855F7); // purple

    return BouncyButton(
      onTap: widget.onTap,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          transform: Matrix4.identity()
            ..translate(0.0, _isHovered ? -4.0 : 0.0, 0.0), // Lift on hover
          height: 64, // Increased from 56 to 64 for better clickability
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: buttonGradient,
            boxShadow: [
                  
                     BoxShadow(
                color: shadowColor.withValues(alpha: 0.3),
                blurRadius: 15,
                spreadRadius: 0,
              )
            ],
            ),
            child: Stack(
    children: [
      // Hover overlay (all buttons)
      AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: _isHovered ? 1.0 : 0.0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      // Content
      Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null) ...[
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),

            child: Icon(
              widget.icon,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 8), // Increased from 8 to 10
        ],
            Text(
                      widget.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),

                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}

/// Ambient animated background with subtle glow effects
  class AmbientBackground extends StatelessWidget {
    const AmbientBackground({super.key});

    @override
    Widget build(BuildContext context) {
      return Positioned.fill(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0F0F23),  // Dark blue-black top
                Color(0xFF000000),  // Pure black bottom
              ],
            ),
          ),
          child: Stack(
            children: [
              // Top-right purple glow
              Positioned(
                top: -100,
                right: -100,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF8B5CF6).withOpacity(0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Bottom-left blue glow
              Positioned(
                bottom: -150,
                left: -150,
                child: Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF3B82F6).withOpacity(0.1),
                        Colors.transparent,
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
