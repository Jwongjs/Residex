import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/domain/entities/finance_summary.dart';
import 'package:residex_app/features/landlord/presentation/providers/finance_providers.dart';
import 'package:residex_app/features/landlord/presentation/screens/3-Finance/finance_screen.dart';

FinanceSummary _fakeSummary(int year) {
  return FinanceSummary(
    year: year,
    totals: FinanceTotals(
      receivedRent: 84000.0,
      derivedRent: 0.0,
      directExpenses: 59516.87,
      netPl: 24483.13,
      statutoryRentalIncome: 24483.13,
      statutoryNote: 'Estimate — for your tax agent',
    ),
    expenseBreakdown: const {'loan': 32000.0},
    properties: [
      PropertyFinance(
        propertyId: 'p1',
        name: 'Ayer 8',
        ownershipShare: 0.5,
        receivedRent: 84000.0,
        derivedRent: 0.0,
        directExpenses: 59516.87,
        rentalIncomeOrLoss: 24483.13,
        units: [
          UnitFinance(
            unitId: 'u1',
            label: 'Unit A',
            rentedMonths: 12,
            contribution: 84000.0,
            months: const [],
          ),
        ],
        coverage: [
          YearCoverage(year: 2025, missing: const ['insurance']),
          YearCoverage(year: 2026, missing: const []),
        ],
      ),
    ],
    caveats: const ['Income assumes rent billed equals rent received — invoices are the ledger, payment is not confirmed.'],
    missingCategories: const {
      'p1': ['insurance']
    },
  );
}

void main() {
  testWidgets('Finance tab renders headline, property block and completeness',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeYearsProvider.overrideWith(
              (ref) async => [DateTime.now().year, DateTime.now().year - 1]),
          financeSummaryProvider.overrideWith(
              (ref, year) async => _fakeSummary(year)),
        ],
        child: const MaterialApp(home: FinanceScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Statutory rental income'), findsOneWidget);
    expect(find.text('RM 24,483.13'), findsWidgets); // statutory + P/L rows
    expect(find.text('Ayer 8'), findsOneWidget);
    expect(find.textContaining('Estimate'), findsWidgets);
    expect(find.text('Unit A'), findsOneWidget);
    expect(find.textContaining('50%'), findsOneWidget); // ownership badge
    expect(find.textContaining('Insurance policy'), findsOneWidget); // missing category
    expect(find.textContaining('1 missing'), findsOneWidget); // coverage chip for 2025
  });
}
