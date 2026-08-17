import 'package:flutter_test/flutter_test.dart';
import 'package:residex_app/features/landlord/domain/entities/property.dart';
import 'package:residex_app/features/landlord/domain/share_basis.dart';

Property _property({
  double ownershipShare = 1.0,
  String shareBasisDefault = 'full',
  Map<String, String> shareBasisExceptions = const {},
}) =>
    Property(
      id: 'p1',
      landlordId: 'l1',
      name: 'Ayer 8',
      address: const PropertyAddress(
        street: '1 Jalan Kiara', city: 'KL', state: 'WP',
        zipCode: '50480', country: 'Malaysia',
      ),
      type: PropertyType.condo,
      purchasePrice: 500000,
      currentValue: 550000,
      ownershipShare: ownershipShare,
      shareBasisDefault: shareBasisDefault,
      shareBasisExceptions: shareBasisExceptions,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  group('shareApplies', () {
    test('a co-owned property qualifies on its own', () {
      expect(shareApplies(propertyShare: 0.5, unitShares: const []), isTrue);
    });

    test('a wholly-owned property with no unit overrides does not', () {
      expect(shareApplies(propertyShare: 1.0, unitShares: const [null, null]),
          isFalse);
    });

    test('a wholly-owned property with one co-owned unit qualifies', () {
      // THE GATE. Keyed on the property's own share this reads false, the
      // question is never asked, and that unit's documents are scaled with no
      // way for the landlord to say they arrived already split.
      expect(shareApplies(propertyShare: 1.0, unitShares: const [null, 0.5]),
          isTrue);
    });

    test('a unit explicitly at 100% does not qualify on its own', () {
      expect(shareApplies(propertyShare: 1.0, unitShares: const [1.0]), isFalse);
    });
  });

  group('resolveShareBasis', () {
    test('the document override wins over everything', () {
      expect(
        resolveShareBasis(
          property: _property(
            shareBasisDefault: 'full',
            shareBasisExceptions: const {'tax': 'full'},
          ),
          category: 'tax',
          documentBasis: 'mine',
        ),
        'mine',
      );
    });

    test('a category exception beats the default', () {
      expect(
        resolveShareBasis(
          property: _property(
            shareBasisDefault: 'full',
            shareBasisExceptions: const {'tax': 'mine'},
          ),
          category: 'tax',
        ),
        'mine',
      );
    });

    test('the default applies to a category with no exception', () {
      expect(
        resolveShareBasis(
          property: _property(shareBasisDefault: 'mine'),
          category: 'upkeep',
        ),
        'mine',
      );
    });

    test('a bundled expenses statement can only take the default', () {
      // 'expenses' is not a declarable category, so no exception can match —
      // which is exactly why the per-document chip exists.
      expect(
        resolveShareBasis(
          property: _property(
            shareBasisDefault: 'full',
            shareBasisExceptions: const {'maintenance': 'mine'},
          ),
          category: 'expenses',
        ),
        'full',
      );
    });

    test('a stray expenses key in exceptions is never matched', () {
      // 'expenses' is never a key the UI writes, but the resolver must not
      // trust that — a direct Firestore edit or a future UI bug must not
      // make a bundled statement pick up a stray exception, matching the
      // backend's own engine-enforced guard for the same document.
      expect(
        resolveShareBasis(
          property: _property(
            shareBasisDefault: 'full',
            shareBasisExceptions: const {'expenses': 'mine'},
          ),
          category: 'expenses',
        ),
        'full',
      );
    });

    test('an unanswered property resolves to full', () {
      expect(
        resolveShareBasis(property: _property(), category: 'maintenance'),
        'full',
      );
    });
  });

  test('loan is never offered as a declarable category', () {
    // Offering it would let a landlord halve their own interest deduction,
    // contradicting a settled rule the engine enforces unconditionally.
    expect(shareBasisCategories.containsKey('loan'), isFalse);
    expect(shareBasisCategories.keys, hasLength(6));
  });
}
