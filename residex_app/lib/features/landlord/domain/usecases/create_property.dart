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
