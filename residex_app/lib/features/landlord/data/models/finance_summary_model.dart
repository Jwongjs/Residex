import '../../domain/entities/finance_summary.dart';

/// JSON -> FinanceSummary parsing for the finance summary endpoint.
/// Defensive: absent/oddly-typed fields fall back to zeros/empties so a
/// malformed field can never crash the Finance tab.
class FinanceSummaryModel {
  static FinanceSummary fromJson(Map<String, dynamic> json) {
    return FinanceSummary(
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      totals: _totals(json['totals'] as Map<String, dynamic>? ?? const {}),
      expenseBreakdown: _doubleMap(json['expense_breakdown']),
      properties: (json['properties'] as List<dynamic>? ?? const [])
          .map((p) => _property(p as Map<String, dynamic>))
          .toList(),
      caveats: (json['caveats'] as List<dynamic>? ?? const [])
          .map((c) => c.toString())
          .toList(),
      missingCategories: (json['missing_categories'] as Map<String, dynamic>? ?? const {})
          .map((key, value) => MapEntry(
                key,
                (value as List<dynamic>? ?? const []).map((v) => v.toString()).toList(),
              )),
    );
  }

  static FinanceTotals _totals(Map<String, dynamic> json) {
    return FinanceTotals(
      receivedRent: _d(json['received_rent']),
      derivedRent: _d(json['derived_rent']),
      outstandingRent: _d(json['outstanding_rent']),
      directExpenses: _d(json['direct_expenses']),
      netPl: _d(json['net_pl']),
      landlordExpenses: _d(json['landlord_expenses']),
      statutoryRentalIncome: _d(json['statutory_rental_income']),
      statutoryNote: json['statutory_note'] as String? ?? 'Estimate — for your tax agent',
    );
  }

  static PropertyFinance _property(Map<String, dynamic> json) {
    return PropertyFinance(
      propertyId: json['property_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Property',
      ownershipShare: json['ownership_share'] == null ? 1.0 : _d(json['ownership_share']),
      complete: json['complete'] as bool? ?? true,
      receivedRent: _d(json['received_rent']),
      derivedRent: _d(json['derived_rent']),
      outstandingRent: _d(json['outstanding_rent']),
      directExpenses: _d(json['direct_expenses']),
      rentalIncomeOrLoss: _d(json['rental_income_or_loss']),
      netPl: _d(json['net_pl']),
      statutoryContribution:
          json['statutory_contribution'] == null ? null : _d(json['statutory_contribution']),
      units: (json['units'] as List<dynamic>? ?? const [])
          .map((u) => _unit(u as Map<String, dynamic>))
          .toList(),
      expenseLines: _lines(json['expense_lines']),
      propertyExpenseLines: _lines(json['property_expense_lines']),
      recoveredRent: (json['recovered_rent'] as List<dynamic>? ?? const [])
          .map((r) => r as Map<String, dynamic>)
          .map((r) => RecoveredRentLine(
                unitId: r['unit_id'] as String?,
                originalMonth: r['original_month'] as String? ?? '',
                amount: _d(r['amount']),
                label: r['label'] as String? ?? 'Recovered rent',
              ))
          .toList(),
      coverage: (json['coverage'] as List<dynamic>? ?? const [])
          .map((c) => c as Map<String, dynamic>)
          .map((c) => YearCoverage(
                year: (c['year'] as num?)?.toInt() ?? 0,
                missing: (c['missing'] as List<dynamic>? ?? const [])
                    .map((m) => m.toString())
                    .toList(),
                partialInstallments: (c['partial_installments'] as List<dynamic>? ?? const [])
                    .map((g) => g as Map<String, dynamic>)
                    .map((g) => InstallmentGap(
                          label: g['label'] as String? ?? '',
                          have: (g['have'] as num?)?.toInt() ?? 0,
                          expect: (g['expect'] as num?)?.toInt() ?? 0,
                        ))
                    .toList(),
                partialCategories: (c['partial_categories'] as List<dynamic>? ?? const [])
                    .map((p) => p as Map<String, dynamic>)
                    .map((p) => PartialCategory(
                          category: p['category'] as String? ?? '',
                          have: (p['have'] as num?)?.toInt() ?? 0,
                          expect: (p['expect'] as num?)?.toInt() ?? 0,
                        ))
                    .toList(),
                unavailable: (c['unavailable'] as List<dynamic>? ?? const [])
                    .map((u) => u.toString())
                    .toList(),
              ))
          .toList(),
      expectedCategories: (json['expected_categories'] as List<dynamic>? ?? const [])
          .map((c) => c.toString())
          .toList(),
      manualLoanIncomplete: json['manual_loan_incomplete'] as bool? ?? false,
    );
  }

  static UnitFinance _unit(Map<String, dynamic> json) {
    return UnitFinance(
      unitId: json['unit_id'] as String?,
      label: json['label'] as String? ?? 'Unit',
      rentedMonths: (json['rented_months'] as num?)?.toInt() ?? 0,
      contribution: _d(json['contribution']),
      statutoryContribution: _d(json['statutory_contribution']),
      months: (json['months'] as List<dynamic>? ?? const [])
          .map((m) => m as Map<String, dynamic>)
          .map((m) => MonthIncome(
                month: (m['month'] as num?)?.toInt() ?? 0,
                source: m['source'] as String? ?? 'vacant',
                amount: _d(m['amount']),
                reason: m['reason'] as String?,
                paymentState: m['payment_state'] as String?,
                billedAmount: m['billed_amount'] == null ? null : _d(m['billed_amount']),
              ))
          .toList(),
      missingInvoiceMonths: (json['missing_invoice_months'] as List<dynamic>? ?? const [])
          .map((m) => (m as num).toInt())
          .toList(),
      expenseLines: _lines(json['expense_lines']),
      loanStatus: json['loan_status'] as String?,
    );
  }

  static List<ExpenseLine> _lines(dynamic value) {
    return (value as List<dynamic>? ?? const [])
        .map((l) => l as Map<String, dynamic>)
        .map((l) => ExpenseLine(
              docId: l['doc_id'] as String? ?? '',
              category: l['category'] as String? ?? 'other',
              subtype: l['subtype'] as String?,
              description: l['description'] as String?,
              amount: _d(l['amount']),
              date: l['date'] as String?,
              unitId: l['unit_id'] as String?,
              deductible: l['deductible'] as bool? ?? true,
              paidByLandlord: l['paid_by_landlord'] as bool? ?? true,
            ))
        .toList();
  }

  static Map<String, double> _doubleMap(dynamic value) {
    return (value as Map<String, dynamic>? ?? const {})
        .map((key, v) => MapEntry(key, _d(v)));
  }

  static double _d(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
