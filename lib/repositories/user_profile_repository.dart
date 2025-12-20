/// UserProfileRepository - Abstract interface for user profile data access.
///
/// Part of PHASE 2: Backend is the only source of truth.
///
/// Data Flow:
/// UI → userProfileProvider → UserProfileRepository → BoxAccessor.userProfile() → Hive
library;

import '../../../models/user_profile_model.dart';

/// Abstract repository for user profile operations.
///
/// All user profile access MUST go through this interface.
abstract class UserProfileRepository {
  /// Watch the current user profile as a reactive stream.
  Stream<UserProfileModel?> watchCurrent();

  /// Get the current user profile (one-time read).
  Future<UserProfileModel?> getCurrent();

  /// Get a profile by ID.
  Future<UserProfileModel?> getById(String id);

  /// Save a user profile.
  Future<void> save(UserProfileModel profile);

  /// Update profile fields.
  Future<void> updateProfile({
    String? displayName,
    String? email,
    String? role,
  });

  /// Delete a profile.
  Future<void> delete(String id);

  /// Clear current profile (logout).
  Future<void> clearCurrent();
}
