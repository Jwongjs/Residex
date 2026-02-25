// lib/core/di/injection.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../providers/auth_provider.dart';

// Re-export for convenience
export '../providers/auth_provider.dart';

// Database provider (Phase 2)
// final databaseProvider = Provider<AppDatabase>((ref) {
//   return AppDatabase();
// });

// Global providers registry
final appProvidersProvider = Provider((ref) {
  // Initialize all core services
  ref.watch(authServiceProvider);
  // ref.watch(databaseProvider);
  // ref.watch(storageServiceProvider);
  
  return true; // Initialization complete
});