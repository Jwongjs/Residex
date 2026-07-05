import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/property_remote_datasource.dart';
import '../../data/repositories/property_repository_impl.dart';
import '../../domain/entities/property.dart';
import '../../domain/repositories/property_repository.dart';
import '../../domain/usecases/create_property.dart';
import '../../domain/usecases/delete_property.dart';
import '../../domain/usecases/get_properties.dart';
import '../../domain/usecases/get_property_by_id.dart';
import '../../domain/usecases/search_properties.dart';
import '../../domain/usecases/update_property.dart';
import '../../../shared/presentation/providers/auth_providers.dart';
import 'documind_provider.dart';
import 'unit_providers.dart';

// ============================================================
// DATA LAYER PROVIDERS
// ============================================================

/// Property remote data source provider
final propertyRemoteDataSourceProvider = Provider<PropertyRemoteDataSource>((ref) {
  return PropertyRemoteDataSource(
    firestore: FirebaseFirestore.instance,
  );
});

/// Property repository provider
final propertyRepositoryProvider = Provider<PropertyRepository>((ref) {
  final dataSource = ref.watch(propertyRemoteDataSourceProvider);
  return PropertyRepositoryImpl(remoteDataSource: dataSource);
});

// ============================================================
// USE CASE PROVIDERS
// ============================================================

final createPropertyUseCaseProvider = Provider<CreateProperty>((ref) {
  final repository = ref.watch(propertyRepositoryProvider);
  return CreateProperty(repository);
});

final getPropertiesUseCaseProvider = Provider<GetProperties>((ref) {
  final repository = ref.watch(propertyRepositoryProvider);
  return GetProperties(repository);
});

final getPropertyByIdUseCaseProvider = Provider<GetPropertyById>((ref) {
  final repository = ref.watch(propertyRepositoryProvider);
  return GetPropertyById(repository);
});

final updatePropertyUseCaseProvider = Provider<UpdateProperty>((ref) {
  final repository = ref.watch(propertyRepositoryProvider);
  return UpdateProperty(repository);
});

final deletePropertyUseCaseProvider = Provider<DeleteProperty>((ref) {
  final repository = ref.watch(propertyRepositoryProvider);
  return DeleteProperty(repository);
});

final searchPropertiesUseCaseProvider = Provider<SearchProperties>((ref) {
  final repository = ref.watch(propertyRepositoryProvider);
  return SearchProperties(repository);
});

// ============================================================
// PRESENTATION LAYER PROVIDERS
// ============================================================

/// Stream properties for current landlord (real-time updates)
final propertiesStreamProvider = StreamProvider<List<Property>>((ref) {
  final user = ref.watch(currentFirebaseUserProvider);
  
  if (user == null) {
    return Stream.value([]);
  }

  final getPropertiesUseCase = ref.watch(getPropertiesUseCaseProvider);
  return getPropertiesUseCase.stream(user.uid);
});

/// Get properties for current landlord (one-time fetch)
final propertiesProvider = FutureProvider<List<Property>>((ref) async {
  final user = ref.watch(currentFirebaseUserProvider);
  
  if (user == null) {
    return [];
  }

  final getPropertiesUseCase = ref.watch(getPropertiesUseCaseProvider);
  return getPropertiesUseCase(user.uid);
});

/// Get a specific property by ID
final propertyByIdProvider = FutureProvider.family<Property?, String>((ref, propertyId) async {
  final getPropertyByIdUseCase = ref.watch(getPropertyByIdUseCaseProvider);
  return getPropertyByIdUseCase(propertyId);
});

// ============================================================
// PROPERTY FILTERING
// ============================================================

/// Property filter enum
enum PropertyFilter {
  all,
  fullyOccupied,
  hasVacancy,
}

/// Notifier for current property filter state
class PropertyFilterNotifier extends Notifier<PropertyFilter> {
  @override
  PropertyFilter build() => PropertyFilter.all;

  void setFilter(PropertyFilter filter) => state = filter;
}

/// Current property filter state
final propertyFilterProvider =
    NotifierProvider<PropertyFilterNotifier, PropertyFilter>(
  PropertyFilterNotifier.new,
);

