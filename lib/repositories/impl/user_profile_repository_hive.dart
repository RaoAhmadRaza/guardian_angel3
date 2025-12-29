/// UserProfileRepositoryHive - Hive implementation of UserProfileRepository.
///
/// Part of PHASE 2: Backend is the only source of truth.
/// Updated in PHASE 1 BLOCKER FIX: HiveError handling.
///
/// Data Flow:
/// UI → userProfileProvider → UserProfileRepositoryHive → BoxAccessor.userProfile() → Hive
library;

import 'package:hive/hive.dart';
import '../../models/user_profile_model.dart';
import '../../persistence/box_registry.dart';
import '../../persistence/errors/errors.dart';
import '../../persistence/wrappers/box_accessor.dart';
import '../user_profile_repository.dart';

/// Hive-backed implementation of UserProfileRepository.
class UserProfileRepositoryHive implements UserProfileRepository {
  static const String _currentProfileKey = 'current_profile';
  final BoxAccessor _boxAccessor;

  UserProfileRepositoryHive({BoxAccessor? boxAccessor})
      : _boxAccessor = boxAccessor ?? BoxAccessor();

  Box get _box => _boxAccessor.userProfile();

  @override
  Stream<UserProfileModel?> watchCurrent() async* {
    // Emit current state immediately
    yield _getCurrentSync();
    // Then emit on every change
    yield* _box.watch(key: _currentProfileKey).map((_) => _getCurrentSync());
  }

  UserProfileModel? _getCurrentSync() {
    final data = _box.get(_currentProfileKey);
    if (data == null) return null;
    if (data is UserProfileModel) return data;
    if (data is Map) {
      return UserProfileModel.fromJson(Map<String, dynamic>.from(data));
    }
    return null;
  }

  @override
  Future<UserProfileModel?> getCurrent() async {
    return _getCurrentSync();
  }

  @override
  Future<UserProfileModel?> getById(String id) async {
    final data = _box.get(id);
    if (data == null) return null;
    if (data is UserProfileModel) return data;
    if (data is Map) {
      return UserProfileModel.fromJson(Map<String, dynamic>.from(data));
    }
    return null;
  }

  @override
  Future<void> save(UserProfileModel profile) async {
    // Validate before persisting
    profile.validate();
    // PHASE 1 BLOCKER FIX: Safe HiveError handling
    final result1 = await SafeBoxOps.put(
      _box,
      profile.id,
      profile.toJson(),
      boxName: BoxRegistry.userProfileBox,
    );
    if (result1.isFailure) throw result1.error!;
    
    final result2 = await SafeBoxOps.put(
      _box,
      _currentProfileKey,
      profile.toJson(),
      boxName: BoxRegistry.userProfileBox,
    );
    if (result2.isFailure) throw result2.error!;
  }

  @override
  Future<void> updateProfile({
    String? displayName,
    String? email,
    String? role,
    String? gender,
    int? age,
    String? address,
    String? medicalHistory,
  }) async {
    final current = await getCurrent();
    if (current == null) return;

    // Use copyWith for clean, immutable updates
    final updated = current.copyWith(
      role: role,
      displayName: displayName,
      email: email,
      gender: gender,
      age: age,
      address: address,
      medicalHistory: medicalHistory,
      updatedAt: DateTime.now(),
    );
    await save(updated);
  }

  @override
  Future<void> delete(String id) async {
    final result = await SafeBoxOps.delete(
      _box,
      id,
      boxName: BoxRegistry.userProfileBox,
    );
    if (result.isFailure) throw result.error!;
    
    final current = _getCurrentSync();
    if (current?.id == id) {
      final result2 = await SafeBoxOps.delete(
        _box,
        _currentProfileKey,
        boxName: BoxRegistry.userProfileBox,
      );
      if (result2.isFailure) throw result2.error!;
    }
  }

  @override
  Future<void> clearCurrent() async {
    final result = await SafeBoxOps.delete(
      _box,
      _currentProfileKey,
      boxName: BoxRegistry.userProfileBox,
    );
    if (result.isFailure) throw result.error!;
  }

  @override
  Future<UserProfileModel> upsertProfile(UserProfileModel profile) async {
    // Step 1: Validate the model (throws on failure)
    profile.validate();
    
    // Step 2: Check if profile exists
    final existing = await getById(profile.id);
    
    // Step 3: Create or update
    final UserProfileModel profileToSave;
    if (existing != null) {
      // Update existing - preserve createdAt and existing data, update updatedAt
      // Only overwrite fields if the new profile has non-null values
      profileToSave = UserProfileModel(
        id: profile.id,
        role: profile.role,
        displayName: profile.displayName,
        email: profile.email ?? existing.email,
        gender: profile.gender ?? existing.gender,
        age: profile.age ?? existing.age,
        address: profile.address ?? existing.address,
        medicalHistory: profile.medicalHistory ?? existing.medicalHistory,
        createdAt: existing.createdAt, // Preserve original creation time
        updatedAt: DateTime.now().toUtc(),
      );
    } else {
      // New profile - ensure timestamps are set
      profileToSave = UserProfileModel(
        id: profile.id,
        role: profile.role,
        displayName: profile.displayName,
        email: profile.email,
        gender: profile.gender,
        age: profile.age,
        address: profile.address,
        medicalHistory: profile.medicalHistory,
        createdAt: profile.createdAt,
        updatedAt: DateTime.now().toUtc(),
      );
    }
    
    // Step 4: Persist to Hive (throws on failure)
    await save(profileToSave);
    
    // Step 5: Return the saved profile
    return profileToSave;
  }
}
