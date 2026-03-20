import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../domain/entities/users/app_user.dart';
import '../../domain/repositories/auth/auth_repository.dart';
import '../../domain/repositories/auth/firebase_user_repository.dart';
import '../../domain/usecases/auth/sign_in_with_email.dart';
import '../../domain/usecases/auth/sign_up_with_email.dart';
import '../../domain/usecases/auth/sign_out.dart';
import '../../domain/usecases/auth/get_current_user_profile.dart';
import '../../domain/usecases/auth/stream_user_profile.dart';
import '../../data/datasources/auth/auth_remote_datasource.dart';
import '../../data/datasources/auth/user_remote_datasource.dart';
import '../../data/repositories/auth/auth_repository_impl.dart';
import '../../data/repositories/auth/firebase_user_repository_impl.dart';

// ============================================================================
// DEV BYPASS PROVIDER (skips Firebase auth for quick UI testing)
// ============================================================================

class _DevBypassNotifier extends Notifier<UserRole?> {
  @override
  UserRole? build() => null;
  void bypass(UserRole role) => state = role;
  void clear() => state = null;
}

final devBypassProvider =
    NotifierProvider<_DevBypassNotifier, UserRole?>(_DevBypassNotifier.new);

// ============================================================================
// DATA LAYER PROVIDERS
// ============================================================================

/// Firebase Auth data source
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource();
});

/// Firestore user data source
final firebaseUserDataSourceProvider = Provider<UserRemoteDataSource>((ref) {
  return UserRemoteDataSource();
});

/// Auth repository (coordinates Firebase Auth + Firestore)
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    authDataSource: ref.watch(authRemoteDataSourceProvider),
    userDataSource: ref.watch(firebaseUserDataSourceProvider),
  );
});

/// Firebase user repository (Firestore CRUD for user profiles)
/// Named firebaseUserRepositoryProvider to avoid conflict with the Drift-based
/// userRepositoryProvider in injection.dart (used for local friends cache).
final firebaseUserRepositoryProvider = Provider<FirebaseUserRepository>((ref) {
  return FirebaseUserRepositoryImpl(
    dataSource: ref.watch(firebaseUserDataSourceProvider),
  );
});

// ============================================================================
// USE CASE PROVIDERS
// ============================================================================

final signInWithEmailUseCaseProvider = Provider<SignInWithEmail>((ref) {
  return SignInWithEmail(ref.watch(authRepositoryProvider));
});

final signUpWithEmailUseCaseProvider = Provider<SignUpWithEmail>((ref) {
  return SignUpWithEmail(ref.watch(authRepositoryProvider));
});

final signOutUseCaseProvider = Provider<SignOut>((ref) {
  return SignOut(ref.watch(authRepositoryProvider));
});

final getCurrentUserProfileUseCaseProvider =
    Provider<GetCurrentUserProfile>((ref) {
  return GetCurrentUserProfile(ref.watch(firebaseUserRepositoryProvider));
});

final streamUserProfileUseCaseProvider = Provider<StreamUserProfile>((ref) {
  return StreamUserProfile(ref.watch(firebaseUserRepositoryProvider));
});

// ============================================================================
// AUTH STATE PROVIDERS
// ============================================================================

/// Raw Firebase Auth user stream (for low-level Firebase operations)
final firebaseAuthStateProvider =
    StreamProvider<firebase_auth.User?>((ref) {
  final authDataSource = ref.watch(authRemoteDataSourceProvider);
  return authDataSource.authStateChanges;
});

/// Domain-level auth state stream (AppUser entity)
final authStateProvider = StreamProvider<AppUser?>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return authRepository.authStateChanges;
});

/// Current raw Firebase user (sync convenience provider)
final currentFirebaseUserProvider = Provider<firebase_auth.User?>((ref) {
  return ref.watch(firebaseAuthStateProvider).when(
    data: (user) => user,
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Current authenticated user as AppUser domain entity (sync, nullable)
/// Use this for role-based routing and quick auth checks.
final authUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authStateProvider).when(
    data: (user) => user,
    loading: () => null,
    error: (_, __) => null,
  );
});

// ============================================================================
// USER PROFILE PROVIDERS
// ============================================================================

/// Current user's Firestore profile (one-shot Future)
final currentUserProfileProvider = FutureProvider<AppUser?>((ref) async {
  final useCase = ref.watch(getCurrentUserProfileUseCaseProvider);
  return await useCase();
});

/// Current user's Firestore profile as a real-time stream
final currentUserProfileStreamProvider = StreamProvider<AppUser?>((ref) {
  final firebaseUser = ref.watch(currentFirebaseUserProvider);
  if (firebaseUser == null) return Stream.value(null);
  final streamUserProfile = ref.watch(streamUserProfileUseCaseProvider);
  return streamUserProfile(firebaseUser.uid);
});

/// Any user's Firestore profile as a real-time stream (by UID)
final userProfileStreamProvider =
    StreamProvider.family<AppUser?, String>((ref, uid) {
  final streamUserProfile = ref.watch(streamUserProfileUseCaseProvider);
  return streamUserProfile(uid);
});

// ============================================================================
// USER ROLE PROVIDERS
// ============================================================================

/// Get a user's role by UID (Future)
final userRoleProvider =
    FutureProvider.family<UserRole?, String>((ref, uid) async {
  final repo = ref.watch(firebaseUserRepositoryProvider);
  return await repo.getUserRole(uid);
});

/// Current authenticated user's role (Future)
final currentUserRoleProvider = FutureProvider<UserRole?>((ref) async {
  final firebaseUser = ref.watch(currentFirebaseUserProvider);
  if (firebaseUser == null) return null;
  final repo = ref.watch(firebaseUserRepositoryProvider);
  return await repo.getUserRole(firebaseUser.uid);
});

// ============================================================================
// AUTH CONTROLLER (for UI to call authentication actions)
// ============================================================================

final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(ref);
});

/// Provides authentication action methods to UI layer.
/// Catches and rethrows errors so UI can show appropriate messages.
class AuthController {
  final Ref _ref;

  AuthController(this._ref);

  /// Sign in with email and password
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final useCase = _ref.read(signInWithEmailUseCaseProvider);
    await useCase(email: email, password: password);
  }

  /// Sign up with email and password
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    String? phoneNumber,
  }) async {
    final useCase = _ref.read(signUpWithEmailUseCaseProvider);
    await useCase(
      email: email,
      password: password,
      displayName: displayName,
      role: role,
      phoneNumber: phoneNumber,
    );
  }

  /// Sign out
  Future<void> signOut() async {
    final useCase = _ref.read(signOutUseCaseProvider);
    await useCase();
  }

  /// Sign in with Google
  Future<void> signInWithGoogle() async {
    final authRepo = _ref.read(authRepositoryProvider);
    await authRepo.signInWithGoogle();
  }
}
