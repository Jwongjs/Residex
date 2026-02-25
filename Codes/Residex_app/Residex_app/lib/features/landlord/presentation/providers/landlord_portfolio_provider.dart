import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/common/property_card.dart';

/// Property data model
class Property {
  final String id;
  final String name;
  final String unitNumber;
  final PropertyStatus status;
  final String? tenantName;
  final RentStatus? rentStatus;
  final double monthlyRent;
  final String address;

  Property({
    required this.id,
    required this.name,
    required this.unitNumber,
    required this.status,
    this.tenantName,
    this.rentStatus,
    required this.monthlyRent,
    required this.address,
  });
}

/// Portfolio statistics
class PortfolioStats {
  final int totalProperties;
  final int occupiedUnits;
  final int vacantUnits;
  final double totalMonthlyRevenue;
  final double occupancyRate;

  PortfolioStats({
    required this.totalProperties,
    required this.occupiedUnits,
    required this.vacantUnits,
    required this.totalMonthlyRevenue,
  }) : occupancyRate = (occupiedUnits / totalProperties * 100);
}

/// Provider for property portfolio (mock data Phase 1)
final portfolioPropertiesProvider = Provider<List<Property>>((ref) {
  return [
    Property(
      id: '1',
      name: 'Verdi Eco-Dominium',
      unitNumber: 'Unit 4-2',
      status: PropertyStatus.occupied,
      tenantName: 'Ali Rahman',
      rentStatus: RentStatus.paid,
      monthlyRent: 1800.0,
      address: 'Cyberjaya, Selangor',
    ),
    Property(
      id: '2',
      name: 'The Grand Subang',
      unitNumber: 'Block B-12',
      status: PropertyStatus.occupied,
      tenantName: 'Sarah Tan',
      rentStatus: RentStatus.pending,
      monthlyRent: 2200.0,
      address: 'Subang Jaya, Selangor',
    ),
    Property(
      id: '3',
      name: 'Arcuz Kelana Jaya',
      unitNumber: 'Unit 08-01',
      status: PropertyStatus.vacant,
      monthlyRent: 1600.0,
      address: 'Kelana Jaya, Selangor',
    ),
    Property(
      id: '4',
      name: 'Soho Suites KLCC',
      unitNumber: 'Unit 15-A',
      status: PropertyStatus.occupied,
      tenantName: 'Michael Wong',
      rentStatus: RentStatus.paid,
      monthlyRent: 3500.0,
      address: 'KLCC, Kuala Lumpur',
    ),
  ];
});

/// Provider for portfolio statistics
final portfolioStatsProvider = Provider<PortfolioStats>((ref) {
  final properties = ref.watch(portfolioPropertiesProvider);
  
  final occupied = properties.where((p) => p.status == PropertyStatus.occupied).length;
  final vacant = properties.where((p) => p.status == PropertyStatus.vacant).length;
  
  final totalRevenue = properties
      .where((p) => p.status == PropertyStatus.occupied)
      .fold<double>(0, (sum, p) => sum + p.monthlyRent);

  return PortfolioStats(
    totalProperties: properties.length,
    occupiedUnits: occupied,
    vacantUnits: vacant,
    totalMonthlyRevenue: totalRevenue,
  );
});