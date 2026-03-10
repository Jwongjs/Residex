import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/property_model.dart';

/// Remote data source for property operations using Firestore
/// 
/// Handles all Firebase Firestore operations for properties collection
class PropertyRemoteDataSource {
  final FirebaseFirestore _firestore;

  PropertyRemoteDataSource({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Firestore collection reference
  CollectionReference get _propertiesCollection =>
      _firestore.collection('properties');

  /// Stream all properties for a landlord (real-time updates)
  Stream<List<PropertyModel>> streamProperties(String landlordId) {
    print('🔵 DataSource: Streaming properties for landlord: $landlordId');
    
    return _propertiesCollection
        .where('landlordId', isEqualTo: landlordId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      print('✅ DataSource: Received ${snapshot.docs.length} properties');
      
      return snapshot.docs.map((doc) {
        try {
          return PropertyModel.fromFirestore(doc);
        } catch (e) {
          print('❌ Error parsing property ${doc.id}: $e');
          rethrow;
        }
      }).toList();
    });
  }

  /// Get all properties for a landlord
  Future<List<PropertyModel>> getPropertiesByLandlord(String landlordId) async {
    print('🔵 DataSource: Fetching properties for landlord: $landlordId');
    
    try {
      final querySnapshot = await _propertiesCollection
          .where('landlordId', isEqualTo: landlordId)
          .orderBy('createdAt', descending: true)
          .get();

      print('✅ DataSource: Found ${querySnapshot.docs.length} properties');

      return querySnapshot.docs
          .map((doc) => PropertyModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('❌ DataSource: Error fetching properties: $e');
      rethrow;
    }
  }

    /// Stream properties in real-time (NEW METHOD)
  Stream<List<PropertyModel>> streamPropertiesByLandlord(String landlordId) {
    print('🔵 DataSource: Streaming properties for landlord $landlordId');
    
    return _propertiesCollection
        .where('landlordId', isEqualTo: landlordId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          print('🔵 DataSource: Received ${snapshot.docs.length} properties from stream');
          return snapshot.docs
              .map((doc) => PropertyModel.fromFirestore(doc))
              .toList();
        })
        .handleError((error) {
          print('❌ DataSource: Stream error: $error');
          throw error;
        });
  }

  /// Get a single property by ID
  Future<PropertyModel?> getPropertyById(String propertyId) async {
    print('🔵 DataSource: Fetching property: $propertyId');
    
    try {
      final doc = await _propertiesCollection.doc(propertyId).get();

      if (!doc.exists) {
        print('⚠️ DataSource: Property not found: $propertyId');
        return null;
      }

      print('✅ DataSource: Property found: $propertyId');
      return PropertyModel.fromFirestore(doc);
    } catch (e) {
      print('❌ DataSource: Error fetching property: $e');
      rethrow;
    }
  }

  /// Create a new property
  Future<String> createProperty(PropertyModel property) async {
    print('🔵 DataSource: Creating property: ${property.name}');
    
    try {
      final docRef = await _propertiesCollection.add(property.toFirestore());
      
      print('✅ DataSource: Property created with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ DataSource: Error creating property: $e');
      rethrow;
    }
  }

  /// Update existing property
  Future<void> updateProperty(PropertyModel property) async {
    print('🔵 DataSource: Updating property: ${property.id}');
    
    try {
      await _propertiesCollection
          .doc(property.id)
          .update(property.toFirestore());
      
      print('✅ DataSource: Property updated: ${property.id}');
    } catch (e) {
      print('❌ DataSource: Error updating property: $e');
      rethrow;
    }
  }

  /// Delete a property
  Future<void> deleteProperty(String propertyId) async {
    print('🔵 DataSource: Deleting property: $propertyId');
    
    try {
      await _propertiesCollection.doc(propertyId).delete();
      
      print('✅ DataSource: Property deleted: $propertyId');
    } catch (e) {
      print('❌ DataSource: Error deleting property: $e');
      rethrow;
    }
  }

  /// Search properties by name or address
  Future<List<PropertyModel>> searchProperties(
    String landlordId,
    String query,
  ) async {
    print('🔵 DataSource: Searching properties: "$query"');
    
    try {
      // Get all properties for landlord first (Firestore limitation)
      final querySnapshot = await _propertiesCollection
          .where('landlordId', isEqualTo: landlordId)
          .get();

      final properties = querySnapshot.docs
          .map((doc) => PropertyModel.fromFirestore(doc))
          .toList();

      // Filter by query locally
      final lowerQuery = query.toLowerCase();
      final filtered = properties.where((property) {
        return property.name.toLowerCase().contains(lowerQuery) ||
            property.address.fullAddress.toLowerCase().contains(lowerQuery);
      }).toList();

      print('✅ DataSource: Found ${filtered.length} matching properties');
      return filtered;
    } catch (e) {
      print('❌ DataSource: Error searching properties: $e');
      rethrow;
    }
  }

  /// Check if property exists
  Future<bool> propertyExists(String propertyId) async {
    try {
      final doc = await _propertiesCollection.doc(propertyId).get();
      return doc.exists;
    } catch (e) {
      print('❌ DataSource: Error checking property existence: $e');
      return false;
    }
  }
}
