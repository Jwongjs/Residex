import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/domain/entities/finance_summary.dart';
import 'package:residex_app/features/landlord/presentation/providers/finance_providers.dart';
import 'package:residex_app/features/landlord/presentation/screens/3-Finance/unit_finance_detail_screen.dart';

FinanceSummary _summaryWithUnit(int year, UnitFinance unit) {
  return FinanceSummary(
    year: year,
    totals: FinanceTotals(
      receivedRent: 3200.0,
      derivedRent: 0.0,
      directExpenses: 0.0,
      netPl: 3200.0,
      statutoryRentalIncome: 3200.0,
      statutoryNote: '',
    ),
    properties: [
      PropertyFinance(
        propertyId: 'p1',
        name: 'Ayer 8',
        receivedRent: 3200.0,
        derivedRent: 0.0,
        directExpenses: 0.0,
        rentalIncomeOrLoss: 3200.0,
        units: [unit],
      ),
    ],
  );
}

Future<void> _pumpScreen(WidgetTester tester, int year, UnitFinance unit) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        financeYearsProvider.overrideWith((ref) async => [year]),
        financeSummaryProvider.overrideWith((ref, y) async => _summaryWithUnit(y, unit)),
      ],
      child: MaterialApp(
        home: UnitFinanceDetailScreen(
          propertyId: 'p1',
          propertyName: 'Ayer 8',
          unit: unit,
          year: year,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a month cell renders the full currency string without an ellipsis',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final year = DateTime.now().year;
    final unit = UnitFinance(
      unitId: 'u1',
      label: 'Unit A',
      rentedMonths: 1,
      contribution: 2900.0,
      months: [
        MonthIncome(month: 1, source: 'actual', amount: 3200.0),
      ],
    );
    await _pumpScreen(tester, year, unit);

    expect(tester.takeException(), isNull);
    expect(find.text('RM 3,200.00'), findsOneWidget);
    expect(find.textContaining('RM 3,200.00…'), findsNothing);
  });

  testWidgets('the net-contribution accordion is collapsed by default and reveals the breakdown on tap',
      (tester) async {
    final year = DateTime.now().year;
    final unit = UnitFinance(
      unitId: 'u1',
      label: 'Unit A',
      rentedMonths: 1,
      contribution: 2800.0,
      months: [
        MonthIncome(month: 1, source: 'actual', amount: 3200.0),
      ],
      expenseLines: [
        ExpenseLine(
          docId: 'd1',
          category: 'maintenance',
          description: 'Plumbing repair',
          amount: 400.0,
          date: '2025-01-15',
        ),
      ],
    );
    await _pumpScreen(tester, year, unit);

    expect(find.text('Gross income'), findsNothing);
    expect(find.text('Plumbing repair'), findsNothing);

    await tester.tap(find.text('Net contribution'));
    await tester.pumpAndSettle();

    expect(find.text('Gross income'), findsOneWidget);
    expect(find.text('Plumbing repair'), findsOneWidget);
  });

  testWidgets('a tenant-paid utility line is marked excluded and kept out of the direct-expenses total',
      (tester) async {
    final year = DateTime.now().year;
    final unit = UnitFinance(
      unitId: 'u1',
      label: 'Unit A',
      rentedMonths: 1,
      // Backend already excluded the RM 80 utility: 3200 gross − 300 deductible.
      contribution: 2900.0,
      months: [
        MonthIncome(month: 3, source: 'actual', amount: 3200.0),
      ],
      expenseLines: [
        ExpenseLine(
          docId: 'd1', category: 'maintenance', subtype: 'maintenance',
          description: 'Service charge', amount: 300.0, date: '2025-03-01',
        ),
        ExpenseLine(
          docId: 'd2', category: 'utilities', subtype: 'utilities',
          description: 'Water meter', amount: 80.0, date: '2025-03-01',
          deductible: false,
        ),
      ],
    );
    await _pumpScreen(tester, year, unit);
    await tester.tap(find.text('Net contribution'));
    await tester.pumpAndSettle();

    // Total reflects only the deductible RM 300, not RM 380.
    expect(find.text('−RM 300.00'), findsOneWidget);
    expect(find.text('−RM 380.00'), findsNothing);
    // The excluded line still shows, tagged with its reason.
    expect(find.text('Water meter'), findsOneWidget);
    expect(find.text('Tenant pays — excluded'), findsOneWidget);
  });

  testWidgets('an empty expenseLines list shows the no-direct-expenses row',
      (tester) async {
    final year = DateTime.now().year;
    final unit = UnitFinance(
      unitId: 'u1',
      label: 'Unit A',
      rentedMonths: 1,
      contribution: 3200.0,
      months: [
        MonthIncome(month: 1, source: 'actual', amount: 3200.0),
      ],
    );
    await _pumpScreen(tester, year, unit);

    await tester.tap(find.text('Net contribution'));
    await tester.pumpAndSettle();

    expect(find.text('No direct expenses recorded for $year'), findsOneWidget);
  });

  testWidgets('switching years shows a spinner while the new year loads, then updates',
      (tester) async {
    final year = DateTime.now().year;
    final nextYear = year + 1;
    final unitYear1 = UnitFinance(
      unitId: 'u1', label: 'Unit A', rentedMonths: 1, contribution: 3200.0,
      months: [MonthIncome(month: 1, source: 'actual', amount: 3200.0)],
    );
    final unitYear2 = UnitFinance(
      unitId: 'u1', label: 'Unit A', rentedMonths: 1, contribution: 5000.0,
      months: [MonthIncome(month: 1, source: 'actual', amount: 5000.0)],
    );
    final completer = Completer<FinanceSummary>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeYearsProvider.overrideWith((ref) async => [year, nextYear]),
          financeSummaryProvider.overrideWith((ref, y) {
            if (y == year) return Future.value(_summaryWithUnit(y, unitYear1));
            return completer.future;
          }),
        ],
        child: MaterialApp(
          home: UnitFinanceDetailScreen(
            propertyId: 'p1', propertyName: 'Ayer 8', unit: unitYear1, year: year,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('$year'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('$nextYear'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Unit A — $year'), findsOneWidget); // still frozen on old year

    completer.complete(_summaryWithUnit(nextYear, unitYear2));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Unit A — $nextYear'), findsOneWidget);
    expect(find.text('RM 5,000.00'), findsWidgets);
  });

  testWidgets('switching years twice in a row both show a spinner and update',
      (tester) async {
    final year = DateTime.now().year;
    final year2 = year + 1;
    final year3 = year + 2;
    final unit1 = UnitFinance(
      unitId: 'u1', label: 'Unit A', rentedMonths: 1, contribution: 1000.0,
      months: [MonthIncome(month: 1, source: 'actual', amount: 1000.0)],
    );
    final unit2 = UnitFinance(
      unitId: 'u1', label: 'Unit A', rentedMonths: 1, contribution: 2000.0,
      months: [MonthIncome(month: 1, source: 'actual', amount: 2000.0)],
    );
    final unit3 = UnitFinance(
      unitId: 'u1', label: 'Unit A', rentedMonths: 1, contribution: 3000.0,
      months: [MonthIncome(month: 1, source: 'actual', amount: 3000.0)],
    );
    final completer2 = Completer<FinanceSummary>();
    final completer3 = Completer<FinanceSummary>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeYearsProvider.overrideWith((ref) async => [year, year2, year3]),
          financeSummaryProvider.overrideWith((ref, y) {
            if (y == year) return Future.value(_summaryWithUnit(y, unit1));
            if (y == year2) return completer2.future;
            return completer3.future;
          }),
        ],
        child: MaterialApp(
          home: UnitFinanceDetailScreen(
            propertyId: 'p1', propertyName: 'Ayer 8', unit: unit1, year: year,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // First switch: year -> year2.
    await tester.tap(find.text('$year'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('$year2'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    completer2.complete(_summaryWithUnit(year2, unit2));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Unit A — $year2'), findsOneWidget);

    // Second switch: year2 -> year3. This is the one the user reports as broken.
    await tester.tap(find.text('$year2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('$year3'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget,
        reason: 'spinner should reappear for the second switch too');
    completer3.complete(_summaryWithUnit(year3, unit3));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Unit A — $year3'), findsOneWidget);
    expect(find.text('RM 3,000.00'), findsWidgets);
  });

  testWidgets('switching back to an already-cached year updates the display (regression)',
      (tester) async {
    final year = DateTime.now().year;
    final year2 = year + 1;
    final unit1 = UnitFinance(
      unitId: 'u1', label: 'Unit A', rentedMonths: 1, contribution: 1000.0,
      months: [MonthIncome(month: 1, source: 'actual', amount: 1000.0)],
    );
    final unit2 = UnitFinance(
      unitId: 'u1', label: 'Unit A', rentedMonths: 1, contribution: 2000.0,
      months: [MonthIncome(month: 1, source: 'actual', amount: 2000.0)],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeYearsProvider.overrideWith((ref) async => [year, year2]),
          financeSummaryProvider.overrideWith((ref, y) async =>
              y == year ? _summaryWithUnit(y, unit1) : _summaryWithUnit(y, unit2)),
        ],
        child: MaterialApp(
          home: UnitFinanceDetailScreen(
            propertyId: 'p1', propertyName: 'Ayer 8', unit: unit1, year: year,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to year2 — a fresh fetch (still fast here, but goes through
    // the same loading path as a real network call).
    await tester.tap(find.text('$year'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('$year2'));
    await tester.pumpAndSettle();

    expect(find.text('Unit A — $year2'), findsOneWidget);

    // Switch BACK to the original year. By now financeSummaryProvider(year)
    // is already cached from the initial load, so there is no loading ->
    // data transition left for ref.listen to react to — this is exactly
    // the sequence that left the screen frozen on year2 before the fix.
    await tester.tap(find.text('$year2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('$year'));
    await tester.pumpAndSettle();

    expect(find.text('Unit A — $year'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a failed year switch reverts the selection and shows an error',
      (tester) async {
    final year = DateTime.now().year;
    final nextYear = year + 1;
    final unit = UnitFinance(
      unitId: 'u1', label: 'Unit A', rentedMonths: 1, contribution: 3200.0,
      months: [MonthIncome(month: 1, source: 'actual', amount: 3200.0)],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeYearsProvider.overrideWith((ref) async => [year, nextYear]),
          financeSummaryProvider.overrideWith((ref, y) {
            if (y == year) return Future.value(_summaryWithUnit(y, unit));
            return Future<FinanceSummary>.error(Exception('network down'));
          }),
        ],
        child: MaterialApp(
          home: UnitFinanceDetailScreen(
            propertyId: 'p1', propertyName: 'Ayer 8', unit: unit, year: year,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('$year'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('$nextYear'));
    await tester.pumpAndSettle();

    expect(find.text('Unit A — $year'), findsOneWidget); // reverted, not stuck
    expect(find.textContaining("Couldn't load $nextYear"), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
