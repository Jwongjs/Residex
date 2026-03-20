import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/router/app_router.dart';
import '../../../../../core/widgets/residex_bottom_nav.dart';
import '../../../../shared/domain/entities/users/app_user.dart';
import '../../widgets/home/header.dart';
import '../../widgets/home/balance_card.dart';
import '../../widgets/home/toolkit_grid.dart';
import '../../widgets/home/summary_cards.dart';
import '../../widgets/home/friends_list.dart';
import '../../widgets/chores/calendar_widget.dart';
import '../../widgets/home/property_pulse_widget.dart';
import '../../widgets/tools/report_widget.dart';

  class TenantDashboardScreen extends ConsumerWidget {
      const TenantDashboardScreen({super.key});

      static const _mockUser = AppUser(
        id: 'user1',
        name: 'Ali Rahman',
        avatarInitials: 'AR',
        fiscalScore: 820,
        syncState: SyncState.synced,
        role: UserRole.tenant,
      );

      static const _mockHousemates = [
        AppUser(id: 'u2', name: 'Sarah Tan',  avatarInitials: 'ST'),
        AppUser(id: 'u3', name: 'Raj Kumar',  avatarInitials: 'RK'),
        AppUser(id: 'u4', name: 'David Wong', avatarInitials: 'DW'),
      ];

    @override
    Widget build(BuildContext context, WidgetRef ref) {
      return Scaffold(
        backgroundColor: AppColors.deepSpace,
        body: Stack(
          children: [
            // Radial gradient background matching React
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
                      AppColors.indigo500.withValues(alpha: 0.5),
                      AppColors.deepSpace,
                      AppColors.deepSpace,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),

            // Main Content
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(
                        left: 12,
                        right: 12,
                        top: 16,
                        bottom: 120, // Extra padding for bottom nav
                      ),
                      children: [
                        // ========================================
                        // LIQUID GLASS CONTAINER - TOP 6 CARDS
                        // Apple-style frosted glass with dark tint
                        // ========================================
                         Column(
                                  children: [
                                    // 1. Header
                                    Header(
                                      currentUser: _mockUser,
                                      onNotificationTap: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Notifications')),
                                        );
                                      },
                                      onHealthTap: () {
                                        context.push('/property-pulse');
                                      },
                                    ),

                                    const SizedBox(height: 16), // Reduced from 24

                                    // 2. Balance Card (each gauge routes independently)
                                    BalanceCards(
                                      fiscalScore: _mockUser.fiscalScore,
                                      harmonyScore: 750, // TODO: Get from currentUser when available
                                      onFiscalTap: () {
                                        context.push('/credit-bridge');
                                      },
                                      onHarmonyTap: () {
                                        context.push('/harmony-hub');
                                      },
                                    ),

                                    const SizedBox(height: 16), // Reduced from 24

                                    // 3. Toolkit Grid (Rental ID + Ghost Mode)
                                    ToolkitGrid(
                                      onRentalResumeClick: () {
                                        context.push('/rental-resume', extra: _mockUser);
                                      },
                                      onGhostModeClick: () {
                                        context.push('/ghost-mode');
                                      },
                                    ),

                                    const SizedBox(height: 16), // Reduced from 24

                                    // 4. Summary Cards (You Owe + Pending Tasks)
                                    // height: 112px (matching Rental ID + Ghost Mode cards)
                                    SizedBox(
                                      height: 112,
                                      child: SummaryCards(
                                        youOweCount: 2,
                                        pendingTasksCount: 3,
                                        onYouOweTap: () {
                                          context.push('/you-owe');
                                        },
                                        onPendingTasksTap: () {
                                          context.push('/chore-scheduler');
                                        },
                                      ),
                                    ),
                                  ],
                                ),


                        const SizedBox(height: 24),

                        // ========================================
                        // REMAINING WIDGETS (OUTSIDE BLACK BOX)
                        // ========================================

                        // 5. Friends List
                        FriendsList(
                          friends: _mockHousemates,
                          onFriendTap: (friend) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Tapped ${friend.name}')),
                            );
                          },
                        ),

                        const SizedBox(height: 16),

                        // 6. Calendar Widget
                        CalendarWidget(
                          onOpenDetail: () {
                            context.push('/chore-scheduler');
                          },
                        ),

                        const SizedBox(height: 16),

                        // 7. Property Pulse Widget
                          PropertyPulseWidget(
                            onOpenDetail: () {
                              context.push('/property-pulse');
                            },
                          ),


                        const SizedBox(height: 16),

                        // 8. Report Widget
                        ReportWidget(
                          onOpenDetail: () {
                            context.push('/maintenance');
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

      );
    }
  }
