// lib/features/landlord/domain/entities/property.dart

/// Property occupancy status
enum PropertyStatus {
  occupied,
  vacant,
  maintenance,
  renovation,
}

/// Property type classification
enum PropertyType {
  apartment,
  house,
  condo,
  commercial,
  studio,
}

/// Pure business object - Property entity
/// 
/// Represents a real estate property with rental potential
class Property {
  final String id;
  final String landlordId;
  final String name;
  final String address;
  final String unitNumber;
  final PropertyType type;
  final PropertyStatus status;
  final int totalUnits;
  final int occupiedUnits;
  final double monthlyRent;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Property({
    required this.id,
    required this.landlordId,
    required this.name,
    required this.address,
    required this.unitNumber,
    required this.type,
    required this.status,
    required this.totalUnits,
    required this.occupiedUnits,
    required this.monthlyRent,
    required this.createdAt,
    this.updatedAt,
  });

  // ✅ Business Logic Methods (Domain-specific calculations)
  
  /// Calculate occupancy rate as percentage
  double get occupancyRate {
    if (totalUnits == 0) return 0;
    return (occupiedUnits / totalUnits) * 100;
  }

  /// Calculate maximum potential revenue
  double get potentialRevenue => monthlyRent * totalUnits;

  /// Calculate actual revenue from occupied units
  double get actualRevenue => monthlyRent * occupiedUnits;

  /// Calculate revenue loss from vacant units
  double get revenueLoss => potentialRevenue - actualRevenue;

  /// Check if property is fully occupied
  bool get isFullyOccupied => occupiedUnits == totalUnits;

  /// Check if property has vacancies
  bool get hasVacancy => occupiedUnits < totalUnits;

  /// Check if property needs attention (vacant or maintenance)
  bool get needsAttention =>
      status == PropertyStatus.vacant ||
      status == PropertyStatus.maintenance;

  /// Copy with method for immutability
  Property copyWith({
    String? id,
    String? landlordId,
    String? name,
    String? address,
    String? unitNumber,
    PropertyType? type,
    PropertyStatus? status,
    int? totalUnits,
    int? occupiedUnits,
    double? monthlyRent,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Property(
      id: id ?? this.id,
      landlordId: landlordId ?? this.landlordId,
      name: name ?? this.name,
      address: address ?? this.address,
      unitNumber: unitNumber ?? this.unitNumber,
      type: type ?? this.type,
      status: status ?? this.status,
      totalUnits: totalUnits ?? this.totalUnits,
      occupiedUnits: occupiedUnits ?? this.occupiedUnits,
      monthlyRent: monthlyRent ?? this.monthlyRent,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Property &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}