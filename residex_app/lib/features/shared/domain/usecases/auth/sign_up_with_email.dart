import 'package:firebase_auth/firebase_auth.dart' show UserCredential;
import '../../entities/users/app_user.dart';
import '../../repositories/auth/auth_repository.dart';

/// Use Case: Sign Up With Email
///
/// Encapsulates business rules for email/password registration.
class SignUpWithEmail {
  final AuthRepository _authRepository;

  SignUpWithEmail(this._authRepository);

  Future<UserCredential> call({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    String? phoneNumber,
  }) async {
    if (email.isEmpty) throw Exception('Email cannot be empty');
    if (password.isEmpty) throw Exception('Password cannot be empty');
    if (password.length < 6) throw Exception('Password must be at least 6 characters');
    if (displayName.isEmpty) throw Exception('Display name cannot be empty');

    return await _authRepository.signUpWithEmail(
      email: email,
      password: password,
      displayName: displayName,
      role: role,
      phoneNumber: phoneNumber,
    );
  }
}
