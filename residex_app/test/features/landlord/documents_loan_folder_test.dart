import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/domain/entities/documind_document.dart';
import 'package:residex_app/features/landlord/domain/entities/property.dart';
import 'package:residex_app/features/landlord/presentation/providers/documind_provider.dart';
import 'package:residex_app/features/landlord/presentation/providers/property_providers.dart';
import 'package:residex_app/features/landlord/presentation/screens/5-Documents/documents_screen.dart';

/// Task 2: the Loans & Financing folder is unconditional. It was once gated
/// by `loanInputMethod`; that fork is gone — upload to the folder or type at
/// the finance panel, both always available regardless of the property's
/// mortgage state.
///
/// Note: this file does not have a "property fails to load" test. Passing a
/// null property would require `propertiesStreamProvider` to emit an empty
/// list, which routes DocumentsScreen to `_buildNoPropertiesState()` (a
/// distinct "No Properties Found" screen with no GridView at all) rather
/// than the category grid — there is no reachable path where the grid
/// renders with a null property, since `build()` only calls `_buildMainUI`
/// once `_selectedPropertyId` is confirmed present in a non-empty
/// `properties` list. `_categoriesFor(Property?)`'s nullable parameter is a
/// defensive signature, not a reachable UI state.
void main() {
  Property propertyWith({bool? hasMortgage}) => Property(
        id: 'prop-1',
        landlordId: 'landlord-1',
        name: 'Maple Residency',
        address: const PropertyAddress(
          street: '123 Main St',
          city: 'Kuala Lumpur',
          state: 'WP Kuala Lumpur',
          zipCode: '50000',
          country: 'Malaysia',
        ),
        type: PropertyType.apartment,
        purchasePrice: 500000,
        currentValue: 550000,
        createdAt: DateTime(2026, 1, 1),
        hasMortgage: hasMortgage,
      );

  Widget buildTestWidget({
    required Property property,
    List<DocuMindDocument> documents = const <DocuMindDocument>[],
  }) {
    return ProviderScope(
      overrides: [
        propertiesStreamProvider.overrideWith((ref) => Stream.value([property])),
        documindDocumentsProvider.overrideWith((ref, propertyId) async => documents),
      ],
      child: MaterialApp(
        home: DocumentsScreen(onOpenDocumind: () {}),
      ),
    );
  }

  testWidgets('the Loans & Financing tile is shown for a mortgaged property',
      (tester) async {
    await tester.pumpWidget(buildTestWidget(property: propertyWith(hasMortgage: true)));
    await tester.pumpAndSettle();

    // Scroll to make sure a tile in the second row wouldn't be missed.
    await tester.drag(find.byType(GridView), const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(find.text('Loans & Financing'), findsOneWidget);
  });

  testWidgets('the Loans & Financing tile is shown for an unmortgaged property',
      (tester) async {
    await tester.pumpWidget(buildTestWidget(property: propertyWith(hasMortgage: false)));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(GridView), const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(find.text('Loans & Financing'), findsOneWidget);
  });

  testWidgets('the Loans & Financing tile is shown when the mortgage question '
      'is unanswered', (tester) async {
    await tester.pumpWidget(buildTestWidget(property: propertyWith(hasMortgage: null)));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(GridView), const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(find.text('Loans & Financing'), findsOneWidget);
  });

  testWidgets('neither folder state offers manual entry', (tester) async {
    // Empty state.
    await tester.pumpWidget(buildTestWidget(property: propertyWith(hasMortgage: true)));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(GridView), const Offset(0, -200));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Loans & Financing'), warnIfMissed: false);
    await tester.pumpAndSettle();

    // Prove the tap actually landed in the folder (the empty-state CTA)
    // before asserting the manual-entry button is absent — otherwise a
    // missed tap would leave us on the grid and this would pass vacuously.
    expect(find.text('Upload Loans & Financing'), findsOneWidget);
    expect(find.text('Enter figures manually'), findsNothing);

    // Populated state. Tear down first — pumping a structurally identical
    // widget tree would otherwise reuse the existing State (same type, no
    // key) and stay stuck on the folder we just navigated into.
    await tester.pumpWidget(const SizedBox.shrink());
    final loanDoc = DocuMindDocument(
      docId: 'loan-1', landlordId: 'landlord-1', propertyId: 'prop-1',
      category: 'loan', filename: 'loan_statement.pdf', chunksIndexed: 1,
      uploadedAt: DateTime(2026, 1, 1),
    );
    await tester.pumpWidget(buildTestWidget(
      property: propertyWith(hasMortgage: true),
      documents: [loanDoc],
    ));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(GridView), const Offset(0, -200));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Loans & Financing'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('loan_statement.pdf'), findsOneWidget);
    expect(find.text('Enter figures manually'), findsNothing);
  });

  testWidgets(
      'switching mortgage state while inside the Loans folder keeps the tile reachable',
      (tester) async {
    // Drive propertiesStreamProvider through a controller we keep open for
    // the whole test, so we can push a live update — the landlord changing
    // the mortgage answer from property settings while this screen is still
    // open on the Loans folder — without re-pumping the widget tree (which
    // would just reuse the existing State rather than exercising a real
    // provider-driven rebuild).
    final controller = StreamController<List<Property>>();
    addTearDown(controller.close);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        propertiesStreamProvider.overrideWith((ref) => controller.stream),
        documindDocumentsProvider.overrideWith(
          (ref, propertyId) async => const <DocuMindDocument>[],
        ),
      ],
      child: MaterialApp(home: DocumentsScreen(onOpenDocumind: () {})),
    ));
    controller.add([propertyWith(hasMortgage: true)]);
    await tester.pumpAndSettle();

    await tester.drag(find.byType(GridView), const Offset(0, -200));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Loans & Financing'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Upload Loans & Financing'), findsOneWidget);

    controller.add([propertyWith(hasMortgage: false)]);
    await tester.pumpAndSettle();

    expect(find.text('Upload Loans & Financing'), findsOneWidget);
  });
}
