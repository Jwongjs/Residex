import 'package:flutter/material.dart';
import 'dart:ui';

/// Navigation tab configuration model
class NavTab {
  final IconData icon;
  final String label;
  final Color color;
  final Color glowColor;

  const NavTab({
    required this.icon,
    required this.label,
    required this.color,
    required this.glowColor,
  });
}

/// Reusable custom bottom navigation bar with protruding center button
///
/// Features:
/// - Glass morphism effect on center button
/// - Fading gradient at top
/// - Glow effects for active tabs
/// - Animated transitions
/// - Supports any odd number of navigation tabs, with the middle tab elevated
class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<NavTab> tabs;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.tabs,
  }) : assert(tabs.length > 0, 'CustomBottomNavBar requires at least 1 tab');

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Fading gradient at top of nav bar
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  const Color(0xFF020617).withOpacity(0.5),
                  const Color(0xFF020617).withOpacity(0.9),
                ],
                stops: const [0.0, 0.3, 1.0],
              ),
            ),
          ),
        ),
        // Main navigation bar
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF020617).withOpacity(0.9),
            border: Border(
              top: BorderSide(
                color: Colors.white.withOpacity(0.05),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 40,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: SafeArea(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Regular navigation items
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(tabs.length, (index) {
                      final tab = tabs[index];
                      final isActive = currentIndex == index;
                      final centerIndex = tabs.length ~/ 2;
                      final isCenter = index == centerIndex;

                      // Skip rendering the center tab here, it's rendered separately
                      if (isCenter) {
                        return const Expanded(child: SizedBox());
                      }

                      return Expanded(
                        child: GestureDetector(
                          onTap: () => onTap(index),
                          behavior: HitTestBehavior.opaque,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Glow effect for active tab
                                  if (isActive)
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: tab.glowColor.withOpacity(0.6),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: tab.glowColor.withOpacity(0.6),
                                            blurRadius: 12,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                    ),
                                  // Icon
                                  AnimatedScale(
                                    scale: isActive ? 1.1 : 1.0,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOut,
                                    child: Icon(
                                      tab.icon,
                                      size: 24,
                                      color:
                                          isActive ? tab.color : Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              // Label (only visible when active)
                              AnimatedOpacity(
                                opacity: isActive ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 300),
                                child: Text(
                                  tab.label,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: tab.color,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                // Protruding center button with glass effect
                Positioned(
                  left: 0,
                  right: 0,
                  top: -28,
                  child: Center(
                    child: GestureDetector(
                      onTap: () => onTap(tabs.length ~/ 2),
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.indigo.shade400.withOpacity(0.8),
                              Colors.indigo.shade600.withOpacity(0.9),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.indigo.shade500.withOpacity(0.8),
                              blurRadius: 20,
                              spreadRadius: 4,
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withOpacity(0.15),
                                    Colors.white.withOpacity(0.05),
                                  ],
                                ),
                              ),
                              child: Icon(
                                tabs[tabs.length ~/ 2].icon,
                                size: 32,
                                color: currentIndex == tabs.length ~/ 2
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
