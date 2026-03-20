  import 'package:equatable/equatable.dart';
  import 'bill_enums.dart';

  /// Pure domain entity for a receipt item
  /// No Flutter dependencies, no JSON serialization
  class ReceiptItem extends Equatable {
    final String id;
    final String name;
    final int quantity;
    final double price;
    final ReceiptItemType type;
    final double? taxRate;

    const ReceiptItem({
      required this.id,
      required this.name,
      required this.quantity,
      required this.price,
      required this.type,
      this.taxRate,
    });

    /// Calculate total price for this item
    double get totalPrice => quantity * price;

    /// Check if this item is a regular item (not tax/discount)
    bool get isRegularItem => type == ReceiptItemType.item;

    /// Create a copy with modified fields
    ReceiptItem copyWith({
      String? id,
      String? name,
      int? quantity,
      double? price,
      ReceiptItemType? type,
      double? taxRate,
    }) {
      return ReceiptItem(
        id: id ?? this.id,
        name: name ?? this.name,
        quantity: quantity ?? this.quantity,
        price: price ?? this.price,
        type: type ?? this.type,
        taxRate: taxRate ?? this.taxRate,
      );
    }

    @override
    List<Object?> get props => [id, name, quantity, price, type, taxRate];
  }
