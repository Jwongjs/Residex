// lib/features/landlord/domain/entities/financial_summary.dart

/// Financial summary for dashboard
class FinancialSummary {
  final String landlordId;
  final double projectedRevenue;
  final double actualRevenue;
  final double totalExpenses;
  final double netIncome;
  final double revenueChangePercentage;
  final DateTime period;

  FinancialSummary({
    required this.landlordId,
    required this.projectedRevenue,
    required this.actualRevenue,
    required this.totalExpenses,
    required this.period,
    double? revenueChangePercentage,
  })  : netIncome = actualRevenue - totalExpenses,
        revenueChangePercentage = revenueChangePercentage ?? 0.0;

  /// Calculate profit margin percentage
  double get profitMargin {
    if (actualRevenue == 0) return 0;
    return (netIncome / actualRevenue) * 100;
  }

  /// Check if financially healthy (positive net income)
  bool get isHealthy => netIncome > 0;

  /// Revenue collection rate
  double get collectionRate {
    if (projectedRevenue == 0) return 0;
    return (actualRevenue / projectedRevenue) * 100;
  }
}