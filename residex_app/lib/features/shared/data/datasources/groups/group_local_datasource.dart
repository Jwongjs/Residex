import 'package:drift/drift.dart';
import '../../../../../data/database/app_database.dart';
import '../../models/groups/app_group_model.dart';

/// Local data source for groups using Drift
class GroupLocalDataSource {
  final AppDatabase database;

  GroupLocalDataSource(this.database);

  /// Get all groups
  Future<List<AppGroupModel>> getAllGroups() async {
    final groups = await database.groupDao.getAllGroups();
    return groups.map((group) {
      return AppGroupModel.fromDb({
        'id': group.id,
        'name': group.name,
        'emoji': group.emoji,
        'colorValue': group.colorValue,
        'address': group.address,
        'tenantIds': group.tenantIds,
        'landlordId': group.landlordId,
        'leaseStartDate': group.leaseStartDate,
        'leaseEndDate': group.leaseEndDate,
        'createdBy': group.createdBy,
      });
    }).toList();
  }

  /// Get group by ID
  Future<AppGroupModel?> getGroupById(String id) async {
    final group = await database.groupDao.getGroupById(id);
    if (group == null) return null;

    return AppGroupModel.fromDb({
      'id': group.id,
      'name': group.name,
      'emoji': group.emoji,
      'colorValue': group.colorValue,
      'address': group.address,
      'tenantIds': group.tenantIds,
      'landlordId': group.landlordId,
      'leaseStartDate': group.leaseStartDate,
      'leaseEndDate': group.leaseEndDate,
      'createdBy': group.createdBy,
    });
  }

  /// Add or update group
  Future<void> upsertGroup(AppGroupModel group) async {
    final dbData = group.toDb();
    await database.groupDao.upsertGroup(
      GroupsCompanion(
        id: Value(dbData['id'] as String),
        name: Value(dbData['name'] as String),
        emoji: Value(dbData['emoji'] as String),
        colorValue: Value(dbData['colorValue'] as int),
        address: Value(dbData['address'] as String?),
        tenantIds: Value(dbData['tenantIds'] as String),
        landlordId: Value(dbData['landlordId'] as String?),
        leaseStartDate: Value(dbData['leaseStartDate'] as DateTime?),
        leaseEndDate: Value(dbData['leaseEndDate'] as DateTime?),
        createdBy: Value(dbData['createdBy'] as String?),
      ),
    );
  }

  /// Delete group
  Future<void> deleteGroup(String id) async {
    await database.groupDao.deleteGroup(id);
  }

  /// Add member to group (update tenantIds)
  Future<void> addMemberToGroup(String groupId, String userId) async {
    final group = await getGroupById(groupId);
    if (group == null) return;

    final updatedTenantIds = [...group.tenantIds];
    if (!updatedTenantIds.contains(userId)) {
      updatedTenantIds.add(userId);
      final updatedGroup = AppGroupModel.fromEntity(
        group.copyWith(tenantIds: updatedTenantIds),
      );
      await upsertGroup(updatedGroup);
    }
  }

  /// Remove member from group (update tenantIds)
  Future<void> removeMemberFromGroup(String groupId, String userId) async {
    final group = await getGroupById(groupId);
    if (group == null) return;

    final updatedTenantIds = group.tenantIds.where((id) => id != userId).toList();
    final updatedGroup = AppGroupModel.fromEntity(
      group.copyWith(tenantIds: updatedTenantIds),
    );
    await upsertGroup(updatedGroup);
  }
}
