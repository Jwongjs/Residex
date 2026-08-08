import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/property.dart';

/// Data Transfer Object for Property
/// 
/// Extends Property entity and adds serialization logic
/// for Firestore database operations
class PropertyModel extends Property {
  PropertyModel({
    required super.id,
    required super.landlordId,
    required super.name,
    required super.address,
    required super.type,
    required super.purchasePrice,
    required super.currentValue,
    super.ownershipShare = 1.0,
    super.structureType,
    super.hasMortgage,
    super.trackFromYear,
    super.utilitiesPaidBy = 'tenant',
    super.loanInputCadence,
    super.mortgageSettledOn,
    super.nextSetupStep = 0,
    super.foldersEnabled = false,
    super.folderNames = const {},
    super.folderMoves = const {},
    super.photos,
    required super.createdAt,
    super.updatedAt,
  });

  /// Create PropertyModel from domain entity
  factory PropertyModel.fromEntity(Property property) {
    return PropertyModel(
      id: property.id,
      landlordId: property.landlordId,
      name: property.name,
      address: property.address,
      type: property.type,
      purchasePrice: property.purchasePrice,
      currentValue: property.currentValue,
      ownershipShare: property.ownershipShare,
      structureType: property.structureType,
      hasMortgage: property.hasMortgage,
      trackFromYear: property.trackFromYear,
      utilitiesPaidBy: property.utilitiesPaidBy,
      loanInputCadence: property.loanInputCadence,
      mortgageSettledOn: property.mortgageSettledOn,
      nextSetupStep: property.nextSetupStep,
      foldersEnabled: property.foldersEnabled,
      folderNames: property.folderNames,
      folderMoves: property.folderMoves,
      photos: property.photos,
      createdAt: property.createdAt,
      updatedAt: property.updatedAt,
    );
  }

  /// Convert to domain entity
  Property toEntity() {
    return Property(
      id: id,
      landlordId: landlordId,
      name: name,
      address: address,
      type: type,
      purchasePrice: purchasePrice,
      currentValue: currentValue,
      ownershipShare: ownershipShare,
      structureType: structureType,
      hasMortgage: hasMortgage,
      trackFromYear: trackFromYear,
      utilitiesPaidBy: utilitiesPaidBy,
      loanInputCadence: loanInputCadence,
      mortgageSettledOn: mortgageSettledOn,
      nextSetupStep: nextSetupStep,
      foldersEnabled: foldersEnabled,
      folderNames: folderNames,
      folderMoves: folderMoves,
      photos: photos,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Create PropertyModel from JSON (FIXED: Null-safe parsing)
  factory PropertyModel.fromJson(Map<String, dynamic> json, String id) {
    final addressData = json['address'] as Map<String, dynamic>;
    
    return PropertyModel(
      id: id,
      landlordId: json['landlordId'] as String,
      name: json['name'] as String,
      address: PropertyAddress(
        street: addressData['street'] as String,
        city: addressData['city'] as String,
        state: addressData['state'] as String,
        zipCode: addressData['zipCode'] as String,
        country: addressData['country'] as String? ?? 'Malaysia',
      ),
      type: PropertyType.fromJson(json['type'] as String),
      // ✅ FIXED: Safe numeric parsing with fallback
      purchasePrice: _parseDouble(json['purchasePrice']),
      currentValue: _parseDouble(json['currentValue']),
      ownershipShare: json['ownership_share'] != null
          ? _parseDouble(json['ownership_share'])
          : 1.0,
      structureType: PropertyStructureType.fromJson(json['property_type'] as String?),
      hasMortgage: json['has_mortgage'] as bool?,
      trackFromYear: (json['track_from_year'] as num?)?.toInt(),
      utilitiesPaidBy: json['utilities_paid_by'] as String? ?? 'tenant',
      loanInputCadence: json['loan_input_cadence'] as String?,
      mortgageSettledOn: json['mortgage_settled_on'] as String?,
      nextSetupStep: (json['next_setup_step'] as num?)?.toInt() ?? 0,
      foldersEnabled: json['folders_enabled'] as bool? ?? false,
      folderNames: (json['folder_names'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as String)) ??
          const {},
      folderMoves: (json['folder_moves'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as String)) ??
          const {},
      photos: (json['photos'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      createdAt: _parseTimestamp(json['createdAt']),
      updatedAt: json['updatedAt'] != null
          ? _parseTimestamp(json['updatedAt'])
          : null,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'landlordId': landlordId,
      'name': name,
      'address': {
        'street': address.street,
        'city': address.city,
        'state': address.state,
        'zipCode': address.zipCode,
        'country': address.country,
      },
      'type': type.toJson(),
      'purchasePrice': purchasePrice,
      'currentValue': currentValue,
      'ownership_share': ownershipShare,
      'property_type': structureType?.toJson(),
      'has_mortgage': hasMortgage,
      'track_from_year': trackFromYear,
      'utilities_paid_by': utilitiesPaidBy,
      'loan_input_cadence': loanInputCadence,
      'mortgage_settled_on': mortgageSettledOn,
      'next_setup_step': nextSetupStep,
      'folders_enabled': foldersEnabled,
      'folder_names': folderNames,
      'folder_moves': folderMoves,
      'photos': photos,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// Create PropertyModel from Firestore document
  factory PropertyModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PropertyModel.fromJson(data, doc.id);
  }

  /// Convert to Firestore document data
  Map<String, dynamic> toFirestore() {
    return toJson();
  }

  // ========== HELPER METHODS FOR SAFE PARSING ==========

  /// Safely parse double from dynamic value
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Safely parse Firestore Timestamp
  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}