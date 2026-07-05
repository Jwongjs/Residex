import '../repositories/unit_repository.dart';

/// Use case for deleting a unit
class DeleteUnit {
  final UnitRepository _repository;

  DeleteUnit(this._repository);

  Future<void> call(String propertyId, String unitId) async {
    print('🔵 UseCase: Deleting unit: $unitId');

    try {
      await _repository.deleteUnit(propertyId, unitId);
      print('✅ UseCase: Unit deleted successfully: $unitId');
    } catch (e) {
      print('❌ UseCase: Failed to delete unit: $e');
      rethrow;
    }
  }
}
