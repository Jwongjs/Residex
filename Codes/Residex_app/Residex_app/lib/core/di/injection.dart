// lib/core/di/injection.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/shared/presentation/providers/auth_providers.dart';

// Re-export for convenience
export '../../features/shared/presentation/providers/auth_providers.dart';

// Database provider (Phase 2)
// final databaseProvider = Provider<AppDatabase>((ref) {
//   return AppDatabase();
// });

// Global providers registry
final appProvidersProvider = Provider((ref) {
  // Initialize all core services
  ref.watch(authRemoteDataSourceProvider);
  ref.watch(userRemoteDataSourceProvider);
  // ref.watch(databaseProvider);
  // ref.watch(storageServiceProvider);
  
  return true; // Initialization complete
});