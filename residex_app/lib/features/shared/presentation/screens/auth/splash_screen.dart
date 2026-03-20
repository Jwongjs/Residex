import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/widgets/residex_loader.dart';
import '../../../../../core/theme/app_theme.dart';

class SplashScreen extends ConsumerStatefulWidget {
    const SplashScreen({super.key});

    @override
    ConsumerState<SplashScreen> createState() => _SplashScreenState();
  }

  class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Wait for first frame to be rendered
    await WidgetsBinding.instance.endOfFrame;

    // Preload and initialize resources
    final initFuture = _preloadResources();

    // Minimum splash screen display time (for branding)
    final minDisplayTime = Future.delayed(const Duration(milliseconds: 2500));

    // Wait for both initialization and minimum display time
    await Future.wait([
      initFuture,
      minDisplayTime,
    ]);

    // Add buffer time for smooth transition
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      setState(() => _isInitialized = true);

      // Navigate to login
      context.go('/login');
    }
  }

  Future<void> _preloadResources() async {
    // Preload critical assets and prepare animations
    final futures = <Future>[];

    // Precache images (if any critical ones exist)
    if (mounted) {
      // Example: Preload background gradients or important images
      // futures.add(precacheImage(AssetImage('assets/images/logo.png'), context));
    }

    // Wait for all preloading to complete
    await Future.wait(futures);

    // Allow animations to initialize (one full animation cycle of ResidexLoader is 2500ms)
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const ResidexLoader(
              size: 150.0,
            ),
            const SizedBox(height: 40),
            AnimatedOpacity(
              opacity: _isInitialized ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: const Text(
                'Loading...',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
