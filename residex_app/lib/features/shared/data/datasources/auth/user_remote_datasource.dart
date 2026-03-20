import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/users/app_user_model.dart';
import '../../../domain/entities/users/app_user.dart';

/// User Remote Data Source
///
/// Handles all Firestore operations for user profiles.
/// This is the ONLY place where Firestore is directly accessed for users.
class UserRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  UserRemoteDataSource({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Get current user's Firestore profile
  Future<AppUserModel?> getCurrentUserProfile() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return null;
      return await getUserProfile(currentUser.uid);
    } catch (e) {
      return null;
    }
  }

  /// Get user profile by UID
  Future<AppUserModel?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return AppUserModel.fromFirestore(doc);
    } catch (e) {
      return null;
    }
  }

  /// Stream user profile for real-time updates
  Stream<AppUserModel?> streamUserProfile(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return AppUserModel.fromFirestore(doc);
    });
  }

  /// Create a new Firestore user profile
  Future<void> createUserProfile({
    required String uid,
    required String email,
    required String displayName,
    required UserRole role,
    String? phoneNumber,
    String? photoURL,
  }) async {
    try {
      final userModel = AppUserModel(
        id: uid,
        name: displayName,
        avatarInitials: _computeInitials(displayName),
        email: email,
        phone: phoneNumber,
        phoneNumber: phoneNumber,
        profileImage: photoURL,
        role: role,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _firestore
          .collection('users')
          .doc(uid)
          .set(userModel.toFirestore());
    } catch (e) {
      rethrow;
    }
  }

  /// Update an existing Firestore user profile
  Future<void> updateUserProfile(AppUserModel user) async {
    try {
      await _firestore.collection('users').doc(user.id).update({
        'displayName': user.name,
        'phoneNumber': user.phone ?? user.phoneNumber ?? '',
        'photoURL': user.profileImage,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Delete user profile document
  Future<void> deleteUserProfile(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).delete();
    } catch (e) {
      rethrow;
    }
  }

  /// Check if a user profile document exists
  Future<bool> userProfileExists(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  /// Get user role from Firestore
  Future<UserRole?> getUserRole(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      final data = doc.data();
      final roleString = data?['role'] as String?;
      if (roleString == null) return null;
      return UserRole.fromJson(roleString);
    } catch (e) {
      return null;
    }
  }

  static String _computeInitials(String name) {
    final names = name.trim().split(' ');
    if (names.isEmpty) return '?';
    if (names.length == 1) return names[0][0].toUpperCase();
    return '${names.first[0]}${names.last[0]}'.toUpperCase();
  }
}
