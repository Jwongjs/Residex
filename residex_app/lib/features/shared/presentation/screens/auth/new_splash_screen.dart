import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/router/app_router.dart';
import '../../../../../core/widgets/residex_logo.dart';

class NewSplashScreen extends ConsumerStatefulWidget {
  const NewSplashScreen({super.key});

  @override
  ConsumerState<NewSplashScreen> createState() => _NewSplashScreenState();
}

class _NewSplashScreenState extends ConsumerState<NewSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _master;

  late final Animation<double> _textOpacity;
  late final Animation<double> _textSlide;
  late final Animation<double> _exitScale;
  late final Animation<double> _exitOpacity;

  @override
  void initState() {
    super.initState();

    _master = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _master,
          curve: const Interval(0.111, 0.333, curve: Curves.easeOut)));

    _textSlide = Tween<double>(begin: 10.0, end: 0.0).animate(
      CurvedAnimation(parent: _master,
          curve: const Interval(0.111, 0.333, curve: Curves.easeOut)));

    _exitScale = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _master,
          curve: const Interval(0.778, 1.0, curve: Curves.easeIn)));

    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _master,
          curve: const Interval(0.778, 1.0, curve: Curves.easeIn)));

    _master.forward();
    Future.delayed(const Duration(milliseconds: 4500), () {
      if (mounted) context.go(AppRoutes.login);
    });
  }

  @override
  void dispose() {
    _master.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: AnimatedBuilder(
        animation: _master,
        builder: (context, _) {
          return Center(
            child: Transform.scale(
              scale: _exitScale.value,
              child: Opacity(
                opacity: _exitOpacity.value,
                child: Opacity(
                  opacity: _textOpacity.value,
                  child: Transform.translate(
                    offset: Offset(0, _textSlide.value),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const ResidexLogo(size: 96, animate: true),
                        const SizedBox(height: 24),
                        Text(
                          'ResiDex',
                          style: AppTextStyles.displayLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Your properties' paperwork, answered.",
                          style: AppTextStyles.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
