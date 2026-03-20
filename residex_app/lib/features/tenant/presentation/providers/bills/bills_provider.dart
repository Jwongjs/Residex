import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/bills/bill.dart';
import '../../../domain/entities/bills/bill_enums.dart';
import '../../../domain/repositories/bills/bill_repository.dart';
import '../../../data/repositories/bills/bill_repository_impl.dart';
import '../../../../../core/di/injection.dart';
import '../../../../landlord/domain/entities/property.dart';
import '../../../../shared/presentation/providers/users_provider.dart';
import '../../../data/datasources/bills/mock_bills_data.dart';
import '../../../../shared/domain/entities/groups/app_group.dart';

class BillsNotifier extends AsyncNotifier<List<Bill>> {
  @override
  Future<List<Bill>> build() async {
    final repository = ref.watch(billRepositoryProvider);
    final result = await repository.getAllBills();
    return result.fold(
      (failure) => throw Exception(failure.message),
      (bills) => bills,
    );
  }

  Future<void> loadBills() async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(billRepositoryProvider);
      final result = await repository.getAllBills();
      result.fold(
        (failure) => state = AsyncValue.error(failure, StackTrace.current),
        (bills) => state = AsyncValue.data(bills),
      );
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }

  Future<void> createBill({
    required String title,
    required String location,
    required double totalAmount,
    required BillCategory category,
    required String provider,
    required DateTime? dueDate,
    required List<String> participantIds,
    String? imageUrl,
  }) async {
    try {
      final bill = Bill(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        location: location,
        totalAmount: totalAmount,
        createdAt: DateTime.now(),
        participantIds: participantIds,
        participantShares: _calculateEqualShares(totalAmount, participantIds),
        paymentStatus: _initializePaymentStatus(participantIds),
        items: [],
        imageUrl: imageUrl,
        category: category,
        provider: provider,
        dueDate: dueDate,
        status: BillStatus.pending,
      );

      final repository = ref.read(billRepositoryProvider);
      final result = await repository.saveBill(bill);
      result.fold(
        (failure) => state = AsyncValue.error(failure, StackTrace.current),
        (_) => loadBills(),
      );
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }

  Future<void> markUserAsPaid(String billId, String userId) async {
    try {
      final repository = ref.read(billRepositoryProvider);
      final result = await repository.updatePaymentStatus(
        billId: billId,
        userId: userId,
        hasPaid: true,
      );
      result.fold(
        (failure) => state = AsyncValue.error(failure, StackTrace.current),
        (_) => loadBills(),
      );
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }

  List<Bill> getBillsByCategory(BillCategory category) {
    final bills = state.value ?? [];
    return bills.where((bill) => bill.category == category).toList();
  }

  List<Bill> getOutstandingBills(String userId) {
    final bills = state.value ?? [];
    return bills.where((bill) {
      final userStatus = bill.getPaymentStatusForUser(userId);
      return userStatus != PaymentStatus.paid;
    }).toList();
  }

  List<Bill> getSettledBills(String userId) {
    final bills = state.value ?? [];
    return bills.where((bill) {
      final userStatus = bill.getPaymentStatusForUser(userId);
      return userStatus == PaymentStatus.paid;
    }).toList();
  }

  List<Bill> getBillsByProvider(String provider) {
    final bills = state.value ?? [];
    return bills.where((bill) => bill.provider == provider).toList();
  }

  List<Bill> getOverdueBills(String userId) {
    final bills = state.value ?? [];
    final now = DateTime.now();
    return bills.where((bill) {
      if (bill.dueDate == null) return false;
      final userStatus = bill.getPaymentStatusForUser(userId);
      return now.isAfter(bill.dueDate!) && userStatus != PaymentStatus.paid;
    }).toList();
  }

  List<Bill> searchBills(String query) {
    final bills = state.value ?? [];
    final queryLower = query.toLowerCase();
    return bills.where((bill) {
      return bill.title.toLowerCase().contains(queryLower) ||
          bill.provider.toLowerCase().contains(queryLower) ||
          bill.category.name.toLowerCase().contains(queryLower);
    }).toList();
  }

  Future<void> deleteBill(String billId) async {
    try {
      final repository = ref.read(billRepositoryProvider);
      final result = await repository.deleteBill(billId);
      result.fold(
        (failure) => state = AsyncValue.error(failure, StackTrace.current),
        (_) => loadBills(),
      );
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }

  Future<void> initializeMockData() async {
    try {
      final repository = ref.read(billRepositoryProvider);
      final mockBills = MockBillsData.getMockBills();
      for (final bill in mockBills) {
        await repository.saveBill(bill);
      }
      await loadBills();
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }

  Future<void> clearAllBills() async {
    try {
      final bills = state.value ?? [];
      final repository = ref.read(billRepositoryProvider);
      for (final bill in bills) {
        await repository.deleteBill(bill.id);
      }
      await loadBills();
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }

  // ============================================================================
  // Helpers
  // ============================================================================

  Map<String, double> _calculateEqualShares(
      double total, List<String> participantIds) {
    final share = total / participantIds.length;
    return Map.fromEntries(
      participantIds.map((id) => MapEntry(id, share)),
    );
  }

  Map<String, bool> _initializePaymentStatus(List<String> userIds) {
    return Map.fromEntries(
      userIds.map((id) => MapEntry(id, false)),
    );
  }
}

// ============================================================================
// Provider definitions
// ============================================================================

final billsProvider =
    AsyncNotifierProvider<BillsNotifier, List<Bill>>(BillsNotifier.new);

/// Selected group filter
class _SelectedGroupNotifier extends Notifier<AppGroup?> {
  @override
  AppGroup? build() => null;
}

final selectedGroupFilterProvider =
    NotifierProvider<_SelectedGroupNotifier, AppGroup?>(_SelectedGroupNotifier.new);

/// Bills filtered by selected group
final groupFilteredBillsProvider = Provider<AsyncValue<List<Bill>>>((ref) {
  final selectedGroup = ref.watch(selectedGroupFilterProvider);
  final billsAsync = ref.watch(billsProvider);

  if (selectedGroup == null) return billsAsync;

  return billsAsync.when(
    data: (bills) {
      final filteredBills = bills.where((bill) {
        return bill.participantIds
            .any((userId) => selectedGroup.tenantIds.contains(userId));
      }).toList();
      return AsyncValue.data(filteredBills);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

/// Bills where others owe the current user
final owedToYouBillsProvider = Provider<AsyncValue<List<Bill>>>((ref) {
  final currentUserAsync = ref.watch(currentUserProvider);
  final billsAsync = ref.watch(billsProvider);

  return currentUserAsync.when(
    data: (currentUser) {
      return billsAsync.when(
        data: (bills) {
          final owedBills = bills.where((bill) {
            final currentUserPaid =
                bill.paymentStatus[currentUser.id] ?? false;
            if (!currentUserPaid) return false;
            return bill.participantIds.any((participantId) {
              if (participantId == currentUser.id) return false;
              final hasPaid = bill.paymentStatus[participantId] ?? false;
              return !hasPaid;
            });
          }).toList();
          return AsyncValue.data(owedBills);
        },
        loading: () => const AsyncValue.loading(),
        error: (error, stack) => AsyncValue.error(error, stack),
      );
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

/// Bills where the current user owes others
final youOweBillsProvider = Provider<AsyncValue<List<Bill>>>((ref) {
  final currentUserAsync = ref.watch(currentUserProvider);
  final billsAsync = ref.watch(billsProvider);

  return currentUserAsync.when(
    data: (currentUser) {
      return billsAsync.when(
        data: (bills) {
          final oweBills = bills.where((bill) {
            if (!bill.participantIds.contains(currentUser.id)) return false;
            final currentUserPaid =
                bill.paymentStatus[currentUser.id] ?? false;
            return !currentUserPaid;
          }).toList();
          return AsyncValue.data(oweBills);
        },
        loading: () => const AsyncValue.loading(),
        error: (error, stack) => AsyncValue.error(error, stack),
      );
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});
