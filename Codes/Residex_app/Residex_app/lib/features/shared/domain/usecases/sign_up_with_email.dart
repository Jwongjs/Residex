import 'package:firebase_auth/firebase_auth.dart' show UserCredential;
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

/// Use Case: Sign Up With Email
/// 
/// Encapsulates the business logic for email/password registration.
/// Single Responsibility: Handle user registration flow.
class SignUpWithEmail {
  final AuthRepository _authRepository;

  SignUpWithEmail(this._authRepository);

  /// Execute the use case
  Future<UserCredential> call({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    String? phoneNumber,
  }) async {
    // Input validation (business rules)
    if (email.isEmpty) {
      throw Exception('Email cannot be empty');
    }
    if (password.isEmpty) {
      throw Exception('Password cannot be empty');
    }
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters');
    }
    if (displayName.isEmpty) {
      throw Exception('Display name cannot be empty');
    }

    // Delegate to repository
    return await _authRepository.signUpWithEmail(
      email: email,
      password: password,
      displayName: displayName,
      role: role,
      phoneNumber: phoneNumber,
    );
  }
}
