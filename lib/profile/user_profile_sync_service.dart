/// UserProfileSyncService - Orchestrates local and remote profile sync.
///
/// Responsibilities:
/// - Accept Firebase User
/// - Create a UserProfileModel from auth data
/// - Save profile locally FIRST (Hive)
/// - Then sync profile to Firestore (non-blocking)
/// - Handle errors gracefully without breaking local flow
///
/// This service is idempotent - safe to call multiple times.
library;

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_profile_model.dart';
import '../repositories/user_profile_repository.dart';
import '../repositories/impl/user_profile_repository_hive.dart';
import '../services/telemetry_service.dart';
import 'user_profile_remote_service.dart';

/// Service for bootstrapping and syncing user profiles.
///
/// Usage:
/// ```dart
/// final syncService = UserProfileSyncService();
/// 
/// // After successful authentication:
/// await syncService.bootstrapUserProfile(
///   firebaseUser: user,
///   role: 'patient',
/// );
/// ```
class UserProfileSyncService {
  UserProfileSyncService({
    UserProfileRepository? localRepository,
    UserProfileRemoteService? remoteService,
    TelemetryService? telemetry,
  })  : _localRepository =
            localRepository ?? UserProfileRepositoryHive(),
        _remoteService = remoteService ?? UserProfileRemoteService(),
        _telemetry = telemetry ?? getSharedTelemetryInstance();

  final UserProfileRepository _localRepository;
  final UserProfileRemoteService _remoteService;
  final TelemetryService _telemetry;

  // ═══════════════════════════════════════════════════════════════════════════
  // SINGLETON (for convenience - DI is still preferred)
  // ═══════════════════════════════════════════════════════════════════════════
  
  static UserProfileSyncService? _instance;
  
  /// Gets the shared instance of UserProfileSyncService.
  /// 
  /// Prefer using DI/Riverpod when possible.
  static UserProfileSyncService get instance {
    return _instance ??= UserProfileSyncService();
  }
  
