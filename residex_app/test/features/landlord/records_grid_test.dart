import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/domain/entities/finance_summary.dart';
import 'package:residex_app/features/landlord/presentation/widgets/common/records_grid.dart';

void main() {
  testWidgets('grid shows present, missing, partial and unavailable cells',
      (tester) async {
    final property = PropertyFinance(
      propertyId: 'p1', name: 'Ayer 8',
      receivedRent: 0, derivedRent: 0, directExpenses: 0, rentalIncomeOrLoss: 0,
      expectedCategories: const ['assessment', 'land_office_tax', 'maintenance', 'loan'],
      coverage: [
        YearCoverage(
          year: 2025,
          missing: const ['loan'],
          partialCategories: [PartialCategory(category: 'maintenance', have: 4, expect: 12)],
          unavailable: const ['land_office_tax'],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: RecordsGridBody(propertyId: 'p1', property: property),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2025'), findsOneWidget);
    expect(find.text('Assessment tax'), findsOneWidget); // present -> label shown as column header
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget); // assessment: present
    expect(find.byIcon(Icons.upload_file_outlined), findsOneWidget); // loan: missing
    expect(find.text('4/12'), findsOneWidget); // maintenance: partial
    expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget); // land_office_tax: unavailable
  });

  testWidgets('empty coverage shows a friendly placeholder, not an empty table',
      (tester) async {
    final property = PropertyFinance(
      propertyId: 'p1', name: 'Ayer 8',
      receivedRent: 0, derivedRent: 0, directExpenses: 0, rentalIncomeOrLoss: 0,
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: RecordsGridBody(propertyId: 'p1', property: property)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Nothing to track yet'), findsOneWidget);
  });
}
