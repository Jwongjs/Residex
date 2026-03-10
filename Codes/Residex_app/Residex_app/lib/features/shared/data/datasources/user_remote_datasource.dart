import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../../domain/entities/user_entity.dart';

/// User Remote Data Source
/// 
/// Handles all Firestore operations for user data.
/// This is the ONLY place where Firestore is directly accessed for users.
class UserRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  UserRemoteDataSource({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Get current user's profile
  Future<UserModel?> getCurrentUserProfile() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('⚠️ No authenticated user');
        return null;
      }

      print('🔵 Getting profile for current user: ${currentUser.uid}');
      return await getUserProfile(currentUser.uid);
    } catch (e) {
      print('❌ Error getting current user profile: $e');
      return null;
    }
  }

  /// Get user profile by ID
  Future<UserModel?> getUserProfile(String uid) async {
    try {
      print('🔵 UserRemoteDataSource.getUserProfile called for: $uid');
      
      final doc = await _firestore.collection('users').doc(uid).get();

      if (!doc.exists) {
        print('⚠️ User document does not exist: $uid');
        return null;
      }

      final userModel = UserModel.fromFirestore(doc);
      print('✅ User profile retrieved: ${userModel.displayName}');
      return userModel;
    } catch (e) {
      print('❌ Error getting user profile: $e');
      return null;
    }
  }

  /// Stream user profile for real-time updates
  Stream<UserModel?> streamUserProfile(String uid) {
    print('🔵 UserRemoteDataSource.streamUserProfile called for: $uid');
    
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) {
        print('⚠️ User document does not exist in stream: $uid');
        return null;
      }
      return UserModel.fromFirestore(doc);
    });
  }

  /// Create user profile
  Future<void> createUserProfile({
    required String uid,
    required String email,
    required String displayName,
    required UserRole role,
    String? phoneNumber,
    String? photoURL,
  }) async {
    try {
      print('🔵 UserRemoteDataSource.createUserProfile called');
      print('🔵 UID: $uid, Role: ${role.toJson()}');

      final userModel = UserModel(
        uid: uid,
        email: email,
        displayName: displayName,
        role: role,
        phoneNumber: phoneNumber,
        photoURL: photoURL,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(uid).set(userModel.toFirestore());

      print('✅ User profile created successfully');
    } catch (e) {
      print('❌ Error creating user profile: $e');
      rethrow;
    }
  }

  /// Update user profile
  Future<void> updateUserProfile(UserModel user) async {
    try {
      print('🔵 UserRemoteDataSource.updateUserProfile called for: ${user.uid}');

      await _firestore.collection('users').doc(user.uid).update({
        'displayName': user.displayName,
        'phoneNumber': user.phoneNumber ?? '',
        'photoURL': user.photoURL,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ User profile updated successfully');
    } catch (e) {
      print('❌ Error updating user profile: $e');
      rethrow;
    }
  }

  /// Delete user profile
  Future<void> deleteUserProfile(String uid) async {
    try {
      print('🔵 UserRemoteDataSource.deleteUserProfile called for: $uid');
      await _firestore.collection('users').doc(uid).delete();
      print('✅ User profile deleted successfully');
    } catch (e) {
      print('❌ Error deleting user profile: $e');
      rethrow;
    }
  }

  /// Check if user profile exists
  Future<bool> userProfileExists(String uid) async {
    try {
      print('🔵 UserRemoteDataSource.userProfileExists called for: $uid');
      final doc = await _firestore.collection('users').doc(uid).get();
      final exists = doc.exists;
      print('✅ User profile exists: $exists');
      return exists;
    } catch (e) {
      print('❌ Error checking user profile existence: $e');
      return false;
    }
  }

  /// Get user role
  Future<UserRole?> getUserRole(String uid) async {
    try {
      print('🔵 UserRemoteDataSource.getUserRole called for: $uid');
      final doc = await _firestore.collection('users').doc(uid).get();
      
      if (!doc.exists) {
        print('⚠️ User document does not exist: $uid');
        return null;
      }

      final data = doc.data();
      final roleString = data?['role'] as String?;
      
      if (roleString == null) {
        print('⚠️ Role not found in user document');
        return null;
      }

      final role = UserRole.fromJson(roleString);
      print('✅ User role retrieved: ${role.toJson()}');
      return role;
    } catch (e) {
      print('❌ Error getting user role: $e');
      return null;
    }
  }
}
