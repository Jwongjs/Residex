  import 'package:dartz/dartz.dart';
  import '../../../../../core/errors/failures.dart';
  import '../../entities/users/app_user.dart';

  /// Abstract interface for user data operations
  abstract class UserRepository {
    /// Get all users (friends)
    Future<Either<Failure, List<AppUser>>> getAllUsers();

    /// Get a single user by ID
    Future<Either<Failure, AppUser?>> getUserById(String id);

    /// Get current logged-in user
    Future<Either<Failure, AppUser>> getCurrentUser();

    /// Add a new user/friend
    Future<Either<Failure, void>> addUser(AppUser user);

    /// Update user details
    Future<Either<Failure, void>> updateUser(AppUser user);

    /// Delete a user
    Future<Either<Failure, void>> deleteUser(String userId);
  }