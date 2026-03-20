  import 'package:dartz/dartz.dart';
  import '../../../../../core/errors/failures.dart';
  import '../../../../../core/errors/exceptions.dart';
  import '../../../domain/entities/users/app_user.dart';
  import '../../../domain/repositories/users/user_repository.dart';
  import 'user_local_datasource.dart';
  import '../../models/users/app_user_model.dart';

  /// Implementation of UserRepository using local data source
  class UserRepositoryImpl implements UserRepository {
    final UserLocalDataSource localDataSource;

    UserRepositoryImpl({required this.localDataSource});

    @override
    Future<Either<Failure, List<AppUser>>> getAllUsers() async {
      try {
        final users = await localDataSource.getAllUsers();
        return Right(users.map((model) => model.toEntity()).toList());
      } on CacheException catch (e) {
        return Left(CacheFailure(e.message));
      } catch (e) {
        return Left(CacheFailure('Failed to get users: ${e.toString()}'));
      }
    }

    @override
    Future<Either<Failure, AppUser?>> getUserById(String id) async {
      try {
        final user = await localDataSource.getUserById(id);
        return Right(user?.toEntity());
      } on CacheException catch (e) {
        return Left(CacheFailure(e.message));
      } catch (e) {
        return Left(CacheFailure('Failed to get user: ${e.toString()}'));
      }
    }

    @override
    Future<Either<Failure, AppUser>> getCurrentUser() async {
      try {
        // For now, get the first user or return a default user
        // In production, this would check authentication
        final users = await localDataSource.getAllUsers();
        if (users.isEmpty) {
          return const Left(CacheFailure('No current user found'));
        }
        return Right(users.first.toEntity());
      } on CacheException catch (e) {
        return Left(CacheFailure(e.message));
      } catch (e) {
        return Left(CacheFailure('Failed to get current user: ${e.toString()}'));
      }
    }

    @override
    Future<Either<Failure, void>> addUser(AppUser user) async {
      try {
        final userModel = AppUserModel.fromEntity(user);
        await localDataSource.upsertUser(userModel);
        return const Right(null);
      } on CacheException catch (e) {
        return Left(CacheFailure(e.message));
      } catch (e) {
        return Left(CacheFailure('Failed to add user: ${e.toString()}'));
      }
    }

    @override
    Future<Either<Failure, void>> updateUser(AppUser user) async {
      try {
        final userModel = AppUserModel.fromEntity(user);
        await localDataSource.upsertUser(userModel);
        return const Right(null);
      } on CacheException catch (e) {
        return Left(CacheFailure(e.message));
      } catch (e) {
        return Left(CacheFailure('Failed to update user: ${e.toString()}'));
      }
    }

    @override
    Future<Either<Failure, void>> deleteUser(String userId) async {
      try {
        await localDataSource.deleteUser(userId);
        return const Right(null);
      } on CacheException catch (e) {
        return Left(CacheFailure(e.message));
      } catch (e) {
        return Left(CacheFailure('Failed to delete user: ${e.toString()}'));
      }
    }
  }