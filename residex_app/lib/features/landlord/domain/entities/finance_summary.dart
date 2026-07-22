/// Deterministic finance summary computed by the backend engine
/// (GET /api/rex/documind/finance/summary). Pure display data — the app
/// never recomputes any figure.
class FinanceSummary {
  final int year;
  final FinanceTotals totals;
  final Map<String, double> expenseBreakdown;
  final List<PropertyFinance> properties;
  final List<String> caveats;
  final Map<String, List<String>> missingCategories;

  FinanceSummary({
    required this.year,
    required this.totals,
    this.expenseBreakdown = const {},
    this.properties = const [],
    this.caveats = const [],
    this.missingCategories = const {},
  });
}

class FinanceTotals {
  final double receivedRent;
  final double derivedRent;
  final double outstandingRent;
  final double directExpenses;
  final double netPl;
  final double statutoryRentalIncome;
  final String statutoryNote;

  FinanceTotals({
    required this.receivedRent,
    required this.derivedRent,
    this.outstandingRent = 0.0,
    required this.directExpenses,
    required this.netPl,
    required this.statutoryRentalIncome,
    required this.statutoryNote,
  });
}

class PropertyFinance {
  final String propertyId;
  final String name;
  final double ownershipShare;
  final bool complete;
  final double receivedRent;
  final double derivedRent;
  final double outstandingRent;
  final double directExpenses;
  final double rentalIncomeOrLoss;
  final List<UnitFinance> units;
  final List<ExpenseLine> expenseLines;
  final List<ExpenseLine> propertyExpenseLines;
  final List<RecoveredRentLine> recoveredRent;
  final List<YearCoverage> coverage;
  final List<String> expectedCategories;

  PropertyFinance({
    required this.propertyId,
    required this.name,
    this.ownershipShare = 1.0,
    this.complete = true,
    required this.receivedRent,
    required this.derivedRent,
    this.outstandingRent = 0.0,
    required this.directExpenses,
    required this.rentalIncomeOrLoss,
    this.units = const [],
    this.expenseLines = const [],
    this.propertyExpenseLines = const [],
    this.recoveredRent = const [],
    this.coverage = const [],
    this.expectedCategories = const [],
  });
}

class InstallmentGap {
  final String label;
  final int have;
  final int expect;

  InstallmentGap({required this.label, required this.have, required this.expect});
}

class PartialCategory {
  final String category;
  final int have;
  final int expect;

  PartialCategory({required this.category, required this.have, required this.expect});
}

class YearCoverage {
  final int year;
  final List<String> missing;
  final List<InstallmentGap> partialInstallments;
  final List<PartialCategory> partialCategories;
  final List<String> unavailable;

  YearCoverage({
    required this.year,
    this.missing = const [],
    this.partialInstallments = const [],
    this.partialCategories = const [],
    this.unavailable = const [],
  });
}

class RecoveredRentLine {
  final String? unitId;
  final String originalMonth;
  final double amount;
  final String label;

  RecoveredRentLine({
    this.unitId,
    required this.originalMonth,
    required this.amount,
    required this.label,
  });
}

class UnitFinance {
  /// Null = the synthetic "Whole property" income line.
  final String? unitId;
  final String label;
  final int rentedMonths;
  final double contribution;
  final List<MonthIncome> months;
  final List<int> missingInvoiceMonths;
  final List<ExpenseLine> expenseLines;

  UnitFinance({
    this.unitId,
    required this.label,
    required this.rentedMonths,
    required this.contribution,
    this.months = const [],
    this.missingInvoiceMonths = const [],
    this.expenseLines = const [],
  });
}

class MonthIncome {
  final int month; // 1-12
  final String source; // actual | derived | unpaid | vacant
  final double amount;
  final String? reason;
  final String? paymentState; // outstanding | written_off, only when source == 'unpaid'
  final double? billedAmount;

  MonthIncome({
    required this.month,
    required this.source,
    required this.amount,
    this.reason,
    this.paymentState,
    this.billedAmount,
  });
}

class ExpenseLine {
  final String docId;
  final String category;
  final String? subtype;
  final String? description;
  final double amount;
  final String? date;
  final String? unitId; // null = property-level expense
  final bool deductible;

  ExpenseLine({
    required this.docId,
    required this.category,
    this.subtype,
    this.description,
    required this.amount,
    this.date,
    this.unitId,
    this.deductible = true,
  });
}
