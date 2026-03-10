import '../repositories/auth_repository.dart';

/// Use Case: Sign Out
/// 
/// Encapsulates the business logic for signing out.
/// Single Responsibility: Handle sign out flow.
class SignOut {
  final AuthRepository _authRepository;

  SignOut(this._authRepository);

  /// Execute the use case
  Future<void> call() async {
    await _authRepository.signOut();
  }
}
