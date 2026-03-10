// ⚠️ DEPRECATED - DO NOT USE ⚠️
// 
// This file has been moved to follow Clean Architecture principles.
// 
// OLD LOCATION (WRONG):
//   lib/core/services/auth_service.dart
// 
// NEW LOCATION (CORRECT):
//   Domain Layer: lib/features/shared/domain/
//     ├── entities/user_entity.dart (UserEntity, UserRole enum)
//     ├── repositories/auth_repository.dart (interface)
//     ├── repositories/user_repository.dart (interface)
//     └── usecases/
//         ├── sign_in_with_email.dart
//         ├── sign_up_with_email.dart
//         ├── sign_out.dart
//         ├── get_current_user_profile.dart
//         └── stream_user_profile.dart
// 
//   Data Layer: lib/features/shared/data/
//     ├── models/user_model.dart (DTO)
//     ├── datasources/
//     │   ├── auth_remote_datasource.dart (Firebase Auth)
//     │   └── user_remote_datasource.dart (Firestore)
//     └── repositories/
//         ├── auth_repository_impl.dart
//         └── user_repository_impl.dart
// 
//   Presentation Layer: lib/features/shared/presentation/
//     └── providers/auth_providers.dart (all Riverpod providers)
// 
// MIGRATION GUIDE:
// 
//   Before (OLD):
//     import '../../core/services/auth_service.dart';
//     final authService = ref.read(authServiceProvider);
//     await authService.signInWithEmail(email: email, password: password);
// 
//   After (NEW):
//     import '../../features/shared/presentation/providers/auth_providers.dart';
//     final authController = ref.read(authControllerProvider);
//     await authController.signInWithEmail(email: email, password: password);
// 
// WHY THIS CHANGE?
//   - core/ should only contain technical utilities (theme, widgets, formatters)
//   - Auth is a BUSINESS FEATURE, not infrastructure
//   - Clean Architecture: Presentation → Domain ← Data
//   - Domain layer has NO external dependencies (testable!)
//   - Data layer implementation can be swapped (Firebase → Supabase)
//   - Type safety with UserRole enum instead of strings
// 
// This file kept for reference only. Will be deleted in future release.

// @Deprecated('Use features/shared/presentation/providers/auth_providers.dart instead')
// class AuthService {
//   AuthService() {
//     throw Exception(
//       '⚠️ AuthService is deprecated!\n\n'
//       'Import from: features/shared/presentation/providers/auth_providers.dart\n'
//       'Use: ref.read(authControllerProvider)\n\n'
//       'See file header comments for migration guide.',
//     );
//   }
// }

//       print('✅ Firebase Auth user created: ${userCredential.user?.uid}');

//       // Update display name
//       await userCredential.user?.updateDisplayName(displayName);
//       print('✅ Display name updated');

//       // Create user document in Firestore
//       await _firestore.collection('users').doc(userCredential.user!.uid).set({
//         'uid': userCredential.user!.uid,
//         'email': email,
//         'displayName': displayName,
//         'role': role,
//         'phoneNumber': phoneNumber ?? '',
//         'createdAt': FieldValue.serverTimestamp(),
//         'updatedAt': FieldValue.serverTimestamp(),
//       });

//       print('✅ Firestore user document created');

//       return userCredential;
//     } on FirebaseAuthException catch (e) {
//       print('❌ FirebaseAuthException: ${e.code}');
//       print('❌ Message: ${e.message}');
//       throw _handleAuthException(e);
//     } catch (e) {
//       print('❌ Unexpected error: $e');
//       rethrow;
//     }
//   }

//   /// Sign in with email and password
//   Future<UserCredential> signInWithEmail({
//     required String email,
//     required String password,
//   }) async {
//     try {
//       print('🔵 AuthService.signInWithEmail called');
//       print('🔵 Email: $email');

//       final userCredential = await _auth.signInWithEmailAndPassword(
//         email: email,
//         password: password,
//       );

//       print('✅ User signed in: ${userCredential.user?.uid}');
//       return userCredential;
//     } on FirebaseAuthException catch (e) {
//       print('❌ FirebaseAuthException: ${e.code}');
//       print('❌ Message: ${e.message}');
//       throw _handleAuthException(e);
//     }
//   }

