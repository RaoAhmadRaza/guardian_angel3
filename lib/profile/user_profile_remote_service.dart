/// UserProfileRemoteService - Firebase Firestore integration for user profiles.
///
/// Responsibilities:
/// - Write user profiles to Firestore at users/{uid}
/// - Uses SetOptions(merge: true) to avoid overwriting existing data
/// - Provides error handling with retry capability
///
/// This service is NOT the source of truth. Local (Hive) is always primary.
/// Firestore is used for backup/sync only.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_profile_model.dart';
import '../services/telemetry_service.dart';

/// Result of a remote sync operation.
class RemoteSyncResult {
  final bool success;
  final String? errorMessage;
  final String? errorCode;

  const RemoteSyncResult._({
    required this.success,
    this.errorMessage,
    this.errorCode,
  });

  factory RemoteSyncResult.success() => const RemoteSyncResult._(success: true);

  factory RemoteSyncResult.failure({
    required String errorCode,
    required String errorMessage,
  }) =>
      RemoteSyncResult._(
        success: false,
        errorCode: errorCode,
        errorMessage: errorMessage,
      );
}

/// Service for syncing user profiles to Firebase Firestore.
///
/// Usage:
/// ```dart
/// final service = UserProfileRemoteService();
/// final result = await service.syncProfile(profile);
/// if (!result.success) {
///   // Handle failure - log for retry later
/// }
/// ```
class UserProfileRemoteService {
  UserProfileRemoteService({
    FirebaseFirestore? firestore,
    TelemetryService? telemetry,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _telemetry = telemetry ?? getSharedTelemetryInstance();

  final FirebaseFirestore _firestore;
  final TelemetryService _telemetry;

  /// Collection name in Firestore.
  static const String _usersCollection = 'users';

  /// Syncs a user profile to Firestore.
  ///
  /// Writes to: users/{profile.id}
  /// Uses merge: true to avoid overwriting existing fields.
  ///
  /// Returns [RemoteSyncResult] indicating success or failure.
  /// Never throws - all errors are captured in the result.
  Future<RemoteSyncResult> syncProfile(UserProfileModel profile) async {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('[UserProfileRemoteService] Syncing profile: ${profile.id}');

      // Prepare Firestore document data
      final docData = _profileToFirestoreDoc(profile);

      // Write to Firestore with merge
      await _firestore
          .collection(_usersCollection)
          .doc(profile.id)
          .set(docData, SetOptions(merge: true));

      stopwatch.stop();
      _telemetry.increment('profile_sync_success');

      debugPrint(
          '[UserProfileRemoteService] Profile synced successfully in ${stopwatch.elapsedMilliseconds}ms');

      return RemoteSyncResult.success();
    } on FirebaseException catch (e) {
      stopwatch.stop();
      _telemetry.increment('profile_sync_failure');

      debugPrint(
          '[UserProfileRemoteService] Firestore error: ${e.code} - ${e.message}');

      return RemoteSyncResult.failure(
        errorCode: e.code,
        errorMessage: e.message ?? 'Firestore sync failed',
      );
    } catch (e, stack) {
      stopwatch.stop();
      _telemetry.increment('profile_sync_failure');

      debugPrint('[UserProfileRemoteService] Unexpected error: $e');
      debugPrint('[UserProfileRemoteService] Stack: $stack');

      return RemoteSyncResult.failure(
        errorCode: 'unknown',
        errorMessage: e.toString(),
      );
    }
  }

  /// Fetches a user profile from Firestore.
  ///
  /// Returns null if the document doesn't exist.
  /// Used for conflict resolution if needed.
  Future<UserProfileModel?> fetchProfile(String uid) async {
    try {
      debugPrint('[UserProfileRemoteService] Fetching profile: $uid');

      final doc = await _firestore.collection(_usersCollection).doc(uid).get();

      if (!doc.exists || doc.data() == null) {
        debugPrint('[UserProfileRemoteService] Profile not found in Firestore');
        return null;
      }

      return _firestoreDocToProfile(doc.data()!);
    } catch (e) {
      debugPrint('[UserProfileRemoteService] Fetch error: $e');
      return null;
    }
  }

  /// Converts a UserProfileModel to Firestore document format.
  Map<String, dynamic> _profileToFirestoreDoc(UserProfileModel profile) {
    final doc = {
      'id': profile.id,
      'role': profile.role,
      'display_name': profile.displayName,
      'email': profile.email,
      'gender': profile.gender,
      'age': profile.age,
      'address': profile.address,
      'medical_history': profile.medicalHistory,
      'created_at': profile.createdAt.toUtc().toIso8601String(),
      'updated_at': profile.updatedAt.toUtc().toIso8601String(),
      // Firestore server timestamp for sync tracking
      'synced_at': FieldValue.serverTimestamp(),
    };
    // Remove null values to avoid overwriting with null
    doc.removeWhere((key, value) => value == null && key != 'synced_at');
    return doc;
  }

  /// Converts a Firestore document to UserProfileModel.
  UserProfileModel? _firestoreDocToProfile(Map<String, dynamic> data) {
    try {
      return UserProfileModel(
        id: data['id'] as String? ?? '',
        role: data['role'] as String? ?? 'patient',
        displayName: data['display_name'] as String? ?? '',
        email: data['email'] as String?,
        gender: data['gender'] as String?,
        age: data['age'] as int?,
        address: data['address'] as String?,
        medicalHistory: data['medical_history'] as String?,
        createdAt: _parseDateTime(data['created_at']),
        updatedAt: _parseDateTime(data['updated_at']),
      );
    } catch (e) {
      debugPrint('[UserProfileRemoteService] Parse error: $e');
      return null;
    }
  }

  /// Safely parses a DateTime from various formats.
  DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now().toUtc();
    if (value is Timestamp) return value.toDate().toUtc();
    if (value is String) {
      return DateTime.tryParse(value)?.toUtc() ?? DateTime.now().toUtc();
    }
    return DateTime.now().toUtc();
  }
}
