import '../entities/property.dart';
import '../repositories/property_repository.dart';

/// Use case for getting a single property by ID
class GetPropertyById {
  final PropertyRepository _repository;

  GetPropertyById(this._repository);

  /// Get a property by ID
  /// 
  /// Returns null if property not found
  Future<Property?> call(String propertyId) async {
    print('🔵 UseCase: Getting property: $propertyId');

    if (propertyId.trim().isEmpty) {
      throw Exception('Property ID cannot be empty');
    }

    try {
      final property = await _repository.getPropertyById(propertyId);
      
      if (property == null) {
        print('⚠️ UseCase: Property not found: $propertyId');
      } else {
        print('✅ UseCase: Property found: ${property.name}');
      }
      
      return property;
    } catch (e) {
      print('❌ UseCase: Failed to get property: $e');
      rethrow;
    }
  }
}
