# Unit-Level Rent Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `Property`'s flat `monthlyRent`/`totalUnits`/`occupiedUnits` fields with a new `Unit` entity (one document per unit, stored as a Firestore subcollection), so each unit in a property has its own rent and occupancy status.

**Architecture:** A new `Unit` domain entity is stored at `properties/{propertyId}/units/{unitId}`. `Property` loses `totalUnits`, `occupiedUnits`, `monthlyRent`, and their dependent getters entirely — those become values computed from real `Unit` records wherever needed. A new `UnitRepository` (datasource → repository impl → abstract interface, mirroring `PropertyRepository`'s exact 3-layer shape) handles unit CRUD. `portfolioStatsProvider` becomes an async `FutureProvider` that fans out one unit-fetch per property. A new `UnitsScreen` is reached by tapping a property card (currently unwired) and lets a landlord edit each unit's label/rent/occupied-status individually.

**Tech Stack:** Flutter (Riverpod, `cloud_firestore`) — this migration is Flutter-only; no backend Python/FastAPI changes.

## Global Constraints

- No backend/Python changes — confirmed rent/units are never read/written server-side today.
- No data migration/backfill script — existing demo properties will be deleted and re-created manually through the app after this ships.
- Occupancy is binary (Occupied/Vacant) — no "Under Maintenance" or other states.
- New Firestore subcollection `properties/{propertyId}/units/{unitId}` requires an explicit security rule (Firestore does not cascade parent rules to subcollections) — add a rule scoping access to the parent property's `landlordId` via `get()`.
- `portfolioStatsProvider` becomes a `FutureProvider<PortfolioStats>` (was `Provider<PortfolioStats>`) — every call site must be updated to handle `AsyncValue` in the same task that changes the provider type, since nothing compiles otherwise.
- `filteredPropertiesProvider`'s "Fully Occupied"/"Has Vacancy" filter chips must be recomputed from real `Unit` records, not removed.
- Follow this codebase's existing print-logging convention exactly (🔵 before an operation, ✅ on success, ❌ on failure, ⚠️ for a caught-but-non-fatal condition) in every new datasource/repository/usecase method — this project has NOT adopted an emoji-free convention for this layer (unlike the backend Python code touched in a separate, unrelated feature this session); match the Dart layer's existing style as-is.
- No new automated test suite is being introduced — this codebase has zero existing Flutter unit tests for property CRUD (confirmed: no test file references `PropertyRepository`/`CreateProperty`/etc.). Verification is `flutter analyze` (must stay at the 0-error baseline) plus manual testing, consistent with how prior Flutter-only work in this project has been verified.

---

### Task 1: `Unit` entity + Firestore security rule

**Files:**
- Create: `residex_app/lib/features/landlord/domain/entities/unit.dart`
- Modify: `residex_app/firestore.rules`

**Interfaces:**
- Produces: `Unit` class (`id`, `propertyId`, `label`, `monthlyRent`, `isOccupied`, `createdAt`, `updatedAt`), consumed by every later task.

- [ ] **Step 1: Create the `Unit` entity**

Create `residex_app/lib/features/landlord/domain/entities/unit.dart`:

```dart
// lib/features/landlord/domain/entities/unit.dart

/// Pure business object - Unit entity
///
/// Represents a single rentable unit within a Property (e.g. "Unit 1" in a
/// 10-unit apartment building). Each unit has its own rent and occupancy
/// status — Property no longer stores a flat rent/unit-count.
/// Matches Firebase schema: properties/{propertyId}/units/{unitId}
class Unit {
  final String id;
  final String propertyId;
  final String label;
  final double monthlyRent;
  final bool isOccupied;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Unit({
    required this.id,
    required this.propertyId,
    required this.label,
    required this.monthlyRent,
    required this.isOccupied,
    required this.createdAt,
    this.updatedAt,
  });

  Unit copyWith({
    String? id,
    String? propertyId,
    String? label,
    double? monthlyRent,
    bool? isOccupied,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Unit(
      id: id ?? this.id,
      propertyId: propertyId ?? this.propertyId,
      label: label ?? this.label,
      monthlyRent: monthlyRent ?? this.monthlyRent,
      isOccupied: isOccupied ?? this.isOccupied,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Unit &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
```

- [ ] **Step 2: Add the Firestore security rule for the new subcollection**

In `residex_app/firestore.rules`, the current `properties/{propertyId}` block (full file has 38 lines) reads:

```
    // ========== PROPERTIES (for property name lookup) ==========
    match /properties/{propertyId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
                      request.auth.uid == resource.data.landlordId;
    }
```

Add a nested `units` match block immediately after the closing `}` of the `properties/{propertyId}` block (still inside it, so `propertyId` from the outer match is in scope):

```
    // ========== PROPERTIES (for property name lookup) ==========
    match /properties/{propertyId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
                      request.auth.uid == resource.data.landlordId;

      // ========== UNITS (per-property rentable units) ==========
      match /units/{unitId} {
        allow read, write: if request.auth != null &&
            request.auth.uid == get(/databases/$(database)/documents/properties/$(propertyId)).data.landlordId;
      }
    }
```

This scopes every unit read/write to the landlord who owns the parent property, via a `get()` lookup on the parent document — matching the ownership check already used for `properties/{propertyId}` itself.

- [ ] **Step 3: Verify with flutter analyze**

Run: `cd residex_app && flutter analyze lib/features/landlord/domain/entities/unit.dart`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add residex_app/lib/features/landlord/domain/entities/unit.dart residex_app/firestore.rules
git commit -m "feat: add Unit entity and Firestore security rule for units subcollection"
```

---

### Task 2: `UnitModel` + `UnitRemoteDataSource`

**Files:**
- Create: `residex_app/lib/features/landlord/data/models/unit_model.dart`
- Create: `residex_app/lib/features/landlord/data/datasources/unit_remote_datasource.dart`

**Interfaces:**
- Consumes: `Unit` entity (Task 1).
- Produces: `UnitModel` (Firestore serialization), `UnitRemoteDataSource` with methods `getUnitsForProperty`, `streamUnitsForProperty`, `createUnit`, `updateUnit`, `deleteUnit` — consumed by Task 3's `UnitRepositoryImpl`.

- [ ] **Step 1: Create `UnitModel`**

Create `residex_app/lib/features/landlord/data/models/unit_model.dart`, mirroring `property_model.dart`'s exact shape:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/unit.dart';

/// Data Transfer Object for Unit
///
/// Extends Unit entity and adds serialization logic for Firestore.
class UnitModel extends Unit {
  UnitModel({
    required super.id,
    required super.propertyId,
    required super.label,
    required super.monthlyRent,
    required super.isOccupied,
    required super.createdAt,
    super.updatedAt,
  });

  /// Create UnitModel from domain entity
  factory UnitModel.fromEntity(Unit unit) {
    return UnitModel(
      id: unit.id,
      propertyId: unit.propertyId,
      label: unit.label,
      monthlyRent: unit.monthlyRent,
      isOccupied: unit.isOccupied,
      createdAt: unit.createdAt,
      updatedAt: unit.updatedAt,
    );
  }

  /// Create UnitModel from JSON
  factory UnitModel.fromJson(Map<String, dynamic> json, String id, String propertyId) {
    return UnitModel(
      id: id,
      propertyId: propertyId,
      label: json['label'] as String,
      monthlyRent: _parseDouble(json['monthlyRent']),
      isOccupied: json['isOccupied'] as bool? ?? false,
      createdAt: _parseTimestamp(json['createdAt']),
      updatedAt: json['updatedAt'] != null
          ? _parseTimestamp(json['updatedAt'])
          : null,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'monthlyRent': monthlyRent,
      'isOccupied': isOccupied,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// Create UnitModel from Firestore document
  factory UnitModel.fromFirestore(DocumentSnapshot doc, String propertyId) {
    final data = doc.data() as Map<String, dynamic>;
    return UnitModel.fromJson(data, doc.id, propertyId);
  }

  /// Convert to Firestore document data
  Map<String, dynamic> toFirestore() => toJson();

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
```

Note: `propertyId` is NOT stored as a field inside the Firestore document itself (it's implicit in the document's path, `properties/{propertyId}/units/{unitId}`) — it's threaded through as a constructor/factory parameter instead, since `UnitRemoteDataSource` always knows which property it's querying.

- [ ] **Step 2: Create `UnitRemoteDataSource`**

Create `residex_app/lib/features/landlord/data/datasources/unit_remote_datasource.dart`, mirroring `property_remote_datasource.dart`'s exact print/try-catch/rethrow convention, extended one level deeper (subcollection instead of top-level collection — there is no existing subcollection precedent in this codebase; this establishes the first one, based directly on `PropertyRemoteDataSource`'s single-collection CRUD pattern):

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/unit_model.dart';

