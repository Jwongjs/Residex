import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';
import '../../features/shared/data/repositories/users/user_local_datasource.dart';
import '../../features/shared/data/repositories/users/user_repository_impl.dart';
import '../../features/shared/domain/repositories/users/user_repository.dart';
import '../../features/shared/data/datasources/groups/group_local_datasource.dart';
import '../../features/shared/data/repositories/groups/group_repository_impl.dart';
import '../../features/shared/domain/repositories/groups/group_repository.dart';

  // ============================================================================
  // DATABASE
  // ============================================================================

  /// Provide the database instance
  final appDatabaseProvider = Provider<AppDatabase>((ref) {
    return AppDatabase();
  });

  // ============================================================================
  // DATA SOURCES
  // ============================================================================

  /// User local data source
  final userLocalDataSourceProvider = Provider<UserLocalDataSource>((ref) {
    final database = ref.watch(appDatabaseProvider);
    return UserLocalDataSource(database);
  });

  /// Group local data source
  final groupLocalDataSourceProvider = Provider<GroupLocalDataSource>((ref) {
    final database = ref.watch(appDatabaseProvider);
    return GroupLocalDataSource(database);
  });

  // ============================================================================
  // REPOSITORIES
  // ============================================================================

  /// User repository
  final userRepositoryProvider = Provider<UserRepository>((ref) {
    final localDataSource = ref.watch(userLocalDataSourceProvider);
    return UserRepositoryImpl(localDataSource: localDataSource);
  });

  /// Group repository
  final groupRepositoryProvider = Provider<GroupRepository>((ref) {
    final localDataSource = ref.watch(groupLocalDataSourceProvider);
    return GroupRepositoryImpl(localDataSource: localDataSource);
  });