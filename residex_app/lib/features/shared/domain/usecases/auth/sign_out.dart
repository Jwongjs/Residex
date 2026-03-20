import '../../repositories/auth/auth_repository.dart';

/// Use Case: Sign Out
class SignOut {
  final AuthRepository _authRepository;

  SignOut(this._authRepository);

  Future<void> call() async {
    await _authRepository.signOut();
  }
}
