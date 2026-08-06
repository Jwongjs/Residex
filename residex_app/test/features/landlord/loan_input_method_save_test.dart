// Fix round 1 (loan-entry-method workstream, task 1): the widget-visibility
// tests in loan_input_method_dialog_test.dart never asserted what actually
// gets written on save, which is how the edit branch's copyWith-swallows-null
// bug (see add_property_dialog.dart's edit-mode Property construction) went
// unnoticed. These tests drive the dialog through a real save against a
// captured fake repository and assert on the written Property.
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:residex_app/features/landlord/domain/entities/property.dart';
import 'package:residex_app/features/landlord/domain/entities/unit.dart';
import 'package:residex_app/features/landlord/domain/repositories/property_repository.dart';
import 'package:residex_app/features/landlord/domain/repositories/unit_repository.dart';
import 'package:residex_app/features/landlord/presentation/providers/property_providers.dart';
import 'package:residex_app/features/landlord/presentation/providers/unit_providers.dart';
import 'package:residex_app/features/landlord/presentation/widgets/common/add_property_dialog.dart';
import 'package:residex_app/features/shared/presentation/providers/auth_providers.dart';

// `implements` only requires the public interface, not User's private
// constructor, so this works even though User can't be `extends`ed.
class _FakeUser extends Mock implements firebase_auth.User {
  @override
  String get uid => 'landlord-1';
}

class _FakePropertyRepository implements PropertyRepository {
  final Property property;
  Property? lastUpdated;
  Property? lastCreated;

  _FakePropertyRepository(this.property);

  @override
  Future<void> updateProperty(Property property) async {
    lastUpdated = property;
  }

