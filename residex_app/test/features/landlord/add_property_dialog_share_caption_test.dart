import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:residex_app/features/landlord/domain/entities/property.dart';
import 'package:residex_app/features/landlord/presentation/widgets/common/add_property_dialog.dart';

Property _property({PropertyStructureType? structureType}) => Property(
      id: 'p1',
      landlordId: 'l1',
      name: 'Kiara Court',
      address: const PropertyAddress(
        street: '1 Jalan Kiara', city: 'KL', state: 'WP',
        zipCode: '50480', country: 'Malaysia',
      ),
      type: PropertyType.condo,
      structureType: structureType,
      purchasePrice: 500000,
      currentValue: 550000,
      createdAt: DateTime(2026, 1, 1),
    );

const landedCaption = 'Rooms may be tracked as individual units, but this '
    'share applies to all of them.';
const strataCaption = "New units start at this share. Set a different "
    'share for an individual unit from Units if it differs.';

void main() {
  testWidgets('a landed property explains why there is only one share field',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
          home: AddPropertyDialog(
              property: _property(structureType: PropertyStructureType.landed))),
    ));
    await tester.pumpAndSettle();

    expect(find.text(landedCaption), findsOneWidget);
    expect(find.text(strataCaption), findsNothing);
  });

  testWidgets('a strata property frames its share as the default for new units',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
          home: AddPropertyDialog(
              property: _property(structureType: PropertyStructureType.strata))),
    ));
    await tester.pumpAndSettle();

    expect(find.text(strataCaption), findsOneWidget);
    expect(find.text(landedCaption), findsNothing);
  });

  testWidgets('an unknown structure type shows neither caption', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(home: AddPropertyDialog(property: _property())),
    ));
    await tester.pumpAndSettle();

    expect(find.text(landedCaption), findsNothing);
    expect(find.text(strataCaption), findsNothing);
  });

  testWidgets('a new property defaults to apartment, so the strata caption shows',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: AddPropertyDialog()),
    ));
    await tester.pumpAndSettle();

    expect(find.text(strataCaption), findsOneWidget);
  });
}
