import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/presentation/widgets/common/expense_lines_review_sheet.dart';

Future<void> _pumpSheet(WidgetTester tester, List<Map<String, dynamic>> lines) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: ExpenseLinesReviewSheet(docId: 'doc-1', initialLines: lines),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opening the edit dialog on a late_penalty line does not crash the dropdown',
      (tester) async {
    await _pumpSheet(tester, [
      {'subtype': 'late_penalty', 'amount': 50.0, 'period_year': 2025},
    ]);

    // Tapping the row opens the edit dialog, whose type dropdown must contain
    // an item for every stored subtype — including late_penalty.
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Edit expense line'), findsOneWidget);
  });

  testWidgets('every backend expense subtype has a dropdown label', (tester) async {
    // Guards against any stored subtype crashing the edit dialog.
    const backendSubtypes = {
      'loan_interest', 'assessment_tax', 'quit_rent', 'parcel_rent',
      'maintenance', 'sinking_fund', 'insurance_premium', 'upkeep',
      'management_fee', 'rent_collection', 'security_fee', 'pest_control',
      'agent_commission', 'legal_fee', 'stamp_duty', 'advertising', 'sst',
      'utilities', 'late_penalty', 'renovation', 'loan_principal',
    };
    for (final subtype in backendSubtypes) {
      expect(expenseSubtypeLabels.containsKey(subtype), isTrue,
          reason: 'missing dropdown label for "$subtype"');
    }
  });
}
