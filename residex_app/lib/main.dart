import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/di/injection.dart';
import 'data/database/app_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';

  void main() async {
    WidgetsFlutterBinding.ensureInitialized();

     try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('✅ Firebase initialized successfully');

      if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android ||
                      defaultTargetPlatform == TargetPlatform.iOS)) {
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.debug,
          appleProvider: AppleProvider.debug,
        );
        debugPrint('✅ App Check initialized (Mobile)');
      } else if (kIsWeb) {
        await FirebaseAppCheck.instance.activate(
          webProvider: ReCaptchaV3Provider('your-recaptcha-site-key'),
        );
        debugPrint('✅ App Check initialized (Web)');
      } else {
        debugPrint('⚠️ App Check skipped (Desktop platform)');
      }
    } catch (e) {
      debugPrint('❌ Firebase initialization error: $e');
    }

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      if (kReleaseMode) {
        debugPrint('Flutter Error: ${details.exception}');
      }
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      if (kReleaseMode) {
        debugPrint('Platform Error: $error');
      }
      return true;
    };

    // Initialize database
    final database = AppDatabase();

    // Demo data seeding disabled after tenant feature removal

    runApp(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
        ],
        child: const ResidexApp(),
      ),
    );
  }

  class ResidexApp extends ConsumerWidget {
    const ResidexApp({super.key});

    @override
    Widget build(BuildContext context, WidgetRef ref) {
      final router = ref.watch(appRouterProvider);
      return MaterialApp.router(
        title: 'Residex',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: router,
      );
    }
  }

