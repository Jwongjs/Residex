import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        }) async {
          capturedInterest = interestPaid;
          capturedPrincipal = principalPaid;
        }),
        manualLoanEntriesProvider((propertyId: 'p1', year: 2025))
            .overrideWith((ref) async => <Map<String, dynamic>>[]),
      ],
      child: const MaterialApp(
        home: ManualLoanEntrySheet(
          propertyId: 'p1', year: 2025, cadence: 'annual',
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
}
