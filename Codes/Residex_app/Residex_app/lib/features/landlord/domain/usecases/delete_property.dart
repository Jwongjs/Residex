import '../repositories/property_repository.dart';

/// Use case for deleting a property
class DeleteProperty {
  final PropertyRepository _repository;

  DeleteProperty(this._repository);

  /// Delete a property
  /// 
  /// ⚠️ Warning: This operation cannot be undone
  Future<void> call(String propertyId) async {
    print('🔵 UseCase: Deleting property: $propertyId');

    if (propertyId.trim().isEmpty) {
      throw Exception('Property ID cannot be empty');
    }

    try {
      await _repository.deleteProperty(propertyId);
      
      print('✅ UseCase: Property deleted successfully: $propertyId');
    } catch (e) {
      print('❌ UseCase: Failed to delete property: $e');
      rethrow;
    }
  }
}
