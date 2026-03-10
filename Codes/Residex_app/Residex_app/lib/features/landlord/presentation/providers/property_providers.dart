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
final filteredPropertiesProvider = Provider<AsyncValue<List<Property>>>((ref) {
  final propertiesAsync = ref.watch(propertiesStreamProvider);
  final filter = ref.watch(propertyFilterProvider);

  return propertiesAsync.whenData((properties) {
    switch (filter) {
      case PropertyFilter.all:
        return properties;
      case PropertyFilter.fullyOccupied:
        return properties.where((p) => p.isFullyOccupied).toList();
      case PropertyFilter.hasVacancy:
        return properties.where((p) => p.hasVacancy).toList();
      default:
        return [];
    }
  });
});

// ============================================================
// PORTFOLIO STATISTICS
// ============================================================

/// Portfolio statistics provider (calculated from properties)
final portfolioStatsProvider = Provider<PortfolioStats>((ref) {
  final propertiesAsync = ref.watch(propertiesStreamProvider);
  
  return propertiesAsync.when(
    data: (properties) {
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

      final totalUnits = properties.fold<int>(
        0,
        (sum, property) => sum + property.totalUnits,
      );

      final occupiedUnits = properties.fold<int>(
        0,
        (sum, property) => sum + property.occupiedUnits,
      );

      final vacantUnits = totalUnits - occupiedUnits;
      
      final averageOccupancyRate = totalUnits > 0 
          ? (occupiedUnits / totalUnits) * 100 
          : 0.0;

      final fullyOccupiedCount = properties.where((p) => p.isFullyOccupied).length;
      final vacantCount = properties.where((p) => p.hasVacancy).length;

      // Calculate total revenue (sum of monthly rent * occupied units)
      final totalRevenue = properties.fold<double>(
        0.0,
        (sum, property) => sum + (property.monthlyRent * property.occupiedUnits),
      );

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
    },
    loading: () => PortfolioStats(
      totalProperties: 0,
      totalUnits: 0,
      occupiedUnits: 0,
      vacantUnits: 0,
      averageOccupancyRate: 0.0,
      fullyOccupiedProperties: 0,
      vacantProperties: 0,
      totalRevenue: 0.0,
    ),
    error: (_, __) => PortfolioStats(
      totalProperties: 0,
      totalUnits: 0,
      occupiedUnits: 0,
      vacantUnits: 0,
      averageOccupancyRate: 0.0,
      fullyOccupiedProperties: 0,
      vacantProperties: 0,
      totalRevenue: 0.0,
    ),
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

  /// Delete a property
  Future<void> deleteProperty(String propertyId) async {
    try {
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