  @override
  Future<String> createProperty(Property property) async {
    lastCreated = property;
    return 'p1';
  }

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

/// Every method beyond `createUnit` is unreachable here — the create-mode
/// coverage tests below only exercise the dialog's unit-creation loop, never
/// read units back — but the interface requires them.
class _FakeUnitRepository implements UnitRepository {
  @override
  Future<String> createUnit(Unit unit) async => 'u1';
  @override
  Future<void> deleteAllUnitsForProperty(String propertyId) async {}
  @override
  Future<void> deleteUnit(String propertyId, String unitId) async {}
  @override
  Future<List<Unit>> getUnitsForProperty(String propertyId) async => [];
  @override
  Future<void> updateUnit(Unit unit) async {}
  @override
  Stream<List<Unit>> streamUnitsForProperty(String propertyId) => const Stream.empty();
}

Property _property({required bool? hasMortgage, required String? loanInputMethod}) => Property(
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
      loanInputMethod: loanInputMethod,
      createdAt: DateTime(2026, 1, 1),
    );

/// Opens the edit dialog the way the app does — via showDialog, so
/// Navigator.pop(true) in _handleSubmit has a route to pop instead of
/// emptying the root Navigator's history.
Future<_FakePropertyRepository> _openEditDialog(
  WidgetTester tester, {
  required bool? hasMortgage,
  required String? loanInputMethod,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final property = _property(hasMortgage: hasMortgage, loanInputMethod: loanInputMethod);
  final fakeRepo = _FakePropertyRepository(property);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        propertyRepositoryProvider.overrideWithValue(fakeRepo),
        currentFirebaseUserProvider.overrideWithValue(_FakeUser()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return TextButton(
              onPressed: () => showDialog(
                context: context,
                builder: (context) => AddPropertyDialog(property: property),
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
  return fakeRepo;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

/// Opens the create dialog (no `property:` argument) the way the app does —
/// via showDialog — and fills every required field so `_handleSubmit`'s
/// validators pass. Mirrors [_openEditDialog]'s save-path-through-a-real-
/// repository approach, but for the create branch (add_property_dialog.dart
/// line ~190), which has no equivalent save-path coverage at all.
Future<_FakePropertyRepository> _openCreateDialog(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final fakeRepo = _FakePropertyRepository(
    _property(hasMortgage: null, loanInputMethod: null),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        propertyRepositoryProvider.overrideWithValue(fakeRepo),
        unitRepositoryProvider.overrideWithValue(_FakeUnitRepository()),
        currentFirebaseUserProvider.overrideWithValue(_FakeUser()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return TextButton(
              onPressed: () => showDialog(
                context: context,
                builder: (context) => const AddPropertyDialog(),
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

  // Fills the required fields in build() order: name, street, city, state,
  // zip, purchase price, current value, (ownership share already defaults
  // to '100'), total units.
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'Test Property');
  await tester.enterText(fields.at(1), '1 Jalan Kiara');
  await tester.enterText(fields.at(2), 'KL');
  await tester.enterText(fields.at(3), 'WP');
  await tester.enterText(fields.at(4), '50480');
  await tester.enterText(fields.at(5), '500000');
  await tester.enterText(fields.at(6), '550000');
  await tester.enterText(fields.at(8), '1');

  return fakeRepo;
}

/// Taps Add Property and pumps in bounded steps rather than pumpAndSettle:
/// _isLoading's CircularProgressIndicator spins forever while _handleSubmit
/// awaits showRegistrationDocumentSteps' sheet, which nothing here dismisses
/// until after the assertion — settling would time out. Bounded pumps flush
/// the fakes' async create/unit-creation chain (no real I/O, so a handful of
/// frames is ample) without waiting on that unbounded animation.
Future<void> _submitCreateDialog(WidgetTester tester) async {
  await _tap(tester, find.text('Add Property'));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Dismisses the post-create "registration steps" sheet opened by
/// [_submitCreateDialog], so _handleSubmit's pending future completes and
/// the spinner's ticker is disposed before the test ends.
Future<void> _dismissRegistrationSteps(WidgetTester tester) async {
  await tester.tap(find.text("I'll do this later"));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.tap(find.text('Done'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'answering No on an existing manual-entry property clears loanInputMethod on save',
      (tester) async {
    // Repro from the review: hasMortgage true + loanInputMethod 'manual',
    // landlord flips the mortgage answer to No.
    final fakeRepo = await _openEditDialog(tester, hasMortgage: true, loanInputMethod: 'manual');

    await _tap(tester, find.text('No'));
    await tester.pumpAndSettle();

    await _tap(tester, find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(fakeRepo.lastUpdated, isNotNull);
    expect(fakeRepo.lastUpdated!.hasMortgage, false);
    expect(fakeRepo.lastUpdated!.loanInputMethod, isNull,
        reason: 'a mortgage-free property must not stay flagged for manual '
            'loan entry — manual_loan_entry_sheet.dart keys off == "manual"');
  });

  testWidgets(
      'answering Not sure on an existing manual-entry property keeps loanInputMethod',
      (tester) async {
    // CRITICAL from the final review: hasMortgage true + loanInputMethod
    // 'manual', landlord taps "Not sure" (a live chip — a mis-tap is
    // enough). hasMortgage coalesces back to the existing value (true) via
    // `_hasMortgage ?? existing.hasMortgage`, but loanInputMethod was being
    // gated on the raw (now-null) _hasMortgage instead of that same
    // coalesced value — writing hasMortgage: true, loanInputMethod: null in
    // the same save and orphaning the booked figures from every UI surface
    // while they kept feeding the engine.
    final fakeRepo = await _openEditDialog(tester, hasMortgage: true, loanInputMethod: 'manual');

    await _tap(tester, find.text('Not sure'));
    await tester.pumpAndSettle();

    await _tap(tester, find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(fakeRepo.lastUpdated, isNotNull);
    expect(fakeRepo.lastUpdated!.hasMortgage, true,
        reason: '"Not sure" must fall back to the existing value, not clear it');
    expect(fakeRepo.lastUpdated!.loanInputMethod, 'manual',
        reason: 'loanInputMethod must be derived from the same effective '
            'hasMortgage that was actually written, not the raw (null) tap');
  });

  testWidgets('selecting Enter figures myself writes manual on save', (tester) async {
    final fakeRepo = await _openEditDialog(tester, hasMortgage: true, loanInputMethod: null);

    await _tap(tester, find.text('Enter figures myself'));
    await tester.pumpAndSettle();

    await _tap(tester, find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(fakeRepo.lastUpdated!.loanInputMethod, 'manual');
  });

  testWidgets('leaving the loan method unanswered writes null on save', (tester) async {
    final fakeRepo = await _openEditDialog(tester, hasMortgage: true, loanInputMethod: null);

    // Mortgage is already Yes (from the existing property) and neither card
    // is tapped.
    await _tap(tester, find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(fakeRepo.lastUpdated!.loanInputMethod, isNull);
  });

  // --- Coverage gaps flagged by the final review, task 1: both behaviours
  // already work, but neither had a test. ---

  testWidgets('selecting Upload statements writes upload on create', (tester) async {
    final fakeRepo = await _openCreateDialog(tester);

    await _tap(tester, find.text('Yes'));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Upload statements'));
    await tester.pumpAndSettle();

    await _submitCreateDialog(tester);

    expect(fakeRepo.lastCreated, isNotNull);
    expect(fakeRepo.lastCreated!.hasMortgage, true);
    expect(fakeRepo.lastCreated!.loanInputMethod, 'upload');

    await _dismissRegistrationSteps(tester);
  });

  testWidgets('selecting Enter figures myself writes manual on create', (tester) async {
    final fakeRepo = await _openCreateDialog(tester);

    await _tap(tester, find.text('Yes'));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Enter figures myself'));
    await tester.pumpAndSettle();

    await _submitCreateDialog(tester);

    expect(fakeRepo.lastCreated, isNotNull);
    expect(fakeRepo.lastCreated!.hasMortgage, true);
    expect(fakeRepo.lastCreated!.loanInputMethod, 'manual');

    await _dismissRegistrationSteps(tester);
  });

  testWidgets('editing a property preselects its stored method', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: AddPropertyDialog(
            property: _property(hasMortgage: true, loanInputMethod: 'manual'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('loan-method-manual-selected')), findsOneWidget);
    expect(find.byKey(const Key('loan-method-upload-selected')), findsNothing);
  });
}
