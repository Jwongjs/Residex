import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/domain/entities/finance_summary.dart';
import 'package:residex_app/features/landlord/presentation/providers/finance_logic.dart';

FinanceSummary _summary({
  required int year,
  List<MonthIncome> months = const [],
  List<ExpenseLine> expenseLines = const [],
}) {
  return FinanceSummary(
    year: year,
    totals: FinanceTotals(
      receivedRent: 0,
      derivedRent: 0,
      directExpenses: 0,
      netPl: 0,
      statutoryRentalIncome: 0,
      statutoryNote: '',
    ),
    properties: [
      PropertyFinance(
        propertyId: 'p1',
        name: 'Test Property',
        receivedRent: 0,
        derivedRent: 0,
        directExpenses: 0,
        rentalIncomeOrLoss: 0,
        units: [
          UnitFinance(
            unitId: 'u1',
            label: 'Unit A',
            rentedMonths: months.length,
            contribution: 0,
            months: months,
          ),
        ],
        expenseLines: expenseLines,
      ),
    ],
  );
}

void main() {
  group('monthlyNetSeries', () {
    test('sums actual and derived income into their months', () {
      final summary = _summary(
        year: 2025,
        months: [
          MonthIncome(month: 1, source: 'actual', amount: 1000),
          MonthIncome(month: 2, source: 'derived', amount: 500),
          MonthIncome(month: 3, source: 'actual', amount: 200),
        ],
      );
      final series = monthlyNetSeries(summary);
      expect(series, [1000, 500, 200]);
    });

    test('ignores unpaid and vacant amounts entirely', () {
      final summary = _summary(
        year: 2025,
        months: [
          MonthIncome(month: 1, source: 'actual', amount: 1000),
          MonthIncome(month: 2, source: 'unpaid', amount: 999),
          MonthIncome(month: 3, source: 'vacant', amount: 999),
        ],
      );
      final series = monthlyNetSeries(summary);
      // Only Jan has activity, Feb/Mar contribute nothing -> < 2 active months.
      expect(series, isEmpty);
    });

    test('subtracts dated expense lines from the matching month', () {
      final summary = _summary(
        year: 2025,
        months: [
          MonthIncome(month: 1, source: 'actual', amount: 1000),
          MonthIncome(month: 2, source: 'actual', amount: 1000),
        ],
        expenseLines: [
          ExpenseLine(
            docId: 'd1',
            category: 'maintenance',
            amount: 300,
            date: '2025-02-15',
          ),
        ],
      );
      final series = monthlyNetSeries(summary);
      expect(series, [1000, 700]);
    });

    test('excludes expense lines with an absent or unparseable date', () {
      final summary = _summary(
        year: 2025,
        months: [
          MonthIncome(month: 1, source: 'actual', amount: 1000),
          MonthIncome(month: 2, source: 'actual', amount: 1000),
        ],
        expenseLines: [
          ExpenseLine(docId: 'd1', category: 'maintenance', amount: 300, date: null),
          ExpenseLine(docId: 'd2', category: 'maintenance', amount: 300, date: 'not-a-date'),
        ],
      );
      final series = monthlyNetSeries(summary);
      expect(series, [1000, 1000]);
    });

    test('excludes expense lines dated in a different year', () {
      final summary = _summary(
        year: 2025,
        months: [
          MonthIncome(month: 1, source: 'actual', amount: 1000),
          MonthIncome(month: 2, source: 'actual', amount: 1000),
        ],
        expenseLines: [
          ExpenseLine(
            docId: 'd1',
            category: 'maintenance',
            amount: 300,
            date: '2024-02-15',
          ),
        ],
      );
      final series = monthlyNetSeries(summary);
      expect(series, [1000, 1000]);
    });

    test('trims trailing no-activity months but keeps interior zeros', () {
      final summary = _summary(
        year: 2025,
        months: [
          MonthIncome(month: 1, source: 'actual', amount: 1000),
          MonthIncome(month: 2, source: 'vacant', amount: 0),
          MonthIncome(month: 3, source: 'actual', amount: 500),
        ],
      );
      final series = monthlyNetSeries(summary);
      expect(series, [1000, 0, 500]);
    });

    test('returns empty when fewer than 2 months have activity', () {
      final summary = _summary(
        year: 2025,
        months: [
          MonthIncome(month: 1, source: 'actual', amount: 1000),
        ],
      );
      final series = monthlyNetSeries(summary);
      expect(series, isEmpty);
    });
  });
}
