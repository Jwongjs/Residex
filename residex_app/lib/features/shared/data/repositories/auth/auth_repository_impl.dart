import 'package:firebase_auth/firebase_auth.dart';
import '../../../domain/entities/users/app_user.dart';
import '../../../domain/repositories/auth/auth_repository.dart';
import '../../datasources/auth/auth_remote_datasource.dart';
import '../../datasources/auth/user_remote_datasource.dart';

/// Auth Repository Implementation
///
/// Coordinates between AuthRemoteDataSource (Firebase Auth)
/// and UserRemoteDataSource (Firestore profiles).
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _authDataSource;
  final UserRemoteDataSource _userDataSource;

  AuthRepositoryImpl({
    required AuthRemoteDataSource authDataSource,
    required UserRemoteDataSource userDataSource,
  })  : _authDataSource = authDataSource,
        _userDataSource = userDataSource;

  @override
  Stream<AppUser?> get authStateChanges {
    return _authDataSource.authStateChanges.asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;
      final userModel = await _userDataSource.getUserProfile(firebaseUser.uid);
      return userModel?.toEntity();
    });
  }

  @override
  AppUser? get currentUser {
    // Synchronous access — Firestore profile not available synchronously.
    // Use authStateChanges stream or currentUserProfileProvider instead.
    return null;
  }

  @override
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    String? phoneNumber,
  }) async {
    try {
      final userCredential = await _authDataSource.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );

      await _userDataSource.createUserProfile(
        uid: userCredential.user!.uid,
        email: email,
        displayName: displayName,
        role: role,
        phoneNumber: phoneNumber,
        photoURL: userCredential.user!.photoURL,
      );

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _authDataSource.signInWithEmail(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<UserCredential?> signInWithGoogle({String? role}) async {
    try {
      final userCredential = await _authDataSource.signInWithGoogle();
      if (userCredential == null) return null;

      final exists = await _userDataSource.userProfileExists(
        userCredential.user!.uid,
      );

      if (!exists && role != null) {
        await _userDataSource.createUserProfile(
          uid: userCredential.user!.uid,
          email: userCredential.user!.email!,
          displayName: userCredential.user!.displayName ?? 'User',
          role: UserRole.fromJson(role),
          photoURL: userCredential.user!.photoURL,
        );
      }

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    await _authDataSource.signOut();
  }

  @override
  Future<void> deleteAccount() async {
    final user = _authDataSource.currentUser;
    if (user != null) {
      await _userDataSource.deleteUserProfile(user.uid);
      await _authDataSource.deleteAccount();
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _authDataSource.sendPasswordResetEmail(email);
  }

  @override
  Future<void> verifyEmail() async {
    await _authDataSource.verifyEmail();
  }
}