//   /// Sign in with Google
//   Future<UserCredential?> signInWithGoogle({String? role}) async {
//     try {
//       print('🔵 AuthService.signInWithGoogle called');

//       // Trigger the authentication flow
//       final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

//       if (googleUser == null) {
//         print('⚠️ Google sign in cancelled by user');
//         throw Exception('Google sign in cancelled');
//       }

//       // Obtain the auth details from the request
//       final GoogleSignInAuthentication googleAuth =
//           await googleUser.authentication;

//       // Create a new credential
//       final credential = GoogleAuthProvider.credential(
//         accessToken: googleAuth.accessToken,
//         idToken: googleAuth.idToken,
//       );

//       // Sign in to Firebase with the Google credential
//       final userCredential = await _auth.signInWithCredential(credential);

//       print('✅ Google sign in successful: ${userCredential.user?.uid}');

//       // Check if user document exists, if not create it
//       final userDoc = await _firestore
//           .collection('users')
//           .doc(userCredential.user!.uid)
//           .get();

//       if (!userDoc.exists && role != null) {
//         await _firestore.collection('users').doc(userCredential.user!.uid).set({
//           'uid': userCredential.user!.uid,
//           'email': userCredential.user!.email,
//           'displayName': userCredential.user!.displayName,
//           'role': role,
//           'photoURL': userCredential.user!.photoURL,
//           'createdAt': FieldValue.serverTimestamp(),
//           'updatedAt': FieldValue.serverTimestamp(),
//         });
//         print('✅ New Google user document created with role: $role');
//       }

//       return userCredential;
//     } catch (e) {
//       print('❌ Google sign in error: $e');
//       rethrow;
//     }
//   }

//   /// Get user role from Firestore
//   Future<String?> getUserRole(String uid) async {
//     try {
//       print('🔵 Getting user role for: $uid');
//       final userDoc = await _firestore.collection('users').doc(uid).get();
//       final role = userDoc.data()?['role'] as String?;
//       print('✅ User role: $role');
//       return role;
//     } catch (e) {
//       print('❌ Error getting user role: $e');
//       return null;
//     }
//   }

//   /// Sign out
//   Future<void> signOut() async {
//     try {
//       print('🔵 Signing out user');
//       await Future.wait([
//         _auth.signOut(),
//         _googleSignIn.signOut(),
//       ]);
//       print('✅ User signed out');
//     } catch (e) {
//       print('❌ Sign out error: $e');
//       rethrow;
//     }
//   }

//   /// Delete account
//   Future<void> deleteAccount() async {
//     try {
//       final user = _auth.currentUser;
//       if (user != null) {
//         print('🔵 Deleting account: ${user.uid}');

//         // Delete user document from Firestore
//         await _firestore.collection('users').doc(user.uid).delete();
//         print('✅ Firestore document deleted');

//         // Delete user from Firebase Auth
//         await user.delete();
//         print('✅ Firebase Auth user deleted');
//       }
//     } catch (e) {
//       print('❌ Delete account error: $e');
//       rethrow;
//     }
//   }

//   /// Handle Firebase Auth exceptions
//   String _handleAuthException(FirebaseAuthException e) {
//     switch (e.code) {
//       case 'weak-password':
//         return 'The password provided is too weak (min 6 characters).';
//       case 'email-already-in-use':
//         return 'An account already exists for that email.';
//       case 'user-not-found':
//         return 'No user found for that email.';
//       case 'wrong-password':
//         return 'Wrong password provided.';
//       case 'invalid-email':
//         return 'The email address is not valid.';
//       case 'user-disabled':
//         return 'This user has been disabled.';
//       case 'too-many-requests':
//         return 'Too many attempts. Please try again later.';
//       case 'operation-not-allowed':
//         return 'Email/Password sign-in is not enabled.';
//       case 'network-request-failed':
//         return 'Network error. Please check your internet connection.';
//       default:
//         return e.message ?? 'Authentication failed. Please try again.';
//     }
//   }
// }