import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:residex_app/features/landlord/domain/entities/finance_summary.dart';
import 'package:residex_app/features/landlord/presentation/providers/documind_provider.dart';
import 'package:residex_app/features/landlord/presentation/widgets/common/manual_loan_entry_sheet.dart';

void main() {
  testWidgets('save calls the record action with entered amounts', (tester) async {
    double? capturedInterest;
    double? capturedPrincipal;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        recordManualLoanEntryActionProvider.overrideWithValue(({
          required String propertyId,
          required int year,
          required String cadence,
          required double interestPaid,
          required double principalPaid,
          int? month,
          String? unitId,
        }) async {
          capturedInterest = interestPaid;
          capturedPrincipal = principalPaid;
        }),
        manualLoanEntriesProvider((propertyId: 'p1', year: 2025))
            .overrideWith((ref) async => <Map<String, dynamic>>[]),
      ],
      child: const MaterialApp(
        home: ManualLoanEntrySheet(
          propertyId: 'p1', year: 2025, cadence: 'annual', units: [],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('manual-loan-interest')), '5000');
    await tester.enterText(find.byKey(const Key('manual-loan-principal')), '3000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(capturedInterest, 5000);
    expect(capturedPrincipal, 3000);
  });

  testWidgets('selecting a unit forwards its unitId when saving', (tester) async {
    String? capturedUnitId;
    var capturedUnitIdSet = false;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        recordManualLoanEntryActionProvider.overrideWithValue(({
          required String propertyId,
          required int year,
          required String cadence,
          required double interestPaid,
          required double principalPaid,
          int? month,
          String? unitId,
        }) async {
          capturedUnitId = unitId;
          capturedUnitIdSet = true;
        }),
        manualLoanEntriesProvider((propertyId: 'p1', year: 2025))
            .overrideWith((ref) async => <Map<String, dynamic>>[]),
      ],
      child: MaterialApp(
        home: ManualLoanEntrySheet(
          propertyId: 'p1',
          year: 2025,
          cadence: 'annual',
          units: [
            UnitFinance(
              unitId: 'u1', label: 'A-1', rentedMonths: 0, contribution: 0,
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButton<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A-1').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('manual-loan-interest')), '100');
    await tester.enterText(find.byKey(const Key('manual-loan-principal')), '50');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(capturedUnitIdSet, isTrue);
    expect(capturedUnitId, 'u1');
  });

  testWidgets('tapping "No loan here" calls the exemption action with the selected unitId',
      (tester) async {
    String? capturedPropertyId;
    String? capturedUnitId;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        setUnitLoanExemptionActionProvider.overrideWithValue(
            ({required String propertyId, required String unitId}) async {
          capturedPropertyId = propertyId;
          capturedUnitId = unitId;
        }),
        manualLoanEntriesProvider((propertyId: 'p1', year: 2025))
            .overrideWith((ref) async => <Map<String, dynamic>>[]),
      ],
      child: MaterialApp(
        home: ManualLoanEntrySheet(
          propertyId: 'p1',
          year: 2025,
          cadence: 'annual',
          units: [
            UnitFinance(
              unitId: 'u1', label: 'A-1', rentedMonths: 0, contribution: 0,
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButton<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A-1').last);
    await tester.pumpAndSettle();

    expect(find.text('No loan here'), findsOneWidget);
    await tester.tap(find.text('No loan here'));
    await tester.pumpAndSettle();

    expect(capturedPropertyId, 'p1');
    expect(capturedUnitId, 'u1');
  });
}
