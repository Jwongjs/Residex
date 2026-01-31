import 'package:flutter/material.dart';
import 'landlord_command_screen.dart';
import 'landlord_finance_screen.dart';
import 'landlord_rex_ai_screen.dart';
import 'landlord_portfolio_screen.dart';
import 'landlord_community_screen.dart';
import '../widgets/navigation/custom_bottom_nav_bar.dart';

/// Landlord Home Screen with 5-tab bottom navigation
/// 
/// Navigation Tabs:
/// 1. Command - Dashboard overview and analytics
/// 2. Finance - Rental income and property expenses
/// 3. Rex AI - AI assistant (Lease Sentinel & DocuMind) [CENTER/PROTRUDING]
/// 4. Portfolio - Property management and listings
/// 5. Community - Tenant communication and announcements
class LandlordHomeScreen extends StatefulWidget {
  const LandlordHomeScreen({super.key});

  @override
  State<LandlordHomeScreen> createState() => _LandlordHomeScreenState();
}

class _LandlordHomeScreenState extends State<LandlordHomeScreen> {
  int _currentIndex = 0;

  // Landlord-specific screens
  final List<Widget> _screens = const [
    LandlordCommandScreen(),
    LandlordFinanceScreen(),
    LandlordRexAIScreen(),
    LandlordPortfolioScreen(),
    LandlordCommunityScreen(),
  ];

  // Navigation tab configuration
  final List<NavTab> _navTabs = [
    const NavTab(
      icon: Icons.dashboard_outlined,
      label: 'Command',
      color: Color(0xFF93C5FD), // blue.shade300
      glowColor: Color(0xFF3B82F6), // blue.shade500
    ),
    const NavTab(
      icon: Icons.trending_up,
      label: 'Finance',
      color: Color(0xFF67E8F9), // cyan.shade300
      glowColor: Color(0xFF06B6D4), // cyan.shade500
    ),
    const NavTab(
      icon: Icons.smart_toy_outlined,
      label: 'Rex AI',
      color: Color(0xFFA5B4FC), // indigo.shade300
      glowColor: Color(0xFF6366F1), // indigo.shade500
    ),
    const NavTab(
      icon: Icons.business,
      label: 'Portfolio',
      color: Color(0xFF93C5FD), // blue.shade300
      glowColor: Color(0xFF3B82F6), // blue.shade500
    ),
    const NavTab(
      icon: Icons.forum_outlined,
      label: 'Community',
      color: Color(0xFFC084FC), // purple.shade300
      glowColor: Color(0xFFA855F7), // purple.shade500
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        tabs: _navTabs,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}

