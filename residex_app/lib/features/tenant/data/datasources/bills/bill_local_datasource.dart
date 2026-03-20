  import 'package:drift/drift.dart';
  import '../../../../../data/database/app_database.dart';
  import '../../models/bills/bill_model.dart';
  import '../../models/bills/receipt_item_model.dart';

  /// Local data source for bills using Drift
  class BillLocalDataSource {
    final AppDatabase database;

    BillLocalDataSource(this.database);

    /// Get all bills with their items
    Future<List<BillModel>> getAllBills() async {
      final bills = await database.billDao.getAllBills();

      final billModels = <BillModel>[];
      for (final bill in bills) {
        final items = await database.billDao.getReceiptItemsForBill(bill.id);
        final itemModels = items.map((item) {
          return ReceiptItemModel.fromDb({
            'id': item.id,
            'name': item.name,
            'quantity': item.quantity,
            'price': item.price,
            'type': item.type,
            'taxRate': item.taxRate,
          });
        }).toList();

        billModels.add(BillModel.fromDb({
          'id': bill.id,
          'title': bill.title,
          'location': bill.location,
          'totalAmount': bill.totalAmount,
          'createdAt': bill.createdAt.toIso8601String(),
          'participantIds': bill.participantIds,
          'participantShares': bill.participantShares,
          'paymentStatus': bill.paymentStatus,
          'imageUrl': bill.imageUrl,
        }, itemModels));
      }

      return billModels;
    }

    /// Get bill by ID with items
    Future<BillModel?> getBillById(String id) async {
      final bill = await database.billDao.getBillById(id);
      if (bill == null) return null;

      final items = await database.billDao.getReceiptItemsForBill(id);
      final itemModels = items.map((item) {
        return ReceiptItemModel.fromDb({
          'id': item.id,
          'name': item.name,
          'quantity': item.quantity,
          'price': item.price,
          'type': item.type,
          'taxRate': item.taxRate,
        });
      }).toList();

      return BillModel.fromDb({
        'id': bill.id,
        'title': bill.title,
        'location': bill.location,
        'totalAmount': bill.totalAmount,
        'createdAt': bill.createdAt.toIso8601String(),
        'participantIds': bill.participantIds,
        'participantShares': bill.participantShares,
        'paymentStatus': bill.paymentStatus,
        'imageUrl': bill.imageUrl,
      }, itemModels);
    }

    /// Save bill with items
    Future<void> saveBill(BillModel bill) async {
      final dbData = bill.toDb();

      // Save bill
      await database.billDao.upsertBill(
        BillsCompanion(
          id: Value(dbData['id'] as String),
          title: Value(dbData['title'] as String),
          location: Value(dbData['location'] as String),
          totalAmount: Value(dbData['totalAmount'] as double),
          createdAt: Value(DateTime.parse(dbData['createdAt'] as String)),
          participantIds: Value(dbData['participantIds'] as String),
          participantShares: Value(dbData['participantShares'] as String),
          paymentStatus: Value(dbData['paymentStatus'] as String),
          imageUrl: Value(dbData['imageUrl'] as String?),
        ),
      );

      // Save items
      for (final item in bill.items) {
        final itemModel = ReceiptItemModel.fromEntity(item);
        final itemDbData = itemModel.toDb(bill.id);

        await database.billDao.upsertReceiptItem(
          ReceiptItemsCompanion(
            id: Value(itemDbData['id'] as String),
            billId: Value(itemDbData['billId'] as String),
            name: Value(itemDbData['name'] as String),
            quantity: Value(itemDbData['quantity'] as int),
            price: Value(itemDbData['price'] as double),
            type: Value(itemDbData['type'] as String),
            taxRate: Value(itemDbData['taxRate'] as double?),
          ),
        );
      }
    }

    /// Update payment status
    Future<void> updatePaymentStatus({
      required String billId,
      required String userId,
      required bool hasPaid,
    }) async {
      final bill = await getBillById(billId);
      if (bill == null) return;

      final updatedPaymentStatus = Map<String, bool>.from(bill.paymentStatus);
      updatedPaymentStatus[userId] = hasPaid;

      final updatedBill = BillModel.fromEntity(
        bill.copyWith(paymentStatus: updatedPaymentStatus),
      );

      await saveBill(updatedBill);
    }

    /// Delete bill
    Future<void> deleteBill(String id) async {
      await database.billDao.deleteBill(id);
    }
  }
