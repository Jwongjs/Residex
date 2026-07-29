import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/domain/entities/property.dart';
import 'package:residex_app/features/landlord/domain/repositories/property_repository.dart';
import 'package:residex_app/features/landlord/presentation/providers/documind_provider.dart';
import 'package:residex_app/features/landlord/presentation/providers/property_providers.dart';
import 'package:residex_app/features/landlord/presentation/widgets/common/registration_document_steps_sheet.dart';

class _FakePropertyRepository implements PropertyRepository {
  Property? lastUpdated;

  @override
  Future<void> updateProperty(Property property) async {
    lastUpdated = property;
  }

  @override
  Future<String> createProperty(Property property) async => 'p1';
  @override
  Future<void> deleteProperty(String propertyId) async {}
  @override
  Future<Property?> getPropertyById(String propertyId) async => null;
  @override
  Future<List<Property>> getPropertiesByLandlord(String landlordId) async => [];
  @override
  Future<List<Property>> searchProperties(String landlordId, String query) async => [];
  @override
  Stream<List<Property>> streamPropertiesByLandlord(String landlordId) => const Stream.empty();
}

Property _property({PropertyStructureType? structureType, bool? hasMortgage}) {
  return Property(
    id: 'p1', landlordId: 'l1', name: 'Ayer 8',
    address: const PropertyAddress(street: 's', city: 'c', state: 'st', zipCode: 'z', country: 'Malaysia'),
    type: PropertyType.condo, purchasePrice: 0, currentValue: 0,
    createdAt: DateTime(2026, 1, 1),
    structureType: structureType, hasMortgage: hasMortgage, nextSetupStep: 2,
  );
}

void main() {
  testWidgets('step 2 shows the two unlock documents and advances to step 3 on skip',
      (tester) async {
    final fakeRepo = _FakePropertyRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          propertyRepositoryProvider.overrideWithValue(fakeRepo),
          uploadDocumentActionProvider.overrideWithValue(({
            required String propertyId,
            required String category,
            required dynamic file,
            String? unitId,
            String? unitLabel,
            void Function(String stage)? onProgress,
          }) async =>
              throw UnimplementedError('not exercised in this test')),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(builder: (context) {
              return TextButton(
                onPressed: () => showRegistrationDocumentSteps(
                  context, property: _property(structureType: PropertyStructureType.strata, hasMortgage: true),
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

    expect(find.text('Step 2 of 3'), findsOneWidget);
    expect(find.text('Tenancy agreement'), findsOneWidget);
    expect(find.text('Latest management statement'), findsOneWidget);

    await tester.tap(find.text("I'll do this later"));
    await tester.pumpAndSettle();

    expect(find.text('Step 3 of 3'), findsOneWidget);
    expect(fakeRepo.lastUpdated?.nextSetupStep, 3);
  });

  testWidgets('step 3 hides insurance for strata and shows loan only when mortgaged',
      (tester) async {
    final fakeRepo = _FakePropertyRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [propertyRepositoryProvider.overrideWithValue(fakeRepo)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(builder: (context) {
              return TextButton(
                onPressed: () => showRegistrationDocumentSteps(
                  context,
                  property: _property(structureType: PropertyStructureType.strata, hasMortgage: true),
                  startAtStep: 3,
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

    expect(find.text('Step 3 of 3'), findsOneWidget);
    expect(find.text('Assessment tax / land-office tax'), findsOneWidget);
    expect(find.text('Fire insurance'), findsNothing);
    expect(find.text('Loan interest statement'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(fakeRepo.lastUpdated?.nextSetupStep, 0);
  });
}
