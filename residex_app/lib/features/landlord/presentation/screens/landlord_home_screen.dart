import 'package:flutter/material.dart';
import '1-Dashboard/landlord_dashboard_screen.dart';
import '2-Documind/documind_screen.dart';
import '3-Finance/finance_screen.dart';
import '4-Portfolio/landlord_portfolio_screen.dart';
import '5-Documents/documents_screen.dart';
import '../widgets/navigation/custom_bottom_nav_bar.dart';
import '../../../../core/theme/app_colors.dart';

/// Landlord Home Screen with 5-tab bottom navigation.
///
/// Navigation Tabs:
/// 1. Dashboard - overview, recent Documind activity
/// 2. Documind - AI document Q&A (flagship feature, chat-only since Stage E)
/// 3. Finance - the deterministic finance engine's figures per year
/// 4. Portfolio - property management
/// 5. Documents - the property document store (split out of Documind in Stage E)
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
      color: AppColors.registry,
    ),
    NavTab(
      icon: Icons.auto_awesome_outlined,
      label: 'Documind',
      color: AppColors.registry,
    ),
    NavTab(
      icon: Icons.payments_outlined,
      label: 'Finance',
      color: AppColors.registry,
    ),
    NavTab(
      icon: Icons.business_outlined,
      label: 'Portfolio',
      color: AppColors.registry,
    ),
    NavTab(
      icon: Icons.folder_outlined,
      label: 'Documents',
      color: AppColors.registry,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _screens = [
      LandlordDashboardScreen(
        onOpenDocumind: () => setState(() => _currentIndex = 1),
        onOpenPortfolio: () => setState(() => _currentIndex = 3),
      ),
      const DocuMindScreen(),
      const FinanceScreen(),
      const LandlordPortfolioScreen(),
      DocumentsScreen(
        onOpenDocumind: () => setState(() => _currentIndex = 1),
      ),
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
