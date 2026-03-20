  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import '../../../../../core/di/injection.dart';
  import 'bills_provider.dart';
  import '../../../../shared/presentation/providers/users_provider.dart';

  /// Provider for user balances (You Owe / Owed to You)
  final balanceProvider = FutureProvider<Map<String, double>>((ref) async {
    final currentUserAsync = ref.watch(currentUserProvider);
    final billsAsync = ref.watch(billsProvider);

    return currentUserAsync.when(
      data: (currentUser) {
        return billsAsync.when(
          data: (bills) {
            final calculateBalances = ref.watch(calculateUserBalancesProvider);
            return calculateBalances(userId: currentUser.id, bills: bills);
          },
          loading: () => {'youOwe': 0.0, 'owedToYou': 0.0},
          error: (_, __) => {'youOwe': 0.0, 'owedToYou': 0.0},
        );
      },
      loading: () => {'youOwe': 0.0, 'owedToYou': 0.0},
      error: (_, __) => {'youOwe': 0.0, 'owedToYou': 0.0},
    );
  });
