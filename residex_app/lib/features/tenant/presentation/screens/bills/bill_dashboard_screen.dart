import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../shared/presentation/providers/users_provider.dart';
import '../../providers/bills/bills_provider.dart';
import '../../../domain/entities/bills/bill.dart';
import '../../../domain/entities/bills/bill_enums.dart';
import '../../../../../core/widgets/residex_bottom_nav.dart';
import '../../../../shared/domain/entities/users/app_user.dart';
import '../../widgets/bills/ledger_summary_cards.dart';
import '../../widgets/bills/bill_list_item.dart';
import '../../providers/bills/bill_statistics_provider.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_dimensions.dart';
import '../../widgets/bills/bill_filter_modal.dart';
import '../../../../../core/router/app_router.dart';
import '../../../../shared/domain/entities/users/app_user.dart';


  class BillDashboardScreen extends ConsumerStatefulWidget {
  const BillDashboardScreen({super.key});

  @override
  ConsumerState<BillDashboardScreen> createState() => _BillDashboardScreenState();
}

class _BillDashboardScreenState extends ConsumerState<BillDashboardScreen> {
  BillCategory? _selectedCategory;
  String _searchQuery = '';
  bool _showOutstandingOnly = false;
  PaymentStatusFilter _paymentStatusFilter = PaymentStatusFilter.all;

