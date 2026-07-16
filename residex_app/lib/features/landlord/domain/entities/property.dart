// lib/features/landlord/domain/entities/property.dart

/// Property type classification
enum PropertyType {
  apartment,
  house,
  condo,
  commercial;

  String toJson() => name;
  
  static PropertyType fromJson(String json) {
    return PropertyType.values.firstWhere(
      (type) => type.name == json,
      orElse: () => PropertyType.apartment,
    );
  }
  
  String get displayName {
    switch (this) {
      case PropertyType.apartment:
        return 'Apartment';
      case PropertyType.house:
        return 'House';
      case PropertyType.condo:
        return 'Condo';
      case PropertyType.commercial:
        return 'Commercial';
    }
  }
}

/// Address value object
class PropertyAddress {
  final String street;
  final String city;
  final String state;
  final String zipCode;
  final String country;

  const PropertyAddress({
    required this.street,
    required this.city,
    required this.state,
    required this.zipCode,
    required this.country,
  });

  String get fullAddress => '$street, $city, $state $zipCode, $country';
  
  PropertyAddress copyWith({
    String? street,
    String? city,
    String? state,
    String? zipCode,
    String? country,
  }) {
    return PropertyAddress(
      street: street ?? this.street,
      city: city ?? this.city,
      state: state ?? this.state,
      zipCode: zipCode ?? this.zipCode,
      country: country ?? this.country,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PropertyAddress &&
          street == other.street &&
          city == other.city &&
          state == other.state &&
          zipCode == other.zipCode &&
          country == other.country;

  @override
  int get hashCode => Object.hash(street, city, state, zipCode, country);
}

/// Pure business object - Property entity
///
/// Represents a real estate property with rental potential. Per-unit rent
/// and occupancy live on the Unit entity (properties/{id}/units subcollection),
/// not here — Property no longer tracks aggregate unit counts or rent.
/// Matches Firebase schema: properties/{propertyId}
class Property {
  final String id;
  final String landlordId;
  final String name;
  final PropertyAddress address;
  final PropertyType type;
  final double purchasePrice;
  final double currentValue;

  /// The landlord's share of this property (0-1). Co-ownership is the norm
  /// in the reference data; the finance engine scales the statutory figure
  /// by this. 1.0 = solely owned.
  final double ownershipShare;

  final List<String> photos;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Property({
    required this.id,
    required this.landlordId,
    required this.name,
    required this.address,
    required this.type,
    required this.purchasePrice,
    required this.currentValue,
    this.ownershipShare = 1.0,
    this.photos = const [],
    required this.createdAt,
    this.updatedAt,
  });

  /// Calculate property appreciation
  double get appreciation => currentValue - purchasePrice;
  
  /// Calculate appreciation percentage
  double get appreciationPercentage {
    if (purchasePrice == 0) return 0;
    return ((currentValue - purchasePrice) / purchasePrice) * 100;
  }

  /// Calculate return on investment (simplified, actual ROI needs rental income data)
  double get roi {
    if (purchasePrice == 0) return 0;
    return (appreciation / purchasePrice) * 100;
  }

  /// Copy with method for immutability
  Property copyWith({
    String? id,
    String? landlordId,
    String? name,
    PropertyAddress? address,
    PropertyType? type,
    double? purchasePrice,
    double? currentValue,
    double? ownershipShare,
    List<String>? photos,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Property(
      id: id ?? this.id,
      landlordId: landlordId ?? this.landlordId,
      name: name ?? this.name,
      address: address ?? this.address,
      type: type ?? this.type,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      currentValue: currentValue ?? this.currentValue,
      ownershipShare: ownershipShare ?? this.ownershipShare,
      photos: photos ?? this.photos,
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