import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/unit_model.dart';

/// A units read can fail with `permission-denied` in one benign, expected case:
/// the parent property document is not yet visible to the Firestore security
/// rules. The create-property flow subscribes to the units stream a beat before
/// the parent write commits on the server, so the units rule's
/// `get(parent).data.landlordId` sees null and denies until the parent lands.
///
/// The app only ever reads units for properties the signed-in user owns (every
/// entry point is reached from their own uid-filtered portfolio), so a
/// permission-denied here means "parent not visible yet", not a real
/// cross-tenant access. We surface an empty unit list instead of a hard error;
/// the create flow's stream invalidation re-runs the read once the parent
/// exists. Any other failure propagates unchanged.
@visibleForTesting
bool isBenignUnitsPermissionDenied(Object error) =>
    error is FirebaseException && error.code == 'permission-denied';

/// Remote data source for unit operations using Firestore
///
/// Handles all Firebase Firestore operations for the
/// properties/{propertyId}/units subcollection.
class UnitRemoteDataSource {
  final FirebaseFirestore _firestore;

  UnitRemoteDataSource({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference _unitsCollection(String propertyId) =>
      _firestore.collection('properties').doc(propertyId).collection('units');

  /// Get all units for a property
  Future<List<UnitModel>> getUnitsForProperty(String propertyId) async {
    print('🔵 DataSource: Fetching units for property: $propertyId');

    try {
      final querySnapshot = await _unitsCollection(propertyId)
          .orderBy('createdAt', descending: false)
          .get();

      print('✅ DataSource: Found ${querySnapshot.docs.length} units');

      return querySnapshot.docs
          .map((doc) => UnitModel.fromFirestore(doc, propertyId))
          .toList();
    } catch (e) {
      if (isBenignUnitsPermissionDenied(e)) {
        print('⚠️ DataSource: units not yet visible for $propertyId '
            '(parent property pending) — treating as empty');
        return <UnitModel>[];
      }
      print('❌ DataSource: Error fetching units: $e');
      rethrow;
    }
  }

  /// Stream units for a property in real-time
  Stream<List<UnitModel>> streamUnitsForProperty(String propertyId) async* {
    print('🔵 DataSource: Streaming units for property: $propertyId');

    try {
      yield* _unitsCollection(propertyId)
          .orderBy('createdAt', descending: false)
          .snapshots()
          .map((snapshot) {
            print('✅ DataSource: Received ${snapshot.docs.length} units');
            return snapshot.docs
                .map((doc) => UnitModel.fromFirestore(doc, propertyId))
                .toList();
          });
    } catch (error) {
      if (isBenignUnitsPermissionDenied(error)) {
        print('⚠️ DataSource: units not yet visible for $propertyId '
            '(parent property pending) — treating as empty');
        yield <UnitModel>[];
        return;
      }
      print('❌ DataSource: Stream error: $error');
      rethrow;
    }
  }

  /// Create a new unit
  Future<String> createUnit(UnitModel unit) async {
    print('🔵 DataSource: Creating unit: ${unit.label}');

    try {
      final docRef = await _unitsCollection(unit.propertyId).add(unit.toFirestore());

      print('✅ DataSource: Unit created with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ DataSource: Error creating unit: $e');
      rethrow;
    }
  }

  /// Update an existing unit
  Future<void> updateUnit(UnitModel unit) async {
    print('🔵 DataSource: Updating unit: ${unit.id}');

    try {
      await _unitsCollection(unit.propertyId)
          .doc(unit.id)
          .update(unit.toFirestore());

      print('✅ DataSource: Unit updated: ${unit.id}');
    } catch (e) {
      print('❌ DataSource: Error updating unit: $e');
      rethrow;
    }
  }

  /// Delete ALL units for a property (part of the property-delete cascade).
  /// Firestore does not cascade subcollection deletes, so this must run
  /// before the property document itself is deleted.
  Future<void> deleteAllUnitsForProperty(String propertyId) async {
    print('🔵 DataSource: Deleting all units for property: $propertyId');

    try {
      final snapshot = await _unitsCollection(propertyId).get();
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      print('✅ DataSource: Deleted ${snapshot.docs.length} units');
    } catch (e) {
      print('❌ DataSource: Error deleting units: $e');
      rethrow;
    }
  }

  /// Delete a unit
  Future<void> deleteUnit(String propertyId, String unitId) async {
    print('🔵 DataSource: Deleting unit: $unitId');

    try {
      await _unitsCollection(propertyId).doc(unitId).delete();

      print('✅ DataSource: Unit deleted: $unitId');
    } catch (e) {
      print('❌ DataSource: Error deleting unit: $e');
      rethrow;
    }
  }
}
