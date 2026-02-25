// lib/features/landlord/domain/entities/tenant.dart

/// Tenant rent payment status
enum RentStatus {
  paid,
  pending,
  overdue,
  partial,
}

/// Tenant account status
enum TenantStatus {
  active,
  inactive,
  suspended,
  terminated,
}

/// Pure business object - Tenant entity
class Tenant {
  final String id;
  final String propertyId;
  final String name;
  final String email;
  final String phone;
  final String unitNumber;
  final TenantStatus status;
  final RentStatus rentStatus;
  final double monthlyRent;
  final DateTime leaseStartDate;
  final DateTime leaseEndDate;
  final DateTime? lastPaymentDate;
  final DateTime createdAt;

  Tenant({
    required this.id,
    required this.propertyId,
    required this.name,
    required this.email,
    required this.phone,
    required this.unitNumber,
    required this.status,
    required this.rentStatus,
    required this.monthlyRent,
    required this.leaseStartDate,
    required this.leaseEndDate,
    this.lastPaymentDate,
    required this.createdAt,
  });

  // Business logic methods
  
  /// Check if lease is active
  bool get isLeaseActive {
    final now = DateTime.now();
    return now.isAfter(leaseStartDate) && now.isBefore(leaseEndDate);
  }

  /// Check if lease is expiring soon (within 60 days)
  bool get isLeaseExpiringSoon {
    final now = DateTime.now();
    final daysUntilExpiry = leaseEndDate.difference(now).inDays;
    return daysUntilExpiry > 0 && daysUntilExpiry <= 60;
  }

  /// Days remaining until lease expires
  int get daysUntilLeaseExpiry {
    return leaseEndDate.difference(DateTime.now()).inDays;
  }

  /// Check if rent is overdue
  bool get isRentOverdue => rentStatus == RentStatus.overdue;

  /// Check if tenant is in good standing
  bool get isInGoodStanding =>
      status == TenantStatus.active &&
      (rentStatus == RentStatus.paid || rentStatus == RentStatus.pending);

  Tenant copyWith({
    String? id,
    String? propertyId,
    String? name,
    String? email,
    String? phone,
    String? unitNumber,
    TenantStatus? status,
    RentStatus? rentStatus,
    double? monthlyRent,
    DateTime? leaseStartDate,
    DateTime? leaseEndDate,
    DateTime? lastPaymentDate,
    DateTime? createdAt,
  }) {
    return Tenant(
      id: id ?? this.id,
      propertyId: propertyId ?? this.propertyId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      unitNumber: unitNumber ?? this.unitNumber,
      status: status ?? this.status,
      rentStatus: rentStatus ?? this.rentStatus,
      monthlyRent: monthlyRent ?? this.monthlyRent,
      leaseStartDate: leaseStartDate ?? this.leaseStartDate,
      leaseEndDate: leaseEndDate ?? this.leaseEndDate,
      lastPaymentDate: lastPaymentDate ?? this.lastPaymentDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}