  import 'package:drift/drift.dart';
  import '../app_database.dart';
  import '../tables/groups_table.dart';

  part 'group_dao.g.dart';

  @DriftAccessor(tables: [Groups])
  class GroupDao extends DatabaseAccessor<AppDatabase> with _$GroupDaoMixin {
    GroupDao(super.db);

    /// Get all groups
    Future<List<Group>> getAllGroups() => select(groups).get();

    /// Get group by ID
    Future<Group?> getGroupById(String id) {
      return (select(groups)..where((g) => g.id.equals(id))).getSingleOrNull();
    }

    /// Insert or update group
    Future<void> upsertGroup(GroupsCompanion group) {
      return into(groups).insertOnConflictUpdate(group);
    }

    /// Delete group
    Future<void> deleteGroup(String id) {
      return (delete(groups)..where((g) => g.id.equals(id))).go();
    }
  }