  /// Sets a custom instance (useful for testing).
  static void setInstance(UserProfileSyncService service) {
    _instance = service;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════════════════════════════════════════

  /// Bootstraps the user profile after successful authentication.
  ///
  /// This method:
  /// 1. Creates a UserProfileModel from Firebase User data
  /// 2. Saves the profile locally FIRST (throws on failure)
  /// 3. Syncs to Firestore in the background (logs on failure, doesn't throw)
  ///
  /// Parameters:
  /// - [firebaseUser]: The authenticated Firebase User
  /// - [role]: User role ('patient', 'caregiver', 'admin'). Defaults to 'patient'.
  /// - [displayName]: Optional display name override. Falls back to Firebase displayName or phone.
  ///
  /// Returns the saved [UserProfileModel].
  /// Throws only on local save failure.
  Future<UserProfileModel> bootstrapUserProfile({
    required User firebaseUser,
    String role = 'patient',
    String? displayName,
  }) async {
    debugPrint('[UserProfileSyncService] Bootstrapping profile for: ${firebaseUser.uid}');
    _telemetry.increment('profile_bootstrap_started');

    final stopwatch = Stopwatch()..start();

    try {
      // Step 1: Build the profile model from Firebase user data
      final profile = _buildProfileFromFirebaseUser(
        firebaseUser: firebaseUser,
        role: role,
        displayNameOverride: displayName,
      );

      // Step 2: Save locally FIRST (this is the source of truth)
      debugPrint('[UserProfileSyncService] Saving profile locally...');
      final savedProfile = await _localRepository.upsertProfile(profile);
      debugPrint('[UserProfileSyncService] Local save successful');
      _telemetry.increment('profile_local_save_success');

      // Step 3: Sync to Firestore in background (non-blocking)
      // ignore: unawaited_futures
      _syncToFirestoreBackground(savedProfile);

      stopwatch.stop();
      debugPrint(
          '[UserProfileSyncService] Bootstrap complete in ${stopwatch.elapsedMilliseconds}ms');

      return savedProfile;
    } catch (e, stack) {
      stopwatch.stop();
      _telemetry.increment('profile_bootstrap_failure');
      
      debugPrint('[UserProfileSyncService] Bootstrap failed: $e');
      debugPrint('[UserProfileSyncService] Stack: $stack');
      
      // Re-throw local save failures - they are critical
      rethrow;
    }
  }

  /// Bootstraps a mock profile for SIMULATOR testing only.
  /// 
  /// This creates a local-only profile when Firebase auth is bypassed.
  /// The profile is NOT synced to Firestore since there's no real auth.
  ///
  /// Parameters:
  /// - [phoneNumber]: The phone number used for mock verification
  /// - [role]: User role ('patient', 'caregiver', 'admin'). Defaults to 'patient'.
  ///
  /// Returns the saved [UserProfileModel].
  Future<UserProfileModel> bootstrapSimulatorProfile({
    required String phoneNumber,
    String role = 'patient',
  }) async {
    debugPrint('[UserProfileSyncService] Bootstrapping SIMULATOR profile');
    _telemetry.increment('profile_simulator_bootstrap');

    final now = DateTime.now().toUtc();
    
    // Generate a deterministic mock UID based on phone number
    final mockUid = 'simulator_${phoneNumber.replaceAll(RegExp(r'[^0-9]'), '')}';
    
    final profile = UserProfileModel(
      id: mockUid,
      role: role,
      displayName: 'Simulator User',
      email: null,
      createdAt: now,
      updatedAt: now,
    );

    // Save locally only - no Firestore sync for simulator
    debugPrint('[UserProfileSyncService] Saving simulator profile locally...');
    final savedProfile = await _localRepository.upsertProfile(profile);
    debugPrint('[UserProfileSyncService] Simulator profile saved: ${savedProfile.id}');

    return savedProfile;
  }

  /// Syncs the current local profile to Firestore.
  ///
  /// Useful for manual sync triggers or retry scenarios.
  /// Returns true if sync was successful.
  Future<bool> syncCurrentProfileToFirestore() async {
    try {
      final current = await _localRepository.getCurrent();
      if (current == null) {
        debugPrint('[UserProfileSyncService] No current profile to sync');
        return false;
      }

      final result = await _remoteService.syncProfile(current);
      return result.success;
    } catch (e) {
      debugPrint('[UserProfileSyncService] Manual sync failed: $e');
      return false;
    }
  }

  /// Checks if a local profile exists for the given user ID.
  Future<bool> hasLocalProfile(String uid) async {
    final profile = await _localRepository.getById(uid);
    return profile != null;
  }

  /// Gets the current local profile.
  Future<UserProfileModel?> getCurrentProfile() async {
    return _localRepository.getCurrent();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Builds a UserProfileModel from Firebase User data.
  UserProfileModel _buildProfileFromFirebaseUser({
    required User firebaseUser,
    required String role,
    String? displayNameOverride,
  }) {
    final now = DateTime.now().toUtc();

    // Determine display name with fallback chain
    String displayName = displayNameOverride ??
        firebaseUser.displayName ??
        firebaseUser.phoneNumber ??
        firebaseUser.email?.split('@').first ??
        'User';

    // Ensure display name is not empty
    if (displayName.trim().isEmpty) {
      displayName = 'User';
    }

    return UserProfileModel(
      id: firebaseUser.uid,
      role: role,
      displayName: displayName,
      email: firebaseUser.email,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Syncs profile to Firestore in the background.
  ///
  /// This is fire-and-forget - failures are logged but don't affect the caller.
  Future<void> _syncToFirestoreBackground(UserProfileModel profile) async {
    try {
      debugPrint('[UserProfileSyncService] Starting background Firestore sync...');
      
      final result = await _remoteService.syncProfile(profile);
      
      if (result.success) {
        debugPrint('[UserProfileSyncService] Firestore sync successful');
        _telemetry.increment('profile_remote_sync_success');
      } else {
        debugPrint(
            '[UserProfileSyncService] Firestore sync failed: ${result.errorCode} - ${result.errorMessage}');
        _telemetry.increment('profile_remote_sync_failure');
        
        // Queue for retry later (could integrate with existing sync queue)
        _scheduleRetry(profile);
      }
    } catch (e) {
      debugPrint('[UserProfileSyncService] Background sync error: $e');
      _telemetry.increment('profile_remote_sync_failure');
      _scheduleRetry(profile);
    }
  }

  /// Schedules a retry for failed Firestore syncs.
  ///
  /// Currently logs for future implementation.
  /// Could integrate with existing FailedOpsService or sync queue.
  void _scheduleRetry(UserProfileModel profile) {
    // TODO: Integrate with existing retry mechanism (FailedOpsService)
    debugPrint('[UserProfileSyncService] Retry scheduled for profile: ${profile.id}');
    _telemetry.increment('profile_sync_retry_scheduled');
  }

  /// Updates the current profile with patient details and syncs to Firestore.
  ///
  /// Call this from PatientDetailsScreen after collecting patient info.
  /// 
  /// Parameters:
  /// - [displayName]: Patient's full name
  /// - [gender]: Patient's gender (male, female, other, prefer_not_to_say)
  /// - [age]: Patient's age
  /// - [address]: Patient's address
  /// - [medicalHistory]: Patient's medical history
  ///
  /// Returns the updated [UserProfileModel], or null if no current profile exists.
  Future<UserProfileModel?> updateProfileWithPatientDetails({
    required String displayName,
    required String gender,
    required int age,
    String? address,
    String? medicalHistory,
  }) async {
    debugPrint('[UserProfileSyncService] Updating profile with patient details');
    _telemetry.increment('profile_patient_details_update_started');

    try {
      // Step 1: Get current profile
      final current = await _localRepository.getCurrent();
      if (current == null) {
        debugPrint('[UserProfileSyncService] No current profile to update');
        return null;
      }

      // Step 2: Update with patient details using copyWith
      final updated = current.copyWith(
        displayName: displayName,
        gender: gender,
        age: age,
        address: address,
        medicalHistory: medicalHistory,
        updatedAt: DateTime.now().toUtc(),
      );

      // Step 3: Validate and save locally
      updated.validate();
      await _localRepository.save(updated);
      debugPrint('[UserProfileSyncService] Patient details saved locally');
      _telemetry.increment('profile_patient_details_local_save_success');

      // Step 4: Sync to Firestore in background
      // ignore: unawaited_futures
      _syncToFirestoreBackground(updated);

      return updated;
    } catch (e, stack) {
      debugPrint('[UserProfileSyncService] Patient details update failed: $e');
      debugPrint('[UserProfileSyncService] Stack: $stack');
      _telemetry.increment('profile_patient_details_update_failure');
      rethrow;
    }
  }
}
