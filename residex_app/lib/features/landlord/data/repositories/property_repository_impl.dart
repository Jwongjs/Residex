import '../../domain/entities/property.dart';
import '../../domain/repositories/property_repository.dart';
import '../datasources/property_remote_datasource.dart';
import '../models/property_model.dart';

/// Concrete implementation of PropertyRepository
/// 
/// Delegates all operations to PropertyRemoteDataSource (Firebase)
class PropertyRepositoryImpl implements PropertyRepository {
  final PropertyRemoteDataSource remoteDataSource;

  PropertyRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<Property>> getPropertiesByLandlord(String landlordId) async {
    print('🔵 Repository: Get properties for landlord $landlordId');
    try {
      final propertyModels = await remoteDataSource.getPropertiesByLandlord(landlordId);
      print('✅ Repository: Found ${propertyModels.length} properties');
      return propertyModels;
    } catch (e) {
      print('❌ Repository: Failed to get properties: $e');
      rethrow;
    }
  }

  @override
  Stream<List<Property>> streamPropertiesByLandlord(String landlordId) {
    print('🔵 Repository: Streaming properties for landlord $landlordId');
    return remoteDataSource.streamPropertiesByLandlord(landlordId);
  }

  @override
  Future<Property?> getPropertyById(String propertyId) async {
    print('🔵 Repository: Get property by ID $propertyId');
    try {
      final propertyModel = await remoteDataSource.getPropertyById(propertyId);
      return propertyModel;
    } catch (e) {
      print('❌ Repository: Failed to get property: $e');
      rethrow;
    }
  }

  @override
  Future<String> createProperty(Property property) async {
    print('🔵 Repository: Create property');
    try {
      final propertyModel = PropertyModel.fromEntity(property);
      final propertyId = await remoteDataSource.createProperty(propertyModel);
      print('✅ Repository: Property created with ID: $propertyId');
      return propertyId;
    } catch (e) {
      print('❌ Repository: Failed to create property: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateProperty(Property property) async {
    print('🔵 Repository: Update property ${property.id}');
    try {
      final propertyModel = PropertyModel.fromEntity(property);
      await remoteDataSource.updateProperty(propertyModel);
      print('✅ Repository: Property updated');
    } catch (e) {
      print('❌ Repository: Failed to update property: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteProperty(String propertyId) async {
    print('🔵 Repository: Delete property $propertyId');
    try {
      await remoteDataSource.deleteProperty(propertyId);
      print('✅ Repository: Property deleted');
    } catch (e) {
      print('❌ Repository: Failed to delete property: $e');
      rethrow;
    }
  }

  @override
  Future<List<Property>> searchProperties(String landlordId, String query) async {
    print('🔵 Repository: Search properties for "$query"');
    try {
      final propertyModels = await remoteDataSource.searchProperties(landlordId, query);
      return propertyModels;
    } catch (e) {
      print('❌ Repository: Failed to search properties: $e');
      rethrow;
    }
  }

  // ========== STATISTICS METHODS ==========

  @override
  Future<int> getTotalUnits(String landlordId) async {
    print('🔵 Repository: Calculate total units for landlord $landlordId');
    try {
      final properties = await getPropertiesByLandlord(landlordId);
      final totalUnits = properties.fold<int>(
        0,
        (sum, property) => sum + property.totalUnits,
      );
      print('✅ Repository: Total units = $totalUnits');
      return totalUnits;
    } catch (e) {
      print('❌ Repository: Failed to calculate total units: $e');
      rethrow;
    }
  }

  @override
  Future<int> getTotalOccupiedUnits(String landlordId) async {
    print('🔵 Repository: Calculate occupied units for landlord $landlordId');
    try {
      final properties = await getPropertiesByLandlord(landlordId);
      final occupiedUnits = properties.fold<int>(
        0,
        (sum, property) => sum + property.occupiedUnits,
      );
      print('✅ Repository: Occupied units = $occupiedUnits');
      return occupiedUnits;
    } catch (e) {
      print('❌ Repository: Failed to calculate occupied units: $e');
      rethrow;
    }
  }

  @override
  Future<double> getOccupancyRate(String landlordId) async {
    print('🔵 Repository: Calculate occupancy rate for landlord $landlordId');
    try {
      final totalUnits = await getTotalUnits(landlordId);
      final occupiedUnits = await getTotalOccupiedUnits(landlordId);
      
      if (totalUnits == 0) {
        print('⚠️ Repository: No units found, occupancy rate = 0%');
        return 0.0;
      }
      
      final occupancyRate = (occupiedUnits / totalUnits) * 100;
      print('✅ Repository: Occupancy rate = ${occupancyRate.toStringAsFixed(1)}%');
      return occupancyRate;
    } catch (e) {
      print('❌ Repository: Failed to calculate occupancy rate: $e');
      rethrow;
    }
  }

  @override
  Future<double> getTotalPotentialRevenue(String landlordId) async {
    print('🔵 Repository: Calculate potential revenue for landlord $landlordId');
    try {
      final properties = await getPropertiesByLandlord(landlordId);
      final potentialRevenue = properties.fold<double>(
        0.0,
        (sum, property) => sum + property.potentialRevenue,
      );
      print('✅ Repository: Potential revenue = RM ${potentialRevenue.toStringAsFixed(2)}');
      return potentialRevenue;
    } catch (e) {
      print('❌ Repository: Failed to calculate potential revenue: $e');
      rethrow;
    }
  }

  @override
  Future<double> getTotalActualRevenue(String landlordId) async {
    print('🔵 Repository: Calculate actual revenue for landlord $landlordId');
    try {
      final properties = await getPropertiesByLandlord(landlordId);
      final actualRevenue = properties.fold<double>(
        0.0,
        (sum, property) => sum + property.actualRevenue,
      );
      print('✅ Repository: Actual revenue = RM ${actualRevenue.toStringAsFixed(2)}');
      return actualRevenue;
    } catch (e) {
      print('❌ Repository: Failed to calculate actual revenue: $e');
      rethrow;
    }
  }
}