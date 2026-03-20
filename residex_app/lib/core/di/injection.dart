import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';
import '../../features/shared/data/repositories/users/user_local_datasource.dart';
import '../../features/shared/data/repositories/users/user_repository_impl.dart';
import '../../features/shared/domain/repositories/users/user_repository.dart';
import '../../features/shared/data/datasources/groups/group_local_datasource.dart';
import '../../features/shared/data/repositories/groups/group_repository_impl.dart';
import '../../features/shared/domain/repositories/groups/group_repository.dart';
import '../../features/tenant/data/datasources/bills/bill_local_datasource.dart';
import '../../features/tenant/data/repositories/bills/bill_repository_impl.dart';
import '../../features/tenant/domain/repositories/bills/bill_repository.dart';
import '../../features/tenant/domain/usecases/bills/calculate_bill_splits.dart';
import '../../features/tenant/domain/usecases/bills/calculate_user_balances.dart';
import '../../features/tenant/domain/usecases/bills/save_completed_bill.dart';
import '../../features/tenant/domain/usecases/bills/update_payment_status.dart';
import '../../features/landlord/data/datasources/property_remote_datasource.dart';
import '../../features/landlord/data/repositories/property_repository_impl.dart';

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

  /// Bill local data source
  final billLocalDataSourceProvider = Provider<BillLocalDataSource>((ref) {
    final database = ref.watch(appDatabaseProvider);
    return BillLocalDataSource(database);
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

  /// Bill repository
  final billRepositoryProvider = Provider<BillRepository>((ref) {
    final localDataSource = ref.watch(billLocalDataSourceProvider);
    return BillRepositoryImpl(localDataSource: localDataSource);
  });

  // ============================================================================
  // USE CASES
  // ============================================================================

  /// Calculate bill splits use case
  final calculateBillSplitsProvider = Provider<CalculateBillSplits>((ref) {
    return CalculateBillSplits();
  });

  /// Calculate user balances use case
  final calculateUserBalancesProvider = Provider<CalculateUserBalances>((ref) {
    return CalculateUserBalances();
  });

  /// Save completed bill use case
  final saveCompletedBillProvider = Provider<SaveCompletedBill>((ref) {
    final repository = ref.watch(billRepositoryProvider);
    return SaveCompletedBill(repository);
  });

  /// Update payment status use case
  final updatePaymentStatusProvider = Provider<UpdatePaymentStatus>((ref) {
    final repository = ref.watch(billRepositoryProvider);
    return UpdatePaymentStatus(repository);
  });