import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/router/app_router.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../providers/bills/bills_provider.dart';
import '../../providers/bills/balance_provider.dart';
import '../../../../shared/presentation/providers/users_provider.dart';
import '../../../domain/entities/bills/bill.dart';
import '../../../../shared/domain/entities/users/app_user.dart';
import '../../widgets/bills/breakdown_filter_tabs.dart';
import '../../widgets/bills/entity_selection_grid.dart';
import '../../widgets/bills/branching_tree.dart';
import '../../../domain/entities/bills/breakdown_item.dart';
import '../../../../landlord/domain/entities/property.dart';
import '../../../domain/entities/bills/bill_enums.dart';
import '../../../../../core/widgets/animations.dart';
import '../../../../../core/di/injection.dart';
import '../../../../shared/presentation/providers/groups_provider.dart';
import '../../../../shared/domain/entities/groups/app_group.dart';



class OwedToYouScreen extends ConsumerStatefulWidget {
    const OwedToYouScreen({super.key});

    @override
    ConsumerState<OwedToYouScreen> createState() => _OwedToYouScreenState();
  }

  class _OwedToYouScreenState extends ConsumerState<OwedToYouScreen> {
    BreakdownFilter _activeFilter = BreakdownFilter.all;
    BreakdownGroup? _selectedEntity;
    bool _selectionMode = false;
    Set<String> _selectedItems = {};
    bool _simplifyDebts = false;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final billsAsync = ref.watch(owedToYouBillsProvider);
    final balanceAsync = ref.watch(balanceProvider);
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
                  final owedToYou = balance['owedToYou'] ?? 0.0;
                  return _buildHeader(owedToYou)
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: -0.1, end: 0);
                },
                loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
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
                    child: Row(
                      children: [
                        Switch(
                          value: _simplifyDebts,
                          onChanged: (value) {
                            setState(() => _simplifyDebts = value);
                          },
                          thumbColor: WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.selected)) {
                              return Colors.white;
                            }
                            return Colors.grey;
                          }),
                          trackColor: WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.selected)) {
                             return const Color(0xFF10B981); // Green when enabled
                            }
                            return Colors.grey.withValues(alpha: 0.3);
                           }),
                         ),
                        const SizedBox(width: 6),
                        const Flexible(
                          child: Text(
                            'Simplify Debts',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                             ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                 // Entity selection grid (Person/Group tabs)
  if (_selectedEntity == null && _activeFilter != BreakdownFilter.all)
    Expanded(
      child: _activeFilter == BreakdownFilter.person
          ? userAsync.when(
              data: (currentUser) {
                return billsAsync.when(
                  data: (bills) {
                    // Build breakdown groups for each person
                    final personGroups = _buildPersonBreakdownGroups(bills, currentUser);

                    return EntitySelectionGrid(
                      groups: personGroups,
                      isGroupMode: false,
                      onEntitySelected: (group) {
                        setState(() {
                          _selectedEntity = group;
                        });
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Error: $err')),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            )
                        :userAsync.when(
              data: (currentUser) {
                return billsAsync.when(
                  data: (bills) {
                    return groupsAsync.when(
                      data: (groups) {
                        // Build breakdown groups for each group
                        final groupBreakdowns = _buildGroupBreakdownGroups(bills, groups, currentUser);

                        return EntitySelectionGrid(
                          groups: groupBreakdowns,
                          isGroupMode: true,
                          onEntitySelected: (group) {
                            setState(() {
                              _selectedEntity = group;
                            });
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, stack) => Center(child: Text('Error: $err')),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Error: $err')),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
    ),

                 // Tree view when entity is selected
  if (_selectedEntity != null)
    Expanded(
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Back button + entity name
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedEntity = null;
                      });
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
                ],
              ),
            ),

            // Branching tree (NO Expanded wrapper)
            userAsync.when(
              data: (currentUser) {
                return BranchingTree(
                  entityId: _selectedEntity!.entityId,
                  entityName: _selectedEntity!.entityName,
                  items: _selectedEntity!.items,
                  totalAmount: _selectedEntity!.totalAmount,
                  direction: 'in',
                  isGroup: _selectedEntity!.isGroup,
                  entityEmoji: _selectedEntity!.entityEmoji,
                  entityColor: _selectedEntity!.entityColor,
                  entityUser: _selectedEntity!.user,
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ],
        ),
      ),
    ),


              // List (only show when not viewing tree and in "All" tab)
                if (_selectedEntity == null && _activeFilter == BreakdownFilter.all)
                  Expanded(
                    child: userAsync.when(
                  data: (user) {
                    return billsAsync.when(
                      data: (owedBills) {
                        if (owedBills.isEmpty) {
                          return _buildEmptyState();
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: owedBills.length + 1,
                          itemBuilder: (context, index) {
                            if (index == owedBills.length) {
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

                            final bill = owedBills[index];

                            // Calculate total amount owed to user from this bill
                            double totalOwed = 0;
                            for (final participantId in bill.participantIds) {
                              if (participantId != user.id) {
                                final share = bill.participantShares[participantId] ?? 0;
                                final isPaid = bill.paymentStatus[participantId] ?? false;
                                if (!isPaid && share > 0) {
                                  totalOwed += share;
                                }
                              }
                            }

                            return RepaintBoundary(
                              child: _buildBillCard(
                                bill,
                                totalOwed,
                                index,
                                showCheckbox: _selectionMode,
                                isSelected: _selectedItems.contains(bill.id),
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
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, stack) => Center(child: Text('Error loading bills: $err')),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Error loading user: $err')),
                ),
              ),
            ],
          ),
        // ADD BATCH ACTION BAR
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
                        color: const Color(0xFF10B981).withValues(alpha: 0.3),
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
                                  color: Color(0xFF10B981),
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

                        // Remind selected button
                        ElevatedButton(
                          onPressed: _remindSelected,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
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
                            'Remind Selected',
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

  Widget _buildHeader(double totalAmount) {
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
            AppColors.background.withValues(alpha:0.0),
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
                      'Owed To You',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Money coming your way',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            // ADD SELECTION MODE TOGGLE
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
          const SizedBox(height: 20),
          GlassCard(
            borderRadius: BorderRadius.circular( 24),
            padding: const EdgeInsets.all(24),
            opacity: 0.05,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha:0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.arrowDownLeft,
                    color: Color(0xFF10B981),
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
    Bill bill,
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
                        activeColor: const Color(0xFF10B981), // Green color for "owed to you"
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
                      color: Color(0xFF10B981),
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
                      color: const Color(0xFF10B981).withValues(alpha:0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'PENDING',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Details button
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () {
                    context.push(AppRoutes.billSummary, extra: bill.id);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.slate900,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Details',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, size: 14),
                    ],
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
              color: AppColors.slate800.withValues(alpha:0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.inbox,
              size: 48,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Pending Payments',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Nobody owes you money',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }
  double _calculateSelectedTotal() {
      final billsAsync = ref.read(owedToYouBillsProvider);
      final userAsync = ref.read(currentUserProvider);

      return billsAsync.when(
        data: (bills) {
          final user = userAsync.value;
          if (user == null) return 0.0;

          double total = 0.0;
          for (final billId in _selectedItems) {
            try {
              final bill = bills.firstWhere((b) => b.id == billId);
              // Calculate total owed from this bill
              for (final participantId in bill.participantIds) {
                if (participantId != user.id) {
                  final share = bill.participantShares[participantId] ?? 0;
                  final isPaid = bill.paymentStatus[participantId] ?? false;
                  if (!isPaid && share > 0) {
                    total += share;
                  }
                }
              }
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
      final billsAsync = ref.read(owedToYouBillsProvider);

      billsAsync.whenData((bills) {
        setState(() {
          _selectedItems = bills.map((b) => b.id).toSet();
        });
      });
    }

    void _remindSelected() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.slate800,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Send Reminder',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          content: Text(
            'Send payment reminder for ${_selectedItems.length} bill${_selectedItems.length == 1 ? '' : 's'}?\n\nTotal: RM ${_calculateSelectedTotal().toStringAsFixed(2)}',
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
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.black,
              ),
              child: const Text(
                'Send Reminder',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        // TODO: Implement actual reminder logic

        setState(() {
          _selectedItems.clear();
          _selectionMode = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reminders sent!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      }
    }
     List<BreakdownGroup> _buildPersonBreakdownGroups(List<Bill> bills, AppUser currentUser) {
      final Map<String, List<BreakdownItem>> personItemsMap = {};

      for (final bill in bills) {
        for (final participantId in bill.participantIds) {
          if (participantId != currentUser.id) {
            final share = bill.participantShares[participantId] ?? 0;
            final isPaid = bill.paymentStatus[participantId] ?? false;

            if (!isPaid && share > 0) {
               final item = BreakdownItem(
                bill: bill,
                amount: share,
                direction: 'IN',
                personId: participantId,
                isPending: bill.status == BillStatus.pending,
              );

              personItemsMap.putIfAbsent(participantId, () => []).add(item);
            }
          }
        }
      }

      // Convert to BreakdownGroups
      final usersAsync = ref.read(usersProvider);
      return usersAsync.when(
        data: (users) {
          return personItemsMap.entries
      .where((entry) => entry.value.isNotEmpty) // ADD THIS LINE
      .map((entry) {
        final user = users.firstWhere(
          (u) => u.id == entry.key,
          orElse: () => users.isNotEmpty ? users.first : AppUser(
            id: entry.key,
            name: 'Unknown User',
            avatarInitials: 'UN',
          ),
        );
        final totalAmount = entry.value.fold(0.0, (sum, item) => sum + item.amount);

        return BreakdownGroup(
          entityId: entry.key,
          entityName: user.name,
          items: entry.value,
          totalAmount: totalAmount,
          user: user,
        );
      }).toList();
        },
        loading: () => [],
        error: (_, __) => [],
      );
    }

    List<BreakdownGroup> _buildGroupBreakdownGroups(
      List<Bill> bills,
      List<AppGroup> groups,
      AppUser currentUser,
    ) {
      final List<BreakdownGroup> groupBreakdowns = [];

      for (final group in groups) {
        final List<BreakdownItem> items = [];

        for (final bill in bills) {
          // Check if any group member is in this bill
          final groupMembersInBill = bill.participantIds
              .where((id) => group.tenantIds.contains(id) && id != currentUser.id)
              .toList();

          if (groupMembersInBill.isNotEmpty) {
            // Calculate total owed from group members in this bill
            double billAmount = 0;
            for (final memberId in groupMembersInBill) {
              final share = bill.participantShares[memberId] ?? 0;
              final isPaid = bill.paymentStatus[memberId] ?? false;

              if (!isPaid && share > 0) {
                billAmount += share;
              }
            }

            if (billAmount > 0) {
              items.add(BreakdownItem(
              bill: bill,
              amount: billAmount,
              direction: 'IN',
              groupId: group.id,
              isPending: bill.status == BillStatus.pending,
            ));
            }
          }
        }

        if (items.isNotEmpty) {
          final totalAmount = items.fold(0.0, (sum, item) => sum + item.amount);
          groupBreakdowns.add(BreakdownGroup(
            entityId: group.id,
            entityName: group.name,
            entityEmoji: group.emoji,
            entityColor: group.colorValue,
            items: items,
            totalAmount: totalAmount,
          ));
        }
      }

      return groupBreakdowns;
    }
}
