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

  /// This unit's own ownership share, 0–1. Null means "inherit the
  /// property's" — the overwhelmingly common case. An explicit 1.0 is a
  /// distinct, meaningful state: a unit owned outright inside a property
  /// that is otherwise co-owned.
  final double? ownershipShare;

  final DateTime createdAt;
  final DateTime? updatedAt;

  Unit({
    required this.id,
    required this.propertyId,
    required this.label,
    required this.monthlyRent,
    required this.isOccupied,
    this.ownershipShare,
    required this.createdAt,
    this.updatedAt,
  });

  Unit copyWith({
    String? id,
    String? propertyId,
    String? label,
    double? monthlyRent,
    bool? isOccupied,
    double? ownershipShare,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Unit(
      id: id ?? this.id,
      propertyId: propertyId ?? this.propertyId,
      label: label ?? this.label,
      monthlyRent: monthlyRent ?? this.monthlyRent,
      isOccupied: isOccupied ?? this.isOccupied,
      ownershipShare: ownershipShare ?? this.ownershipShare,
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
