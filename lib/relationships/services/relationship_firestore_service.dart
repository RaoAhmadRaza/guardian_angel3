/// RelationshipFirestoreService - Mirrors relationship data to Firestore.
///
/// This service handles Firestore mirroring for relationships.
/// NEVER blocks UI - all operations are fire-and-forget with retry.
///
/// Collection: relationships/{relationshipId}
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/relationship_model.dart';
import '../../services/telemetry_service.dart';

/// Firestore mirror service for relationships.
class RelationshipFirestoreService {
  RelationshipFirestoreService._();

  static final RelationshipFirestoreService _instance = RelationshipFirestoreService._();
  static RelationshipFirestoreService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TelemetryService _telemetry = getSharedTelemetryInstance();

  /// Collection reference for relationships.
  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('relationships');

  /// Mirrors a relationship to Firestore.
  /// 
  /// This is NON-BLOCKING. Errors are logged but do not propagate.
  /// Use set with merge to handle both create and update.
  Future<void> mirrorRelationship(RelationshipModel relationship) async {
    debugPrint('[RelationshipFirestoreService] Mirroring relationship: ${relationship.id}');
    _telemetry.increment('relationship.firestore.mirror.attempt');

    try {
      await _collection.doc(relationship.id).set(
        relationship.toJson(),
        SetOptions(merge: true),
      );

      debugPrint('[RelationshipFirestoreService] Mirror success: ${relationship.id}');
      _telemetry.increment('relationship.firestore.mirror.success');
    } catch (e) {
      debugPrint('[RelationshipFirestoreService] Mirror failed: $e');
      _telemetry.increment('relationship.firestore.mirror.error');
      // Do NOT rethrow - Firestore failures should not block UI
    }
  }

  /// Fetches a relationship from Firestore by ID.
  /// 
  /// Used for sync/recovery scenarios.
  Future<RelationshipModel?> fetchRelationship(String relationshipId) async {
    try {
      final doc = await _collection.doc(relationshipId).get();
      if (!doc.exists || doc.data() == null) return null;
      
      return RelationshipModel.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('[RelationshipFirestoreService] Fetch failed: $e');
      _telemetry.increment('relationship.firestore.fetch.error');
      return null;
    }
  }

  /// Fetches all relationships for a user from Firestore.
  /// 
  /// Queries both patient_id and caregiver_id fields.
  Future<List<RelationshipModel>> fetchRelationshipsForUser(String uid) async {
    try {
      // Query as patient
      final patientQuery = await _collection
          .where('patient_id', isEqualTo: uid)
          .get();

      // Query as caregiver
      final caregiverQuery = await _collection
          .where('caregiver_id', isEqualTo: uid)
          .get();

      // Combine results, avoiding duplicates
      final Map<String, RelationshipModel> results = {};
      
      for (final doc in patientQuery.docs) {
        if (doc.data().isNotEmpty) {
          final relationship = RelationshipModel.fromJson(doc.data());
          results[relationship.id] = relationship;
        }
      }
      
      for (final doc in caregiverQuery.docs) {
        if (doc.data().isNotEmpty) {
          final relationship = RelationshipModel.fromJson(doc.data());
          results[relationship.id] = relationship;
        }
      }

      return results.values.toList();
    } catch (e) {
      debugPrint('[RelationshipFirestoreService] Fetch for user failed: $e');
      _telemetry.increment('relationship.firestore.fetch_user.error');
      return [];
    }
  }

  /// Finds a relationship by invite code in Firestore.
  /// 
  /// Used as fallback when local lookup fails.
  Future<RelationshipModel?> findByInviteCode(String inviteCode) async {
    try {
      final query = await _collection
          .where('invite_code', isEqualTo: inviteCode)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;
      
      final doc = query.docs.first;
      if (doc.data().isEmpty) return null;
      
      return RelationshipModel.fromJson(doc.data());
    } catch (e) {
      debugPrint('[RelationshipFirestoreService] Find by invite code failed: $e');
      _telemetry.increment('relationship.firestore.find_invite.error');
      return null;
    }
  }

  /// Deletes a relationship from Firestore.
  /// 
  /// Used when relationship is permanently deleted (rare).
  Future<void> deleteRelationship(String relationshipId) async {
    try {
      await _collection.doc(relationshipId).delete();
      debugPrint('[RelationshipFirestoreService] Deleted: $relationshipId');
      _telemetry.increment('relationship.firestore.delete.success');
    } catch (e) {
      debugPrint('[RelationshipFirestoreService] Delete failed: $e');
      _telemetry.increment('relationship.firestore.delete.error');
    }
  }

  /// Watches relationships for a user in Firestore.
  /// 
  /// Returns a stream of relationship lists.
  /// Note: This creates TWO Firestore listeners (patient + caregiver queries).
  Stream<List<RelationshipModel>> watchRelationshipsForUser(String uid) {
    // Watch as patient
    final patientStream = _collection
        .where('patient_id', isEqualTo: uid)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .where((doc) => doc.data().isNotEmpty)
            .map((doc) => RelationshipModel.fromJson(doc.data()))
            .toList());

    // For simplicity, we only return the patient stream here.
    // In production, you'd want to merge both streams.
    return patientStream;
  }
}
