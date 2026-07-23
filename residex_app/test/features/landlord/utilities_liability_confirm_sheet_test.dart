import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/domain/entities/property.dart';
import 'package:residex_app/features/landlord/domain/repositories/property_repository.dart';
import 'package:residex_app/features/landlord/presentation/providers/property_providers.dart';
import 'package:residex_app/features/landlord/presentation/widgets/common/utilities_liability_confirm_sheet.dart';

class _FakePropertyRepository implements PropertyRepository {
  final Property property;
  Property? lastUpdated;
  _FakePropertyRepository(this.property);

  @override
  Future<void> updateProperty(Property property) async {
    lastUpdated = property;
  }

  @override
  Future<String> createProperty(Property property) async => property.id;
  @override
  Future<void> deleteProperty(String propertyId) async {}
  @override
  Future<Property?> getPropertyById(String propertyId) async => property;
  @override
  Future<List<Property>> getPropertiesByLandlord(String landlordId) async => [property];
  @override
  Future<List<Property>> searchProperties(String landlordId, String query) async => [];
  @override
  Stream<List<Property>> streamPropertiesByLandlord(String landlordId) => const Stream.empty();
}

Property _property() {
  return Property(
    id: 'p1', landlordId: 'l1', name: 'Ayer 8',
    address: const PropertyAddress(street: 's', city: 'c', state: 'st', zipCode: 'z', country: 'Malaysia'),
    type: PropertyType.condo, purchasePrice: 0, currentValue: 0,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  testWidgets('tapping Correct confirms the extracted liability as-is', (tester) async {
    final fakeRepo = _FakePropertyRepository(_property());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [propertyRepositoryProvider.overrideWithValue(fakeRepo)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(builder: (context) {
              return TextButton(
                onPressed: () => showUtilitiesLiabilityConfirmSheet(
                  context,
                  property: _property(),
                  liability: 'tenant',
                  clauseRef: 'Clause 5.2',
                  quote: 'To pay all charges due and incurred in respect of '
                      'electricity, water and all other utilities.',
                ),
                child: const Text('open'),
              );
            }),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('the tenant pays'), findsOneWidget);
    expect(find.text('Clause 5.2'), findsOneWidget);
    expect(find.textContaining('To pay all charges'), findsOneWidget);

    await tester.tap(find.text('Correct'));
    await tester.pumpAndSettle();

    expect(fakeRepo.lastUpdated?.utilitiesPaidBy, 'tenant');
  });

  testWidgets("tapping 'That's not right' confirms the flipped liability", (tester) async {
    final fakeRepo = _FakePropertyRepository(_property());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [propertyRepositoryProvider.overrideWithValue(fakeRepo)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(builder: (context) {
              return TextButton(
                onPressed: () => showUtilitiesLiabilityConfirmSheet(
                  context,
                  property: _property(),
                  liability: 'tenant',
                  quote: 'Utilities clause text.',
                ),
                child: const Text('open'),
              );
            }),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text("That's not right"));
    await tester.pumpAndSettle();

    expect(fakeRepo.lastUpdated?.utilitiesPaidBy, 'landlord');
  });

  testWidgets("dismissing with 'I'll confirm later' writes nothing", (tester) async {
    final fakeRepo = _FakePropertyRepository(_property());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [propertyRepositoryProvider.overrideWithValue(fakeRepo)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(builder: (context) {
              return TextButton(
                onPressed: () => showUtilitiesLiabilityConfirmSheet(
                  context,
                  property: _property(),
                  liability: 'tenant',
                  quote: 'Utilities clause text.',
                ),
                child: const Text('open'),
              );
            }),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text("I'll confirm later"));
    await tester.pumpAndSettle();

    expect(fakeRepo.lastUpdated, isNull);
  });

  testWidgets('maybeShowUtilitiesLiabilityConfirm opens the sheet when facts carry liability + quote',
      (tester) async {
    final fakeRepo = _FakePropertyRepository(_property());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [propertyRepositoryProvider.overrideWithValue(fakeRepo)],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(builder: (context, ref, _) {
              return TextButton(
                onPressed: () => maybeShowUtilitiesLiabilityConfirm(
                  context, ref,
                  propertyId: 'p1',
                  category: 'lease',
                  extractedFacts: const {
                    'utilities_liability': 'tenant',
                    'utilities_clause_ref': 'Clause 5.2',
                    'utilities_clause_quote': 'To pay all charges...',
                  },
                ),
                child: const Text('trigger'),
              );
            }),
          ),
        ),
      ),
    );
    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    expect(find.text('Correct'), findsOneWidget);
    expect(find.text('Clause 5.2'), findsOneWidget);
  });

  testWidgets('maybeShowUtilitiesLiabilityConfirm is a no-op without a quote', (tester) async {
    final fakeRepo = _FakePropertyRepository(_property());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [propertyRepositoryProvider.overrideWithValue(fakeRepo)],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(builder: (context, ref, _) {
              return TextButton(
                onPressed: () => maybeShowUtilitiesLiabilityConfirm(
                  context, ref,
                  propertyId: 'p1',
                  category: 'lease',
                  extractedFacts: const {'utilities_liability': 'tenant'},
                ),
                child: const Text('trigger'),
              );
            }),
          ),
        ),
      ),
    );
    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    expect(find.text('Correct'), findsNothing);
  });

  testWidgets('maybeShowUtilitiesLiabilityConfirm is a no-op for a non-lease category', (tester) async {
    final fakeRepo = _FakePropertyRepository(_property());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [propertyRepositoryProvider.overrideWithValue(fakeRepo)],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(builder: (context, ref, _) {
              return TextButton(
                onPressed: () => maybeShowUtilitiesLiabilityConfirm(
                  context, ref,
                  propertyId: 'p1',
                  category: 'expenses',
                  extractedFacts: const {
                    'utilities_liability': 'tenant',
                    'utilities_clause_quote': 'quote',
                  },
                ),
                child: const Text('trigger'),
              );
            }),
          ),
        ),
      ),
    );
    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    expect(find.text('Correct'), findsNothing);
  });
}
