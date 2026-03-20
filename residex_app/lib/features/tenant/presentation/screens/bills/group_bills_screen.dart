import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../providers/bills/bills_provider.dart';
import '../../../../landlord/domain/entities/property.dart';
import '../../widgets/bills/branching_tree.dart';
import '../../../domain/entities/bills/breakdown_item.dart';
import '../../../domain/entities/bills/bill_enums.dart';
import '../../../../shared/domain/entities/groups/app_group.dart';

  enum BillStatusFilter { all, pending, settled }

  class GroupBillsScreen extends ConsumerStatefulWidget {
    final AppGroup group;

    const GroupBillsScreen({super.key, required this.group});

    @override
    ConsumerState<GroupBillsScreen> createState() => _GroupBillsScreenState();
  }

  class _GroupBillsScreenState extends ConsumerState<GroupBillsScreen> {
    BillStatusFilter _activeFilter = BillStatusFilter.all;

    @override
    Widget build(BuildContext context) {
      // Set the selected group filter
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(selectedGroupFilterProvider.notifier).state = widget.group;
      });

      final billsAsync = ref.watch(groupFilteredBillsProvider);

      return Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            // Ambient background
            const AmbientBackground(),

            SafeArea(
              child: Column(
                children: [
                  // Header with back button
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            // Clear the group filter when leaving
                            ref.read(selectedGroupFilterProvider.notifier).state = null;
                            context.pop();
                          },
                          child: GlassCard(
                            borderRadius: BorderRadius.circular( 12),
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.arrow_back,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Back',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Group icon and name
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Color(widget.group.colorValue),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              widget.group.emoji,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.group.name,
                            style: AppTextStyles.headlineMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0),

                  // Status Filter Tabs
                  _buildStatusFilterTabs(),

                  const SizedBox(height: 8),

                  // Branching Tree
                  Expanded(
                    child: billsAsync.when(
                      data: (groupBills) {
                        if (groupBills.isEmpty) {
                          return _buildEmptyState();
                        }

                        // Build breakdown items for this group
                        var breakdownItems = groupBills.map((bill) {
                          return BreakdownItem(
                            bill: bill,
                            amount: bill.totalAmount,
                            direction: 'GROUP',
                            groupId: widget.group.id,
                            isPending: bill.status == BillStatus.pending,
                          );
                        }).toList();

                        // Apply filter
                        if (_activeFilter == BillStatusFilter.pending) {
                          breakdownItems = breakdownItems
                              .where((item) => item.isPending)
                              .toList();
                        } else if (_activeFilter == BillStatusFilter.settled) {
                          breakdownItems = breakdownItems
                              .where((item) => !item.isPending)
                              .toList();
                        }

                        if (breakdownItems.isEmpty) {
                          return _buildEmptyFilterState();
                        }

                        final totalAmount = breakdownItems.fold(
                          0.0,
                          (sum, item) => sum + item.amount,
                        );

                        return SingleChildScrollView(
                          child: BranchingTree(
                            entityId: widget.group.id,
                            entityName: widget.group.name,
                            entityEmoji: widget.group.emoji,
                            entityColor: widget.group.colorValue,
                            items: breakdownItems,
                            totalAmount: totalAmount,
                            direction: 'GROUP',
                            isGroup: true,
                            entityUser: null,
                          ),
                        );
                      },
                      loading: () => const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryCyan,
                        ),
                      ),
                      error: (error, stack) => _buildEmptyState(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget _buildStatusFilterTabs() {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            _buildFilterTab('All', BillStatusFilter.all, Icons.home),
            const SizedBox(width: 8),
            _buildFilterTab('Pending', BillStatusFilter.pending, Icons.access_time),
            const SizedBox(width: 8),
            _buildFilterTab('Settled', BillStatusFilter.settled, Icons.check_circle),
          ],
        ),
      ).animate().fadeIn(duration: 500.ms, delay: 100.ms);
    }

    Widget _buildFilterTab(String label, BillStatusFilter filter, IconData icon) {
      final isActive = _activeFilter == filter;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _activeFilter = filter),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primaryCyan.withValues(alpha: 0.2)
                  : AppColors.slate800.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive
                    ? AppColors.primaryCyan.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isActive ? AppColors.primaryCyan : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive ? AppColors.primaryCyan : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget _buildEmptyState() {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long,
                size: 64, color: AppColors.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('No bills for this group yet',
                style: AppTextStyles.titleMedium
                    .copyWith(color: AppColors.textMuted)),
            const SizedBox(height: 8),
            Text('Create bills with group members to see them here',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    Widget _buildEmptyFilterState() {
      String filterName;
      if (_activeFilter == BillStatusFilter.pending) {
        filterName = 'pending';
      } else if (_activeFilter == BillStatusFilter.settled) {
        filterName = 'settled';
      } else {
        filterName = 'bills';
      }

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_alt_off,
                size: 64, color: AppColors.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('No $filterName bills',
                style: AppTextStyles.titleMedium
                    .copyWith(color: AppColors.textMuted)),
            const SizedBox(height: 8),
            Text('Try changing the filter to see other bills',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
      );
    }
  }

  class AmbientBackground extends StatelessWidget {
    const AmbientBackground({super.key});

    @override
    Widget build(BuildContext context) {
      return Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryCyan.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFA855F7).withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }
  }
