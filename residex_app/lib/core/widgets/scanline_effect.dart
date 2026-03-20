import 'package:flutter/material.dart';
class ScanlineEffect extends StatefulWidget {
  const ScanlineEffect({super.key});
  @override
  State<ScanlineEffect> createState() => _ScanlineEffectState();
}

class _ScanlineEffectState extends State<ScanlineEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, MediaQuery.of(context).size.height *
            (_controller.value * 2 - 1)), // -100% to +100%
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha:0),
                  Colors.white.withValues(alpha:0.03),
                  Colors.white.withValues(alpha:0),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}