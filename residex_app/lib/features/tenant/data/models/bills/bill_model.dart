import 'dart:convert';
import '../../../domain/entities/bills/bill.dart';
import '../../../domain/entities/bills/receipt_item.dart';
import 'receipt_item_model.dart';
import '../../../domain/entities/bills/bill_enums.dart';

  /// Data model for Bill
  class BillModel extends Bill {
    const BillModel({
      required super.id,
      required super.title,
      required super.location,
      required super.totalAmount,
      required super.createdAt,
      required super.participantIds,
      required super.participantShares,
      required super.paymentStatus,
      required super.items,
      super.imageUrl,
      super.category,
      super.provider,
      super.dueDate,
      super.status,
    });

    /// Create from domain entity
    factory BillModel.fromEntity(Bill bill) {
      return BillModel(
        id: bill.id,
        title: bill.title,
        location: bill.location,
        totalAmount: bill.totalAmount,
        createdAt: bill.createdAt,
        participantIds: bill.participantIds,
        participantShares: bill.participantShares,
        paymentStatus: bill.paymentStatus,
        items: bill.items,
        imageUrl: bill.imageUrl,
        category: bill.category,
        provider: bill.provider,
        dueDate: bill.dueDate,
        status: bill.status,
      );
    }

    /// Convert to domain entity
    Bill toEntity() {
      return Bill(
        id: id,
        title: title,
        location: location,
        totalAmount: totalAmount,
        createdAt: createdAt,
        participantIds: participantIds,
        participantShares: participantShares,
        paymentStatus: paymentStatus,
        items: items,
        imageUrl: imageUrl,
        category: category,
        provider: provider,
        dueDate: dueDate,
        status: status,
      );
    }

    /// From JSON
    factory BillModel.fromJson(Map<String, dynamic> json) {
      return BillModel(
        id: json['id'] as String,
        title: json['title'] as String,
        location: json['location'] as String,
        totalAmount: (json['totalAmount'] as num).toDouble(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        participantIds: List<String>.from(json['participantIds'] as List),
        participantShares: Map<String, double>.from(
          (json['participantShares'] as Map).map(
            (key, value) => MapEntry(key as String, (value as num).toDouble()),
          ),
        ),
        paymentStatus: Map<String, bool>.from(json['paymentStatus'] as Map),
        items: (json['items'] as List)
            .map((item) => ReceiptItemModel.fromJson(item as Map<String, dynamic>))
            .toList(),
        imageUrl: json['imageUrl'] as String?,
        category: BillCategory.values.firstWhere(
          (e) => e.name == (json['category'] as String?),
          orElse: () => BillCategory.other,
        ),
        provider: json['provider'] as String? ?? '',
        dueDate: json['dueDate'] != null
            ? DateTime.parse(json['dueDate'] as String)
            : null,
        status: BillStatus.values.firstWhere(
          (e) => e.name == (json['status'] as String?),
          orElse: () => BillStatus.pending,
          ),
      );
    }

    /// To JSON
    Map<String, dynamic> toJson() {
      return {
        'id': id,
        'title': title,
        'location': location,
        'totalAmount': totalAmount,
        'createdAt': createdAt.toIso8601String(),
        'participantIds': participantIds,
        'participantShares': participantShares,
        'paymentStatus': paymentStatus,
        'items': items.map((item) => ReceiptItemModel.fromEntity(item).toJson()).toList(),
        'imageUrl': imageUrl,
        'category': category.name,
        'provider': provider,
        'dueDate': dueDate?.toIso8601String(),
        'status': status.name,
      };
    }

    /// From database row
    factory BillModel.fromDb(Map<String, dynamic> row, List<ReceiptItem> items) {
      return BillModel(
        id: row['id'] as String,
        title: row['title'] as String,
        location: row['location'] as String,
        totalAmount: row['totalAmount'] as double,
        createdAt: DateTime.parse(row['createdAt'] as String),
        participantIds: List<String>.from(jsonDecode(row['participantIds'] as String)),
        participantShares: Map<String, double>.from(
          (jsonDecode(row['participantShares'] as String) as Map).map(
            (key, value) => MapEntry(key as String, (value as num).toDouble()),
          ),
        ),
        paymentStatus: Map<String, bool>.from(jsonDecode(row['paymentStatus'] as String)),
        items: items,
        imageUrl: row['imageUrl'] as String?,
      );
    }

    /// To database format
    Map<String, dynamic> toDb() {
      return {
        'id': id,
        'title': title,
        'location': location,
        'totalAmount': totalAmount,
        'createdAt': createdAt.toIso8601String(),
        'participantIds': jsonEncode(participantIds),
        'participantShares': jsonEncode(participantShares),
        'paymentStatus': jsonEncode(paymentStatus),
        'imageUrl': imageUrl,
      };
    }
  }
