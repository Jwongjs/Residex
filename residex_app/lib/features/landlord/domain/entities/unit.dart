// lib/features/landlord/domain/entities/unit.dart

/// Pure business object - Unit entity
///
/// Represents a single rentable unit within a Property (e.g. "Unit 1" in a
/// 10-unit apartment building). Each unit has its own rent and occupancy
/// status — Property no longer stores a flat rent/unit-count.
/// Matches Firebase schema: properties/{propertyId}/units/{unitId}
class Unit {
  final String id;
  final String propertyId;
  final String label;
  final double monthlyRent;
  final bool isOccupied;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Unit({
    required this.id,
    required this.propertyId,
    required this.label,
    required this.monthlyRent,
    required this.isOccupied,
    required this.createdAt,
    this.updatedAt,
  });

  Unit copyWith({
    String? id,
    String? propertyId,
    String? label,
    double? monthlyRent,
    bool? isOccupied,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Unit(
      id: id ?? this.id,
      propertyId: propertyId ?? this.propertyId,
      label: label ?? this.label,
      monthlyRent: monthlyRent ?? this.monthlyRent,
      isOccupied: isOccupied ?? this.isOccupied,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Unit &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
