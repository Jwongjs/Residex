import 'package:flutter/material.dart';


/// Status of a bill
  enum BillStatus {
    pending,
    settled;

    /// Helper to check if bill is settled
    bool get isSettled => this == BillStatus.settled;
  }

  /// Type of receipt item
  enum ReceiptItemType {
    item,
    tax,
    discount;

    bool get isTaxOrDiscount => this == ReceiptItemType.tax || this ==
  ReceiptItemType.discount;
  }

  /// Filter types for bills
  enum FilterType {
    all,
    pending,
    settled;

    String get label {
      switch (this) {
        case FilterType.all:
          return 'All';
        case FilterType.pending:
          return 'Pending';
        case FilterType.settled:
          return 'Settled';
      }
    }
  }

    /// Category of utility bill
enum BillCategory {
  rent,
  electricity,
  water,
  internet,
  gas,
  other;

  String get label {
    switch (this) {
      case BillCategory.rent:
        return 'Rent';
      case BillCategory.electricity:
        return 'Electricity';
      case BillCategory.water:
        return 'Water';
      case BillCategory.internet:
        return 'Internet';
      case BillCategory.gas:
        return 'Gas';
      case BillCategory.other:
        return 'Other';
    }
  }

  /// Get icon for category (Material Icons)
  IconData get icon {
    switch (this) {
      case BillCategory.rent:
        return Icons.home_rounded;
      case BillCategory.electricity:
        return Icons.flash_on_rounded;
      case BillCategory.water:
        return Icons.water_drop_rounded;
      case BillCategory.internet:
        return Icons.wifi_rounded;
      case BillCategory.gas:
        return Icons.local_fire_department_rounded;
      case BillCategory.other:
        return Icons.description_rounded;
    }
  }

  /// Get color for category (matching screenshot colors)
  Color get color {
    switch (this) {
      case BillCategory.rent:
        return const Color(0xFF10B981); // Green/Emerald
      case BillCategory.electricity:
        return const Color(0xFFF59E0B); // Orange/Yellow
      case BillCategory.water:
        return const Color(0xFF3B82F6); // Blue
      case BillCategory.internet:
        return const Color(0xFFA855F7); // Purple
      case BillCategory.gas:
        return const Color(0xFFEF4444); // Red
      case BillCategory.other:
        return const Color(0xFF64748B); // Gray
    }
  }

  /// Get background color for category icon
  Color get backgroundColor {
    switch (this) {
      case BillCategory.rent:
        return const Color(0xFF10B981).withValues(alpha: 0.15);
      case BillCategory.electricity:
        return const Color(0xFFF59E0B).withValues(alpha: 0.15);
      case BillCategory.water:
        return const Color(0xFF3B82F6).withValues(alpha: 0.15);
      case BillCategory.internet:
        return const Color(0xFFA855F7).withValues(alpha: 0.15);
      case BillCategory.gas:
        return const Color(0xFFEF4444).withValues(alpha: 0.15);
      case BillCategory.other:
        return const Color(0xFF64748B).withValues(alpha: 0.15);
    }
  }

  /// Get common provider names for category
  List<String> get commonProviders {
    switch (this) {
      case BillCategory.rent:
        return ['LANDLORD', 'PROPERTY MANAGEMENT'];
      case BillCategory.electricity:
        return ['TNB', 'SESB', 'SEB', 'SESCO'];
      case BillCategory.water:
        return ['AIR SELANGOR', 'SYABAS', 'SAJ', 'PBA', 'SAINS'];
      case BillCategory.internet:
        return ['TIME', 'MAXIS', 'UNIFI', 'CELCOM', 'DIGI', 'YES'];
      case BillCategory.gas:
        return ['GAS PETRONAS', 'GAS MALAYSIA'];
      case BillCategory.other:
        return ['OTHER'];
    }
  }
}

/// Payment status for bills (enhanced)
enum PaymentStatus {
  paid,
  unpaid,
  pending;

  String get label {
    switch (this) {
      case PaymentStatus.paid:
        return 'PAID';
      case PaymentStatus.unpaid:
        return 'UNPAID';
      case PaymentStatus.pending:
        return 'PENDING';
    }
  }

  Color get color {
    switch (this) {
      case PaymentStatus.paid:
        return const Color(0xFF10B981); // Green
      case PaymentStatus.unpaid:
        return const Color(0xFFEF4444); // Red
      case PaymentStatus.pending:
        return const Color(0xFF3B82F6); // Blue
    }
  }

  Color get backgroundColor {
    switch (this) {
      case PaymentStatus.paid:
        return const Color(0xFF10B981).withValues(alpha: 0.15);
      case PaymentStatus.unpaid:
        return const Color(0xFFEF4444).withValues(alpha: 0.15);
      case PaymentStatus.pending:
        return const Color(0xFF3B82F6).withValues(alpha: 0.15);
    }
  }
  }
