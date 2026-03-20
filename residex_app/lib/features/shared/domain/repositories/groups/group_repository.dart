import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../../entities/groups/app_group.dart';

abstract class GroupRepository {
  Future<Either<Failure, List<AppGroup>>> getAllGroups();
  Future<Either<Failure, AppGroup?>> getGroupById(String id);
  Future<Either<Failure, void>> createGroup(AppGroup group);
  Future<Either<Failure, void>> updateGroup(AppGroup group);
  Future<Either<Failure, void>> deleteGroup(String groupId);
  Future<Either<Failure, void>> addMemberToGroup({
    required String groupId,
    required String userId,
  });
  Future<Either<Failure, void>> removeMemberFromGroup({
    required String groupId,
    required String userId,
  });
}
