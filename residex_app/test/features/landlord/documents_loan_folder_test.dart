import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/domain/entities/documind_document.dart';
import 'package:residex_app/features/landlord/domain/entities/property.dart';
import 'package:residex_app/features/landlord/presentation/providers/documind_provider.dart';
import 'package:residex_app/features/landlord/presentation/providers/property_providers.dart';
import 'package:residex_app/features/landlord/presentation/screens/5-Documents/documents_screen.dart';

/// Task 2: the Loans & Financing folder is gated by `loanInputMethod`, and
/// manual entry is dropped from both folder states (a later task puts a
/// permanent loan-figures row on the finance tab instead).
void main() {
  Property propertyWith(String? loanInputMethod) => Property(
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
        loanInputMethod: loanInputMethod,
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

  testWidgets('manual hides the Loans & Financing tile', (tester) async {
    await tester.pumpWidget(buildTestWidget(property: propertyWith('manual')));
    await tester.pumpAndSettle();

    // Scroll to make sure a tile in the second row wouldn't be missed.
    await tester.drag(find.byType(GridView), const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(find.text('Loans & Financing'), findsNothing);
  });

  testWidgets('upload keeps the tile', (tester) async {
    await tester.pumpWidget(buildTestWidget(property: propertyWith('upload')));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(GridView), const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(find.text('Loans & Financing'), findsOneWidget);
  });

  testWidgets('null keeps the tile', (tester) async {
    await tester.pumpWidget(buildTestWidget(property: propertyWith(null)));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(GridView), const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(find.text('Loans & Financing'), findsOneWidget);
  });

  testWidgets('neither folder state offers manual entry', (tester) async {
    // Empty state.
    await tester.pumpWidget(buildTestWidget(property: propertyWith('upload')));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(GridView), const Offset(0, -200));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Loans & Financing'), warnIfMissed: false);
    await tester.pumpAndSettle();

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
      property: propertyWith('upload'),
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
}
