import '../entities/unit.dart';

/// Abstract unit repository - defines unit data operations
abstract class UnitRepository {
  /// Get all units for a property
  Future<List<Unit>> getUnitsForProperty(String propertyId);

  /// Stream units for a property in real-time
  Stream<List<Unit>> streamUnitsForProperty(String propertyId);

  /// Create a new unit
  Future<String> createUnit(Unit unit);

  /// Update an existing unit
  Future<void> updateUnit(Unit unit);

  /// Delete a unit
  Future<void> deleteUnit(String propertyId, String unitId);
}
