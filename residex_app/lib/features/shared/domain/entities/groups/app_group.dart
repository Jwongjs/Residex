/// Represents a tenant house-share group (the central unit linking tenants + property)
class AppGroup {
  final String id;
  final String name;
  final String? address;
  final List<String> tenantIds;
  final String? landlordId;
  final String emoji;
  final int colorValue;
  final DateTime? leaseStartDate;
  final DateTime? leaseEndDate;
  final String? createdBy;

  const AppGroup({
    required this.id,
    required this.name,
    this.address,
    required this.tenantIds,
    this.landlordId,
    required this.emoji,
    required this.colorValue,
    this.leaseStartDate,
    this.leaseEndDate,
    this.createdBy,
  });

  AppGroup copyWith({
    String? id,
    String? name,
    String? address,
    List<String>? tenantIds,
    String? landlordId,
    String? emoji,
    int? colorValue,
    DateTime? leaseStartDate,
    DateTime? leaseEndDate,
    String? createdBy,
  }) {
    return AppGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      tenantIds: tenantIds ?? this.tenantIds,
      landlordId: landlordId ?? this.landlordId,
      emoji: emoji ?? this.emoji,
      colorValue: colorValue ?? this.colorValue,
      leaseStartDate: leaseStartDate ?? this.leaseStartDate,
      leaseEndDate: leaseEndDate ?? this.leaseEndDate,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppGroup && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
