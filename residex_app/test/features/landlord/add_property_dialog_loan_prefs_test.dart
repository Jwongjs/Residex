import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:residex_app/features/landlord/domain/entities/property.dart';
import 'package:residex_app/features/landlord/presentation/widgets/common/add_property_dialog.dart';

Property _property({bool? hasMortgage}) => Property(
      id: 'p1',
      landlordId: 'l1',
      name: 'Kiara Court',
      address: const PropertyAddress(
        street: '1 Jalan Kiara', city: 'KL', state: 'WP',
        zipCode: '50480', country: 'Malaysia',
      ),
      type: PropertyType.condo,
      purchasePrice: 500000,
      currentValue: 550000,
      hasMortgage: hasMortgage,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  testWidgets('mortgage question stays', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(home: AddPropertyDialog(property: _property(hasMortgage: true))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Do you have a mortgage on this property?'), findsOneWidget);
  });

  testWidgets('cadence question stays gone; loan method question is back under new wording',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(home: AddPropertyDialog(property: _property(hasMortgage: true))),
    ));
    await tester.pumpAndSettle();
    // The old copy for this question is gone for good...
    expect(find.text('How do you record loan figures?'), findsNothing);
    expect(find.text('Enter manually'), findsNothing);
    // ...but the loan-entry-method workstream (2026-08-05) reinstates the
    // question under new wording — see loan_input_method_dialog_test.dart.
    expect(find.text('How will loan figures arrive?'), findsOneWidget);
    expect(find.text('Upload statements'), findsOneWidget);
    expect(find.text('Enter figures myself'), findsOneWidget);
    // Cadence was not reinstated by that workstream.
    expect(find.text('Annually'), findsNothing);
    expect(find.text('Monthly'), findsNothing);
  });
}
