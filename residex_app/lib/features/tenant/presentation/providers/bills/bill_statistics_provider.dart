import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/bills/bill.dart';
import '../../../domain/entities/bills/bill_enums.dart';
import 'bills_provider.dart';

/// Statistics for bill dashboard
class BillStatistics {
  final int totalBills;
  final int outstandingCount;
  final double outstandingAmount;
  final int settledCount;
  final double settledAmount;
  final int overdueCount;
  final double overdueAmount;
  final Map<BillCategory, int> categoryBreakdown;
  final Map<String, double> providerSpending;

  const BillStatistics({
    required this.totalBills,
    required this.outstandingCount,
    required this.outstandingAmount,
    required this.settledCount,
    required this.settledAmount,
    required this.overdueCount,
    required this.overdueAmount,
    required this.categoryBreakdown,
    required this.providerSpending,
  });

  static BillStatistics empty() {
    return const BillStatistics(
      totalBills: 0,
      outstandingCount: 0,
      outstandingAmount: 0.0,
      settledCount: 0,
      settledAmount: 0.0,
      overdueCount: 0,
      overdueAmount: 0.0,
      categoryBreakdown: {},
      providerSpending: {},
    );
  }
}

/// Provider for bill statistics
final billStatisticsProvider = Provider.family<BillStatistics, String>((ref, userId) {
  final billsAsync = ref.watch(billsProvider);

  return billsAsync.when(
    data: (bills) {
      int outstandingCount = 0;
      double outstandingAmount = 0.0;
      int settledCount = 0;
      double settledAmount = 0.0;
      int overdueCount = 0;
      double overdueAmount = 0.0;
      final categoryBreakdown = <BillCategory, int>{};
      final providerSpending = <String, double>{};

      final now = DateTime.now();

      for (final bill in bills) {
        final userStatus = bill.getPaymentStatusForUser(userId);
        final userShare = bill.participantShares[userId] ?? 0.0;

        // Count by status
        if (userStatus == PaymentStatus.paid) {
          settledCount++;
          settledAmount += userShare;
        } else {
          outstandingCount++;
          outstandingAmount += userShare;

          // Check if overdue
          if (bill.dueDate != null && now.isAfter(bill.dueDate!)) {
            overdueCount++;
            overdueAmount += userShare;
          }
        }

        // Category breakdown
        categoryBreakdown[bill.category] = (categoryBreakdown[bill.category] ?? 0) + 1;

        // Provider spending
        if (bill.provider.isNotEmpty) {
          providerSpending[bill.provider] = (providerSpending[bill.provider] ?? 0.0) + userShare;
        }
      }

      return BillStatistics(
        totalBills: bills.length,
        outstandingCount: outstandingCount,
        outstandingAmount: outstandingAmount,
        settledCount: settledCount,
        settledAmount: settledAmount,
        overdueCount: overdueCount,
        overdueAmount: overdueAmount,
        categoryBreakdown: categoryBreakdown,
        providerSpending: providerSpending,
      );
    },
    loading: () => BillStatistics.empty(),
    error: (_, __) => BillStatistics.empty(),
  );
});

/// Provider for filtered bills
final filteredBillsProvider = Provider.family<List<Bill>, BillFilter>((ref, filter) {
  final billsAsync = ref.watch(billsProvider);

  return billsAsync.when(
    data: (bills) {
      var filtered = bills.where((bill) {
        // Search filter
        if (filter.searchQuery.isNotEmpty) {
          final searchLower = filter.searchQuery.toLowerCase();
          final matchesTitle = bill.title.toLowerCase().contains(searchLower);
          final matchesProvider = bill.provider.toLowerCase().contains(searchLower);
          if (!matchesTitle && !matchesProvider) return false;
        }

        // Category filter
        if (filter.category != null && bill.category != filter.category) {
          return false;
        }

        // Status filter
        if (filter.showOutstandingOnly) {
          final userStatus = bill.getPaymentStatusForUser(filter.userId);
          if (userStatus == PaymentStatus.paid) return false;
        }

        return true;
      }).toList();

      // Sort by due date (overdue first, then by date)
      filtered.sort((a, b) {
        final aOverdue = a.dueDate != null && DateTime.now().isAfter(a.dueDate!);
        final bOverdue = b.dueDate != null && DateTime.now().isAfter(b.dueDate!);

        if (aOverdue && !bOverdue) return -1;
        if (!aOverdue && bOverdue) return 1;

        if (a.dueDate == null) return 1;
        if (b.dueDate == null) return -1;
        return a.dueDate!.compareTo(b.dueDate!);
      });

      return filtered;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Filter configuration for bills
class BillFilter {
  final String userId;
  final String searchQuery;
  final BillCategory? category;
  final bool showOutstandingOnly;

  const BillFilter({
    required this.userId,
    this.searchQuery = '',
    this.category,
    this.showOutstandingOnly = false,
  });

  BillFilter copyWith({
    String? userId,
    String? searchQuery,
    BillCategory? category,
    bool? showOutstandingOnly,
  }) {
    return BillFilter(
      userId: userId ?? this.userId,
      searchQuery: searchQuery ?? this.searchQuery,
      category: category ?? this.category,
      showOutstandingOnly: showOutstandingOnly ?? this.showOutstandingOnly,
    );
  }
}
