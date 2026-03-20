  import 'dart:io';
  import 'package:drift/drift.dart';
  import 'package:drift/native.dart';
  import 'package:path_provider/path_provider.dart';
  import 'package:path/path.dart' as p;

  import 'tables/users_table.dart';
  import 'tables/groups_table.dart';
  import 'tables/bills_table.dart';
  import 'tables/receipt_items_table.dart';
  import 'daos/user_dao.dart';
  import 'daos/group_dao.dart';
  import 'daos/bill_dao.dart';

  part 'app_database.g.dart';

  @DriftDatabase(
    tables: [Users, Groups, Bills, ReceiptItems],
    daos: [UserDao, GroupDao, BillDao],
  )
  class AppDatabase extends _$AppDatabase {
    AppDatabase() : super(_openConnection());

    @override
    int get schemaVersion => 2;

    static LazyDatabase _openConnection() {
      return LazyDatabase(() async {
        final dbFolder = await getApplicationDocumentsDirectory();
        final file = File(p.join(dbFolder.path, 'residex.db'));
        return NativeDatabase(file);
      });
    }
  }