/// Remote data source for unit operations using Firestore
///
/// Handles all Firebase Firestore operations for the
/// properties/{propertyId}/units subcollection.
class UnitRemoteDataSource {
  final FirebaseFirestore _firestore;

  UnitRemoteDataSource({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference _unitsCollection(String propertyId) =>
      _firestore.collection('properties').doc(propertyId).collection('units');

  /// Get all units for a property
  Future<List<UnitModel>> getUnitsForProperty(String propertyId) async {
    print('🔵 DataSource: Fetching units for property: $propertyId');

    try {
      final querySnapshot = await _unitsCollection(propertyId)
          .orderBy('createdAt', descending: false)
          .get();

      print('✅ DataSource: Found ${querySnapshot.docs.length} units');

      return querySnapshot.docs
          .map((doc) => UnitModel.fromFirestore(doc, propertyId))
          .toList();
    } catch (e) {
      print('❌ DataSource: Error fetching units: $e');
      rethrow;
    }
  }

  /// Stream units for a property in real-time
  Stream<List<UnitModel>> streamUnitsForProperty(String propertyId) {
    print('🔵 DataSource: Streaming units for property: $propertyId');

    return _unitsCollection(propertyId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
          print('✅ DataSource: Received ${snapshot.docs.length} units');
          return snapshot.docs
              .map((doc) => UnitModel.fromFirestore(doc, propertyId))
              .toList();
        })
        .handleError((error) {
          print('❌ DataSource: Stream error: $error');
          throw error;
        });
  }

  /// Create a new unit
  Future<String> createUnit(UnitModel unit) async {
    print('🔵 DataSource: Creating unit: ${unit.label}');

    try {
      final docRef = await _unitsCollection(unit.propertyId).add(unit.toFirestore());

      print('✅ DataSource: Unit created with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ DataSource: Error creating unit: $e');
      rethrow;
    }
  }

  /// Update an existing unit
  Future<void> updateUnit(UnitModel unit) async {
    print('🔵 DataSource: Updating unit: ${unit.id}');

    try {
      await _unitsCollection(unit.propertyId)
          .doc(unit.id)
          .update(unit.toFirestore());

      print('✅ DataSource: Unit updated: ${unit.id}');
    } catch (e) {
      print('❌ DataSource: Error updating unit: $e');
      rethrow;
    }
  }

  /// Delete a unit
  Future<void> deleteUnit(String propertyId, String unitId) async {
    print('🔵 DataSource: Deleting unit: $unitId');

    try {
      await _unitsCollection(propertyId).doc(unitId).delete();

      print('✅ DataSource: Unit deleted: $unitId');
    } catch (e) {
      print('❌ DataSource: Error deleting unit: $e');
      rethrow;
    }
  }
}
```

- [ ] **Step 3: Verify with flutter analyze**

Run: `cd residex_app && flutter analyze lib/features/landlord/data/models/unit_model.dart lib/features/landlord/data/datasources/unit_remote_datasource.dart`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add residex_app/lib/features/landlord/data/models/unit_model.dart residex_app/lib/features/landlord/data/datasources/unit_remote_datasource.dart
git commit -m "feat: add UnitModel and UnitRemoteDataSource for Firestore units subcollection"
```

---

### Task 3: `UnitRepository` + `UnitRepositoryImpl` + usecases

**Files:**
- Create: `residex_app/lib/features/landlord/domain/repositories/unit_repository.dart`
- Create: `residex_app/lib/features/landlord/data/repositories/unit_repository_impl.dart`
- Create: `residex_app/lib/features/landlord/domain/usecases/get_units_for_property.dart`
- Create: `residex_app/lib/features/landlord/domain/usecases/create_unit.dart`
- Create: `residex_app/lib/features/landlord/domain/usecases/update_unit.dart`
- Create: `residex_app/lib/features/landlord/domain/usecases/delete_unit.dart`

**Interfaces:**
- Consumes: `Unit` (Task 1), `UnitModel`/`UnitRemoteDataSource` (Task 2).
- Produces: `UnitRepository` abstract interface, `UnitRepositoryImpl`, `GetUnitsForProperty`, `CreateUnit`, `UpdateUnit`, `DeleteUnit` usecases — consumed by Task 4's providers.

- [ ] **Step 1: Create the `UnitRepository` interface**

Create `residex_app/lib/features/landlord/domain/repositories/unit_repository.dart`:

```dart
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
```

- [ ] **Step 2: Create `UnitRepositoryImpl`**

Create `residex_app/lib/features/landlord/data/repositories/unit_repository_impl.dart`, mirroring `property_repository_impl.dart`'s exact pattern:

```dart
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
}
```

- [ ] **Step 3: Create the four unit usecases**

Create `residex_app/lib/features/landlord/domain/usecases/get_units_for_property.dart`:

```dart
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
```

Create `residex_app/lib/features/landlord/domain/usecases/create_unit.dart`:

```dart
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
```

Create `residex_app/lib/features/landlord/domain/usecases/update_unit.dart`:

```dart
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
```

Create `residex_app/lib/features/landlord/domain/usecases/delete_unit.dart`:

```dart
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
```

- [ ] **Step 4: Verify with flutter analyze**

Run: `cd residex_app && flutter analyze lib/features/landlord/domain/repositories/unit_repository.dart lib/features/landlord/data/repositories/unit_repository_impl.dart lib/features/landlord/domain/usecases/get_units_for_property.dart lib/features/landlord/domain/usecases/create_unit.dart lib/features/landlord/domain/usecases/update_unit.dart lib/features/landlord/domain/usecases/delete_unit.dart`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add residex_app/lib/features/landlord/domain/repositories/unit_repository.dart \
        residex_app/lib/features/landlord/data/repositories/unit_repository_impl.dart \
        residex_app/lib/features/landlord/domain/usecases/get_units_for_property.dart \
        residex_app/lib/features/landlord/domain/usecases/create_unit.dart \
        residex_app/lib/features/landlord/domain/usecases/update_unit.dart \
        residex_app/lib/features/landlord/domain/usecases/delete_unit.dart
git commit -m "feat: add UnitRepository, UnitRepositoryImpl, and unit usecases"
```

---

### Task 4: Unit Riverpod providers

**Files:**
- Create: `residex_app/lib/features/landlord/presentation/providers/unit_providers.dart`

**Interfaces:**
- Consumes: `UnitRemoteDataSource` (Task 2), `UnitRepository`/`UnitRepositoryImpl` (Task 3), `GetUnitsForProperty`/`CreateUnit`/`UpdateUnit`/`DeleteUnit` (Task 3).
- Produces: `unitRepositoryProvider`, `unitsForPropertyStreamProvider(propertyId)` (family), `unitControllerProvider` (with `createUnit`/`updateUnit`/`deleteUnit` methods) — consumed by Task 6 (dialog), Task 7 (UnitsScreen), Task 8 (property_card.dart), Task 9 (portfolioStatsProvider rewrite).

- [ ] **Step 1: Create the unit providers file**

Create `residex_app/lib/features/landlord/presentation/providers/unit_providers.dart`, mirroring `property_providers.dart`'s layering exactly:

```dart
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
```

- [ ] **Step 2: Verify with flutter analyze**

Run: `cd residex_app && flutter analyze lib/features/landlord/presentation/providers/unit_providers.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add residex_app/lib/features/landlord/presentation/providers/unit_providers.dart
git commit -m "feat: add unit Riverpod providers and controller"
```

---

### Task 5: Strip rent/unit-count fields from `Property` entity, model, repository, and usecases

**Files:**
- Modify: `residex_app/lib/features/landlord/domain/entities/property.dart`
- Modify: `residex_app/lib/features/landlord/data/models/property_model.dart`
- Modify: `residex_app/lib/features/landlord/domain/repositories/property_repository.dart`
- Modify: `residex_app/lib/features/landlord/data/repositories/property_repository_impl.dart`
- Modify: `residex_app/lib/features/landlord/domain/usecases/create_property.dart`
- Modify: `residex_app/lib/features/landlord/domain/usecases/update_property.dart`

**Interfaces:**
- Produces: `Property` with `totalUnits`/`occupiedUnits`/`monthlyRent` and all dependent getters removed — this is a breaking change that Tasks 6, 8, 9 depend on and must land in the same session (nothing else compiles against the old `Property` shape once this task lands, so subsequent tasks are mandatory follow-ups, not optional).

- [ ] **Step 1: Remove fields and dependent getters from `Property`**

In `residex_app/lib/features/landlord/domain/entities/property.dart`, remove `totalUnits`, `occupiedUnits`, `monthlyRent` from the field list (lines 93-95), the constructor's required params (lines 108-110), and the six dependent getters (`occupancyRate` lines 119-122, `vacantUnits` line 125, `isFullyOccupied` line 128, `hasVacancy` line 131, `potentialRevenue` line 133, `actualRevenue` line 135). Remove the same three params from `copyWith` (lines 161-163, 176-178).

The full resulting file:

```dart
// lib/features/landlord/domain/entities/property.dart

/// Property type classification
enum PropertyType {
  apartment,
  house,
  condo,
  commercial;

