  import 'package:drift/drift.dart';

  /// Bills table definition
  class Bills extends Table {
    TextColumn get id => text()();
    TextColumn get title => text()();
    TextColumn get location => text()();
    RealColumn get totalAmount => real()();
    DateTimeColumn get createdAt => dateTime()();
    TextColumn get participantIds => text()(); // Store as JSON array
    TextColumn get participantShares => text()(); // Store as JSON object
    TextColumn get paymentStatus => text()(); // Store as JSON object
    TextColumn get imageUrl => text().nullable()();
    TextColumn get category => text().withDefault(const Constant('other'))();
    TextColumn get provider => text().withDefault(const Constant(''))();
    DateTimeColumn get dueDate => dateTime().nullable()();
    TextColumn get status => text().withDefault(const Constant('pending'))();

    @override
    Set<Column> get primaryKey => {id};
  }