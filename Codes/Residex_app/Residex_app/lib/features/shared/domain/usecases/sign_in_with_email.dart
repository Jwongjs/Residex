import 'package:firebase_auth/firebase_auth.dart' show UserCredential;
import '../repositories/auth_repository.dart';

/// Use Case: Sign In With Email
/// 
/// Encapsulates the business logic for email/password sign in.
/// Single Responsibility: Handle email authentication flow.
class SignInWithEmail {
  final AuthRepository _authRepository;

  SignInWithEmail(this._authRepository);

  /// Execute the use case
  Future<UserCredential> call({
    required String email,
    required String password,
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

    // Delegate to repository
    return await _authRepository.signInWithEmail(
      email: email,
      password: password,
    );
  }
}
