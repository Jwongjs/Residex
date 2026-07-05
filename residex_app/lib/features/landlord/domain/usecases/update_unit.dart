import '../entities/unit.dart';
import '../repositories/unit_repository.dart';

/// Use case for updating an existing unit
class UpdateUnit {
  final UnitRepository _repository;

  UpdateUnit(this._repository);

  Future<void> call(Unit unit) async {
    print('🔵 UseCase: Updating unit: ${unit.id}');

    if (unit.id.trim().isEmpty) {
      throw Exception('Unit ID cannot be empty');
    }

    if (unit.label.trim().isEmpty) {
      throw Exception('Unit label cannot be empty');
    }

    if (unit.monthlyRent < 0) {
      throw Exception('Monthly rent must be >= 0');
    }

    try {
      final unitToUpdate = unit.copyWith(updatedAt: DateTime.now());
      await _repository.updateUnit(unitToUpdate);
      print('✅ UseCase: Unit updated successfully: ${unit.id}');
    } catch (e) {
      print('❌ UseCase: Failed to update unit: $e');
      rethrow;
    }
  }
}
