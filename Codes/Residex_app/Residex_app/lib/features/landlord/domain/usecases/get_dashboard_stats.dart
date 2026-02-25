import '../entities/property.dart';
import '../entities/financial_summary.dart';
import '../repositories/property_repository.dart';
import '../repositories/financial_repository.dart';

/// Dashboard statistics model
class DashboardStats {
  final double projectedRevenue;
  final double revenueChangePercentage;
  final int occupiedUnits;
  final int totalUnits;
  final int systemHealthScore;
  final int activeMaintenance;

  DashboardStats({
    required this.projectedRevenue,
    required this.revenueChangePercentage,
    required this.occupiedUnits,
    required this.totalUnits,
    required this.systemHealthScore,
    required this.activeMaintenance,
  });
}

/// Use case for fetching dashboard overview statistics
/// 
/// Orchestrates multiple repositories to provide comprehensive dashboard data
class GetDashboardStats {
  final PropertyRepository propertyRepository;
  final FinancialRepository financialRepository;

  GetDashboardStats({
    required this.propertyRepository,
    required this.financialRepository,
  });

  Future<DashboardStats> call(String landlordId) async {
    // Fetch data from repositories
    final properties = await propertyRepository.getPropertiesByLandlord(landlordId);
    final financialSummary = await financialRepository.getFinancialSummary(
      landlordId,
      DateTime.now(),
    );
    final occupiedUnits = await propertyRepository.getTotalOccupiedUnits(landlordId);
    final totalUnits = await propertyRepository.getTotalUnits(landlordId);

    // Calculate derived metrics
    final occupancyRate = totalUnits > 0 ? ((occupiedUnits / totalUnits) * 100).toDouble() : 0.0;
    
    // Calculate system health score (0-100)
    final healthScore = _calculateSystemHealth(
      occupancyRate: occupancyRate,
      profitMargin: financialSummary.profitMargin,
      propertyCount: properties.length,
    );

    return DashboardStats(
      projectedRevenue: financialSummary.projectedRevenue,
      revenueChangePercentage: financialSummary.revenueChangePercentage,
      occupiedUnits: occupiedUnits,
      totalUnits: totalUnits,
      systemHealthScore: healthScore,
      activeMaintenance: 0, // TODO: Add maintenance repository
    );
  }

  /// Business logic: Custom health scoring algorithm
  int _calculateSystemHealth({
    required double occupancyRate,
    required double profitMargin,
    required int propertyCount,
  }) {
    int score = 100;

    // Penalize low occupancy (critical factor)
    if (occupancyRate < 60) {
      score -= 30;
    } else if (occupancyRate < 75) {
      score -= 15;
    } else if (occupancyRate < 90) {
      score -= 5;
    }

    // Penalize low profit margin
    if (profitMargin < 10) {
      score -= 20;
    } else if (profitMargin < 20) {
      score -= 10;
    }

    // Bonus for portfolio growth
    if (propertyCount > 5) {
      score += 5;
    }

    return score.clamp(0, 100);
  }
}