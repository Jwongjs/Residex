import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/domain/entities/documind_document.dart';
import 'package:residex_app/features/landlord/domain/entities/finance_summary.dart';
import 'package:residex_app/features/landlord/data/models/property_model.dart';
import 'package:residex_app/features/landlord/domain/entities/property.dart';
import 'package:residex_app/features/landlord/domain/repositories/property_repository.dart';
import 'package:residex_app/features/landlord/presentation/providers/documind_provider.dart';
import 'package:residex_app/features/landlord/presentation/providers/finance_providers.dart';
import 'package:residex_app/features/landlord/presentation/providers/property_providers.dart';
import 'package:residex_app/features/landlord/presentation/screens/5-Documents/documents_screen.dart';
import 'package:residex_app/features/landlord/presentation/widgets/common/document_categories.dart';
import 'package:residex_app/features/landlord/presentation/widgets/common/manual_loan_entry_sheet.dart';

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

  testWidgets('shows the four folders and no chat toggle', (tester) async {
    await tester.pumpWidget(buildTestWidget(onOpenDocumind: () {}));
    await tester.pumpAndSettle();

    expect(find.text('Tenancy Agreements'), findsOneWidget);
    expect(find.text('Rent records'), findsOneWidget);
    expect(find.text('Loans & Financing'), findsOneWidget);
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

  testWidgets(
      'a properties list backed by real PropertyModel instances does not crash opening a folder',
      (tester) async {
    // Reproduces production data flow: PropertyRemoteDataSource streams
    // List<PropertyModel> (data/datasources/property_remote_datasource.dart),
    // covariantly exposed as Stream<List<Property>> by the repository. The
    // list literal itself stays reified as List<PropertyModel> — unlike
    // buildTestWidget's [testProperty], a bare Property(...) literal that is
    // structurally incapable of reproducing this bug.
    final modelProperty = PropertyModel(
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
    final List<Property> properties = <PropertyModel>[modelProperty];

    await tester.pumpWidget(ProviderScope(
      overrides: [
        propertiesStreamProvider.overrideWith((ref) => Stream.value(properties)),
        documindDocumentsProvider.overrideWith(
          (ref, propertyId) async => const <DocuMindDocument>[],
        ),
      ],
      child: MaterialApp(home: DocumentsScreen(onOpenDocumind: () {})),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rent records'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('No Rent records Yet'), findsOneWidget);
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

  testWidgets('the folder toggle is visible only on the Expenses folder and persists', (tester) async {
    final fakeRepo = _FakePropertyRepository(testProperty);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        propertiesStreamProvider.overrideWith((ref) => Stream.value([testProperty])),
        documindDocumentsProvider.overrideWith((ref, propertyId) async => const <DocuMindDocument>[]),
        propertyRepositoryProvider.overrideWithValue(fakeRepo),
      ],
      child: MaterialApp(home: DocumentsScreen(onOpenDocumind: () {})),
    ));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Organise into folders'), findsNothing);

    // Scroll down to find the Expenses card (same as the tag-chip test above).
    await tester.drag(find.byType(GridView), const Offset(0, -200));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Expenses'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Organise into folders'), findsOneWidget);
    await tester.tap(find.byTooltip('Organise into folders'));
    await tester.pumpAndSettle();

    expect(fakeRepo.lastUpdated?.id, 'prop-1');
    expect(fakeRepo.lastUpdated?.foldersEnabled, true);
  });

  testWidgets('folders-enabled Expenses folder shows folder tiles, not a flat list', (tester) async {
    final feb = DocuMindDocument(
      docId: 'feb', landlordId: 'landlord-1', propertyId: 'prop-1',
      category: 'expenses', filename: 'feb.pdf', chunksIndexed: 1,
      uploadedAt: DateTime(2026, 2, 1),
      tags: const [DocumentTag(tag: 'maintenance', rhythm: 'periodic')],
    );
    final fire = DocuMindDocument(
      docId: 'fire', landlordId: 'landlord-1', propertyId: 'prop-1',
      category: 'insurance', filename: 'fire.pdf', chunksIndexed: 1,
      uploadedAt: DateTime(2026, 3, 1),
      tags: const [DocumentTag(tag: 'insurance_premium', rhythm: 'one_off')],
    );
    final enabledProperty = testProperty.copyWith(foldersEnabled: true);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        propertiesStreamProvider.overrideWith((ref) => Stream.value([enabledProperty])),
        documindDocumentsProvider.overrideWith((ref, propertyId) async => [feb, fire]),
      ],
      child: MaterialApp(home: DocumentsScreen(onOpenDocumind: () {})),
    ));
    await tester.pumpAndSettle();

    // Scroll down to find the Expenses card (same as the tag-chip test above).
    await tester.drag(find.byType(GridView), const Offset(0, -200));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Expenses'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Maintenance fees'), findsOneWidget);
    expect(find.text('Insurance premium'), findsOneWidget);
    expect(find.text('feb.pdf'), findsNothing);

    await tester.tap(find.text('Maintenance fees'));
    await tester.pumpAndSettle();

    expect(find.text('feb.pdf'), findsOneWidget);
  });

  testWidgets('folders-disabled Expenses folder keeps the existing flat list', (tester) async {
    final feb = DocuMindDocument(
      docId: 'feb', landlordId: 'landlord-1', propertyId: 'prop-1',
      category: 'expenses', filename: 'feb.pdf', chunksIndexed: 1,
      uploadedAt: DateTime(2026, 2, 1),
      tags: const [DocumentTag(tag: 'maintenance', rhythm: 'periodic')],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        propertiesStreamProvider.overrideWith((ref) => Stream.value([testProperty])),
        documindDocumentsProvider.overrideWith((ref, propertyId) async => [feb]),
      ],
      child: MaterialApp(home: DocumentsScreen(onOpenDocumind: () {})),
    ));
    await tester.pumpAndSettle();

    // Scroll down to find the Expenses card (same as the tag-chip test above).
    await tester.drag(find.byType(GridView), const Offset(0, -200));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Expenses'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('feb.pdf'), findsOneWidget);
    expect(find.text('Maintenance fees'), findsOneWidget); // the tag chip, not a folder tile
  });

  testWidgets('renaming a folder persists the override and shows it immediately', (tester) async {
    final feb = DocuMindDocument(
      docId: 'feb', landlordId: 'landlord-1', propertyId: 'prop-1',
      category: 'expenses', filename: 'feb.pdf', chunksIndexed: 1,
      uploadedAt: DateTime(2026, 2, 1),
      tags: const [DocumentTag(tag: 'maintenance', rhythm: 'periodic')],
    );
    final enabledProperty = testProperty.copyWith(
      foldersEnabled: true,
      folderNames: const {'insurance_premium': 'Fire policy'},
    );
    final fakeRepo = _FakePropertyRepository(enabledProperty);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        propertiesStreamProvider.overrideWith((ref) => Stream.value([enabledProperty])),
        documindDocumentsProvider.overrideWith((ref, propertyId) async => [feb]),
        propertyRepositoryProvider.overrideWithValue(fakeRepo),
      ],
      child: MaterialApp(home: DocumentsScreen(onOpenDocumind: () {})),
    ));
    await tester.pumpAndSettle();

    // Scroll down to find the Expenses card.
    await tester.drag(find.byType(GridView), const Offset(0, -200));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Expenses'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maintenance fees'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Strata bills');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Verify both the new rename landed and the pre-existing entry survived (merge, not clobber).
    expect(fakeRepo.lastUpdated?.folderNames['maintenance'], 'Strata bills');
    expect(fakeRepo.lastUpdated?.folderNames['insurance_premium'], 'Fire policy');
  });

  testWidgets('renaming a document calls the rename action with the new name', (tester) async {
    final doc = DocuMindDocument(
      docId: 'doc-9', landlordId: 'landlord-1', propertyId: 'prop-1',
      category: 'lease',
      filename: '2023 Final Agreement Ayer 8 and a very long trailing name.pdf',
      chunksIndexed: 1, uploadedAt: DateTime(2026, 1, 1),
    );
    String? capturedProperty;
    String? capturedDoc;
    String? capturedName;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        propertiesStreamProvider.overrideWith((ref) => Stream.value([testProperty])),
        documindDocumentsProvider.overrideWith((ref, propertyId) async => [doc]),
        renameDocumentActionProvider.overrideWithValue(({
          required String propertyId,
          required String docId,
          required String filename,
        }) async {
          capturedProperty = propertyId;
          capturedDoc = docId;
          capturedName = filename;
          return filename;
        }),
      ],
      child: MaterialApp(home: DocumentsScreen(onOpenDocumind: () {})),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tenancy Agreements'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.drive_file_rename_outline));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Ayer 8 lease 2023.pdf');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(capturedName, 'Ayer 8 lease 2023.pdf');
    expect(capturedDoc, 'doc-9');
    expect(capturedProperty, 'prop-1');
  });

  testWidgets(
      'Loans & Financing folder offers a persistent manual entry path',
      (tester) async {
    final year = DateTime.now().year;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        propertiesStreamProvider.overrideWith((ref) => Stream.value([testProperty])),
        documindDocumentsProvider.overrideWith(
          (ref, propertyId) async => const <DocuMindDocument>[],
        ),
        propertyByIdProvider.overrideWith((ref, id) async => testProperty),
        financeSummaryProvider.overrideWith((ref, y) async => FinanceSummary(
              year: y,
              totals: FinanceTotals(
                receivedRent: 0, derivedRent: 0, directExpenses: 0,
                netPl: 0, statutoryRentalIncome: 0, statutoryNote: '',
              ),
              properties: [
                PropertyFinance(
                  propertyId: 'prop-1', name: 'Maple Residency',
                  receivedRent: 0, derivedRent: 0, directExpenses: 0,
                  rentalIncomeOrLoss: 0,
                ),
              ],
            )),
        manualLoanEntriesProvider((propertyId: 'prop-1', year: year))
            .overrideWith((ref) async => <Map<String, dynamic>>[]),
      ],
      child: MaterialApp(home: DocumentsScreen(onOpenDocumind: () {})),
    ));
    await tester.pumpAndSettle();

    // Scroll down to find the Loans & Financing card (same as the
    // Expenses-folder tests above — both are second-row grid tiles).
    await tester.drag(find.byType(GridView), const Offset(0, -200));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Loans & Financing'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Enter figures manually'), findsOneWidget);

    await tester.tap(find.text('Enter figures manually'));
    await tester.pumpAndSettle();

    expect(find.byType(ManualLoanEntrySheet), findsOneWidget);
  });

  testWidgets(
      'a populated Loans & Financing folder still offers the manual entry path',
      (tester) async {
    // The empty-state affordance disappears once a loan document exists —
    // e.g. after the landlord has uploaded one statement, or after a first
    // round of manual entry that later needs correcting. The populated view
    // (peer of "Add More Loans & Financing") must keep offering the path
    // back in, or there is no way to revisit figures once the folder is
    // no longer empty.
    final year = DateTime.now().year;
    final loanDoc = DocuMindDocument(
      docId: 'loan-1', landlordId: 'landlord-1', propertyId: 'prop-1',
      category: 'loan', filename: 'loan_statement.pdf', chunksIndexed: 1,
      uploadedAt: DateTime(2026, 1, 1),
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        propertiesStreamProvider.overrideWith((ref) => Stream.value([testProperty])),
        documindDocumentsProvider.overrideWith(
          (ref, propertyId) async => [loanDoc],
        ),
        propertyByIdProvider.overrideWith((ref, id) async => testProperty),
        financeSummaryProvider.overrideWith((ref, y) async => FinanceSummary(
              year: y,
              totals: FinanceTotals(
                receivedRent: 0, derivedRent: 0, directExpenses: 0,
                netPl: 0, statutoryRentalIncome: 0, statutoryNote: '',
              ),
              properties: [
                PropertyFinance(
                  propertyId: 'prop-1', name: 'Maple Residency',
                  receivedRent: 0, derivedRent: 0, directExpenses: 0,
                  rentalIncomeOrLoss: 0,
                ),
              ],
            )),
        manualLoanEntriesProvider((propertyId: 'prop-1', year: year))
            .overrideWith((ref) async => <Map<String, dynamic>>[]),
      ],
      child: MaterialApp(home: DocumentsScreen(onOpenDocumind: () {})),
    ));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(GridView), const Offset(0, -200));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Loans & Financing'), warnIfMissed: false);
    await tester.pumpAndSettle();

    // Populated view: the uploaded document is listed, not the empty state.
    expect(find.text('loan_statement.pdf'), findsOneWidget);
    expect(find.text('Add More Loans & Financing'), findsOneWidget);
    expect(find.text('Enter figures manually'), findsOneWidget);

    await tester.tap(find.text('Enter figures manually'));
    await tester.pumpAndSettle();

    expect(find.byType(ManualLoanEntrySheet), findsOneWidget);
  });

  testWidgets('moving a document persists a sticky folderMoves override', (tester) async {
    final feb = DocuMindDocument(
      docId: 'feb', landlordId: 'landlord-1', propertyId: 'prop-1',
      category: 'expenses', filename: 'feb.pdf', chunksIndexed: 1,
      uploadedAt: DateTime(2026, 2, 1),
      tags: const [DocumentTag(tag: 'maintenance', rhythm: 'periodic')],
    );
    final fire = DocuMindDocument(
      docId: 'fire', landlordId: 'landlord-1', propertyId: 'prop-1',
      category: 'insurance', filename: 'fire.pdf', chunksIndexed: 1,
      uploadedAt: DateTime(2026, 3, 1),
      tags: const [DocumentTag(tag: 'insurance_premium', rhythm: 'one_off')],
    );
    final enabledProperty = testProperty.copyWith(
      foldersEnabled: true,
      folderMoves: const {'unrelated-doc': 'insurance_premium'},
    );
    final fakeRepo = _FakePropertyRepository(enabledProperty);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        propertiesStreamProvider.overrideWith((ref) => Stream.value([enabledProperty])),
        documindDocumentsProvider.overrideWith((ref, propertyId) async => [feb, fire]),
        propertyRepositoryProvider.overrideWithValue(fakeRepo),
      ],
      child: MaterialApp(home: DocumentsScreen(onOpenDocumind: () {})),
    ));
    await tester.pumpAndSettle();

    // Scroll down to find the Expenses card (same as the other folder tests above).
    await tester.drag(find.byType(GridView), const Offset(0, -200));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Expenses'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maintenance fees'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Move to folder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Insurance premium').last);
    await tester.pumpAndSettle();

    expect(fakeRepo.lastUpdated?.folderMoves['feb'], 'insurance_premium');
    expect(fakeRepo.lastUpdated?.folderMoves['unrelated-doc'], 'insurance_premium');
  });
}
