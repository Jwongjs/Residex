// Drives the dialog's save path through a real (fake) repository and asserts
// on the written Property. Originally written for the loan-entry-method
// workstream's copyWith-swallows-null bug (add_property_dialog.dart's
// edit-mode Property construction); Task 2 of the loan tracking rework
// removed that fork, so this file now just covers the dialog's save path in
// general — hasMortgage on both the edit and create branches.
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:residex_app/features/landlord/domain/entities/property.dart';
import 'package:residex_app/features/landlord/domain/entities/unit.dart';
import 'package:residex_app/features/landlord/domain/repositories/property_repository.dart';
import 'package:residex_app/features/landlord/domain/repositories/unit_repository.dart';
import 'package:residex_app/features/landlord/presentation/providers/documind_provider.dart';
import 'package:residex_app/features/landlord/presentation/providers/property_providers.dart';
import 'package:residex_app/features/landlord/presentation/providers/unit_providers.dart';
import 'package:residex_app/features/landlord/presentation/widgets/common/add_property_dialog.dart';
import 'package:residex_app/features/landlord/presentation/widgets/common/app_choice_chip.dart';
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

class _FakeUnitRepository implements UnitRepository {
  _FakeUnitRepository([this.units = const []]);

  final List<Unit> units;

  @override
  Future<String> createUnit(Unit unit) async => 'u1';
  @override
  Future<void> deleteAllUnitsForProperty(String propertyId) async {}
  @override
  Future<void> deleteUnit(String propertyId, String unitId) async {}
  @override
  Future<List<Unit>> getUnitsForProperty(String propertyId) async => units;
  @override
  Future<void> updateUnit(Unit unit) async {}
  @override
  Stream<List<Unit>> streamUnitsForProperty(String propertyId) =>
      Stream.value(units);
}

Property _property({
  required bool? hasMortgage,
  PropertyType type = PropertyType.condo,
  PropertyStructureType? structureType,
  int? trackFromYear,
  double ownershipShare = 1.0,
  String shareBasisDefault = 'full',
  Map<String, String> shareBasisExceptions = const {},
}) =>
    Property(
      id: 'p1',
      landlordId: 'l1',
      name: 'Kiara Court',
      address: const PropertyAddress(
        street: '1 Jalan Kiara', city: 'KL', state: 'WP',
        zipCode: '50480', country: 'Malaysia',
      ),
      type: type,
      purchasePrice: 500000,
      currentValue: 550000,
      hasMortgage: hasMortgage,
      structureType: structureType,
      trackFromYear: trackFromYear,
      ownershipShare: ownershipShare,
      shareBasisDefault: shareBasisDefault,
      shareBasisExceptions: shareBasisExceptions,
      createdAt: DateTime(2026, 1, 1),
    );