/// Filtered properties based on current filter
final filteredPropertiesProvider = FutureProvider<List<Property>>((ref) async {
  final propertiesAsync = ref.watch(propertiesStreamProvider);
  final filter = ref.watch(propertyFilterProvider);

  final properties = propertiesAsync.value ?? [];

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

// ============================================================
// PORTFOLIO STATISTICS
// ============================================================

/// Portfolio statistics provider (calculated from properties' units)
final portfolioStatsProvider = FutureProvider<PortfolioStats>((ref) async {
  final propertiesAsync = ref.watch(propertiesStreamProvider);
  final properties = propertiesAsync.value ?? [];

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

// ============================================================
// DATA MODELS
// ============================================================

/// Portfolio statistics model
class PortfolioStats {
  final int totalProperties;
  final int totalUnits;
  final int occupiedUnits;
  final int vacantUnits;
  final double averageOccupancyRate;
  final int fullyOccupiedProperties;
  final int vacantProperties;
  final double totalRevenue;

  PortfolioStats({
    required this.totalProperties,
    required this.totalUnits,
    required this.occupiedUnits,
    required this.vacantUnits,
    required this.averageOccupancyRate,
    required this.fullyOccupiedProperties,
    required this.vacantProperties,
    required this.totalRevenue,
  });

  double get occupancyRate => averageOccupancyRate; // Alias for backward compatibility
}

// ============================================================
// PROPERTY CONTROLLER (UI Actions)
// ============================================================

/// Property controller for UI actions
class PropertyController {
  final Ref _ref;

  PropertyController(this._ref);

  /// Create a new property
  Future<String> createProperty(Property property) async {
    try {
      final createUseCase = _ref.read(createPropertyUseCaseProvider);
      final propertyId = await createUseCase(property);
      
      // Refresh properties list
      _ref.invalidate(propertiesStreamProvider);
      
      return propertyId;
    } catch (e) {
      print('❌ Controller: Failed to create property: $e');
      rethrow;
    }
  }

  /// Update a property
  Future<void> updateProperty(Property property) async {
    try {
      final updateUseCase = _ref.read(updatePropertyUseCaseProvider);
      await updateUseCase(property);
      
      // Refresh properties list
      _ref.invalidate(propertiesStreamProvider);
      _ref.invalidate(propertyByIdProvider(property.id));
    } catch (e) {
      print('❌ Controller: Failed to update property: $e');
      rethrow;
    }
  }

  /// Delete a property and everything under it: Documind documents first
  /// (the backend cascade removes chunks + stored PDFs), then the units
  /// subcollection (Firestore never cascades subcollection deletes), then
  /// the property doc itself. Child-first order so a mid-cascade failure
  /// never strands unreachable data; every step is idempotent, so a retry
  /// simply resumes.
  Future<void> deleteProperty(String propertyId) async {
    try {
      final landlordId = _ref.read(currentLandlordIdProvider);
      await _ref.read(documindRepositoryProvider).deleteDocumentsForProperty(
            landlordId: landlordId,
            propertyId: propertyId,
          );

      await _ref
          .read(unitRepositoryProvider)
          .deleteAllUnitsForProperty(propertyId);

      final deleteUseCase = _ref.read(deletePropertyUseCaseProvider);
      await deleteUseCase(propertyId);

      // Refresh properties list
      _ref.invalidate(propertiesStreamProvider);
    } catch (e) {
      print('❌ Controller: Failed to delete property: $e');
      rethrow;
    }
  }

  /// Search properties
  Future<List<Property>> searchProperties(String query) async {
    try {
      final user = _ref.read(currentFirebaseUserProvider);
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final searchUseCase = _ref.read(searchPropertiesUseCaseProvider);
      return searchUseCase(user.uid, query);
    } catch (e) {
      print('❌ Controller: Failed to search properties: $e');
      rethrow;
    }
  }
}

/// Property controller provider
final propertyControllerProvider = Provider<PropertyController>((ref) {
  return PropertyController(ref);
});