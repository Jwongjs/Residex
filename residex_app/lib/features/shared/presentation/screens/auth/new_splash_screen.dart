 import 'dart:math' as math;                                                                                                                                                                                                                                                  import 'package:flutter/material.dart';                                                                                                                                                                                                                                      import 'package:go_router/go_router.dart';                                                                                                                                                                                                                                 
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:google_fonts/google_fonts.dart';
  import '../../../../../core/widgets/residex_logo.dart';
  import '../../../../../core/theme/app_colors.dart';
  import '../../../domain/entities/users/app_user.dart';

  class NewSplashScreen extends ConsumerStatefulWidget {
    const NewSplashScreen({super.key});

    @override
    ConsumerState<NewSplashScreen> createState() => _NewSplashScreenState();
  }

  class _NewSplashScreenState extends ConsumerState<NewSplashScreen>
      with TickerProviderStateMixin {

    late final AnimationController _master;
    late final AnimationController _pulse;

    late final Animation<double> _diamondScale;
    late final Animation<double> _diamondAngle;
    late final Animation<double> _archProgress;
    late final Animation<double> _textOpacity;
    late final Animation<double> _textSlide;
    late final Animation<double> _exitScale;
    late final Animation<double> _exitOpacity;
    late final Animation<double> _pulseScale;

    @override
    void initState() {
      super.initState();

      _master = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 4500),
      );

      const springCurve = Cubic(0.34, 1.56, 0.64, 1.0);

      _diamondScale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _master,
            curve: const Interval(0.0, 0.222, curve: springCurve)));

      _diamondAngle = Tween<double>(begin: -math.pi / 4, end: 0.0).animate(
        CurvedAnimation(parent: _master,
            curve: const Interval(0.0, 0.222, curve: springCurve)));

      _archProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _master,
            curve: const Interval(0.111, 0.444, curve: Curves.easeOut)));

      _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _master,
            curve: const Interval(0.333, 0.555, curve: Curves.easeOut)));

      _textSlide = Tween<double>(begin: 10.0, end: 0.0).animate(
        CurvedAnimation(parent: _master,
            curve: const Interval(0.333, 0.555, curve: Curves.easeOut)));

      _exitScale = Tween<double>(begin: 1.0, end: 1.1).animate(
        CurvedAnimation(parent: _master,
            curve: const Interval(0.778, 1.0, curve: Curves.easeIn)));

      _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _master,
            curve: const Interval(0.778, 1.0, curve: Curves.easeIn)));

      _pulse = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 3),
      );
      _pulseScale = Tween<double>(begin: 1.0, end: 1.1).animate(
        CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

      _master.forward();
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) _pulse.repeat(reverse: true);
      });
      Future.delayed(const Duration(milliseconds: 4500), () {
        if (mounted) context.go('/login');
      });
    }

    @override
    void dispose() {
      _master.dispose();
      _pulse.dispose();
      super.dispose();
    }

    @override
    Widget build(BuildContext context) {
      final sw = MediaQuery.of(context).size.width;
      return Scaffold(
        backgroundColor: AppColors.deepSpace,
        body: AnimatedBuilder(
          animation: Listenable.merge([_master, _pulse]),
          builder: (context, _) {
            return Stack(
              children: [
                // Purple glow — top-left
                Positioned(
                  top: -(sw * 0.2), left: -(sw * 0.2),
                  child: Opacity(
                    opacity: _exitOpacity.value,
                    child: Container(
                      width: sw * 0.8, height: sw * 0.8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(
                          color: const Color(0xFF9333EA).withValues(alpha: 0.10),
                          blurRadius: 100, spreadRadius: 60,
                        )],
                      ),
                    ),
                  ),
                ),
                // Indigo glow — bottom-right
                Positioned(
                  bottom: -(sw * 0.2), right: -(sw * 0.2),
                  child: Opacity(
                    opacity: _exitOpacity.value,
                    child: Container(
                      width: sw * 0.8, height: sw * 0.8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.10),
                          blurRadius: 100, spreadRadius: 60,
                        )],
                      ),
                    ),
                  ),
                ),

                // Main content
                Center(
                  child: Transform.scale(
                    scale: _exitScale.value,
                    child: Opacity(
                      opacity: _exitOpacity.value,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo + centre glow
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 160, height: 160,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(
                                    color: AppColors.indigo500.withValues(
                                        alpha: 0.20 * _pulseScale.value),
                                    blurRadius: 50, spreadRadius: 20,
                                  )],
                                ),
                              ),
                              Transform.scale(
                                scale: _pulseScale.value,
                                child: ResidexLogo(
                                  size: 200,
                                  animate: false,
                                  syncState: SyncState.synced,
                                  archProgress: _archProgress.value,
                                  diamondScale: _diamondScale.value,
                                  diamondAngle: _diamondAngle.value,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 32),

                          // Brand text
                          Opacity(
                            opacity: _textOpacity.value,
                            child: Transform.translate(
                              offset: Offset(0, _textSlide.value),
                              child: Column(
                                children: [
                                  Text(
                                    'RESIDEX',
                                    style: GoogleFonts.inter(
                                      fontSize: 40,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: -2.0,
                                      shadows: [Shadow(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        blurRadius: 24,
                                      )],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'ECOSYSTEM FOR LIVING',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.slate400,
                                      letterSpacing: 4.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }
  }