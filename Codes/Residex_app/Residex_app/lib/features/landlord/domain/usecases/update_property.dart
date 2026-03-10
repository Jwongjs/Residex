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

    // ✅ Business validation
    if (property.id.trim().isEmpty) {
      throw Exception('Property ID cannot be empty');
    }

    if (property.name.trim().isEmpty) {
      throw Exception('Property name cannot be empty');
    }

    if (property.totalUnits < 0) {
      throw Exception('Total units must be >= 0');
    }

    if (property.occupiedUnits < 0) {
      throw Exception('Occupied units must be >= 0');
    }

    if (property.occupiedUnits > property.totalUnits) {
      throw Exception('Occupied units cannot exceed total units');
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
