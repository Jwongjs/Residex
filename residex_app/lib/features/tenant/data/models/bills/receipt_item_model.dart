  import '../../../domain/entities/bills/receipt_item.dart';
  import '../../../domain/entities/bills/bill_enums.dart';

  /// Data model for ReceiptItem
  class ReceiptItemModel extends ReceiptItem {
    const ReceiptItemModel({
      required super.id,
      required super.name,
      required super.quantity,
      required super.price,
      required super.type,
      super.taxRate,
    });

    /// Create from domain entity
    factory ReceiptItemModel.fromEntity(ReceiptItem item) {
      return ReceiptItemModel(
        id: item.id,
        name: item.name,
        quantity: item.quantity,
        price: item.price,
        type: item.type,
        taxRate: item.taxRate,
      );
    }

    /// Convert to domain entity
    ReceiptItem toEntity() {
      return ReceiptItem(
        id: id,
        name: name,
        quantity: quantity,
        price: price,
        type: type,
        taxRate: taxRate,
      );
    }

    /// From JSON
    factory ReceiptItemModel.fromJson(Map<String, dynamic> json) {
      return ReceiptItemModel(
        id: json['id'] as String,
        name: json['name'] as String,
        quantity: json['quantity'] as int,
        price: (json['price'] as num).toDouble(),
        type: ReceiptItemType.values.byName(json['type'] as String),
        taxRate: json['taxRate'] != null ? (json['taxRate'] as num).toDouble() : null,
      );
    }

    /// To JSON
    Map<String, dynamic> toJson() {
      return {
        'id': id,
        'name': name,
        'quantity': quantity,
        'price': price,
        'type': type.name,
        'taxRate': taxRate,
      };
    }

    /// From database row (includes billId)
    factory ReceiptItemModel.fromDb(Map<String, dynamic> row) {
      return ReceiptItemModel(
        id: row['id'] as String,
        name: row['name'] as String,
        quantity: row['quantity'] as int,
        price: row['price'] as double,
        type: ReceiptItemType.values.byName(row['type'] as String),
        taxRate: row['taxRate'] as double?,
      );
    }

    /// To database format (needs billId)
    Map<String, dynamic> toDb(String billId) {
      return {
        'id': id,
        'billId': billId,
        'name': name,
        'quantity': quantity,
        'price': price,
        'type': type.name,
        'taxRate': taxRate,
      };
    }
  }
