import '../entities/user_entity.dart';
import '../repositories/user_repository.dart';

/// Use Case: Stream User Profile
/// 
/// Streams real-time updates of a user's profile.
/// Single Responsibility: Provide real-time user data.
class StreamUserProfile {
  final UserRepository _userRepository;

  StreamUserProfile(this._userRepository);

  /// Execute the use case
  Stream<UserEntity?> call(String uid) {
    return _userRepository.streamUserProfile(uid);
  }
}
