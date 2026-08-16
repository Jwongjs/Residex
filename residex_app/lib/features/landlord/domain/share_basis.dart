import 'entities/property.dart';

/// The document states the whole property's figure. The finance engine
/// multiplies it by ownership share — what it has always done.
const String shareBasisFull = 'full';

/// The document already states only this landlord's portion, so the engine
/// uses it verbatim.
const String shareBasisMine = 'mine';

/// The categories a landlord may declare an exception for, with their display
/// labels.
///
/// **Loan is deliberately absent.** Loan interest and principal are never
/// scaled by ownership share — the mortgage is the landlord's own borrowing,
/// not a cost shared with co-owners. That is an ownership decision, not a
/// claim about what a statement shows, so offering `loan` here would let a
/// landlord contradict a settled rule and halve their own deduction.
const Map<String, String> shareBasisCategories = <String, String>{
  'lease': 'Tenancy agreements',
  'rental_invoice': 'Rent invoices',
  'tax': 'Assessment & quit rent',
  'upkeep': 'Repairs & upkeep',
  'maintenance': 'Maintenance & service charges',
  'insurance': 'Insurance',
};

/// Whether an ownership share applies anywhere under this property — the one
/// predicate every part of the share-basis feature is gated on.
///
/// **Not `property.ownershipShare < 1.0`.** A property owned outright can
/// contain a single co-owned unit, and that unit's documents need a basis
/// just as much. Keyed on the property's own share, the question would never
/// be asked and the upload chip would never appear for exactly that unit.
///
/// [unitShares] are the units' stored overrides, where null means "inherits
/// the property's" and therefore adds nothing the property's own share does
/// not already say.
bool shareApplies({
  required double propertyShare,
  required Iterable<double?> unitShares,
}) {
  if (propertyShare < 1.0) return true;
  return unitShares.any((share) => share != null && share < 1.0);
}

/// The basis that applies to one document: its own answer, then the
/// property's exception for its category, then the property's default, then
/// [shareBasisFull].
///
/// A bundled `expenses` statement's category is not one of
/// [shareBasisCategories], so no exception can ever match it — it takes its
/// own answer or the default, which is why the upload review sheet asks.
String resolveShareBasis({
  required Property property,
  required String category,
  String? documentBasis,
}) {
  if (documentBasis == shareBasisMine || documentBasis == shareBasisFull) {
    return documentBasis!;
  }
  final exception = property.shareBasisExceptions[category];
  if (exception == shareBasisMine || exception == shareBasisFull) {
    return exception!;
  }
  return property.shareBasisDefault == shareBasisMine
      ? shareBasisMine
      : shareBasisFull;
}

/// There are only two bases, so "this category is an exception" fully
/// determines its value: whatever the default is not.
String oppositeShareBasis(String basis) =>
    basis == shareBasisMine ? shareBasisFull : shareBasisMine;
