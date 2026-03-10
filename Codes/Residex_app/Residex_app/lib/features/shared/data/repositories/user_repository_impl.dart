import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/user_repository.dart';
import '../datasources/user_remote_datasource.dart';
import '../models/user_model.dart';

/// User Repository Implementation
/// 
/// Concrete implementation of UserRepository interface.
/// Delegates to UserRemoteDataSource for Firestore operations.
/// Converts between data models and domain entities.
class UserRepositoryImpl implements UserRepository {
  final UserRemoteDataSource _dataSource;

  UserRepositoryImpl({
    required UserRemoteDataSource dataSource,
  }) : _dataSource = dataSource;

  @override
  Future<UserEntity?> getCurrentUserProfile() async {
    try {
      final userModel = await _dataSource.getCurrentUserProfile();
      return userModel?.toEntity();
    } catch (e) {
      print('❌ UserRepositoryImpl.getCurrentUserProfile error: $e');
      return null;
    }
  }

  @override
  Future<UserEntity?> getUserProfile(String uid) async {
    try {
      final userModel = await _dataSource.getUserProfile(uid);
      return userModel?.toEntity();
    } catch (e) {
      print('❌ UserRepositoryImpl.getUserProfile error: $e');
      return null;
    }
  }

  @override
  Stream<UserEntity?> streamUserProfile(String uid) {
    return _dataSource.streamUserProfile(uid).map(
      (userModel) => userModel?.toEntity(),
    );
  }

  @override
  Future<UserRole?> getUserRole(String uid) async {
    try {
      return await _dataSource.getUserRole(uid);
    } catch (e) {
      print('❌ UserRepositoryImpl.getUserRole error: $e');
      return null;
    }
  }

  @override
  Future<void> createUserProfile(UserEntity user) async {
    try {
      final userModel = UserModel.fromEntity(user);
      await _dataSource.createUserProfile(
        uid: userModel.uid,
        email: userModel.email,
        displayName: userModel.displayName,
        role: userModel.role,
        phoneNumber: userModel.phoneNumber,
        photoURL: userModel.photoURL,
      );
    } catch (e) {
      print('❌ UserRepositoryImpl.createUserProfile error: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateUserProfile(UserEntity user) async {
    try {
      final userModel = UserModel.fromEntity(user);
      await _dataSource.updateUserProfile(userModel);
    } catch (e) {
      print('❌ UserRepositoryImpl.updateUserProfile error: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteUserProfile(String uid) async {
    try {
      await _dataSource.deleteUserProfile(uid);
    } catch (e) {
      print('❌ UserRepositoryImpl.deleteUserProfile error: $e');
      rethrow;
    }
  }

  @override
  Future<bool> userProfileExists(String uid) async {
    try {
      return await _dataSource.userProfileExists(uid);
    } catch (e) {
      print('❌ UserRepositoryImpl.userProfileExists error: $e');
      return false;
    }
  }
}
