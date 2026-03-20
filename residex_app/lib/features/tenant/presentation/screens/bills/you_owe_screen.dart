import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/router/app_router.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../widgets/bills/breakdown_filter_tabs.dart';
import '../../widgets/bills/entity_selection_grid.dart';
import '../../widgets/bills/branching_tree.dart';
import '../../providers/bills/bills_provider.dart';
import '../../providers/bills/balance_provider.dart';
import '../../../../shared/presentation/providers/users_provider.dart';
import '../../../domain/entities/bills/breakdown_item.dart';
import '../../widgets/bills/net_amount_card.dart';
import '../../../domain/entities/bills/bill.dart';
import '../../../../shared/domain/entities/users/app_user.dart';
import '../../../domain/entities/bills/bill_enums.dart';
import '../../../../../core/di/injection.dart';
import '../../../../../core/widgets/animations.dart';
import '../../../../shared/presentation/providers/groups_provider.dart';
import '../../../../shared/domain/entities/groups/app_group.dart';



class YouOweScreen extends ConsumerStatefulWidget {
  const YouOweScreen({super.key});

  @override
  ConsumerState<YouOweScreen> createState() => _YouOweScreenState();
}

class _YouOweScreenState extends ConsumerState<YouOweScreen> {
  BreakdownFilter _activeFilter = BreakdownFilter.all;
  BreakdownGroup? _selectedEntity;            // 7.1 - Show tree view when entity selected
  bool _selectionMode = false;         // 7.2 - Batch selection mode
  Set<String> _selectedItems = {};     // 7.2 - Selected payment IDs
  bool _simplifyDebts = false;        // 7.3 - Simplified debts toggle
  final Set<String> _paidItems = {}; // Track paid items (hidden until DB updates)

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final billsAsync = ref.watch(youOweBillsProvider);
    final balanceAsync = ref.watch(balanceProvider);
    final usersAsync = ref.watch(usersProvider);
    final groupsAsync = ref.watch(groupsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const AmbientBackground(),
          Column(
            children: [
              // Header
              balanceAsync.when(
                data: (balance) {
                  final youOwe = balance['youOwe'] ?? 0.0;
                  return _buildHeader(context, youOwe)
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: -0.1, end: 0);
                },
                loading: () => const SizedBox(
                    height: 200, child: Center(child: CircularProgressIndicator())),
                error: (err, stack) => const SizedBox(height: 200),
              ),

              // Filter tabs
              if (_selectedEntity == null)
                BreakdownFilterTabs(
                  activeFilter: _activeFilter,
                  onFilterChanged: (filter) {
                    setState(() {
                      _activeFilter = filter;
                      _selectedEntity = null;
                    });
                  },
                ),
                  // Simplify toggle (only show in "All" view)
                if (_selectedEntity == null && _activeFilter == BreakdownFilter.all)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: GlassCard(
                      borderRadius: BorderRadius.circular( 12),
                      padding: const EdgeInsets.all(12),
                      opacity: 0.05,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.compress,
                                size: 14,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Simplify Debts',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: _simplifyDebts,
                            onChanged: (value) {
                              setState(() {
                                _simplifyDebts = value;
                              });
                            },
                            thumbColor: WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return Colors.white;
                              }
                              return null;
                            }),
                            trackColor: WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return AppColors.primaryCyan;
                              }
                              return null;
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),

              // Content
              Expanded(
                child: userAsync.when(
                  data: (user) {
                    return billsAsync.when(
                      data: (owedBills) {
                        if (owedBills.isEmpty) {
                          return _buildEmptyState();
                        }

                        // If entity is selected, show branching tree
                        if (_selectedEntity != null) {
                          return SingleChildScrollView(
                            child: Column(
                              children: [
                                // Back button
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () => setState(() => _selectedEntity = null),
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
                                    ],
                                  ),
                                ),

                                // Branching tree
                                BranchingTree(
                                  entityId: _selectedEntity!.entityId,
                                  entityName: _selectedEntity!.entityName,
                                  entityEmoji: _selectedEntity!.entityEmoji,
                                  entityColor: _selectedEntity!.entityColor,
                                  items: _selectedEntity!.items,
                                  totalAmount: _selectedEntity!.totalAmount,
                                  direction: 'OUT',
                                  isGroup: _selectedEntity!.isGroup,
                                  entityUser: _selectedEntity!.user,
                                ),
                              ],
                            ),
                          );
                        }

                        // Otherwise, show filtered view
                        return _buildFilteredView(
                          user,
                          owedBills,
                          usersAsync,
                          groupsAsync,
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, stack) =>
                          Center(child: Text('Error loading bills: $err')),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) =>
                      Center(child: Text('Error loading user: $err')),
                ),
              ),
            ],
          ),
        // ADD BATCH ACTION BAR HERE
            if (_selectionMode && _selectedItems.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.95),
                    border: Border(
                      top: BorderSide(
                        color: AppColors.primaryCyan.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        // Selection count
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_selectedItems.length} selected',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white70,
                                ),
                              ),
                              Text(
                                'RM ${_calculateSelectedTotal().toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primaryCyan,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Select all button
                        TextButton(
                          onPressed: _selectAll,
                          child: const Text('Select All'),
                        ),

                        const SizedBox(width: 8),

                        // Pay selected button
                        ElevatedButton(
                          onPressed: _paySelected,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryCyan,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Pay Selected',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().slideY(
                  begin: 1.0,
                  end: 0.0,
                  duration: 300.ms,
                  curve: Curves.easeOutCubic,
                ),
              ),
          ],
        ),
      );
  }

  Widget _buildFilteredView(
    AppUser user,
    List<Bill> bills,
    AsyncValue<List<AppUser>> usersAsync,
    AsyncValue<List<AppGroup>> groupsAsync,
  ) {
    switch (_activeFilter) {
      case BreakdownFilter.all:
        return _buildAllBillsList(user, bills);

      case BreakdownFilter.person:
        return usersAsync.when(
          data: (users) {
            final groups = _groupBillsByPerson(user, bills, users);
            return EntitySelectionGrid(
              groups: groups,
              onEntitySelected: (group) {
                setState(() => _selectedEntity = group);
              },
              isGroupMode: false,
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
        );

      case BreakdownFilter.group:
        return groupsAsync.when(
          data: (groups) {
            final breakdownGroups = _groupBillsByGroup(user, bills, groups);
            if (breakdownGroups.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.users,
                      size: 48,
                      color: AppColors.textMuted.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No group bills',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }
            return EntitySelectionGrid(
              groups: breakdownGroups,
              onEntitySelected: (group) {
                setState(() => _selectedEntity = group);
              },
              isGroupMode: true,
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
        );
    }
  }

  List<BreakdownGroup> _groupBillsByPerson(
    AppUser user,
    List<Bill> bills,
    List<AppUser> users,
  ) {
    // Group bills by each person involved
    final Map<String, List<BreakdownItem>> personBills = {};

    for (final bill in bills) {
      final myShare = bill.participantShares[user.id] ?? 0;

      // Find other participants
      for (final participantId in bill.participantShares.keys) {
        if (participantId != user.id) {
          personBills.putIfAbsent(participantId, () => []);
          personBills[participantId]!.add(BreakdownItem(
          bill: bill,
          amount: myShare,
          direction: 'OUT',
          personId: participantId,
          isPending: bill.status == BillStatus.pending,
        ));
        }
      }
    }

    // Convert to BreakdownGroup list
    return personBills.entries.map((entry) {
      final person = users.where((u) => u.id == entry.key).firstOrNull;

      final totalAmount = entry.value.fold<double>(
        0,
        (sum, item) => sum + item.amount,
      );

      return BreakdownGroup(
        entityId: entry.key,
        entityName: person?.name ?? 'Unknown',
        items: entry.value,
        totalAmount: totalAmount,
        user:person,
      );
    }).toList()
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
  }

  List<BreakdownGroup> _groupBillsByGroup(
    AppUser user,
    List<Bill> bills,
    List<AppGroup> groups,
  ) {
    // Group bills by matching participant sets with existing groups
    final Map<String, List<BreakdownItem>> groupBills = {};

    for (final group in groups) {
      // Find bills where participants EXACTLY match this group's members (+ current user)
      for (final bill in bills) {
        final groupMemberIds = {...group.tenantIds, user.id}; // Include current user
        final billParticipantIds = bill.participantIds.toSet();

        // Exact match required - all group members must be in the bill, no extras
        if (groupMemberIds.length == billParticipantIds.length &&
            groupMemberIds.containsAll(billParticipantIds)) {
          final myShare = bill.participantShares[user.id] ?? 0;

          if (myShare > 0) {
            groupBills.putIfAbsent(group.id, () => []);
            groupBills[group.id]!.add(BreakdownItem(
              bill: bill,
              amount: myShare,
              direction: 'OUT',
              groupId: group.id,
              isPending: bill.status == BillStatus.pending,
            ));
          }
        }
      }
    }

    // Convert to BreakdownGroup list
    return groupBills.entries.map((entry) {
      final group = groups.firstWhere(
        (g) => g.id == entry.key,
        orElse: () => groups.first,
      );

      final totalAmount = entry.value.fold<double>(
        0,
        (sum, item) => sum + item.amount,
      );

      return BreakdownGroup(
        entityId: entry.key,
        entityName: group.name,
        entityEmoji: group.emoji,
        entityColor: group.colorValue,
        items: entry.value,
        totalAmount: totalAmount,
        user: null,
      );
    }).toList()
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
  }

  Widget _buildAllBillsList(AppUser user, List<Bill> bills) {
      // Filter out items marked as paid
      final visibleBills = bills.where((bill) => !_paidItems.contains(bill.id)).toList();
      // If simplified view is enabled, show net amounts
      if (_simplifyDebts) {
        final netAmounts = _calculateNetAmounts(user, bills);

        if (netAmounts.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: netAmounts.length + 1,
          itemBuilder: (context, index) {
            // Show "View All Payments" button as last item
            if (index == netAmounts.length) {
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: GestureDetector(
                  onTap: () => context.push(AppRoutes.paymentHistory),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.slate800.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primaryCyan.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.history,
                          color: AppColors.primaryCyan,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'View All Payments',
                          style: TextStyle(
                            color: AppColors.primaryCyan,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final entry = netAmounts.entries.elementAt(index);
            return NetAmountCard(
              entityName: entry.value['name'],
              totalAmount: entry.value['amount'],
              transactionCount: entry.value['count'],
              onSettleAll: () => _settleNetAmount(entry.key, user, bills),
              direction: 'OUT',
            );
          },
        );
      }

      // Otherwise show regular list
      return ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: visibleBills.length + 1,
        itemBuilder: (context, index) {
          // Show "View All Payments" button as last item
          if (index == visibleBills.length) {
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: GestureDetector(
                onTap: () => context.push(AppRoutes.paymentHistory),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.slate800.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primaryCyan.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.history,
                        color: AppColors.primaryCyan,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'View All Payments',
                        style: TextStyle(
                          color: AppColors.primaryCyan,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          // Show regular bill cards
          final bill = visibleBills[index];
          final myShare = bill.participantShares[user.id] ?? 0;

          final isRemoving = _paidItems.contains(bill.id);

            return RepaintBoundary(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: isRemoving ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: AnimatedSlide(
                    offset: isRemoving ? const Offset(-0.3, 0) : Offset.zero,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    child: SizedBox(
                      height: isRemoving ? 0 : null,
                      child: _buildBillCard(
                        context,
                        bill,
                        myShare,
                        index,
                        showCheckbox: _selectionMode,
                        isSelected: _selectedItems.contains(bill.id),
                      ),
                    ),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(
                    duration: 300.ms,
                    delay: (index * 50).ms,
                  )
                  .slideX(
                    begin: 0.05,
                    end: 0,
                    duration: 300.ms,
                    delay: (index * 50).ms,
                  ),
            );
        },
      );
    }

  Widget _buildHeader(BuildContext context, double totalAmount) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 10,
        20,
        20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.background,
            AppColors.background.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: Column(
        children: [
          Row(
              children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: GlassCard(
                    borderRadius: BorderRadius.circular( 50),
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You Owe',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Outstanding payments',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // ADD SELECTION MODE TOGGLE
                if (_activeFilter == BreakdownFilter.all) // Only show in "All" view
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectionMode = !_selectionMode;
                        if (!_selectionMode) {
                          _selectedItems.clear();
                        }
                      });
                    },
                    child: GlassCard(
                      borderRadius: BorderRadius.circular( 50),
                      padding: const EdgeInsets.all(8),
                      opacity: _selectionMode ? 0.2 : 0.0,
                      child: Icon(
                        _selectionMode ? Icons.close : Icons.checklist_rounded,
                        color: _selectionMode ? AppColors.primaryCyan : Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 20.0),
          GlassCard(
            borderRadius: BorderRadius.circular( 24),
            padding: const EdgeInsets.all(24),
            opacity: 0.05,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.arrowUpRight,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TOTAL OWED',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'RM ${totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
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


  Widget _buildBillCard(
    BuildContext context,
    bill,
    double amount,
    int index,
    {bool showCheckbox = false, bool isSelected = false}
  ) {
    // Format date
    final now = DateTime.now();
    final diff = now.difference(bill.createdAt);
    final formattedDate = diff.inDays == 0
        ? 'Today'
        : diff.inDays == 1
            ? 'Yesterday'
            : diff.inDays < 7
                ? '${diff.inDays} days ago'
                : '${bill.createdAt.day}/${bill.createdAt.month}/${bill.createdAt.year}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          context.push(AppRoutes.billSummary, extra: bill.id);
        },
        child: GlassCard(
          borderRadius: BorderRadius.circular( 20),
          padding: const EdgeInsets.all(16),
          opacity: 0.05,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // ADD CHECKBOX
                    if (showCheckbox) ...[
                      Checkbox(
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedItems.add(bill.id);
                            } else {
                              _selectedItems.remove(bill.id);
                            }
                          });
                        },
                        activeColor: AppColors.primaryCyan,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bill.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          bill.location,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'RM ${amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(LucideIcons.calendar, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    formattedDate,
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'PENDING',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              // ADD MARK AS PAID BUTTON
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _markBillAsPaid(bill.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryCyan.withValues(alpha: 0.1),
                      foregroundColor: AppColors.primaryCyan,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text(
                      'Mark as Paid',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.slate800.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.checkCircle2,
              size: 48,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'All Clear!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'You don\'t owe anyone',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }
  double _calculateSelectedTotal() {
      final billsAsync = ref.read(youOweBillsProvider);
      final userAsync = ref.read(currentUserProvider);

      return billsAsync.when(
        data: (bills) {
          final user = userAsync.value;
          if (user == null) return 0.0;

          double total = 0.0;
          for (final billId in _selectedItems) {
            try {
              final bill = bills.firstWhere((b) => b.id == billId);
              total += bill.participantShares[user.id] ?? 0.0;
            } catch (e) {
              // Bill not found, skip it
            }
          }
          return total;
        },
        loading: () => 0.0,
        error: (_, __) => 0.0,
      );
    }

    void _selectAll() {
      final billsAsync = ref.read(youOweBillsProvider);

      billsAsync.whenData((bills) {
        setState(() {
          _selectedItems = bills.map((b) => b.id).toSet();
        });
      });
    }


    void _settleNetAmount(String personId, AppUser user, List<Bill> bills) async {
      final netAmount = _calculateNetAmounts(user, bills)[personId];

      if (netAmount == null) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.slate800,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Settle Net Amount',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          content: Text(
            'Pay net amount of RM ${netAmount['amount'].toStringAsFixed(2)} to ${netAmount['name']}?\n\nThis covers ${netAmount['count']} transaction${netAmount['count'] == 1 ? '' : 's'}.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryCyan,
                foregroundColor: Colors.black,
              ),
              child: const Text(
                'Confirm',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        // Get all bill IDs for this person
        final billIdsToRemove = <String>{};
        for (final bill in bills) {
          if (bill.participantShares.containsKey(personId)) {
            billIdsToRemove.add(bill.id);
          }
        }

        // Mark items as paid (triggers exit animation)
        setState(() {
          _paidItems.addAll(billIdsToRemove);
        });

        // Wait for animation to complete
         await Future.delayed(const Duration(milliseconds: 400));

          // Update database for all bills with this person
          final currentUser = ref.read(currentUserProvider).value;
          if (currentUser != null) {
            final updatePaymentStatus = ref.read(updatePaymentStatusProvider);

            for (final billId in billIdsToRemove) {
              await updatePaymentStatus(
                billId: billId,
                userId: currentUser.id,
                hasPaid: true,
              );
            }

            // Refresh the bills list
            ref.invalidate(youOweBillsProvider);
            ref.invalidate(balanceProvider);
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Payment to ${netAmount['name']} completed!'),
                backgroundColor: Colors.green,
              ),
            );
          }
      }
    }

    void _paySelected() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.slate800,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Confirm Batch Payment',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          content: Text(
            'Mark ${_selectedItems.length} items as paid?\n\nTotal: RM ${_calculateSelectedTotal().toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryCyan,
                foregroundColor: Colors.black,
              ),
              child: const Text(
                'Confirm',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        // Mark items as paid (triggers exit animation)
        setState(() {
          _paidItems.addAll(_selectedItems);
        });

        // Wait for animation to complete
        // Wait for animation to complete
          await Future.delayed(const Duration(milliseconds: 400));

          // Update database for all selected bills
          final currentUser = ref.read(currentUserProvider).value;
          if (currentUser != null) {
            final updatePaymentStatus = ref.read(updatePaymentStatusProvider);

            for (final billId in _selectedItems) {
              await updatePaymentStatus(
                billId: billId,
                userId: currentUser.id,
                hasPaid: true,
              );
            }

            // Refresh the bills list
            ref.invalidate(youOweBillsProvider);
            ref.invalidate(balanceProvider);

            // Clear selection
            setState(() {
              _selectedItems.clear();
            });
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Payments marked as paid!'),
                backgroundColor: Colors.green,
              ),
            );
          }
      }
    }
    Map<String, Map<String, dynamic>> _calculateNetAmounts(AppUser user, List<Bill> bills) {
      final usersAsync = ref.read(usersProvider);

      return usersAsync.when(
        data: (allUsers) {
          // Group bills by person
          final Map<String, Map<String, dynamic>> netAmounts = {};

          for (final bill in bills) {
            for (final participantId in bill.participantShares.keys) {
              if (participantId != user.id) {
                final amount = bill.participantShares[participantId] ?? 0;

                if (!netAmounts.containsKey(participantId)) {
                  String personName = 'Unknown';
                  try {
                    final person = allUsers.firstWhere((u) => u.id == participantId);
                    personName = person.name;
                  } catch (e) {
                    // Person not found, use 'Unknown'
                  }

                  netAmounts[participantId] = {
                    'name': personName,
                    'amount': 0.0,
                    'count': 0,
                  };
                }

                netAmounts[participantId]!['amount'] += amount;
                netAmounts[participantId]!['count'] += 1;
              }
            }
          }

          return netAmounts;
        },
        loading: () => {},
        error: (_, __) => {},
      );
    }


    void _markBillAsPaid(String billId) async {
    // Get current user
    final userAsync = ref.read(currentUserProvider);
    final currentUser = userAsync.value;

    if (currentUser == null) return;

    // Mark as paid (triggers exit animation)
    setState(() {
      _paidItems.add(billId);
    });

    // Wait for animation to complete
    await Future.delayed(const Duration(milliseconds: 400));

    // Update database using the proper use case
    final updatePaymentStatus = ref.read(updatePaymentStatusProvider);
    final result = await updatePaymentStatus(
      billId: billId,
      userId: currentUser.id,
      hasPaid: true,
    );

    // Refresh the bills list
    ref.invalidate(youOweBillsProvider);
    ref.invalidate(balanceProvider);

    // Show result to user
    if (mounted) {
      result.fold(
        (failure) {
          // Show error if failed
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update payment: ${failure.message}'),
              backgroundColor: Colors.red,
            ),
          );
        },
        (_) {
          // Show success
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment marked as paid!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        },
      );
    }
  }
}
