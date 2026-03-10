import '../entities/user_entity.dart';

/// User Repository Interface (Contract)
/// 
/// Defines what user data operations are available.
/// Implementation details (Firestore) are hidden in the data layer.
abstract class UserRepository {
  /// Get current authenticated user's profile
  Future<UserEntity?> getCurrentUserProfile();

  /// Get user profile by ID
  Future<UserEntity?> getUserProfile(String uid);

  /// Stream user profile for real-time updates
  Stream<UserEntity?> streamUserProfile(String uid);

  /// Get user role
  Future<UserRole?> getUserRole(String uid);

  /// Create user profile
  Future<void> createUserProfile(UserEntity user);

  /// Update user profile
  Future<void> updateUserProfile(UserEntity user);

  /// Delete user profile
  Future<void> deleteUserProfile(String uid);

  /// Check if user profile exists
  Future<bool> userProfileExists(String uid);
}