  @override
  Widget build(BuildContext context) {
    // Create filter

    final currentUserAsync = ref.watch(currentUserProvider);
  final currentUserId = currentUserAsync.value?.id ?? '';

  // Create filter
  final filter = BillFilter(
    userId: currentUserId,
    searchQuery: _searchQuery,
    category: _selectedCategory,
    showOutstandingOnly: _showOutstandingOnly,
  );

  // Watch filtered bills and statistics
  final filteredBills = ref.watch(filteredBillsProvider(filter));
  final stats = ref.watch(billStatisticsProvider(currentUserId));

    return Scaffold(
      backgroundColor: AppColors.deepSpace,
       body: Stack(
        children: [
          // Purple radial gradient background
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 500,
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
          SafeArea(
            child: Column(

          children: [
            // Header
            _buildHeader(),

            // Summary Cards with stats from provider
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingLarge,
              ),
              child: LedgerSummaryCards(
                outstandingCount: stats.outstandingCount,
                outstandingAmount: stats.outstandingAmount,
                settledCount: stats.settledCount,
                settledAmount: stats.settledAmount,
              ),
            ),


            const SizedBox(height: AppDimensions.paddingLarge),

            // Search Bar
             _buildFilterButton(),

            const SizedBox(height: 16),

            // Bills List
            Expanded(
              child: currentUserAsync.when(
                data: (currentUser) => _buildBillsList(filteredBills, currentUser.id),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(child: Text('Error loading user')),
              ),
            ),
          ],
        ),
      ),
    ],
  ),

  );
  }

  // Extract widget building methods for cleaner code
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Ledger',
                style: AppTextStyles.h2.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  Icons.science_rounded,
                  color: AppColors.textSecondary,
                  size: 28,
                ),
                onPressed: () => _showMockDataDialog(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _showAddBillDialog(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.cyan500.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.cyan500.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_circle_rounded, color: AppColors.cyan500, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'New Invoice',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.cyan500,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

 Widget _buildSearchBar() {
    return TextField(
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Search provider or bill...',
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary),
        prefixIcon: Icon(Icons.search_rounded, color: AppColors.textTertiary),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear_rounded, color: AppColors.textTertiary),
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                  });
                },
              )
            : null,
        filled: true,
        fillColor: AppColors.surfaceLight.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.cyan500.withValues(alpha: 0.5), width: 2),
        ),
      ),
    );
  }

   Widget _buildFilterButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(child: _buildSearchBar()),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _showFilterModal,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primaryCyan.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primaryCyan.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.filter_list,
                color: AppColors.primaryCyan,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        child: BillFilterModal(
          selectedCategory: _selectedCategory,
          selectedPaymentStatus: _paymentStatusFilter,
          onCategoryChanged: (category) {
            setState(() => _selectedCategory = category);
          },
          onPaymentStatusChanged: (status) {
            setState(() {
              _paymentStatusFilter = status;
              _showOutstandingOnly = status != PaymentStatusFilter.all && status != PaymentStatusFilter.settled;
            });
          },
        ),
      ),
    );
  }


  Widget _buildAllFilterChip() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _selectedCategory == null
              ? AppColors.cyan500.withValues(alpha: 0.2)
              : AppColors.surfaceLight.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _selectedCategory == null
                ? AppColors.cyan500.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        child: Text(
          'ALL',
          style: AppTextStyles.bodySmall.copyWith(
            color: _selectedCategory == null ? AppColors.cyan500 : AppColors.textSecondary,
            fontWeight: _selectedCategory == null ? FontWeight.w700 : FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }



  Widget _buildBillsList(List<Bill> bills, String currentUserId) {
    if (bills.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_rounded,
              size: 64,
              color: AppColors.textTertiary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty || _selectedCategory != null
                  ? 'No bills found'
                  : 'No bills yet',
              style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textTertiary),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty || _selectedCategory != null
                  ? 'Try adjusting your filters'
                  : 'Tap + to add your first bill',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingLarge,
        vertical: AppDimensions.paddingSmall,
      ),
      itemCount: bills.length,
      itemBuilder: (context, index) {
        final bill = bills[index];
        return BillListItem(
          bill: bill,
          currentUserId: currentUserId,
          onTap: () {
            // Navigate to bill details
            context.push('/bill-summary/${bill.id}');
          },
        );
      },
    );
  }

  void _showAddBillDialog() {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final providerController = TextEditingController();
    BillCategory selectedCategory = BillCategory.other;
    DateTime? selectedDueDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.slate800,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Add New Bill',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: providerController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Provider',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount (RM)',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<BillCategory>(
                  value: selectedCategory,
                  dropdownColor: AppColors.slate800,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                  ),
                  items: BillCategory.values.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category.label),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedCategory = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: Text(
                    selectedDueDate == null
                        ? 'Select Due Date'
                        : 'Due: ${DateFormat('dd MMM yyyy').format(selectedDueDate!)}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  trailing: const Icon(Icons.calendar_today, color: AppColors.cyan500),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setDialogState(() => selectedDueDate = date);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty || amountController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all required fields')),
                  );
                  return;
                }

                final currentUser = await ref.read(currentUserProvider.future);

                await ref.read(billsProvider.notifier).createBill(
                  title: titleController.text,
                  location: 'My House',
                  totalAmount: double.parse(amountController.text),
                  category: selectedCategory,
                  provider: providerController.text,
                  dueDate: selectedDueDate,
                  participantIds: [currentUser.id],
                );

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bill added successfully')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cyan500,
              ),
              child: const Text('Add Bill'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMockDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.slate800,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.science_rounded, color: AppColors.cyan500),
            const SizedBox(width: 12),
            const Text(
              'Mock Data',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Initialize realistic rental bills for testing',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'This will add 8 mock bills including:',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            _buildMockDataItem('• Rent (Monthly)'),
            _buildMockDataItem('• TNB Electricity'),
            _buildMockDataItem('• Air Selangor Water'),
            _buildMockDataItem('• Unifi Internet'),
            _buildMockDataItem('• Gas Petronas'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(billsProvider.notifier).clearAllBills();
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All bills cleared'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: const Text(
              'Clear All',
              style: TextStyle(color: AppColors.error),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref.read(billsProvider.notifier).initializeMockData();
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Mock bills loaded successfully!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cyan500,
            ),
            child: const Text('Load Mock Data'),
          ),
        ],
      ),
    );
  }

  Widget _buildMockDataItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Text(
        text,
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
