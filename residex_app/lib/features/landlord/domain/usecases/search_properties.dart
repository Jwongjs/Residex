import '../entities/property.dart';
import '../repositories/property_repository.dart';

/// Use case for searching properties
class SearchProperties {
  final PropertyRepository _repository;

  SearchProperties(this._repository);

  /// Search properties by name or address
  /// 
  /// Returns matching properties
  Future<List<Property>> call(String landlordId, String query) async {
    print('🔵 UseCase: Searching properties: "$query"');

    if (landlordId.trim().isEmpty) {
      throw Exception('Landlord ID cannot be empty');
    }

    if (query.trim().isEmpty) {
      print('⚠️ UseCase: Empty query, returning all properties');
      return _repository.getPropertiesByLandlord(landlordId);
    }

    try {
      final properties = await _repository.searchProperties(landlordId, query);
      
      print('✅ UseCase: Found ${properties.length} matching properties');
      return properties;
    } catch (e) {
      print('❌ UseCase: Failed to search properties: $e');
      rethrow;
    }
  }
}
