import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../widgets/common/stat_card.dart';
import '../../widgets/common/progress_bar.dart';
import '../../providers/landlord_command_provider.dart';
import '../../../../shared/presentation/providers/auth_providers.dart';
import 'sub/landlord_system_health_screen.dart';
import 'sub/landlord_maintenance_screen.dart';

/// Landlord Command Center - Dashboard overview
/// 
/// Displays:
/// - System health metrics
/// - Maintenance console
/// - Quick action modules
/// - Occupancy status
class LandlordCommandScreen extends ConsumerWidget {
  const LandlordCommandScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(landlordCommandProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Ambient background gradient
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 600,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.5,
                  colors: [
                    const Color(0xFF1E40AF).withOpacity(0.5),
                    AppColors.background,
                    AppColors.background,
                  ],
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: CustomScrollView(
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: _buildHeader(context, ref),
                ),

                // Content
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Section title
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'COMMAND MODULES',
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.textDisabled,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Feature Grid
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.95,
                        children: [
                          StatCard(
                            title: 'System Health',
                            value: '${stats.systemHealthScore}/100',
                            badge: 'Optimal',
                            badgeIcon: Icons.speed,
                            gradientColor: AppColors.primary,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LandlordSystemHealthScreen(
                                    healthScore: stats.systemHealthScore,
                                  ),
                                ),
                              );
                            },
                          ),
                          StatCard(
                            title: 'Maintenance',
                            value: '${stats.activeMaintenance} Active',
                            badge: 'Action Req',
                            badgeIcon: Icons.handyman_outlined,
                            gradientColor: AppColors.info,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LandlordMaintenanceScreen(),
                                ),
                              );
                            },
                          ),
                          StatCard(
                            title: 'FairFix Auditor',
                            value: 'Scan Ready',
                            badge: 'AI Assessment',
                            badgeIcon: Icons.find_in_page_outlined,
                            gradientColor: AppColors.accent,
                            onTap: () {
                              // TODO: Navigate to FairFix Auditor
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('FairFix Auditor - Coming Soon'),
                                ),
                              );
                            },
                          ),
                          StatCard(
                            title: 'Ghost Overlay',
                            value: 'Compare',
                            badge: 'Before/After',
                            badgeIcon: Icons.compare_outlined,
                            gradientColor: const Color(0xFFA855F7),
                            onTap: () {
                              // TODO: Navigate to Ghost Overlay
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Ghost Overlay - Coming Soon'),
                                ),
                              );
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Occupancy Bar
                      ProgressBar(
                        label: 'Occupancy',
                        value: stats.occupiedUnits,
                        maxValue: stats.totalUnits,
                        unit: 'Units',
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title with icon
          Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E3A8A).withOpacity(0.2),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.dashboard_outlined,
                  color: AppColors.primaryLight,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Asset Command',
                    style: AppTextStyles.heading2.copyWith(
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'PORTFOLIO OVERVIEW',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.primaryLight.withOpacity(0.8),
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),

          // User profile section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'LO',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Landlord Owner',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'PROPERTY OWNER',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
                child: Icon(
                  Icons.notifications_outlined,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: Text(
                        'Sign Out',
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                      content: Text(
                        'Are you sure you want to sign out?',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text('Cancel',
                              style: TextStyle(color: AppColors.textSecondary)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Sign Out',
                              style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    await ref.read(authControllerProvider).signOut();
                    if (context.mounted) context.go('/login');
                  }
                },
                child: Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.red.withOpacity(0.2),
                    ),
                  ),
                  child: const Icon(
                    Icons.logout,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}