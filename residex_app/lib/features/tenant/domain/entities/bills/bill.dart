import 'package:equatable/equatable.dart';
import 'receipt_item.dart';
import 'bill_enums.dart';

/// Pure domain entity representing a completed bill
/// Contains all business data but no presentation logic
class Bill extends Equatable {
  final String id;
  final String title;
  final String location;
  final double totalAmount;
  final DateTime createdAt;
  final List<String> participantIds;
  final Map<String, double> participantShares; // userId -> amount owed
  final Map<String, bool> paymentStatus; // userId -> has paid
  final List<ReceiptItem> items;
  final String? imageUrl;

final BillCategory category;
final String provider;
final DateTime? dueDate;
final BillStatus status;

  const Bill({
    required this.id,
    required this.title,
    required this.location,
    required this.totalAmount,
    required this.createdAt,
    required this.participantIds,
    required this.participantShares,
    required this.paymentStatus,
    required this.items,
    this.imageUrl,
    this.category = BillCategory.other,
    this.provider = '',
    this.dueDate,
    this.status = BillStatus.pending,
  });



  /// Get number of participants who have paid
  int get paidCount => paymentStatus.values.where((paid) => paid).length;

  /// Get total number of participants
  int get participantCount => participantIds.length;

  /// Check if a specific user has paid
  bool hasUserPaid(String userId) => paymentStatus[userId] ?? false;

  /// Get share amount for a specific user
  double getShareForUser(String userId) => participantShares[userId] ?? 0.0;

  /// Get all regular items (excluding tax/discount)
  List<ReceiptItem> get regularItems =>
      items.where((item) => item.type == ReceiptItemType.item).toList();

  /// Get all tax items
  List<ReceiptItem> get taxItems =>
      items.where((item) => item.type == ReceiptItemType.tax).toList();

  /// Calculate total tax amount
  double get totalTax =>
      taxItems.fold(0.0, (sum, item) => sum + item.totalPrice);

  /// Create a copy with modified fields
  Bill copyWith({
    String? id,
    String? title,
    String? location,
    double? totalAmount,
    DateTime? createdAt,
    List<String>? participantIds,
    Map<String, double>? participantShares,
    Map<String, bool>? paymentStatus,
    List<ReceiptItem>? items,
    String? imageUrl,
    BillCategory? category,
    String? provider,
    DateTime? dueDate,
    BillStatus? status,
  }) {
    return Bill(
      id: id ?? this.id,
      title: title ?? this.title,
      location: location ?? this.location,
      totalAmount: totalAmount ?? this.totalAmount,
      createdAt: createdAt ?? this.createdAt,
      participantIds: participantIds ?? this.participantIds,
      participantShares: participantShares ?? this.participantShares,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      items: items ?? this.items,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      provider: provider ?? this.provider,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        location,
        totalAmount,
        createdAt,
        participantIds,
        participantShares,
        paymentStatus,
        items,
        imageUrl,
        category,
        provider,
        dueDate,
        status,
      ];

       // ✅ ADD HELPER METHOD to get individual payment status:
PaymentStatus getPaymentStatusForUser(String userId) {
  final hasPaid = paymentStatus[userId] ?? false;
  if (hasPaid) return PaymentStatus.paid;

  // Check if bill is overdue
  if (dueDate != null && DateTime.now().isAfter(dueDate!)) {
    return PaymentStatus.unpaid;
  }

  return PaymentStatus.pending;
}

// ✅ ADD HELPER METHOD to check if bill is settled:
bool get isSettled {
  return paymentStatus.values.every((paid) => paid);
}

// ✅ ADD HELPER METHOD to get outstanding amount:
double get outstandingAmount {
  double outstanding = 0.0;
  paymentStatus.forEach((userId, hasPaid) {
    if (!hasPaid) {
      outstanding += participantShares[userId] ?? 0.0;
    }
  });
  return outstanding;
}
}
