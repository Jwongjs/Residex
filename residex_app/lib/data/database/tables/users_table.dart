  import 'package:drift/drift.dart';

  /// Users table definition
  class Users extends Table {
    TextColumn get id => text()();
    TextColumn get name => text()();
    TextColumn get avatarInitials => text()();
    TextColumn get profileImage => text().nullable()();
    TextColumn get gradientColorValues => text().nullable()(); // Store as JSON array
    BoolColumn get isGuest => boolean().withDefault(const Constant(false))();
    TextColumn get phoneNumber => text().nullable()();

    @override
    Set<Column> get primaryKey => {id};
  }