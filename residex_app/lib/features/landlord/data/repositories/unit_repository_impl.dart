import '../../domain/entities/unit.dart';
import '../../domain/repositories/unit_repository.dart';
import '../datasources/unit_remote_datasource.dart';
import '../models/unit_model.dart';

/// Concrete implementation of UnitRepository
///
/// Delegates all operations to UnitRemoteDataSource (Firebase)
class UnitRepositoryImpl implements UnitRepository {
  final UnitRemoteDataSource remoteDataSource;

  UnitRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<Unit>> getUnitsForProperty(String propertyId) async {
    print('🔵 Repository: Get units for property $propertyId');
    try {
      final unitModels = await remoteDataSource.getUnitsForProperty(propertyId);
      print('✅ Repository: Found ${unitModels.length} units');
      return unitModels;
    } catch (e) {
      print('❌ Repository: Failed to get units: $e');
      rethrow;
    }
  }

  @override
  Stream<List<Unit>> streamUnitsForProperty(String propertyId) {
    print('🔵 Repository: Streaming units for property $propertyId');
    return remoteDataSource.streamUnitsForProperty(propertyId);
  }

  @override
  Future<String> createUnit(Unit unit) async {
    print('🔵 Repository: Create unit');
    try {
      final unitModel = UnitModel.fromEntity(unit);
      final unitId = await remoteDataSource.createUnit(unitModel);
      print('✅ Repository: Unit created with ID: $unitId');
      return unitId;
    } catch (e) {
      print('❌ Repository: Failed to create unit: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateUnit(Unit unit) async {
    print('🔵 Repository: Update unit ${unit.id}');
    try {
      final unitModel = UnitModel.fromEntity(unit);
      await remoteDataSource.updateUnit(unitModel);
      print('✅ Repository: Unit updated');
    } catch (e) {
      print('❌ Repository: Failed to update unit: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteUnit(String propertyId, String unitId) async {
    print('🔵 Repository: Delete unit $unitId');
    try {
      await remoteDataSource.deleteUnit(propertyId, unitId);
      print('✅ Repository: Unit deleted');
    } catch (e) {
      print('❌ Repository: Failed to delete unit: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteAllUnitsForProperty(String propertyId) async {
    print('🔵 Repository: Delete all units for property $propertyId');
    try {
      await remoteDataSource.deleteAllUnitsForProperty(propertyId);
      print('✅ Repository: All units deleted');
    } catch (e) {
      print('❌ Repository: Failed to delete units: $e');
      rethrow;
    }
  }
}
