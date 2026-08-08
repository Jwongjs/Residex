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

  testWidgets('neither the cadence nor the loan method question is asked',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(home: AddPropertyDialog(property: _property(hasMortgage: true))),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('How often'), findsNothing);
    expect(find.text('How will loan figures arrive?'), findsNothing);
    expect(find.text('Upload statements'), findsNothing);
    expect(find.text('Enter figures myself'), findsNothing);
  });
}
