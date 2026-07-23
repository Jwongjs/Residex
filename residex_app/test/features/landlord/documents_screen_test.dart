import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/domain/entities/documind_document.dart';
import 'package:residex_app/features/landlord/domain/entities/property.dart';
import 'package:residex_app/features/landlord/presentation/providers/documind_provider.dart';
import 'package:residex_app/features/landlord/presentation/providers/property_providers.dart';
import 'package:residex_app/features/landlord/presentation/screens/5-Documents/documents_screen.dart';

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
    expect(find.text('Rental Invoices'), findsOneWidget);
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('Chat'), findsNothing);
    expect(find.text('Docs'), findsNothing);
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
}
