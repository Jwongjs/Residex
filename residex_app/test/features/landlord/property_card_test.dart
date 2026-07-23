import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/domain/entities/property.dart';
import 'package:residex_app/features/landlord/presentation/providers/unit_providers.dart';
import 'package:residex_app/features/landlord/presentation/widgets/common/property_card.dart';

Property _property({int nextSetupStep = 0}) {
  return Property(
    id: 'p1', landlordId: 'l1', name: 'Ayer 8',
    address: const PropertyAddress(street: 's', city: 'Kuala Lumpur', state: 'WP', zipCode: 'z', country: 'Malaysia'),
    type: PropertyType.condo, purchasePrice: 0, currentValue: 0,
    createdAt: DateTime(2026, 1, 1), nextSetupStep: nextSetupStep,
  );
}

void main() {
  testWidgets('shows Continue setup when nextSetupStep is non-zero, opening the resume sheet',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          unitsForPropertyStreamProvider.overrideWith((ref, id) => Stream.value(const [])),
        ],
        child: MaterialApp(home: Scaffold(body: PropertyCard(property: _property(nextSetupStep: 3)))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Continue setup'), findsOneWidget);

    await tester.tap(find.text('Continue setup'));
    await tester.pumpAndSettle();
    expect(find.text('Step 3 of 3'), findsOneWidget);
  });

  testWidgets('hides Continue setup when nextSetupStep is zero', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          unitsForPropertyStreamProvider.overrideWith((ref, id) => Stream.value(const [])),
        ],
        child: MaterialApp(home: Scaffold(body: PropertyCard(property: _property()))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Continue setup'), findsNothing);
  });
}
