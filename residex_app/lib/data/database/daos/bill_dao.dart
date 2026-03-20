  import 'package:drift/drift.dart';
  import '../app_database.dart';
  import '../tables/bills_table.dart';
  import '../tables/receipt_items_table.dart';

  part 'bill_dao.g.dart';

  @DriftAccessor(tables: [Bills, ReceiptItems])
  class BillDao extends DatabaseAccessor<AppDatabase> with _$BillDaoMixin {
    BillDao(super.db);

    /// Get all bills
    Future<List<Bill>> getAllBills() => select(bills).get();

    /// Get bill by ID
    Future<Bill?> getBillById(String id) {
      return (select(bills)..where((b) => b.id.equals(id))).getSingleOrNull();
    }

    /// Get receipt items for a bill
    Future<List<ReceiptItem>> getReceiptItemsForBill(String billId) {
      return (select(receiptItems)..where((i) => i.billId.equals(billId))).get();
    }

    /// Insert or update bill
    Future<void> upsertBill(BillsCompanion bill) {
      return into(bills).insertOnConflictUpdate(bill);
    }

    /// Insert or update receipt item
    Future<void> upsertReceiptItem(ReceiptItemsCompanion item) {
      return into(receiptItems).insertOnConflictUpdate(item);
    }

    /// Delete bill and its items
    Future<void> deleteBill(String id) async {
      // Delete receipt items first
      await (delete(receiptItems)..where((i) => i.billId.equals(id))).go();
      // Delete bill
      await (delete(bills)..where((b) => b.id.equals(id))).go();
    }
  }