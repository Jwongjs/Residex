import '../../entities/users/app_user.dart';
import '../../repositories/auth/firebase_user_repository.dart';

/// Use Case: Get Current User Profile
///
/// Fetches the currently authenticated user's Firestore profile.
class GetCurrentUserProfile {
  final FirebaseUserRepository _userRepository;

  GetCurrentUserProfile(this._userRepository);

  Future<AppUser?> call() async {
    return await _userRepository.getCurrentUserProfile();
  }
}
