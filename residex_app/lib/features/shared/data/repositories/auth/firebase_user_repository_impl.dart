import '../../../domain/entities/users/app_user.dart';
import '../../../domain/repositories/auth/firebase_user_repository.dart';
import '../../datasources/auth/user_remote_datasource.dart';
import '../../models/users/app_user_model.dart';

/// Firebase User Repository Implementation
///
/// Concrete implementation of FirebaseUserRepository.
/// Delegates to UserRemoteDataSource for all Firestore operations.
/// Converts between AppUserModel (data) and AppUser (domain).
class FirebaseUserRepositoryImpl implements FirebaseUserRepository {
  final UserRemoteDataSource _dataSource;

  FirebaseUserRepositoryImpl({required UserRemoteDataSource dataSource})
      : _dataSource = dataSource;

  @override
  Future<AppUser?> getCurrentUserProfile() async {
    try {
      final model = await _dataSource.getCurrentUserProfile();
      return model?.toEntity();
    } catch (e) {
      return null;
    }
  }

  @override
  Future<AppUser?> getUserProfile(String uid) async {
    try {
      final model = await _dataSource.getUserProfile(uid);
      return model?.toEntity();
    } catch (e) {
      return null;
    }
  }

  @override
  Stream<AppUser?> streamUserProfile(String uid) {
    return _dataSource.streamUserProfile(uid).map(
      (model) => model?.toEntity(),
    );
  }

  @override
  Future<UserRole?> getUserRole(String uid) async {
    try {
      return await _dataSource.getUserRole(uid);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> createUserProfile(AppUser user) async {
    try {
      await _dataSource.createUserProfile(
        uid: user.id,
        email: user.email ?? '',
        displayName: user.name,
        role: user.role,
        phoneNumber: user.phone ?? user.phoneNumber,
        photoURL: user.profileImage,
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updateUserProfile(AppUser user) async {
    try {
      final model = AppUserModel.fromEntity(user);
      await _dataSource.updateUserProfile(model);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteUserProfile(String uid) async {
    try {
      await _dataSource.deleteUserProfile(uid);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> userProfileExists(String uid) async {
    try {
      return await _dataSource.userProfileExists(uid);
    } catch (e) {
      return false;
    }
  }
}
