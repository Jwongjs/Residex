import '../entities/user_entity.dart';
import '../repositories/user_repository.dart';

/// Use Case: Get Current User Profile
/// 
/// Fetches the current authenticated user's profile data.
/// Single Responsibility: Retrieve current user information.
class GetCurrentUserProfile {
  final UserRepository _userRepository;

  GetCurrentUserProfile(this._userRepository);

  /// Execute the use case
  Future<UserEntity?> call() async {
    return await _userRepository.getCurrentUserProfile();
  }
}
