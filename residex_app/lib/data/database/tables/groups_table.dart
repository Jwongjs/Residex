import 'package:drift/drift.dart';

  /// Groups table definition
  class Groups extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get emoji => text()();
  IntColumn get colorValue => integer()();
  TextColumn get createdBy => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get tenantIds => text()();  // JSON array
  TextColumn get landlordId => text().nullable()();
  DateTimeColumn get leaseStartDate => dateTime().nullable()();
  DateTimeColumn get leaseEndDate => dateTime().nullable()();

    @override
    Set<Column> get primaryKey => {id};
  }