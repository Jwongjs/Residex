  import 'package:drift/drift.dart';

  /// Receipt items table definition
  class ReceiptItems extends Table {
    TextColumn get id => text()();
    TextColumn get billId => text()(); // Foreign key to Bills
    TextColumn get name => text()();
    IntColumn get quantity => integer()();
    RealColumn get price => real()();
    TextColumn get type => text()(); // 'item', 'tax', 'discount'
    RealColumn get taxRate => real().nullable()();

    @override
    Set<Column> get primaryKey => {id};
  }