import '../entities/unit.dart';
import '../repositories/unit_repository.dart';

/// Use case for fetching all units belonging to a property
class GetUnitsForProperty {
  final UnitRepository _repository;

  GetUnitsForProperty(this._repository);

  Future<List<Unit>> call(String propertyId) async {
    return _repository.getUnitsForProperty(propertyId);
  }

  Stream<List<Unit>> stream(String propertyId) {
    return _repository.streamUnitsForProperty(propertyId);
  }
}
