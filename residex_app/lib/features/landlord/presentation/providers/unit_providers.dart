import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/unit_remote_datasource.dart';
import '../../data/repositories/unit_repository_impl.dart';
import '../../domain/entities/unit.dart';
import '../../domain/repositories/unit_repository.dart';
import '../../domain/usecases/create_unit.dart';
import '../../domain/usecases/delete_unit.dart';
import '../../domain/usecases/get_units_for_property.dart';
import '../../domain/usecases/update_unit.dart';

// ============================================================
// DATA LAYER PROVIDERS
// ============================================================

final unitRemoteDataSourceProvider = Provider<UnitRemoteDataSource>((ref) {
  return UnitRemoteDataSource(firestore: FirebaseFirestore.instance);
});

final unitRepositoryProvider = Provider<UnitRepository>((ref) {
  final dataSource = ref.watch(unitRemoteDataSourceProvider);
  return UnitRepositoryImpl(remoteDataSource: dataSource);
});

// ============================================================
// USE CASE PROVIDERS
// ============================================================

final getUnitsForPropertyUseCaseProvider = Provider<GetUnitsForProperty>((ref) {
  final repository = ref.watch(unitRepositoryProvider);
  return GetUnitsForProperty(repository);
});

final createUnitUseCaseProvider = Provider<CreateUnit>((ref) {
  final repository = ref.watch(unitRepositoryProvider);
  return CreateUnit(repository);
});

final updateUnitUseCaseProvider = Provider<UpdateUnit>((ref) {
  final repository = ref.watch(unitRepositoryProvider);
  return UpdateUnit(repository);
});

final deleteUnitUseCaseProvider = Provider<DeleteUnit>((ref) {
  final repository = ref.watch(unitRepositoryProvider);
  return DeleteUnit(repository);
});

// ============================================================
// PRESENTATION LAYER PROVIDERS
// ============================================================

/// Stream units for a given property (real-time updates)
final unitsForPropertyStreamProvider =
    StreamProvider.family<List<Unit>, String>((ref, propertyId) {
  final getUnitsUseCase = ref.watch(getUnitsForPropertyUseCaseProvider);
  return getUnitsUseCase.stream(propertyId);
});

/// One-time fetch of units for a property (used by portfolioStatsProvider)
final unitsForPropertyProvider =
    FutureProvider.family<List<Unit>, String>((ref, propertyId) async {
  final getUnitsUseCase = ref.watch(getUnitsForPropertyUseCaseProvider);
  return getUnitsUseCase(propertyId);
});

// ============================================================
// UNIT CONTROLLER (UI Actions)
// ============================================================

class UnitController {
  final Ref _ref;

  UnitController(this._ref);

  Future<String> createUnit(Unit unit) async {
    try {
      final createUseCase = _ref.read(createUnitUseCaseProvider);
      final unitId = await createUseCase(unit);
      _ref.invalidate(unitsForPropertyStreamProvider(unit.propertyId));
      _ref.invalidate(unitsForPropertyProvider(unit.propertyId));
      return unitId;
    } catch (e) {
      print('❌ Controller: Failed to create unit: $e');
      rethrow;
    }
  }

  Future<void> updateUnit(Unit unit) async {
    try {
      final updateUseCase = _ref.read(updateUnitUseCaseProvider);
      await updateUseCase(unit);
      _ref.invalidate(unitsForPropertyStreamProvider(unit.propertyId));
      _ref.invalidate(unitsForPropertyProvider(unit.propertyId));
    } catch (e) {
      print('❌ Controller: Failed to update unit: $e');
      rethrow;
    }
  }

  Future<void> deleteUnit(String propertyId, String unitId) async {
    try {
      final deleteUseCase = _ref.read(deleteUnitUseCaseProvider);
      await deleteUseCase(propertyId, unitId);
      _ref.invalidate(unitsForPropertyStreamProvider(propertyId));
      _ref.invalidate(unitsForPropertyProvider(propertyId));
    } catch (e) {
      print('❌ Controller: Failed to delete unit: $e');
      rethrow;
    }
  }
}

final unitControllerProvider = Provider<UnitController>((ref) {
  return UnitController(ref);
});
