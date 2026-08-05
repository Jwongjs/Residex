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
import 'package:residex_app/features/landlord/domain/repositories/property_repository.dart';
import 'package:residex_app/features/landlord/presentation/providers/property_providers.dart';
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
}
