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
  final double directExpenses;
  final double netPl;
  final double statutoryRentalIncome;
  final String statutoryNote;

  FinanceTotals({
    required this.receivedRent,
    required this.derivedRent,
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
  final double receivedRent;
  final double derivedRent;
  final double directExpenses;
  final double rentalIncomeOrLoss;
  final List<UnitFinance> units;
  final List<ExpenseLine> expenseLines;
  final List<ExpenseLine> propertyExpenseLines;

  PropertyFinance({
    required this.propertyId,
    required this.name,
    this.ownershipShare = 1.0,
    required this.receivedRent,
    required this.derivedRent,
    required this.directExpenses,
    required this.rentalIncomeOrLoss,
    this.units = const [],
    this.expenseLines = const [],
    this.propertyExpenseLines = const [],
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
  final String source; // actual | derived | vacant
  final double amount;

  MonthIncome({required this.month, required this.source, required this.amount});
}

class ExpenseLine {
  final String docId;
  final String category;
  final String? subtype;
  final String? description;
  final double amount;
  final String? date;
  final String? unitId; // null = property-level expense

  ExpenseLine({
    required this.docId,
    required this.category,
    this.subtype,
    this.description,
    required this.amount,
    this.date,
    this.unitId,
  });
}