/// Opens the edit dialog the way the app does — via showDialog, so
/// Navigator.pop(true) in _handleSubmit has a route to pop instead of
/// emptying the root Navigator's history.
Future<_FakePropertyRepository> _openEditDialog(
  WidgetTester tester, {
  required bool? hasMortgage,
  PropertyType type = PropertyType.condo,
  PropertyStructureType? structureType,
  int? trackFromYear,
  List<Map<String, dynamic>>? loanEntries,
  double ownershipShare = 1.0,
  List<Unit> units = const [],
  String shareBasisDefault = 'full',
  Map<String, String> shareBasisExceptions = const {},
  // Simulates a units subscription that never delivers a first event —
  // covers both the loading window and an errored subscription (permission
  // denied, offline cold start), neither of which ever populate `.value`.
  bool unitsStreamUnresolved = false,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final property = _property(
    hasMortgage: hasMortgage,
    type: type,
    structureType: structureType,
    trackFromYear: trackFromYear,
    ownershipShare: ownershipShare,
    shareBasisDefault: shareBasisDefault,
    shareBasisExceptions: shareBasisExceptions,
  );
  final fakeRepo = _FakePropertyRepository(property);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        propertyRepositoryProvider.overrideWithValue(fakeRepo),
        unitRepositoryProvider.overrideWithValue(_FakeUnitRepository(units)),
        if (unitsStreamUnresolved)
          unitsForPropertyStreamProvider.overrideWith(
            (ref, propertyId) => const Stream<List<Unit>>.empty(),
          ),
        currentFirebaseUserProvider.overrideWithValue(_FakeUser()),
        // Both loan-entry providers are faked, and the year-scoped one really
        // filters by year. That fidelity is what gives the prior-year test
        // below its teeth: a guard that asks for one year gets an empty list
        // from this fake and skips the confirmation, exactly as it did against
        // the real backend.
        if (loanEntries != null) ...[
          allManualLoanEntriesProvider
              .overrideWith((ref, propertyId) async => loanEntries),
          manualLoanEntriesProvider.overrideWith(
            (ref, args) async =>
                loanEntries.where((e) => e['year'] == args.year).toList(),
          ),
        ],
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
    _property(hasMortgage: null),
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

  // Fills the required fields in build() order: name, (ownership share
  // already defaults to '100'), street, city, state, zip, purchase price,
  // current value, total units.
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'Test Property');
  await tester.enterText(fields.at(2), '1 Jalan Kiara');
  await tester.enterText(fields.at(3), 'KL');
  await tester.enterText(fields.at(4), 'WP');
  await tester.enterText(fields.at(5), '50480');
  await tester.enterText(fields.at(6), '500000');
  await tester.enterText(fields.at(7), '550000');
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
  testWidgets('answering No on a mortgaged property writes hasMortgage false',
      (tester) async {
    // loanEntries: const [] overrides manualLoanEntriesProvider so
    // _confirmRemovingLoanTracking's booked-figures check resolves locally
    // instead of hitting the real (network-backed) provider — this test
    // predates Task 5's confirmation and isn't exercising it.
    final fakeRepo =
        await _openEditDialog(tester, hasMortgage: true, loanEntries: const []);

    await _tap(tester, find.text('No'));
    await tester.pumpAndSettle();

    await _tap(tester, find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(fakeRepo.lastUpdated, isNotNull);
    expect(fakeRepo.lastUpdated!.hasMortgage, false);
  });

  testWidgets('creating a property with Yes writes hasMortgage true',
      (tester) async {
    final fakeRepo = await _openCreateDialog(tester);

    await _tap(tester, find.text('Yes'));
    await tester.pumpAndSettle();

    await _submitCreateDialog(tester);

    expect(fakeRepo.lastCreated, isNotNull);
    expect(fakeRepo.lastCreated!.hasMortgage, true);

    await _dismissRegistrationSteps(tester);
  });

  testWidgets('the mortgage question offers Yes and No only', (tester) async {
    await _openEditDialog(tester, hasMortgage: true);

    expect(find.text('Yes'), findsOneWidget);
    expect(find.text('No'), findsOneWidget);
    // "Not sure" survives on the structure-type question for commercial
    // properties and in the track-from-year picker's label; this property is
    // a condo, so neither is on screen and a bare finder is unambiguous.
    expect(find.text('Not sure'), findsNothing);
  });

  testWidgets('a property with an unanswered mortgage shows neither chip selected',
      (tester) async {
    final fakeRepo = await _openEditDialog(tester, hasMortgage: null);

    await _tap(tester, find.text('Save changes'));
    await tester.pumpAndSettle();

    // Nothing was tapped, so nothing was answered — and the save must not
    // invent an answer.
    expect(fakeRepo.lastUpdated!.hasMortgage, isNull);
  });

  testWidgets('selecting "Not sure" for structure type persists null on save',
      (tester) async {
    // The bug: edit-mode save coalesced every field with `?? existing.field`,
    // so tapping "Not sure" on an already-answered property was a no-op.
    final fakeRepo = await _openEditDialog(
      tester, hasMortgage: true, type: PropertyType.commercial,
      structureType: PropertyStructureType.strata,
    );

    await _tap(tester, find.text('Not sure'));
    await tester.pumpAndSettle();

    await _tap(tester, find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(fakeRepo.lastUpdated!.structureType, isNull);
  });

  testWidgets('selecting "Not sure" for track-from year persists null on save',
      (tester) async {
    final fakeRepo = await _openEditDialog(
      tester, hasMortgage: true, trackFromYear: 2024,
    );

    await _tap(tester, find.byIcon(Icons.calendar_today_outlined));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Not sure (default)'));
    await tester.pumpAndSettle();

    await _tap(tester, find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(fakeRepo.lastUpdated!.trackFromYear, isNull);
  });

  testWidgets('flipping Yes to No with booked figures raises a confirmation',
      (tester) async {
    final fakeRepo = await _openEditDialog(
      tester, hasMortgage: true,
      loanEntries: [
        {
          'interest_paid': 8200.0, 'principal_paid': 0.0,
          'year': DateTime.now().year, 'month': null, 'unit_id': null,
        },
      ],
    );

    await _tap(tester, find.text('No'));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Remove loan tracking for this property?'), findsOneWidget);
    expect(find.textContaining('RM 8,200.00'), findsOneWidget);
    expect(find.textContaining('mark it settled instead'), findsOneWidget);
    expect(fakeRepo.lastUpdated, isNull, reason: 'nothing saves until confirmed');
  });

  testWidgets('cancelling the confirmation restores Yes and saves nothing',
      (tester) async {
    final fakeRepo = await _openEditDialog(
      tester, hasMortgage: true,
      loanEntries: [
        {
          'interest_paid': 8200.0, 'principal_paid': 0.0,
          'year': DateTime.now().year, 'month': null, 'unit_id': null,
        },
      ],
    );

    await _tap(tester, find.text('No'));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Save changes'));
    await tester.pumpAndSettle();
    // The AddPropertyDialog's own footer also has a 'Cancel' button, and it
    // stays in the tree underneath the confirmation AlertDialog, so a bare
    // find.text('Cancel') is ambiguous — scope to the AlertDialog's button.
    await _tap(
      tester,
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Cancel'),
      ),
    );
    await tester.pumpAndSettle();

    expect(fakeRepo.lastUpdated, isNull);
    // The Yes chip is selected again, so the dialog does not sit in a state
    // that contradicts what is stored.
    final yes = tester.widget<AppChoiceChip>(
      find.widgetWithText(AppChoiceChip, 'Yes'),
    );
    expect(yes.selected, isTrue);
  });

  testWidgets('confirming saves hasMortgage false', (tester) async {
    final fakeRepo = await _openEditDialog(
      tester, hasMortgage: true,
      loanEntries: [
        {
          'interest_paid': 8200.0, 'principal_paid': 0.0,
          'year': DateTime.now().year, 'month': null, 'unit_id': null,
        },
      ],
    );

    await _tap(tester, find.text('No'));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Save changes'));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Remove tracking'));
    await tester.pumpAndSettle();

    expect(fakeRepo.lastUpdated!.hasMortgage, false);
  });

  testWidgets('flipping Yes to No with no booked figures saves without asking',
      (tester) async {
    final fakeRepo = await _openEditDialog(
      tester, hasMortgage: true, loanEntries: const [],
    );

    await _tap(tester, find.text('No'));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Remove loan tracking for this property?'), findsNothing);
    expect(fakeRepo.lastUpdated!.hasMortgage, false);
  });

  testWidgets(
      'figures booked only in earlier years still raise the confirmation',
      (tester) async {
    // The removal is retroactive across every year, so the guard has to look
    // at every year. While it only checked the current one, a property with a
    // full loan history and nothing yet booked this year — the normal state of
    // any property in January — lost its tracking with no warning at all.
    final lastYear = DateTime.now().year - 1;
    final fakeRepo = await _openEditDialog(
      tester, hasMortgage: true,
      loanEntries: [
        {
          'interest_paid': 8200.0, 'principal_paid': 1800.0,
          'year': lastYear, 'month': null, 'unit_id': null,
        },
      ],
    );

    await _tap(tester, find.text('No'));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Remove loan tracking for this property?'), findsOneWidget);
    expect(fakeRepo.lastUpdated, isNull, reason: 'nothing saves until confirmed');
    // The warning names the year the figures are in, so the landlord can check
    // it against what they remember filing rather than trusting a bare total.
    expect(find.textContaining('RM 10,000.00 of $lastYear loan figures'),
        findsOneWidget);
  });

  testWidgets('the confirmation spans the full range of booked years',
      (tester) async {
    final thisYear = DateTime.now().year;
    await _openEditDialog(
      tester, hasMortgage: true,
      loanEntries: [
        {
          'interest_paid': 1000.0, 'principal_paid': 0.0,
          'year': thisYear - 2, 'month': null, 'unit_id': null,
        },
        {
          'interest_paid': 500.0, 'principal_paid': 0.0,
          'year': thisYear, 'month': null, 'unit_id': null,
        },
      ],
    );

    await _tap(tester, find.text('No'));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Save changes'));
    await tester.pumpAndSettle();

    // Totalled across years, not just the latest one.
    expect(
      find.textContaining('RM 1,500.00 of ${thisYear - 2}–$thisYear loan figures'),
      findsOneWidget,
    );
  });

  testWidgets('a wholly-owned property is never asked about share basis',
      (tester) async {
    await _openEditDialog(tester, hasMortgage: true, ownershipShare: 1.0);

    expect(find.text('How do your documents arrive?'), findsNothing);
    expect(find.text('Already split to my share'), findsNothing);
  });

  testWidgets('a co-owned property is asked, and defaults to the full amount',
      (tester) async {
    await _openEditDialog(tester, hasMortgage: true, ownershipShare: 0.5);

    expect(find.text('How do your documents arrive?'), findsOneWidget);
    final full = tester.widget<AppChoiceChip>(
      find.widgetWithText(AppChoiceChip, 'At the full property amount'),
    );
    expect(full.selected, isTrue);
  });

  testWidgets('lowering the share on an existing property raises the question',
      (tester) async {
    // Spec §4: a property that already has documents must be asked at the
    // moment its share is set, because the answer changes existing figures.
    // The question is inline, so it has to appear as the field is typed —
    // which only works if the form rebuilds on that controller.
    await _openEditDialog(tester, hasMortgage: true, ownershipShare: 1.0);
    expect(find.text('How do your documents arrive?'), findsNothing);

    final shareField =
        find.widgetWithText(TextFormField, 'My share of this property (%)');
    await tester.ensureVisible(shareField);
    await tester.enterText(shareField, '50');
    await tester.pumpAndSettle();

    expect(find.text('How do your documents arrive?'), findsOneWidget);
  });

  testWidgets('a property at 100% with one co-owned unit is still asked',
      (tester) async {
    // THE §3a GATE. Keyed on the property's own share this property is at
    // 100% and says nothing, while that unit's documents still need a basis.
    await _openEditDialog(
      tester,
      hasMortgage: true,
      ownershipShare: 1.0,
      units: [
        Unit(
          id: 'u1', propertyId: 'p1', label: 'A-1', monthlyRent: 1200,
          isOccupied: true, ownershipShare: 0.5, createdAt: DateTime(2026, 1, 1),
        ),
      ],
    );

    expect(find.text('How do your documents arrive?'), findsOneWidget);
  });

  testWidgets('answering "already split" saves the default', (tester) async {
    final fakeRepo =
        await _openEditDialog(tester, hasMortgage: true, ownershipShare: 0.5);

    await _tap(tester, find.text('Already split to my share'));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(fakeRepo.lastUpdated!.shareBasisDefault, 'mine');
    expect(fakeRepo.lastUpdated!.shareBasisExceptions, isEmpty);
  });

  testWidgets('an exception stores the opposite of the default', (tester) async {
    final fakeRepo =
        await _openEditDialog(tester, hasMortgage: true, ownershipShare: 0.5);

    await _tap(tester, find.text('Any exceptions?'));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Assessment & quit rent'));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Save changes'));
    await tester.pumpAndSettle();

    // Default is 'full', so an excepted category is 'mine'.
    expect(fakeRepo.lastUpdated!.shareBasisExceptions, {'tax': 'mine'});
  });

  testWidgets('flipping the default flips every stored exception',
      (tester) async {
    // An exception means "this category differs". If the default moves and
    // the exceptions do not, every one of them silently becomes a no-op
    // duplicate of the default.
    final fakeRepo =
        await _openEditDialog(tester, hasMortgage: true, ownershipShare: 0.5);

    await _tap(tester, find.text('Any exceptions?'));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Assessment & quit rent'));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Already split to my share'));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(fakeRepo.lastUpdated!.shareBasisDefault, 'mine');
    expect(fakeRepo.lastUpdated!.shareBasisExceptions, {'tax': 'full'});
  });

  testWidgets('loan is never offered as an exception', (tester) async {
    await _openEditDialog(tester, hasMortgage: true, ownershipShare: 0.5);

    await _tap(tester, find.text('Any exceptions?'));
    await tester.pumpAndSettle();

    expect(find.text('Loan statements'), findsNothing);
    expect(find.text('Assessment & quit rent'), findsOneWidget);
  });

  testWidgets(
      'saving while the units stream has not resolved preserves the stored basis',
      (tester) async {
    // Finding 1 repro: the property's own share is 100%, so it was a
    // co-owned unit that made `shareBasisDefault` get answered 'mine' in
    // the first place. If the units stream simply has not delivered its
    // first event by the time Save is tapped — still loading, or an errored
    // subscription — the dialog cannot tell whether that unit override
    // still applies. It must not guess "no share applies" and silently
    // discard the landlord's stored answer.
    final fakeRepo = await _openEditDialog(
      tester,
      hasMortgage: true,
      ownershipShare: 1.0,
      shareBasisDefault: 'mine',
      shareBasisExceptions: const {'tax': 'full'},
      unitsStreamUnresolved: true,
    );

    // The question is not shown either — with no unit data, the dialog
    // genuinely does not know a share applies here, which is exactly why
    // nothing may be silently reset on save.
    expect(find.text('How do your documents arrive?'), findsNothing);

    await _tap(tester, find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(fakeRepo.lastUpdated!.shareBasisDefault, 'mine');
    expect(fakeRepo.lastUpdated!.shareBasisExceptions, {'tax': 'full'});
  });

  testWidgets('raising the share back to 100 clears an answered basis on save',
      (tester) async {
    // Finding 2: the "only save an answer when a share applies" guard
    // (basisApplies ? ... : shareBasisFull) had no test of its own — the
    // property was answered while co-owned, but by the time Save is tapped
    // the share has been raised back to 100, so nothing must be written
    // that the landlord can no longer see or act on.
    final fakeRepo =
        await _openEditDialog(tester, hasMortgage: true, ownershipShare: 0.5);

    await _tap(tester, find.text('Already split to my share'));
    await tester.pumpAndSettle();

    final shareField =
        find.widgetWithText(TextFormField, 'My share of this property (%)');
    await tester.ensureVisible(shareField);
    await tester.enterText(shareField, '100');
    await tester.pumpAndSettle();

    expect(find.text('How do your documents arrive?'), findsNothing);

    await _tap(tester, find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(fakeRepo.lastUpdated!.shareBasisDefault, 'full');
    expect(fakeRepo.lastUpdated!.shareBasisExceptions, isEmpty);
  });

  testWidgets(
      'answering the question while units are unresolved still saves the '
      'fresh answer',
      (tester) async {
    // Round-2 regression: the property's own share (0.5) already makes
    // shareApplies true with no unit data at all, so the question is shown
    // and answerable regardless of whether the units stream has resolved.
    // The round-1 preservation branch fired on `unitsAsync.value == null`
    // alone and discarded a fresh tap in exactly this window — it must only
    // preserve when the question genuinely could not have been shown.
    final fakeRepo = await _openEditDialog(
      tester,
      hasMortgage: true,
      ownershipShare: 0.5,
      shareBasisDefault: 'full',
      unitsStreamUnresolved: true,
    );

    // Confirms this really is the "shown but units unresolved" case, not
    // something else the fix could accidentally special-case away.
    expect(find.text('How do your documents arrive?'), findsOneWidget);

    await _tap(tester, find.text('Already split to my share'));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(fakeRepo.lastUpdated!.shareBasisDefault, 'mine');
  });
}
