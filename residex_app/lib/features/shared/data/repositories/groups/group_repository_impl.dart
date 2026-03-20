import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../../../domain/entities/groups/app_group.dart';
import '../../../domain/repositories/groups/group_repository.dart';
import '../../datasources/groups/group_local_datasource.dart';
import '../../models/groups/app_group_model.dart';

class GroupRepositoryImpl implements GroupRepository {
  final GroupLocalDataSource localDataSource;

  GroupRepositoryImpl({required this.localDataSource});

  @override
  Future<Either<Failure, List<AppGroup>>> getAllGroups() async {
    try {
      final groups = await localDataSource.getAllGroups();
      return Right(groups.map((model) => model.toEntity()).toList());
    } catch (e) {
      return Left(DatabaseFailure(message: 'Failed to get groups: $e'));
    }
  }

  @override
  Future<Either<Failure, AppGroup?>> getGroupById(String id) async {
    try {
      final group = await localDataSource.getGroupById(id);
      return Right(group?.toEntity());
    } catch (e) {
      return Left(DatabaseFailure(message: 'Failed to get group: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> createGroup(AppGroup group) async {
    try {
      final model = AppGroupModel.fromEntity(group);
      await localDataSource.upsertGroup(model);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(message: 'Failed to create group: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updateGroup(AppGroup group) async {
    try {
      final model = AppGroupModel.fromEntity(group);
      await localDataSource.upsertGroup(model);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(message: 'Failed to update group: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteGroup(String groupId) async {
    try {
      await localDataSource.deleteGroup(groupId);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(message: 'Failed to delete group: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> addMemberToGroup({
    required String groupId,
    required String userId,
  }) async {
    try {
      await localDataSource.addMemberToGroup(groupId, userId);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(message: 'Failed to add member to group: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> removeMemberFromGroup({
    required String groupId,
    required String userId,
  }) async {
    try {
      await localDataSource.removeMemberFromGroup(groupId, userId);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(message: 'Failed to remove member from group: $e'));
    }
  }
}
