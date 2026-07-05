import '../entities/unit.dart';
import '../repositories/unit_repository.dart';

/// Use case for creating a new unit
class CreateUnit {
  final UnitRepository _repository;

  CreateUnit(this._repository);

  /// Create a new unit. Returns the created unit's ID.
  Future<String> call(Unit unit) async {
    print('🔵 UseCase: CreateUnit called for ${unit.label}');

    if (unit.label.trim().isEmpty) {
      throw Exception('Unit label cannot be empty');
    }

    if (unit.monthlyRent < 0) {
      throw Exception('Monthly rent must be >= 0');
    }

    try {
      final unitId = await _repository.createUnit(unit);
      print('✅ UseCase: Unit created successfully: $unitId');
      return unitId;
    } catch (e) {
      print('❌ UseCase: Failed to create unit: $e');
      rethrow;
    }
  }
}
