import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../datasources/user_remote_datasource.dart';

/// Auth Repository Implementation
/// 
/// Concrete implementation of AuthRepository interface.
/// Coordinates between auth and user datasources.
/// Implements the domain contract using Firebase services.
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _authDataSource;
  final UserRemoteDataSource _userDataSource;

  AuthRepositoryImpl({
    required AuthRemoteDataSource authDataSource,
    required UserRemoteDataSource userDataSource,
  })  : _authDataSource = authDataSource,
        _userDataSource = userDataSource;

  @override
  Stream<UserEntity?> get authStateChanges {
    return _authDataSource.authStateChanges.asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;
      final userModel = await _userDataSource.getUserProfile(firebaseUser.uid);
      return userModel?.toEntity();
    });
  }

  @override
  UserEntity? get currentUser {
    final firebaseUser = _authDataSource.currentUser;
    if (firebaseUser == null) return null;
    
    // Note: This is synchronous but we need to fetch from Firestore
    // Consider using a provider that watches the stream instead
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
      // Step 1: Create Firebase Auth user
      final userCredential = await _authDataSource.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );

      // Step 2: Create Firestore user profile
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
      print('❌ AuthRepositoryImpl.signUpWithEmail error: $e');
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
      print('❌ AuthRepositoryImpl.signInWithEmail error: $e');
      rethrow;
    }
  }

  @override
  Future<UserCredential?> signInWithGoogle({String? role}) async {
    try {
      final userCredential = await _authDataSource.signInWithGoogle();
      
      if (userCredential == null) return null;

      // Check if user profile exists, if not create it
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
      print('❌ AuthRepositoryImpl.signInWithGoogle error: $e');
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _authDataSource.signOut();
    } catch (e) {
      print('❌ AuthRepositoryImpl.signOut error: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      final user = _authDataSource.currentUser;
      if (user != null) {
        // Delete Firestore profile first
        await _userDataSource.deleteUserProfile(user.uid);
        // Then delete Firebase Auth account
        await _authDataSource.deleteAccount();
      }
    } catch (e) {
      print('❌ AuthRepositoryImpl.deleteAccount error: $e');
      rethrow;
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _authDataSource.sendPasswordResetEmail(email);
    } catch (e) {
      print('❌ AuthRepositoryImpl.sendPasswordResetEmail error: $e');
      rethrow;
    }
  }

  @override
  Future<void> verifyEmail() async {
    try {
      await _authDataSource.verifyEmail();
    } catch (e) {
      print('❌ AuthRepositoryImpl.verifyEmail error: $e');
      rethrow;
    }
  }
}
