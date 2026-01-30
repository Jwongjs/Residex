import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'features/landlord/presentation/screens/landlord_home_screen.dart';
import 'core/router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ResidexApp());
}

class ResidexApp extends StatelessWidget {
  const ResidexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Residex',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const LandlordHomeScreen(),
      initialRoute: AppRouter.landlordHome,
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}