import 'package:firebase_auth/firebase_auth.dart' show UserCredential;
import '../../entities/users/app_user.dart';

/// Auth Repository Interface (Contract)
///
/// Defines what authentication operations are available.
/// Implementation details (Firebase) are hidden in the data layer.
abstract class AuthRepository {
  /// Stream of authentication state changes (AppUser domain entity)
  Stream<AppUser?> get authStateChanges;

  /// Get current authenticated user (sync — may be null if Firestore hasn't loaded yet)
  AppUser? get currentUser;

  /// Sign up with email and password, creating Firestore profile
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

  /// Sign in with Google (creates Firestore profile if new user)
  Future<UserCredential?> signInWithGoogle({String? role});

  /// Sign out from Firebase and Google
  Future<void> signOut();

  /// Delete user account and Firestore profile
  Future<void> deleteAccount();

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email);

  /// Send email verification to current user
  Future<void> verifyEmail();
}
