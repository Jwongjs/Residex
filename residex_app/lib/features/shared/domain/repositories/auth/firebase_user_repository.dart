import '../../entities/users/app_user.dart';

/// Firebase User Repository Interface (Contract)
///
/// Defines Firestore user profile operations.
/// Separate from the Drift-based UserRepository used for the local friends cache.
abstract class FirebaseUserRepository {
  /// Get the currently authenticated user's Firestore profile
  Future<AppUser?> getCurrentUserProfile();

  /// Get any user's Firestore profile by UID
  Future<AppUser?> getUserProfile(String uid);

  /// Stream a user's Firestore profile for real-time updates
  Stream<AppUser?> streamUserProfile(String uid);

  /// Get a user's role from Firestore
  Future<UserRole?> getUserRole(String uid);

  /// Create a new Firestore user profile document
  Future<void> createUserProfile(AppUser user);

  /// Update an existing Firestore user profile document
  Future<void> updateUserProfile(AppUser user);

  /// Delete a Firestore user profile document
  Future<void> deleteUserProfile(String uid);

  /// Check if a Firestore user profile document exists
  Future<bool> userProfileExists(String uid);
}
