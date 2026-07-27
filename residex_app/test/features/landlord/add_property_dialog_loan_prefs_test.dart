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
  testWidgets('loan-input selectors appear when mortgage = Yes', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(home: AddPropertyDialog(property: _property(hasMortgage: true))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('How do you record loan figures?'), findsOneWidget);
    expect(find.text('Upload statements'), findsOneWidget);
    expect(find.text('Enter manually'), findsOneWidget);
  });

  testWidgets('loan-input selectors hidden when mortgage != Yes', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(home: AddPropertyDialog(property: _property(hasMortgage: false))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('How do you record loan figures?'), findsNothing);
  });
}
