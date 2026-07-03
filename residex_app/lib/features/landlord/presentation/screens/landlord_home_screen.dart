import 'package:flutter/material.dart';
import '1-Dashboard/landlord_dashboard_screen.dart';
import '2-Documind/documind_screen.dart';
import '4-Portfolio/landlord_portfolio_screen.dart';
import '../widgets/navigation/custom_bottom_nav_bar.dart';
import '../../../../core/theme/app_colors.dart';

/// Landlord Home Screen with 3-tab bottom navigation.
///
/// Navigation Tabs:
/// 1. Dashboard - overview, recent Documind activity
/// 2. Documind - AI document Q&A (flagship feature)
/// 3. Portfolio - property management
class LandlordHomeScreen extends StatefulWidget {
  const LandlordHomeScreen({super.key});

  @override
  State<LandlordHomeScreen> createState() => _LandlordHomeScreenState();
}

class _LandlordHomeScreenState extends State<LandlordHomeScreen> {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  final List<NavTab> _navTabs = const [
    NavTab(
      icon: Icons.dashboard_outlined,
      label: 'Dashboard',
      color: AppColors.brass,
      glowColor: AppColors.brass,
    ),
    NavTab(
      icon: Icons.auto_awesome_outlined,
      label: 'Documind',
      color: AppColors.brass,
      glowColor: AppColors.brass,
    ),
    NavTab(
      icon: Icons.business_outlined,
      label: 'Portfolio',
      color: AppColors.brass,
      glowColor: AppColors.brass,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _screens = [
      LandlordDashboardScreen(
        onOpenDocumind: () => setState(() => _currentIndex = 1),
        onOpenPortfolio: () => setState(() => _currentIndex = 2),
      ),
      const DocuMindScreen(),
      const LandlordPortfolioScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        tabs: _navTabs,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
