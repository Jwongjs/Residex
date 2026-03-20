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

  // ========== STATISTICS METHODS (NEW) ==========

  /// Get total number of units across all properties
  Future<int> getTotalUnits(String landlordId);

  /// Get total number of occupied units
  Future<int> getTotalOccupiedUnits(String landlordId);

  /// Get occupancy rate percentage
  Future<double> getOccupancyRate(String landlordId);

  /// Get total potential revenue
  Future<double> getTotalPotentialRevenue(String landlordId);

  /// Get total actual revenue (from occupied units)
  Future<double> getTotalActualRevenue(String landlordId);
}