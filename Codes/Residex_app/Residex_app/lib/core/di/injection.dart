import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Centralized Dependency Injection Container
/// 
/// All providers are defined here for:
/// - Database connections
/// - Repositories (data layer)
/// - Use cases (business logic)
/// - API clients
/// 
/// Usage example:
/// ```dart
/// final repository = ref.watch(propertyRepositoryProvider);
/// final properties = await repository.getAllProperties();
/// ```

// // Database
// final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

// // Repositories
// final propertyRepositoryProvider = Provider<PropertyRepository>((ref) {
//   final db = ref.watch(databaseProvider);
//   return PropertyRepositoryImpl(db);
// });

// final billRepositoryProvider = Provider<BillRepository>((ref) {
//   final db = ref.watch(databaseProvider);
//   return BillRepositoryImpl(db);
// });

// API Clients (when needed)
// final apiClientProvider = Provider<ApiClient>((ref) {
//   return ApiClient(baseUrl: AppConstants.baseUrl);
// });