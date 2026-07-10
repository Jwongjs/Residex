import '../../../domain/entities/unit.dart';

/// Resolve the unit label to display for a document or citation.
///
/// The stored label is a denormalized copy captured at upload time and goes
/// stale when a unit is renamed. Prefer the live units list; fall back to
/// the stored copy when the unit no longer resolves (deleted unit, list
/// still loading). Property-wide records (no unitId) never show a label.
String? resolveUnitLabel({
  required String? unitId,
  required String? storedLabel,
  required List<Unit> liveUnits,
}) {
  if (unitId == null) return null;
  for (final unit in liveUnits) {
    if (unit.id == unitId) return unit.label;
  }
  return storedLabel;
}
