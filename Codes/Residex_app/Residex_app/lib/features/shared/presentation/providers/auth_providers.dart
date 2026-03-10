import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/user_repository.dart';
import '../../domain/usecases/sign_in_with_email.dart';
import '../../domain/usecases/sign_up_with_email.dart';
import '../../domain/usecases/sign_out.dart';
import '../../domain/usecases/get_current_user_profile.dart';
import '../../domain/usecases/stream_user_profile.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/datasources/user_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/user_repository_impl.dart';

// ============================================================================
// DATA LAYER PROVIDERS
// ============================================================================

/// Auth Remote Data Source Provider
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource();
});

/// User Remote Data Source Provider
final userRemoteDataSourceProvider = Provider<UserRemoteDataSource>((ref) {
  return UserRemoteDataSource();
});

/// Auth Repository Provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    authDataSource: ref.watch(authRemoteDataSourceProvider),
    userDataSource: ref.watch(userRemoteDataSourceProvider),
  );
});

/// User Repository Provider
final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepositoryImpl(
    dataSource: ref.watch(userRemoteDataSourceProvider),
  );
});

// ============================================================================
// USE CASE PROVIDERS
// ============================================================================

/// Sign In With Email Use Case Provider
final signInWithEmailUseCaseProvider = Provider<SignInWithEmail>((ref) {
  return SignInWithEmail(ref.watch(authRepositoryProvider));
});

/// Sign Up With Email Use Case Provider
final signUpWithEmailUseCaseProvider = Provider<SignUpWithEmail>((ref) {
  return SignUpWithEmail(ref.watch(authRepositoryProvider));
});

/// Sign Out Use Case Provider
final signOutUseCaseProvider = Provider<SignOut>((ref) {
  return SignOut(ref.watch(authRepositoryProvider));
});

/// Get Current User Profile Use Case Provider
final getCurrentUserProfileUseCaseProvider = Provider<GetCurrentUserProfile>((ref) {
  return GetCurrentUserProfile(ref.watch(userRepositoryProvider));
});

/// Stream User Profile Use Case Provider
final streamUserProfileUseCaseProvider = Provider<StreamUserProfile>((ref) {
  return StreamUserProfile(ref.watch(userRepositoryProvider));
});

// ============================================================================
// AUTH STATE PROVIDERS
// ============================================================================

/// Firebase Auth State Provider (raw Firebase User)
/// For backward compatibility with existing code
final firebaseAuthStateProvider = StreamProvider<firebase_auth.User?>((ref) {
  final authDataSource = ref.watch(authRemoteDataSourceProvider);
  return authDataSource.authStateChanges;
});

/// Auth State Provider (Domain Entity)
/// Streams UserEntity instead of Firebase User
final authStateProvider = StreamProvider<UserEntity?>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return authRepository.authStateChanges;
});

/// Current Firebase User Provider (for backward compatibility)
final currentFirebaseUserProvider = Provider<firebase_auth.User?>((ref) {
  final authState = ref.watch(firebaseAuthStateProvider);
  return authState.when(
    data: (user) => user,
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Current User Provider (Domain Entity)
final currentUserProvider = Provider<UserEntity?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) => user,
    loading: () => null,
    error: (_, __) => null,
  );
});

// ============================================================================
// USER PROFILE PROVIDERS
// ============================================================================

/// Current User Profile Provider (Future)
final currentUserProfileProvider = FutureProvider<UserEntity?>((ref) async {
  final getCurrentUserProfile = ref.watch(getCurrentUserProfileUseCaseProvider);
  return await getCurrentUserProfile();
});

/// Current User Profile Stream Provider
final currentUserProfileStreamProvider = StreamProvider<UserEntity?>((ref) {
  final firebaseUser = ref.watch(currentFirebaseUserProvider);
  if (firebaseUser == null) return Stream.value(null);

  final streamUserProfile = ref.watch(streamUserProfileUseCaseProvider);
  return streamUserProfile(firebaseUser.uid);
});

/// User Profile Stream Provider (by UID)
final userProfileStreamProvider = StreamProvider.family<UserEntity?, String>((ref, uid) {
  final streamUserProfile = ref.watch(streamUserProfileUseCaseProvider);
  return streamUserProfile(uid);
});

// ============================================================================
// USER ROLE PROVIDERS
// ============================================================================

/// User Role Provider (by UID)
final userRoleProvider = FutureProvider.family<UserRole?, String>((ref, uid) async {
  final userRepository = ref.watch(userRepositoryProvider);
  return await userRepository.getUserRole(uid);
});

/// Current User Role Provider
final currentUserRoleProvider = FutureProvider<UserRole?>((ref) async {
  final firebaseUser = ref.watch(currentFirebaseUserProvider);
  if (firebaseUser == null) return null;

  final userRepository = ref.watch(userRepositoryProvider);
  return await userRepository.getUserRole(firebaseUser.uid);
});

// ============================================================================
// AUTH CONTROLLER (for UI actions)
// ============================================================================

/// Auth Controller Provider
/// Provides methods for UI to call authentication actions
final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(ref);
});

/// Auth Controller
/// Handles authentication actions from UI
class AuthController {
  final Ref _ref;

  AuthController(this._ref);

  /// Sign in with email and password
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final signInUseCase = _ref.read(signInWithEmailUseCaseProvider);
    await signInUseCase(email: email, password: password);
  }

  /// Sign up with email and password
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    String? phoneNumber,
  }) async {
    final signUpUseCase = _ref.read(signUpWithEmailUseCaseProvider);
    await signUpUseCase(
      email: email,
      password: password,
      displayName: displayName,
      role: role,
      phoneNumber: phoneNumber,
    );
  }

  /// Sign out
  Future<void> signOut() async {
    final signOutUseCase = _ref.read(signOutUseCaseProvider);
    await signOutUseCase();
  }
}
