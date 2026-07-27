import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/domain/entities/finance_summary.dart';
import 'package:residex_app/features/landlord/presentation/widgets/common/finance_summary_panel.dart';

FinanceSummary _summary() {
  return FinanceSummary(
    year: 2025,
    totals: FinanceTotals(
      receivedRent: 84000.0,
      derivedRent: 0.0,
      directExpenses: 59516.87,
      netPl: 24483.13,
      landlordExpenses: 70516.87,
      statutoryRentalIncome: 24483.13,
      statutoryNote: 'Estimate — for your tax agent',
    ),
    properties: [
      PropertyFinance(
        propertyId: 'p1',
        name: 'Ayer 8',
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
            months: [
              MonthIncome(month: 1, source: 'actual', amount: 7000),
              MonthIncome(month: 2, source: 'actual', amount: 7000),
            ],
          ),
        ],
      ),
    ],
  );
}

Future<void> _pumpAtWidth(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: FinanceSummaryPanel(summary: _summary(), onShowCaveats: () {}),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders without layout errors in the WIDE breakpoint (>=560)',
      (tester) async {
    await _pumpAtWidth(tester, 700);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('TOTAL NET P/L'), findsOneWidget);
  });

  testWidgets('renders without layout errors in the NARROW breakpoint (<560)',
      (tester) async {
    await _pumpAtWidth(tester, 375);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('TOTAL NET P/L'), findsOneWidget);
  });

  testWidgets(
      'TOTAL EXPENSES card shows landlordExpenses so Received - Expenses reconciles to Net P/L',
      (tester) async {
    await _pumpAtWidth(tester, 700);
    // Received (84,000.00) - landlordExpenses (70,516.87) == netPl (24,483.13, hero card).
    // directExpenses (59,516.87) must NOT be what the expenses card shows.
    expect(find.text('RM 70,516.87'), findsOneWidget);
    expect(find.text('RM 59,516.87'), findsNothing);
  });
}
