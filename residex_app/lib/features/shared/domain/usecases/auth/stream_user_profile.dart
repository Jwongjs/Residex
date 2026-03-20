import '../../entities/users/app_user.dart';
import '../../repositories/auth/firebase_user_repository.dart';

/// Use Case: Stream User Profile
///
/// Streams real-time updates of a user's Firestore profile.
class StreamUserProfile {
  final FirebaseUserRepository _userRepository;

  StreamUserProfile(this._userRepository);

  Stream<AppUser?> call(String uid) {
    return _userRepository.streamUserProfile(uid);
  }
}
