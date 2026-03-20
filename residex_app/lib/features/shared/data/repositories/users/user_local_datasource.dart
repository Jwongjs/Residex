  import 'package:drift/drift.dart';
  import '../../../../../data/database/app_database.dart';
  import '../../models/users/app_user_model.dart';

  /// Local data source for users using Drift
  class UserLocalDataSource {
    final AppDatabase database;

    UserLocalDataSource(this.database);

    /// Get all users
    Future<List<AppUserModel>> getAllUsers() async {
      final users = await database.userDao.getAllUsers();
      return users.map((user) {
        return AppUserModel.fromDb({
          'id': user.id,
          'name': user.name,
          'avatarInitials': user.avatarInitials,
          'profileImage': user.profileImage,
          'gradientColorValues': user.gradientColorValues,
          'isGuest': user.isGuest ? 1 : 0,
          'phoneNumber': user.phoneNumber,
        });
      }).toList();
    }

    /// Get user by ID
    Future<AppUserModel?> getUserById(String id) async {
      final user = await database.userDao.getUserById(id);
      if (user == null) return null;

      return AppUserModel.fromDb({
        'id': user.id,
        'name': user.name,
        'avatarInitials': user.avatarInitials,
        'profileImage': user.profileImage,
        'gradientColorValues': user.gradientColorValues,
        'isGuest': user.isGuest ? 1 : 0,
        'phoneNumber': user.phoneNumber,
      });
    }

    /// Add or update user
    Future<void> upsertUser(AppUserModel user) async {
      final dbData = user.toDb();
      await database.userDao.upsertUser(
        UsersCompanion(
          id: Value(dbData['id'] as String),
          name: Value(dbData['name'] as String),
          avatarInitials: Value(dbData['avatarInitials'] as String),
          profileImage: Value(dbData['profileImage'] as String?),
          gradientColorValues: Value(dbData['gradientColorValues'] as String?),
          isGuest: Value(dbData['isGuest'] == 1),
          phoneNumber: Value(dbData['phoneNumber'] as String?),
        ),
      );
    }

    /// Delete user
    Future<void> deleteUser(String id) async {
      await database.userDao.deleteUser(id);
    }
  }