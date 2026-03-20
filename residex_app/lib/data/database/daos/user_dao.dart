  import 'package:drift/drift.dart';
  import '../app_database.dart';
  import '../tables/users_table.dart';

  part 'user_dao.g.dart';

  @DriftAccessor(tables: [Users])
  class UserDao extends DatabaseAccessor<AppDatabase> with _$UserDaoMixin {
    UserDao(super.db);

    /// Get all users
    Future<List<User>> getAllUsers() => select(users).get();

    /// Get user by ID
    Future<User?> getUserById(String id) {
      return (select(users)..where((u) => u.id.equals(id))).getSingleOrNull();
    }

    /// Insert or update user
    Future<void> upsertUser(UsersCompanion user) {
      return into(users).insertOnConflictUpdate(user);
    }

    /// Delete user
    Future<void> deleteUser(String id) {
      return (delete(users)..where((u) => u.id.equals(id))).go();
    }
  }