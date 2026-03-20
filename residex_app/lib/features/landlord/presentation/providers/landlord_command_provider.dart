import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dashboard statistics data model
class DashboardStats {
  final double projectedRevenue;
  final double revenueChangePercentage;
  final int systemHealthScore;
  final int activeMaintenance;
  final int occupiedUnits;
  final int totalUnits;

  DashboardStats({
    required this.projectedRevenue,
    required this.revenueChangePercentage,
    required this.systemHealthScore,
    required this.activeMaintenance,
    required this.occupiedUnits,
    required this.totalUnits,
  });
}

/// Provider for landlord dashboard data
/// 
/// In production, this would fetch from:
/// - Repository (domain layer)
/// - Use cases (business logic)
/// - Remote/local data sources
final landlordCommandProvider = Provider<DashboardStats>((ref) {
  // TODO: Replace with actual repository call
  // final repository = ref.watch(propertyRepositoryProvider);
  // return repository.getDashboardStats();
  
  // Mock data for now
  return DashboardStats(
    projectedRevenue: 14250.00,
    revenueChangePercentage: 8.4,
    systemHealthScore: 87,
    activeMaintenance: 2,
    occupiedUnits: 3,
    totalUnits: 4,
  );
});