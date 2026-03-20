  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import '../../../../core/di/injection.dart';
  import '../../domain/entities/users/app_user.dart';

  /// Provider for all users (friends list)
  final usersProvider = FutureProvider<List<AppUser>>((ref) async {
    final repository = ref.watch(userRepositoryProvider);
    final result = await repository.getAllUsers();

    return result.fold(
      (failure) => throw Exception(failure.message),
      (users) => users,
    );
  });

  /// Provider for current user
  final currentUserProvider = FutureProvider<AppUser>((ref) async {
    final repository = ref.watch(userRepositoryProvider);
    final result = await repository.getCurrentUser();

    return result.fold(
      (failure) => throw Exception(failure.message),
      (user) => user,
    );
  });

  /// Provider for a specific user by ID
  final userByIdProvider = FutureProvider.family<AppUser?, String>((ref, userId) async {
    final repository = ref.watch(userRepositoryProvider);
    final result = await repository.getUserById(userId);

    return result.fold(
      (failure) => throw Exception(failure.message),
      (user) => user,
    );
  });