// ⚠️ DEPRECATED - DO NOT USE ⚠️
// 
// This file has been moved to follow Clean Architecture principles.
// 
// OLD LOCATION (WRONG):
//   lib/core/providers/auth_provider.dart
// 
// NEW LOCATION (CORRECT):
//   lib/features/shared/presentation/providers/auth_providers.dart
// 
// MIGRATION GUIDE:
// 
//   Import Change:
//     OLD: import '../../core/providers/auth_provider.dart';
//     NEW: import '../../features/shared/presentation/providers/auth_providers.dart';
// 
//   Provider Changes:
//     OLD                          → NEW
//     ───────────────────────────────────────────────────────────
//     authServiceProvider          → authControllerProvider
//     authStateProvider            → firebaseAuthStateProvider (Firebase User)
//                                  → authStateProvider (UserEntity)
//     currentUserProvider          → currentFirebaseUserProvider (Firebase User)
//                                  → currentUserProvider (UserEntity) 
//     userRoleProvider             → userRoleProvider(uid).future (returns UserRole enum)
// 
//   Type Changes:
//     OLD: String role = 'landlord'
//     NEW: UserRole role = UserRole.landlord
// 
//   Method Changes:
//     OLD: await ref.read(authServiceProvider).signInWithEmail(...)
//     NEW: await ref.read(authControllerProvider).signInWithEmail(...)
// 
// WHY THIS CHANGE?
//   - Proper Clean Architecture layering
//   - Auth is a business feature, not core infrastructure  
//   - Domain entities (UserEntity, UserRole) provide type safety
//   - Use cases encapsulate business logic
//   - Testable without Firebase mocks
// 
// This file kept for reference only. Will be deleted in future release.

import 'package:flutter_riverpod/flutter_riverpod.dart';

// Re-export new providers for backward compatibility during migration
export '../../features/shared/presentation/providers/auth_providers.dart';

@Deprecated('Import from features/shared/presentation/providers/auth_providers.dart instead')
final authServiceProvider = Provider((ref) {
  throw Exception(
    '⚠️ authServiceProvider is deprecated!\n\n'
    'Import from: features/shared/presentation/providers/auth_providers.dart\n'
    'Use: authControllerProvider\n\n'
    'See file header comments for migration guide.',
  );
});