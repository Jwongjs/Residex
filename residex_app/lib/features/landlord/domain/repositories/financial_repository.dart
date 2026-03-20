import '../entities/financial_summary.dart';

/// Abstract repository for financial operations
abstract class FinancialRepository {
  /// Get financial summary for a specific period
  Future<FinancialSummary> getFinancialSummary(
    String landlordId,
    DateTime period,
  );

  /// Get projected revenue for current month
  Future<double> getProjectedRevenue(String landlordId);

  /// Get actual revenue for current month
  Future<double> getActualRevenue(String landlordId);

  /// Get total expenses for current month
  Future<double> getTotalExpenses(String landlordId);

  /// Get expense breakdown by category
  Future<Map<String, double>> getExpenseBreakdown(String landlordId);

  /// Get revenue change percentage (month-over-month)
  Future<double> getRevenueChangePercentage(String landlordId);

  /// Get historical revenue data (for charts)
  Future<List<Map<String, dynamic>>> getRevenueHistory(
    String landlordId,
    int months,
  );
}