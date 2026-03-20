import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/di/injection.dart';
import 'data/database/app_database.dart';
import 'features/shared/data/repositories/users/user_repository_impl.dart';
import 'features/shared/data/repositories/groups/group_repository_impl.dart';
import 'features/tenant/data/repositories/bills/bill_repository_impl.dart';
import 'features/shared/data/repositories/users/user_local_datasource.dart';
import 'features/shared/data/datasources/groups/group_local_datasource.dart';
import 'features/tenant/data/datasources/bills/bill_local_datasource.dart';
import 'features/tenant/data/datasources/bills/mock_bills_data.dart';
import 'features/shared/domain/entities/users/app_user.dart';
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

    // Seed demo data on first launch
    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool('is_first_launch') ?? true;

    if (isFirstLaunch) {
      debugPrint('First launch detected - seeding demo data...');

      final seeder = DemoDataSeeder(
        userRepository: UserRepositoryImpl(
          localDataSource: UserLocalDataSource(database),
        ),
        groupRepository: GroupRepositoryImpl(
          localDataSource: GroupLocalDataSource(database),
        ),
        billRepository: BillRepositoryImpl(
          localDataSource: BillLocalDataSource(database),
        ),
      );

      await seeder.seedAll();
      await prefs.setBool('is_first_launch', false);
      debugPrint('Demo data seeded successfully!');
    }

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
        theme: AppTheme.darkTheme,
        routerConfig: router,
      );
    }
  }

  class DemoDataSeeder {
    final UserRepositoryImpl userRepository;
    final GroupRepositoryImpl groupRepository;
    final BillRepositoryImpl billRepository;

    DemoDataSeeder({
      required this.userRepository,
      required this.groupRepository,
      required this.billRepository,
    });

    Future<void> seedAll() async {
      try {
        // 1. Seed Users
        await _seedUsers();

        // 2. Seed Bills from MockBillsData
        await _seedBills();

        debugPrint('✅ All demo data seeded successfully');
      } catch (e, stack) {
        debugPrint('❌ Error seeding demo data: $e');
        debugPrint('Stack trace: $stack');
      }
    }

    Future<void> _seedUsers() async {
      final users = [
        AppUser(
          id: MockBillsData.currentUserId,
          name: 'You',
          email: 'you@residex.com',
          avatarInitials: 'Y',
          role: UserRole.tenant,
          fiscalScore: 850,
        
        ),
        AppUser(
          id: MockBillsData.roommateId1,
          name: 'Sarah Lee',
          email: 'sarah@residex.com',
          avatarInitials: 'S',
          role: UserRole.tenant,
          fiscalScore: 720,
          
        ),
        AppUser(
          id: MockBillsData.roommateId2,
          name: 'Ahmad Rahman',
          email: 'ahmad@residex.com',
          avatarInitials: 'A',
          role: UserRole.tenant,
          fiscalScore: 680,
          
        ),
      ];

      for (final user in users) {
        final result = await userRepository.addUser(user);
        result.fold(
          (failure) => debugPrint('Failed to create user ${user.name}: $failure'),
          (success) => debugPrint('✅ Created user: ${user.name}'),
        );
      }
    }

    Future<void> _seedBills() async {
      final mockBills = MockBillsData.getMockBills();

      for (final bill in mockBills) {
        final result = await billRepository.saveBill(bill);
        result.fold(
          (failure) => debugPrint('Failed to create bill ${bill.title}: $failure'),
          (createdBill) => debugPrint('✅ Created bill: ${bill.title}'),
        );
      }
    }
  }