  String toJson() => name;

  static PropertyType fromJson(String json) {
    return PropertyType.values.firstWhere(
      (type) => type.name == json,
      orElse: () => PropertyType.apartment,
    );
  }

  String get displayName {
    switch (this) {
      case PropertyType.apartment:
        return 'Apartment';
      case PropertyType.house:
        return 'House';
      case PropertyType.condo:
        return 'Condo';
      case PropertyType.commercial:
        return 'Commercial';
    }
  }
}

/// Address value object
class PropertyAddress {
  final String street;
  final String city;
  final String state;
  final String zipCode;
  final String country;

  const PropertyAddress({
    required this.street,
    required this.city,
    required this.state,
    required this.zipCode,
    required this.country,
  });

  String get fullAddress => '$street, $city, $state $zipCode, $country';

  PropertyAddress copyWith({
    String? street,
    String? city,
    String? state,
    String? zipCode,
    String? country,
  }) {
    return PropertyAddress(
      street: street ?? this.street,
      city: city ?? this.city,
      state: state ?? this.state,
      zipCode: zipCode ?? this.zipCode,
      country: country ?? this.country,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PropertyAddress &&
          street == other.street &&
          city == other.city &&
          state == other.state &&
          zipCode == other.zipCode &&
          country == other.country;

  @override
  int get hashCode => Object.hash(street, city, state, zipCode, country);
}

/// Pure business object - Property entity
///
/// Represents a real estate property with rental potential. Per-unit rent
/// and occupancy live on the Unit entity (properties/{id}/units subcollection),
/// not here — Property no longer tracks aggregate unit counts or rent.
/// Matches Firebase schema: properties/{propertyId}
class Property {
  final String id;
  final String landlordId;
  final String name;
  final PropertyAddress address;
  final PropertyType type;
  final double purchasePrice;
  final double currentValue;
  final List<String> photos;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Property({
    required this.id,
    required this.landlordId,
    required this.name,
    required this.address,
    required this.type,
    required this.purchasePrice,
    required this.currentValue,
    this.photos = const [],
    required this.createdAt,
    this.updatedAt,
  });

  /// Calculate property appreciation
  double get appreciation => currentValue - purchasePrice;

  /// Calculate appreciation percentage
  double get appreciationPercentage {
    if (purchasePrice == 0) return 0;
    return ((currentValue - purchasePrice) / purchasePrice) * 100;
  }

  /// Calculate return on investment (simplified, actual ROI needs rental income data)
  double get roi {
    if (purchasePrice == 0) return 0;
    return (appreciation / purchasePrice) * 100;
  }

  /// Copy with method for immutability
  Property copyWith({
    String? id,
    String? landlordId,
    String? name,
    PropertyAddress? address,
    PropertyType? type,
    double? purchasePrice,
    double? currentValue,
    List<String>? photos,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Property(
      id: id ?? this.id,
      landlordId: landlordId ?? this.landlordId,
      name: name ?? this.name,
      address: address ?? this.address,
      type: type ?? this.type,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      currentValue: currentValue ?? this.currentValue,
      photos: photos ?? this.photos,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Property &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
```

- [ ] **Step 2: Update `PropertyModel`**

In `residex_app/lib/features/landlord/data/models/property_model.dart`, remove `totalUnits`, `occupiedUnits`, `monthlyRent` from the constructor (lines 17-19), `fromEntity` (lines 35-37), `toEntity` (lines 54-56), `fromJson` (lines 82-84), and `toJson` (lines 111-113). Full resulting file:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/property.dart';

/// Data Transfer Object for Property
///
/// Extends Property entity and adds serialization logic
/// for Firestore database operations
class PropertyModel extends Property {
  PropertyModel({
    required super.id,
    required super.landlordId,
    required super.name,
    required super.address,
    required super.type,
    required super.purchasePrice,
    required super.currentValue,
    super.photos,
    required super.createdAt,
    super.updatedAt,
  });

  /// Create PropertyModel from domain entity
  factory PropertyModel.fromEntity(Property property) {
    return PropertyModel(
      id: property.id,
      landlordId: property.landlordId,
      name: property.name,
      address: property.address,
      type: property.type,
      purchasePrice: property.purchasePrice,
      currentValue: property.currentValue,
      photos: property.photos,
      createdAt: property.createdAt,
      updatedAt: property.updatedAt,
    );
  }

  /// Convert to domain entity
  Property toEntity() {
    return Property(
      id: id,
      landlordId: landlordId,
      name: name,
      address: address,
      type: type,
      purchasePrice: purchasePrice,
      currentValue: currentValue,
      photos: photos,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Create PropertyModel from JSON (null-safe parsing)
  factory PropertyModel.fromJson(Map<String, dynamic> json, String id) {
    final addressData = json['address'] as Map<String, dynamic>;

    return PropertyModel(
      id: id,
      landlordId: json['landlordId'] as String,
      name: json['name'] as String,
      address: PropertyAddress(
        street: addressData['street'] as String,
        city: addressData['city'] as String,
        state: addressData['state'] as String,
        zipCode: addressData['zipCode'] as String,
        country: addressData['country'] as String? ?? 'Malaysia',
      ),
      type: PropertyType.fromJson(json['type'] as String),
      purchasePrice: _parseDouble(json['purchasePrice']),
      currentValue: _parseDouble(json['currentValue']),
      photos: (json['photos'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      createdAt: _parseTimestamp(json['createdAt']),
      updatedAt: json['updatedAt'] != null
          ? _parseTimestamp(json['updatedAt'])
          : null,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'landlordId': landlordId,
      'name': name,
      'address': {
        'street': address.street,
        'city': address.city,
        'state': address.state,
        'zipCode': address.zipCode,
        'country': address.country,
      },
      'type': type.toJson(),
      'purchasePrice': purchasePrice,
      'currentValue': currentValue,
      'photos': photos,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// Create PropertyModel from Firestore document
  factory PropertyModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PropertyModel.fromJson(data, doc.id);
  }

  /// Convert to Firestore document data
  Map<String, dynamic> toFirestore() {
    return toJson();
  }

  // ========== HELPER METHODS FOR SAFE PARSING ==========

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
```

Note: `_parseInt` is removed since nothing in this file parses an int field anymore (`totalUnits`/`occupiedUnits` were its only callers).

- [ ] **Step 3: Remove the 5 statistics methods from `PropertyRepository` and its impl**

In `residex_app/lib/features/landlord/domain/repositories/property_repository.dart`, delete the `// ========== STATISTICS METHODS (NEW) ==========` block and all 5 method signatures (`getTotalUnits`, `getTotalOccupiedUnits`, `getOccupancyRate`, `getTotalPotentialRevenue`, `getTotalActualRevenue`). These were never called by any usecase/provider/UI outside the impl file itself, and depend entirely on the now-removed `Property` fields/getters — there is nothing to preserve. Resulting file:

```dart
import '../entities/property.dart';

/// Abstract property repository - defines property data operations
abstract class PropertyRepository {
  /// Get all properties by landlord ID
  Future<List<Property>> getPropertiesByLandlord(String landlordId);

  /// Stream properties in real-time
  Stream<List<Property>> streamPropertiesByLandlord(String landlordId);

  /// Get a single property by ID
  Future<Property?> getPropertyById(String propertyId);

  /// Create a new property
  Future<String> createProperty(Property property);

  /// Update an existing property
  Future<void> updateProperty(Property property);

  /// Delete a property
  Future<void> deleteProperty(String propertyId);

  /// Search properties by name or address
  Future<List<Property>> searchProperties(String landlordId, String query);
}
```

In `residex_app/lib/features/landlord/data/repositories/property_repository_impl.dart`, delete the entire `// ========== STATISTICS METHODS ==========` block (lines 96-185, the last 5 `@override` methods). The file ends after the `searchProperties` method (previously line 94's closing brace becomes the new second-to-last line before the class's closing `}`).

- [ ] **Step 4: Remove rent/unit-count validation from `CreateProperty` and `UpdateProperty`**

In `residex_app/lib/features/landlord/domain/usecases/create_property.dart`, remove the `print('🔵 Property: ...')` debug line referencing `monthlyRent` (line 19) and all 4 unit/rent validation blocks (lines 26-40: `totalUnits < 0`, `occupiedUnits < 0`, `occupiedUnits > totalUnits`, `monthlyRent <= 0`). Resulting file:

```dart
import '../entities/property.dart';
import '../repositories/property_repository.dart';

/// Use case for creating a new property
///
/// Validates property data and delegates to repository
class CreateProperty {
  final PropertyRepository _repository;

  CreateProperty(this._repository);

  /// Create a new property
  ///
  /// Returns the created property ID
  /// Throws if validation fails or creation fails
  Future<String> call(Property property) async {
    print('🔵 UseCase: CreateProperty called');
    print('🔵 Property: ${property.name}');

    // Business validation
    if (property.name.trim().isEmpty) {
      throw Exception('Property name cannot be empty');
    }

    if (property.purchasePrice < 0) {
      throw Exception('Purchase price must be >= 0');
    }

    if (property.currentValue < 0) {
      throw Exception('Current value must be >= 0');
    }

    try {
      // Update timestamps
      final propertyToCreate = property.copyWith(
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final propertyId = await _repository.createProperty(propertyToCreate);

      print('✅ UseCase: Property created successfully: $propertyId');
      return propertyId;
    } catch (e) {
      print('❌ UseCase: Failed to create property: $e');
      rethrow;
    }
  }
}
```

In `residex_app/lib/features/landlord/domain/usecases/update_property.dart`, remove the 3 unit-count validation blocks (lines 25-35: `totalUnits < 0`, `occupiedUnits < 0`, `occupiedUnits > totalUnits`). Resulting file:

```dart
import '../entities/property.dart';
import '../repositories/property_repository.dart';

/// Use case for updating an existing property
class UpdateProperty {
  final PropertyRepository _repository;

  UpdateProperty(this._repository);

  /// Update a property
  ///
  /// Validates updated data and updates timestamp
  Future<void> call(Property property) async {
    print('🔵 UseCase: Updating property: ${property.id}');

    // Business validation
    if (property.id.trim().isEmpty) {
      throw Exception('Property ID cannot be empty');
    }

    if (property.name.trim().isEmpty) {
      throw Exception('Property name cannot be empty');
    }

    if (property.currentValue < 0) {
      throw Exception('Current value must be >= 0');
    }

    try {
      // Update timestamp
      final propertyToUpdate = property.copyWith(
        updatedAt: DateTime.now(),
      );

      await _repository.updateProperty(propertyToUpdate);

      print('✅ UseCase: Property updated successfully: ${property.id}');
    } catch (e) {
      print('❌ UseCase: Failed to update property: $e');
      rethrow;
    }
  }
}
```

- [ ] **Step 5: Confirm compile errors surface in the expected downstream files (do not fix yet)**

Run: `cd residex_app && flutter analyze lib/features/landlord/domain/entities/property.dart lib/features/landlord/data/models/property_model.dart lib/features/landlord/domain/repositories/property_repository.dart lib/features/landlord/data/repositories/property_repository_impl.dart lib/features/landlord/domain/usecases/create_property.dart lib/features/landlord/domain/usecases/update_property.dart`

Expected: these 6 files themselves report no errors (they're now internally consistent). Then run the full `flutter analyze` and confirm errors appear in exactly these 3 files, which Tasks 6, 8, 9 fix next: `add_property_dialog.dart` (references removed `Property` fields/params), `property_card.dart` (references removed `Property` getters/fields), `property_providers.dart` (`portfolioStatsProvider` and `filteredPropertiesProvider` reference removed getters). This confirms the blast radius is exactly as scoped — no other file is unexpectedly broken.

- [ ] **Step 6: Commit**

```bash
git add residex_app/lib/features/landlord/domain/entities/property.dart \
        residex_app/lib/features/landlord/data/models/property_model.dart \
        residex_app/lib/features/landlord/domain/repositories/property_repository.dart \
        residex_app/lib/features/landlord/data/repositories/property_repository_impl.dart \
        residex_app/lib/features/landlord/domain/usecases/create_property.dart \
        residex_app/lib/features/landlord/domain/usecases/update_property.dart
git commit -m "refactor: remove totalUnits/occupiedUnits/monthlyRent from Property (moved to Unit)"
```

This commit intentionally leaves the app in a non-compiling state (3 files still reference the removed fields) — Tasks 6, 8, 9 fix those next in this same session. This is a deliberate exception to "always commit working code," scoped to this one multi-file entity migration; do not stop here.

---

### Task 6: Update `add_property_dialog.dart` — drop rent/occupied-units fields, create units on save

**Files:**
- Modify: `residex_app/lib/features/landlord/presentation/widgets/common/add_property_dialog.dart`

**Interfaces:**
- Consumes: `Property` (Task 5, no rent/unit-count fields), `unitControllerProvider`/`CreateUnit` (Task 4), `Unit` entity (Task 1).
- Produces: dialog compiles again; on property creation, also creates N blank `Unit` documents.

- [ ] **Step 1: Remove `_monthlyRentController` and `_occupiedUnitsController`, rename "Total Units" field intent**

In `residex_app/lib/features/landlord/presentation/widgets/common/add_property_dialog.dart`:

Remove the controller declarations (former lines 35-36):
```dart
  final _occupiedUnitsController = TextEditingController();
  final _monthlyRentController = TextEditingController();
```

In `initState` (former lines 44-60), remove the 3 lines that read removed `Property` fields:
```dart
      _totalUnitsController.text = property.totalUnits.toString();
      _occupiedUnitsController.text = property.occupiedUnits.toString();
      _monthlyRentController.text = property.monthlyRent.toString();
```
`_totalUnitsController` is no longer populated from `property` in edit mode either — per the design, unit count is create-only, and edit mode disables/hides this field entirely (Step 3 below), so nothing pre-fills it.

In `dispose` (former lines 63-75), remove:
```dart
    _occupiedUnitsController.dispose();
    _monthlyRentController.dispose();
```

- [ ] **Step 2: Update `_handleSubmit` — remove rent/occupied-units from both `copyWith` and constructor calls, add unit-creation step**

Replace the edit-mode `copyWith` call (former lines 102-111):

```dart
      if (existing != null) {
        // Edit mode: preserve id/landlordId/createdAt/photos, update the rest.
        // Unit count/rent are not editable here — see UnitsScreen.
        final updatedProperty = existing.copyWith(
          name: _nameController.text.trim(),
          address: address,
          type: _selectedType,
          purchasePrice: double.parse(_purchasePriceController.text),
          currentValue: double.parse(_currentValueController.text),
        );
        await controller.updateProperty(updatedProperty);
      } else {
```

Replace the create-mode constructor call and add the unit-creation step (former lines 114-129):

```dart
        final property = Property(
          id: '', // Will be generated by Firestore
          landlordId: user.uid,
          name: _nameController.text.trim(),
          address: address,
          type: _selectedType,
          purchasePrice: double.parse(_purchasePriceController.text),
          currentValue: double.parse(_currentValueController.text),
          photos: [],
          createdAt: DateTime.now(),
        );
        final propertyId = await controller.createProperty(property);

        final unitCount = int.parse(_totalUnitsController.text);
        final unitController = ref.read(unitControllerProvider);
        for (var i = 1; i <= unitCount; i++) {
          await unitController.createUnit(Unit(
            id: '',
            propertyId: propertyId,
            label: 'Unit $i',
            monthlyRent: 0,
            isOccupied: false,
            createdAt: DateTime.now(),
          ));
        }
      }
```

Add the import at the top of the file, alongside the existing `property_providers.dart` import:

```dart
import '../../providers/unit_providers.dart';
import '../../../domain/entities/unit.dart';
```

- [ ] **Step 3: Remove the "Monthly Rent" field, remove "Occupied Units" field, rename "Total Units" label, disable it in edit mode**

Replace the "Financial Details" section's rent field block (former lines 313-321 — the `_buildTextField` for `_monthlyRentController` and its preceding `SizedBox`) — simply delete that block entirely, so the "Financial Details" section ends right after the Purchase Price/Current Value `Row` (former lines 290-312).

Replace the "Unit Information" section (former lines 324-364):

```dart
                      Text(
                        'Unit Information',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _totalUnitsController,
                        label: 'Number of Units',
                        hint: '10',
                        keyboardType: TextInputType.number,
                        enabled: !_isEditMode,
                        validator: _validatePositiveInt,
                      ),
                      if (_isEditMode) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Manage individual units from the property card.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
```

`_buildTextField` needs an `enabled` parameter to support this — update its signature and body (former lines 424-465):

```dart
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    TextInputType? keyboardType,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
        floatingLabelStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.registry),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        isDense: true,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, color: AppColors.registry, size: 20) : null,
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.registry, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.error),
        ),
      ),
      validator: validator,
    );
  }
```

(Every other `_buildTextField(...)` call site in this file is unaffected — `enabled` defaults to `true`, matching current behavior.)

For create mode, since `_totalUnitsController` is never pre-filled with a value in `initState` (it was previously only filled in edit mode), give it a sensible starting hint of `'1'` (already the case via the `hint: '10'` parameter, which is just placeholder text, not a pre-filled value — no change needed there beyond what's shown above).

- [ ] **Step 4: Verify with flutter analyze**

Run: `cd residex_app && flutter analyze lib/features/landlord/presentation/widgets/common/add_property_dialog.dart`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add residex_app/lib/features/landlord/presentation/widgets/common/add_property_dialog.dart
git commit -m "refactor: drop rent/occupied-units fields from property dialog, create units on save"
```

---

### Task 7: `UnitsScreen`

**Files:**
- Create: `residex_app/lib/features/landlord/presentation/screens/4-Portfolio/units_screen.dart`

**Interfaces:**
- Consumes: `unitsForPropertyStreamProvider` (Task 4), `unitControllerProvider` (Task 4), `Unit` entity (Task 1).
- Produces: `UnitsScreen(propertyId, propertyName)` widget — consumed by Task 8 (`property_card.dart`'s `onTap` wiring).

- [ ] **Step 1: Create `UnitsScreen`**

Create `residex_app/lib/features/landlord/presentation/screens/4-Portfolio/units_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../domain/entities/unit.dart';
import '../../providers/unit_providers.dart';

/// Lists and manages the individual units within a property: each unit's
/// label, monthly rent, and occupied/vacant status.
class UnitsScreen extends ConsumerWidget {
  final String propertyId;
  final String propertyName;

  const UnitsScreen({
    super.key,
    required this.propertyId,
    required this.propertyName,
  });

  Future<void> _addUnit(BuildContext context, WidgetRef ref, int currentCount) async {
    final controller = ref.read(unitControllerProvider);
    try {
      await controller.createUnit(Unit(
        id: '',
        propertyId: propertyId,
        label: 'Unit ${currentCount + 1}',
        monthlyRent: 0,
        isOccupied: false,
        createdAt: DateTime.now(),
      ));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add unit: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _confirmDeleteUnit(BuildContext context, WidgetRef ref, Unit unit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
            const SizedBox(width: 12),
            Text('Delete Unit', style: AppTextStyles.titleMedium),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete this unit?', style: AppTextStyles.bodyMedium),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                '${unit.label} · RM ${unit.monthlyRent.toStringAsFixed(0)}/mo',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This action cannot be undone.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: AppTextStyles.labelLarge.copyWith(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Delete', style: AppTextStyles.labelLarge.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final controller = ref.read(unitControllerProvider);
      try {
        await controller.deleteUnit(propertyId, unit.id);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete unit: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  Future<void> _editUnit(BuildContext context, WidgetRef ref, Unit unit) async {
    final labelController = TextEditingController(text: unit.label);
    final rentController = TextEditingController(text: unit.monthlyRent.toString());
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Edit Unit', style: AppTextStyles.titleMedium),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: labelController,
                decoration: const InputDecoration(labelText: 'Label'),
                validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: rentController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Monthly Rent'),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final parsed = double.tryParse(v);
                  if (parsed == null) return 'Must be a number';
                  if (parsed < 0) return 'Must be positive';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: AppTextStyles.labelLarge.copyWith(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.registry),
            child: Text('Save', style: AppTextStyles.labelLarge.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );

    if (saved == true) {
      final controller = ref.read(unitControllerProvider);
      try {
        await controller.updateUnit(unit.copyWith(
          label: labelController.text.trim(),
          monthlyRent: double.parse(rentController.text),
        ));
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update unit: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  Future<void> _toggleOccupied(WidgetRef ref, Unit unit) async {
    final controller = ref.read(unitControllerProvider);
    await controller.updateUnit(unit.copyWith(isOccupied: !unit.isOccupied));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsAsync = ref.watch(unitsForPropertyStreamProvider(propertyId));

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text(propertyName, style: AppTextStyles.titleMedium),
        backgroundColor: AppColors.paper,
      ),
      body: unitsAsync.when(
        data: (units) {
          return Column(
            children: [
              Expanded(
                child: units.isEmpty
                    ? Center(
                        child: Text(
                          'No units yet.',
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: units.length,
                        itemBuilder: (context, index) {
                          final unit = units[index];
                          return Card(
                            color: AppColors.card,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: AppColors.hairline),
                            ),
                            child: ListTile(
                              title: Text(unit.label, style: AppTextStyles.bodyLarge),
                              subtitle: Text(
                                'RM ${unit.monthlyRent.toStringAsFixed(0)}/mo',
                                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                              ),
                              onTap: () => _editUnit(context, ref, unit),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Switch(
                                    value: unit.isOccupied,
                                    activeColor: AppColors.registry,
                                    onChanged: (_) => _toggleOccupied(ref, unit),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline, color: AppColors.error),
                                    onPressed: () => _confirmDeleteUnit(context, ref, unit),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: () => _addUnit(context, ref, units.length),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Unit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.registry,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.registry)),
        error: (error, stack) => Center(
          child: Text('Failed to load units: $error', style: AppTextStyles.bodyMedium),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify with flutter analyze**

Run: `cd residex_app && flutter analyze lib/features/landlord/presentation/screens/4-Portfolio/units_screen.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add residex_app/lib/features/landlord/presentation/screens/4-Portfolio/units_screen.dart
git commit -m "feat: add UnitsScreen for per-unit label/rent/occupancy editing"
```

---

### Task 8: Update `property_card.dart` — wire `onTap` to `UnitsScreen`, replace removed-field reads

**Files:**
- Modify: `residex_app/lib/features/landlord/presentation/widgets/common/property_card.dart`
- Modify: `residex_app/lib/features/landlord/presentation/screens/4-Portfolio/landlord_portfolio_screen.dart`

**Interfaces:**
- Consumes: `unitsForPropertyStreamProvider` (Task 4), `UnitsScreen` (Task 7).
- Produces: `property_card.dart` compiles again and shows real unit-derived occupancy; tapping a card opens `UnitsScreen`.

- [ ] **Step 1: Convert `PropertyCard` to a `ConsumerWidget` and replace removed-field reads with a computed value from `Unit` records**

`property_card.dart` currently reads `property.isFullyOccupied`, `property.hasVacancy`, `property.occupancyRate`, `property.occupiedUnits`, `property.totalUnits` — all removed from `Property`. Replace with a `unitsForPropertyStreamProvider(property.id)` watch and compute the equivalent values locally. Full resulting file:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/theme/app_dimensions.dart';
import '../../../domain/entities/property.dart';
import '../../providers/unit_providers.dart';

/// Property card for portfolio screen
///
/// Displays:
/// - Property name and address
/// - Property type
/// - Occupancy rate and unit counts (derived from the property's units)
/// - Current value
class PropertyCard extends ConsumerWidget {
  final Property property;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  const PropertyCard({
    super.key,
    required this.property,
    this.onTap,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsAsync = ref.watch(unitsForPropertyStreamProvider(property.id));
    final totalUnits = unitsAsync.valueOrNull?.length ?? 0;
    final occupiedUnits = unitsAsync.valueOrNull?.where((u) => u.isOccupied).length ?? 0;
    final occupancyRate = totalUnits > 0 ? (occupiedUnits / totalUnits) * 100 : 0.0;
    final isFullyOccupied = totalUnits > 0 && occupiedUnits == totalUnits;
    final hasVacancy = occupiedUnits < totalUnits;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.hairline),
          boxShadow: AppShadows.cardShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: Icon, name, and occupancy badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Property icon
                      Container(
                        height: 48,
                        width: 48,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.hairline),
                        ),
                        child: Icon(
                          _getPropertyIcon(property.type),
                          size: 20,
                          color: AppColors.registry,
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Property info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              property.name,
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${property.address.city}, ${property.address.state}',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Occupancy badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isFullyOccupied
                              ? AppColors.success.withOpacity(0.1)
                              : hasVacancy
                                  ? AppColors.warning.withOpacity(0.1)
                                  : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isFullyOccupied
                                ? AppColors.success.withOpacity(0.2)
                                : hasVacancy
                                    ? AppColors.warning.withOpacity(0.2)
                                    : AppColors.hairline,
                          ),
                        ),
                        child: Text(
                          '${occupancyRate.toStringAsFixed(0)}%',
                          style: AppTextStyles.label.copyWith(
                            fontSize: 10,
                            color: isFullyOccupied
                                ? AppColors.success
                                : hasVacancy
                                    ? AppColors.warning
                                    : AppColors.textMuted,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),

                      if (onEdit != null) ...[
                        const SizedBox(width: 8),
                        // Edit property affordance
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onEdit,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.edit_outlined,
                                size: 18,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Property details
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.only(top: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: AppColors.hairline),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Units info
                        _buildInfoChip(
                          icon: Icons.home_work_outlined,
                          label: '$occupiedUnits/$totalUnits Units',
                          color: AppColors.primary,
                        ),

                        // Property type
                        _buildInfoChip(
                          icon: Icons.category_outlined,
                          label: property.type.displayName,
                          color: AppColors.cyan400,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: color.withOpacity(0.7),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  IconData _getPropertyIcon(PropertyType type) {
    switch (type) {
      case PropertyType.apartment:
        return Icons.apartment;
      case PropertyType.house:
        return Icons.house_outlined;
      case PropertyType.condo:
        return Icons.domain;
      case PropertyType.commercial:
        return Icons.business;
    }
  }
}
```

Note: `PropertyCard extends StatelessWidget` becomes `extends ConsumerWidget` (from `flutter_riverpod`), and `build(BuildContext context)` becomes `build(BuildContext context, WidgetRef ref)` — this is the only structural change beyond the removed-field replacements. `unitsAsync.valueOrNull` degrades gracefully to `0`/`0` while the stream is loading or if it errors, so the card never crashes — it just briefly shows `0/0 Units` and `0%` until the stream delivers data (consistent with how this card has no existing loading-state UI today).

- [ ] **Step 2: Wire `onTap` in `landlord_portfolio_screen.dart` to push `UnitsScreen`**

In `residex_app/lib/features/landlord/presentation/screens/4-Portfolio/landlord_portfolio_screen.dart`, add the import:

```dart
import 'units_screen.dart';
```

Update the single `PropertyCard` construction site (former lines 243-247):

```dart
                              child: PropertyCard(
                                key: ValueKey('property_${properties[index].id}'),
                                property: properties[index],
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => UnitsScreen(
                                      propertyId: properties[index].id,
                                      propertyName: properties[index].name,
                                    ),
                                  ),
                                ),
                                onEdit: () => _showEditPropertyDialog(properties[index]),
                              ),
```

- [ ] **Step 3: Verify with flutter analyze**

Run: `cd residex_app && flutter analyze lib/features/landlord/presentation/widgets/common/property_card.dart lib/features/landlord/presentation/screens/4-Portfolio/landlord_portfolio_screen.dart`
Expected: No errors (this file still has the `portfolioStatsProvider`/`filteredPropertiesProvider` compile errors from Task 5's blast radius, fixed in Task 9 — expect those specific errors to remain until Task 9 lands).

- [ ] **Step 4: Commit**

```bash
git add residex_app/lib/features/landlord/presentation/widgets/common/property_card.dart \
        residex_app/lib/features/landlord/presentation/screens/4-Portfolio/landlord_portfolio_screen.dart
git commit -m "feat: derive occupancy from Unit records in PropertyCard, wire tap to UnitsScreen"
```

---

### Task 9: Rewrite `portfolioStatsProvider` as async, fix `filteredPropertiesProvider`, update call sites

**Files:**
- Modify: `residex_app/lib/features/landlord/presentation/providers/property_providers.dart`
- Modify: `residex_app/lib/features/landlord/presentation/screens/4-Portfolio/landlord_portfolio_screen.dart`
- Modify: `residex_app/lib/features/landlord/presentation/screens/1-Dashboard/landlord_dashboard_screen.dart`

**Interfaces:**
- Consumes: `unitsForPropertyProvider` (Task 4).
- Produces: `portfolioStatsProvider` as `FutureProvider<PortfolioStats>` (was `Provider<PortfolioStats>`); `filteredPropertiesProvider`'s occupancy filter cases work against real unit data.

- [ ] **Step 1: Rewrite `portfolioStatsProvider` and `filteredPropertiesProvider` in `property_providers.dart`**

In `residex_app/lib/features/landlord/presentation/providers/property_providers.dart`, add the import:

```dart
import 'unit_providers.dart';
```

Replace `filteredPropertiesProvider` (former lines 126-142) — since `isFullyOccupied`/`hasVacancy` no longer exist on `Property`, and computing them per-property requires an async unit fetch, this provider becomes a `FutureProvider`:

```dart
/// Filtered properties based on current filter
final filteredPropertiesProvider = FutureProvider<List<Property>>((ref) async {
  final propertiesAsync = ref.watch(propertiesStreamProvider);
  final filter = ref.watch(propertyFilterProvider);

  final properties = propertiesAsync.valueOrNull ?? [];

  if (filter == PropertyFilter.all) {
    return properties;
  }

  final filtered = <Property>[];
  for (final property in properties) {
    final units = await ref.watch(unitsForPropertyProvider(property.id).future);
    final totalUnits = units.length;
    final occupiedUnits = units.where((u) => u.isOccupied).length;
    final isFullyOccupied = totalUnits > 0 && occupiedUnits == totalUnits;
    final hasVacancy = occupiedUnits < totalUnits;

    if (filter == PropertyFilter.fullyOccupied && isFullyOccupied) {
      filtered.add(property);
    } else if (filter == PropertyFilter.hasVacancy && hasVacancy) {
      filtered.add(property);
    }
  }
  return filtered;
});
```

Replace `portfolioStatsProvider` (former lines 149-224) with an async version that fans out one unit-fetch per property:

```dart
/// Portfolio statistics provider (calculated from properties' units)
final portfolioStatsProvider = FutureProvider<PortfolioStats>((ref) async {
  final propertiesAsync = ref.watch(propertiesStreamProvider);
  final properties = propertiesAsync.valueOrNull ?? [];

  if (properties.isEmpty) {
    return PortfolioStats(
      totalProperties: 0,
      totalUnits: 0,
      occupiedUnits: 0,
      vacantUnits: 0,
      averageOccupancyRate: 0.0,
      fullyOccupiedProperties: 0,
      vacantProperties: 0,
      totalRevenue: 0.0,
    );
  }

  var totalUnits = 0;
  var occupiedUnits = 0;
  var fullyOccupiedCount = 0;
  var vacantCount = 0;
  var totalRevenue = 0.0;

  for (final property in properties) {
    final units = await ref.watch(unitsForPropertyProvider(property.id).future);
    final propertyTotalUnits = units.length;
    final propertyOccupiedUnits = units.where((u) => u.isOccupied).length;

    totalUnits += propertyTotalUnits;
    occupiedUnits += propertyOccupiedUnits;

    if (propertyTotalUnits > 0 && propertyOccupiedUnits == propertyTotalUnits) {
      fullyOccupiedCount++;
    }
    if (propertyOccupiedUnits < propertyTotalUnits) {
      vacantCount++;
    }

    totalRevenue += units
        .where((u) => u.isOccupied)
        .fold<double>(0.0, (sum, u) => sum + u.monthlyRent);
  }

  final vacantUnits = totalUnits - occupiedUnits;
  final averageOccupancyRate = totalUnits > 0 ? (occupiedUnits / totalUnits) * 100 : 0.0;

  return PortfolioStats(
    totalProperties: properties.length,
    totalUnits: totalUnits,
    occupiedUnits: occupiedUnits,
    vacantUnits: vacantUnits,
    averageOccupancyRate: averageOccupancyRate,
    fullyOccupiedProperties: fullyOccupiedCount,
    vacantProperties: vacantCount,
    totalRevenue: totalRevenue,
  );
});
```

`PortfolioStats` (former lines 231-253) is unchanged — same fields, only how they're computed changes.

- [ ] **Step 2: Update `landlord_portfolio_screen.dart`'s 3 read sites to handle `AsyncValue`**

In `residex_app/lib/features/landlord/presentation/screens/4-Portfolio/landlord_portfolio_screen.dart`:

Replace the synchronous reads at the top of `build` (former lines 48-50):

```dart
  Widget build(BuildContext context) {
    final propertiesAsync = ref.watch(filteredPropertiesProvider);
    final portfolioStatsAsync = ref.watch(portfolioStatsProvider);
    final currentFilter = ref.watch(propertyFilterProvider);
```

The app-bar subtitle (former line 102) currently reads `portfolioStats.totalProperties`/`portfolioStats.averageOccupancyRate` directly inside a `LayoutBuilder` — wrap that text in `portfolioStatsAsync.when(...)`, falling back to a blank string while loading/erroring so the header never crashes:

```dart
                                if (showSubtitle) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    portfolioStatsAsync.maybeWhen(
                                      data: (stats) =>
                                          '${stats.totalProperties} PROPERTIES • ${stats.averageOccupancyRate.toStringAsFixed(0)}% OCCUPIED',
                                      orElse: () => '',
                                    ),
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: AppColors.textMuted,
                                      letterSpacing: 1.5,
                                      fontSize: 9,
                                      height: 1.0,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
```

The stats-cards `SliverToBoxAdapter` (former lines 123-128) currently passes `portfolioStats` (a plain `PortfolioStats`) to `_buildStatsCards`. Replace with a conditional render:

```dart
                // Portfolio stats cards
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: portfolioStatsAsync.when(
                      data: (stats) => _buildStatsCards(stats),
                      loading: () => const SizedBox(
                        height: 96,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ),
                ),
```

`_buildStatsCards`'s signature (former line 443, `Widget _buildStatsCards(PortfolioStats stats)`) is unchanged — it still takes a plain `PortfolioStats`, since the `.when()` already unwraps it before calling.

`propertiesAsync` (from `filteredPropertiesProvider`, now a `FutureProvider`) is used later in `build` via `propertiesAsync.when(data: ..., loading: ..., error: ...)` (former line 228) — a `FutureProvider`'s `AsyncValue` supports the identical `.when()` API as a `StreamProvider`'s, so this call site requires no changes at all.

- [ ] **Step 3: Update `landlord_dashboard_screen.dart`'s read site**

In `residex_app/lib/features/landlord/presentation/screens/1-Dashboard/landlord_dashboard_screen.dart`, `_buildContent` (lines 108-149) currently reads `stats` synchronously (line 113) and passes it to `_buildStatTileRow(stats)` (line 128) inside a single `return SingleChildScrollView(...)` expression (lines 116-148). `_buildStatTileRow` (lines 151-169) is a separate, already-existing method that takes a plain `PortfolioStats` — it needs no changes, since `portfolioStatsProvider`'s async-ness is resolved before this point once Step lines below are applied.

Replace lines 108-116 (the method signature through the `SingleChildScrollView` opening) — i.e. everything from `Widget _buildContent(...)` through `return SingleChildScrollView(`:

```dart
  Widget _buildContent(BuildContext context, WidgetRef ref, List<Property> properties) {
    if (properties.isEmpty) {
      return _buildEmptyState(context);
    }

    final statsAsync = ref.watch(portfolioStatsProvider);
    final visibleProperties = properties.take(3).toList();

    return statsAsync.when(
      data: (stats) => SingleChildScrollView(
```

Every line inside the original `SingleChildScrollView(...)` body (former lines 117-147: `padding:`, `child: Column(...)`, all the way to the closing `),` that matches `SingleChildScrollView(`) stays completely unchanged — `stats` and `visibleProperties` are still in scope and still plain (non-async) values inside this `data: (stats) => ...` closure.

Replace the method's closing (former lines 148-149, `);` then `}`) with:

```dart
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Failed to load portfolio stats')),
    );
  }
```

This is a minimal wrap — no new helper method is introduced, no other method in this file changes. `_buildStatTileRow`, `_buildStatTile`, `_buildDocumindEntryCard`, `_buildPropertyRow`, `_buildEmptyState` (lines 151-277) are all untouched.

- [ ] **Step 4: Verify with a full flutter analyze**

Run: `cd residex_app && flutter analyze`
Expected: 0 errors. Info-level issue count should be at the pre-existing baseline (260, per `HANDOFF.md`) plus/minus whatever this migration's new files contribute — confirm there are zero errors and zero new warnings specifically (info-level lints like `avoid_print`/`deprecated_member_use` are expected and pre-existing, not new).

- [ ] **Step 5: Commit**

```bash
git add residex_app/lib/features/landlord/presentation/providers/property_providers.dart \
        residex_app/lib/features/landlord/presentation/screens/4-Portfolio/landlord_portfolio_screen.dart \
        residex_app/lib/features/landlord/presentation/screens/1-Dashboard/landlord_dashboard_screen.dart
git commit -m "refactor: make portfolioStatsProvider async, derive occupancy filter from Unit records"
```

---

### Task 10: Manual verification

**Files:** none (verification only).

- [ ] **Step 1: Deploy the updated Firestore rules**

Run: `cd residex_app && firebase deploy --only firestore:rules` (or the project's existing rule-deploy process, if different — check for a `firebase.json`/deploy script first; if none exists, this may require deploying via the Firebase Console directly).

- [ ] **Step 2: Start the backend and run the app**

Per `HANDOFF.md` §6:
```powershell
cd backend
$env:PYTHONIOENCODING = "utf-8"
python main.py

$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-17.0.18.8-hotspot"
flutter emulators --launch documind_light
cd residex_app; flutter run
```

- [ ] **Step 3: Delete existing demo properties**

In the running app (or directly in the Firebase Console), delete all existing properties — they have no `units` subcollection and predate this migration (per this plan's Global Constraints, no backfill is provided).

- [ ] **Step 4: Create a new property with multiple units**

Use the "Add Property" dialog. Set "Number of Units" to 3. Confirm the dialog no longer shows a "Monthly Rent" or "Occupied Units" field. Save. Confirm the property appears in the portfolio list.

- [ ] **Step 5: Verify UnitsScreen**

Tap the new property's card. Confirm `UnitsScreen` opens showing 3 units, labeled "Unit 1"/"Unit 2"/"Unit 3", each at RM 0/mo, all vacant. Edit Unit 1's rent to 1500 and toggle it occupied. Confirm the change persists (navigate away and back). Add a 4th unit via "Add Unit". Delete the 4th unit via its delete icon, confirm the confirmation dialog appears and deletion works.

- [ ] **Step 6: Verify the edit-property dialog no longer edits units**

From the portfolio screen, tap the pencil icon on the property card (not the card itself). Confirm the edit dialog opens (name/address/type/purchase price/current value), and confirms "Number of Units" is present but disabled/non-editable, with no rent field.

- [ ] **Step 7: Verify portfolio stats and dashboard**

Confirm the portfolio screen's stats cards show correct total units (3) and occupancy (1/3 = 33%). Confirm the dashboard screen also shows updated stats without crashing (no loading spinner stuck, no error state).

- [ ] **Step 8: Verify the occupancy filter**

On the portfolio screen, expand the filter dropdown and select "Has Vacancy". Confirm the property with 2 vacant units still appears. Select "Fully Occupied" — confirm it does NOT appear (only 1/3 units occupied). Toggle the other 2 units to occupied via `UnitsScreen`, return to the portfolio screen, re-select "Fully Occupied" — confirm the property now appears.

No commit for this task (verification only, no code changes).

---

## Self-Review Notes

- **Spec coverage:** `Unit` entity (Task 1) ✅, Firestore rule (Task 1) ✅, `UnitRepository`/datasource/impl/usecases (Tasks 2-3) ✅, providers (Task 4) ✅, `Property` field removal (Task 5) ✅, dialog changes — unit-count-only create, no rent field, disabled unit-count in edit mode (Task 6) ✅, `UnitsScreen` (Task 7) ✅, `property_card.dart` onTap wiring + derived occupancy (Task 8) ✅, `portfolioStatsProvider`/`filteredPropertiesProvider` async rewrite + all 3 call sites (Task 9) ✅. All 3 additional gaps found during pre-planning research (Firestore rules, async stats provider blast radius, occupancy filter breakage) are explicitly resolved, not deferred.
- **Type consistency:** `Unit`'s fields (`id`, `propertyId`, `label`, `monthlyRent`, `isOccupied`, `createdAt`, `updatedAt`) are used identically across Tasks 1 (entity), 2 (model), 3 (repository/usecases), 4 (providers), 6 (dialog), 7 (UnitsScreen), 8 (property_card), 9 (stats provider) — no renaming drift. `UnitController.createUnit/updateUnit/deleteUnit` (Task 4) match the calls made in Tasks 6 and 7 exactly. `unitsForPropertyStreamProvider`/`unitsForPropertyProvider` (Task 4, family providers keyed by `propertyId` String) are referenced identically in Tasks 8 and 9.
- **No placeholders:** every step contains complete, runnable code; no "TODO"/"similar to Task N" shortcuts.
- **Task ordering/dependencies:** Tasks 1-4 build new Unit infrastructure with zero risk to existing code (nothing deletes yet). Task 5 is the breaking change — it intentionally leaves the app non-compiling, explicitly flagged, with Tasks 6/8/9 required immediately after (not optional follow-ups). Task 10 is verification-only.
