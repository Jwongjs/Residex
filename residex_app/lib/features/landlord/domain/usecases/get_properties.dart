import '../entities/property.dart';
import '../repositories/property_repository.dart';

/// Use case for getting all properties for a landlord
class GetProperties {
  final PropertyRepository _repository;

  GetProperties(this._repository);

  /// Get all properties for a landlord
  /// 
  /// Returns list of properties sorted by creation date (newest first)
  Future<List<Property>> call(String landlordId) async {
    print('🔵 UseCase: Getting properties for landlord: $landlordId');

    if (landlordId.trim().isEmpty) {
      throw Exception('Landlord ID cannot be empty');
    }

    try {
      final properties = await _repository.getPropertiesByLandlord(landlordId);
      
      print('✅ UseCase: Found ${properties.length} properties');
      return properties;
    } catch (e) {
      print('❌ UseCase: Failed to get properties: $e');
      rethrow;
    }
  }

  /// Stream properties for real-time updates
  Stream<List<Property>> stream(String landlordId) {
    print('🔵 UseCase: Streaming properties for landlord: $landlordId');

    if (landlordId.trim().isEmpty) {
      throw Exception('Landlord ID cannot be empty');
    }

    return _repository.streamPropertiesByLandlord(landlordId);
  }
}
