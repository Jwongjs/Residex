import 'package:firebase_auth/firebase_auth.dart' show UserCredential;
import '../../repositories/auth/auth_repository.dart';

/// Use Case: Sign In With Email
///
/// Encapsulates business rules for email/password sign-in.
class SignInWithEmail {
  final AuthRepository _authRepository;

  SignInWithEmail(this._authRepository);

  Future<UserCredential> call({
    required String email,
    required String password,
  }) async {
    if (email.isEmpty) throw Exception('Email cannot be empty');
    if (password.isEmpty) throw Exception('Password cannot be empty');
    if (password.length < 6) throw Exception('Password must be at least 6 characters');

    return await _authRepository.signInWithEmail(
      email: email,
      password: password,
    );
  }
}
