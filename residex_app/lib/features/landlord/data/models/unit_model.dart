import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/unit.dart';

/// Data Transfer Object for Unit
///
/// Extends Unit entity and adds serialization logic for Firestore.
class UnitModel extends Unit {
  UnitModel({
    required super.id,
    required super.propertyId,
    required super.label,
    required super.monthlyRent,
    required super.isOccupied,
    required super.createdAt,
    super.updatedAt,
  });

  /// Create UnitModel from domain entity
  factory UnitModel.fromEntity(Unit unit) {
    return UnitModel(
      id: unit.id,
      propertyId: unit.propertyId,
      label: unit.label,
      monthlyRent: unit.monthlyRent,
      isOccupied: unit.isOccupied,
      createdAt: unit.createdAt,
      updatedAt: unit.updatedAt,
    );
  }

  /// Create UnitModel from JSON
  factory UnitModel.fromJson(Map<String, dynamic> json, String id, String propertyId) {
    return UnitModel(
      id: id,
      propertyId: propertyId,
      label: json['label'] as String,
      monthlyRent: _parseDouble(json['monthlyRent']),
      isOccupied: json['isOccupied'] as bool? ?? false,
      createdAt: _parseTimestamp(json['createdAt']),
      updatedAt: json['updatedAt'] != null
          ? _parseTimestamp(json['updatedAt'])
          : null,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'monthlyRent': monthlyRent,
      'isOccupied': isOccupied,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// Create UnitModel from Firestore document
  factory UnitModel.fromFirestore(DocumentSnapshot doc, String propertyId) {
    final data = doc.data() as Map<String, dynamic>;
    return UnitModel.fromJson(data, doc.id, propertyId);
  }

  /// Convert to Firestore document data
  Map<String, dynamic> toFirestore() => toJson();

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
