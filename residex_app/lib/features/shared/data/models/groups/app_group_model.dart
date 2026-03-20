import 'dart:convert';
import '../../../domain/entities/groups/app_group.dart';

/// Data model for AppGroup with JSON/DB serialization
class AppGroupModel extends AppGroup {
  const AppGroupModel({
    required super.id,
    required super.name,
    super.address,
    required super.tenantIds,
    super.landlordId,
    required super.emoji,
    required super.colorValue,
    super.leaseStartDate,
    super.leaseEndDate,
    super.createdBy,
  });

  /// Create from database map
  factory AppGroupModel.fromDb(Map<String, dynamic> map) {
    return AppGroupModel(
      id: map['id'] as String,
      name: map['name'] as String,
      address: map['address'] as String?,
      tenantIds: map['tenantIds'] != null
          ? List<String>.from(jsonDecode(map['tenantIds'] as String))
          : [],
      landlordId: map['landlordId'] as String?,
      emoji: map['emoji'] as String,
      colorValue: map['colorValue'] as int,
      leaseStartDate: map['leaseStartDate'] as DateTime?,
      leaseEndDate: map['leaseEndDate'] as DateTime?,
      createdBy: map['createdBy'] as String?,
    );
  }

  /// Convert to database map
  Map<String, dynamic> toDb() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'tenantIds': jsonEncode(tenantIds),
      'landlordId': landlordId,
      'emoji': emoji,
      'colorValue': colorValue,
      'leaseStartDate': leaseStartDate,
      'leaseEndDate': leaseEndDate,
      'createdBy': createdBy,
    };
  }

  /// Create from entity
  factory AppGroupModel.fromEntity(AppGroup group) {
    return AppGroupModel(
      id: group.id,
      name: group.name,
      address: group.address,
      tenantIds: group.tenantIds,
      landlordId: group.landlordId,
      emoji: group.emoji,
      colorValue: group.colorValue,
      leaseStartDate: group.leaseStartDate,
      leaseEndDate: group.leaseEndDate,
      createdBy: group.createdBy,
    );
  }

  /// Convert to entity
  AppGroup toEntity() {
    return AppGroup(
      id: id,
      name: name,
      address: address,
      tenantIds: tenantIds,
      landlordId: landlordId,
      emoji: emoji,
      colorValue: colorValue,
      leaseStartDate: leaseStartDate,
      leaseEndDate: leaseEndDate,
      createdBy: createdBy,
    );
  }
}
