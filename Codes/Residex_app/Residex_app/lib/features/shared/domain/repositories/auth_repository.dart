import 'package:firebase_auth/firebase_auth.dart' show UserCredential;
import '../entities/user_entity.dart';

/// Auth Repository Interface (Contract)
/// 
/// Defines what authentication operations are available.
/// Implementation details (Firebase) are hidden in the data layer.
/// This allows us to swap Firebase for another auth provider without changing business logic.
abstract class AuthRepository {
  /// Stream of authentication state changes
  Stream<UserEntity?> get authStateChanges;

  /// Get current authenticated user
  UserEntity? get currentUser;

  /// Sign up with email and password
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    String? phoneNumber,
  });

  /// Sign in with email and password
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  });

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle({String? role});

  /// Sign out
  Future<void> signOut();

  /// Delete user account
  Future<void> deleteAccount();

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email);

  /// Verify email
  Future<void> verifyEmail();
}
