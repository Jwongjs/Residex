import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/domain/entities/documind_document.dart';
import 'package:residex_app/features/landlord/domain/entities/property.dart';
import 'package:residex_app/features/landlord/presentation/providers/documind_provider.dart';
import 'package:residex_app/features/landlord/presentation/providers/property_providers.dart';
import 'package:residex_app/features/landlord/presentation/screens/5-Documents/documents_screen.dart';
import 'package:residex_app/features/landlord/presentation/widgets/common/document_categories.dart';

void main() {
  final testProperty = Property(
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
  );

  Widget buildTestWidget({required VoidCallback onOpenDocumind}) {
    return ProviderScope(
      overrides: [
        propertiesStreamProvider.overrideWith((ref) => Stream.value([testProperty])),
        documindDocumentsProvider.overrideWith(
          (ref, propertyId) async => const <DocuMindDocument>[],
        ),
      ],
      child: MaterialApp(
        home: DocumentsScreen(onOpenDocumind: onOpenDocumind),
      ),
    );
  }

  testWidgets('shows the three folders and no chat toggle', (tester) async {
    await tester.pumpWidget(buildTestWidget(onOpenDocumind: () {}));
    await tester.pumpAndSettle();

    expect(find.text('Tenancy Agreements'), findsOneWidget);
    expect(find.text('Rent records'), findsOneWidget);
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('Optional · tap to view'), findsOneWidget);
    expect(find.text('Chat'), findsNothing);
    expect(find.text('Docs'), findsNothing);
  });

  testWidgets('rent records empty state explains the optional, lease-derived framing',
      (tester) async {
    await tester.pumpWidget(buildTestWidget(onOpenDocumind: () {}));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rent records'));
    await tester.pumpAndSettle();

    expect(find.text('No Rent records Yet'), findsOneWidget);
    expect(
      find.textContaining('the lease already covers your rent'),
      findsOneWidget,
    );
  });

  testWidgets('tapping Ask on an empty folder calls onOpenDocumind', (tester) async {
    var tapped = false;
    await tester.pumpWidget(buildTestWidget(onOpenDocumind: () => tapped = true));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tenancy Agreements'));
    await tester.pumpAndSettle();

    expect(find.text('No Tenancy Agreements Yet'), findsOneWidget);

    await tester.tap(find.text('Ask'));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });

  testWidgets('a document with tags shows its tag chips', (tester) async {
    final doc = DocuMindDocument(
      docId: 'd1', landlordId: 'landlord-1', propertyId: 'prop-1',
      category: 'tax', filename: 'quitrent.pdf', chunksIndexed: 1,
      uploadedAt: DateTime(2026, 2, 1),
      tags: const [DocumentTag(tag: 'quit_rent', rhythm: 'one_off')],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        propertiesStreamProvider.overrideWith((ref) => Stream.value([testProperty])),
        documindDocumentsProvider.overrideWith((ref, propertyId) async => [doc]),
      ],
      child: MaterialApp(home: DocumentsScreen(onOpenDocumind: () {})),
    ));
    await tester.pumpAndSettle();

    // Scroll down to find the Expenses card
    await tester.drag(find.byType(GridView), const Offset(0, -200));
    await tester.pumpAndSettle();

    // Find and tap the Expenses category card
    await tester.tap(find.text('Expenses'), warnIfMissed: false);
    await tester.pumpAndSettle();

    // The tag label should be displayed on the document tile
    expect(find.text('Quit rent'), findsOneWidget);
  });
}
