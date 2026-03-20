import 'package:flutter_riverpod/flutter_riverpod.dart';
  import '../../../../core/di/injection.dart';
  import '../../domain/entities/users/app_user.dart';

  /// Provider for friends only (non-guest users with phone numbers)
  final friendsProvider = FutureProvider<List<AppUser>>((ref) async {
    final repository = ref.watch(userRepositoryProvider);
    final result = await repository.getAllUsers();

    return result.fold(
      (failure) => throw Exception(failure.message),
      (users) => users.where((u) => !u.isGuest).toList(),
    );
  });