import '../entities/property.dart';

/// Abstract repository interface for property operations
/// 
/// This defines WHAT operations exist, not HOW they're implemented.
/// Implementation will be in the data layer.
abstract class PropertyRepository {
  /// Get all properties for a specific landlord
  Future<List<Property>> getPropertiesByLandlord(String landlordId);

  /// Get a single property by ID
  Future<Property?> getPropertyById(String propertyId);

  /// Add a new property
  Future<void> addProperty(Property property);

  /// Update existing property
  Future<void> updateProperty(Property property);

  /// Delete a property
  Future<void> deleteProperty(String propertyId);

  /// Get total number of occupied units across all properties
  Future<int> getTotalOccupiedUnits(String landlordId);

  /// Get total number of units across all properties
  Future<int> getTotalUnits(String landlordId);

  /// Get total monthly revenue from all properties
  Future<double> getTotalMonthlyRevenue(String landlordId);

  /// Get properties by status
  Future<List<Property>> getPropertiesByStatus(
    String landlordId,
    PropertyStatus status,
  );

  /// Search properties by address or name
  Future<List<Property>> searchProperties(String landlordId, String query);
}