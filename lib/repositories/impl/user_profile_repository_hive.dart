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
  }) async {
    final current = await getCurrent();
    if (current == null) return;

    // Manually create updated profile since model may not have copyWith
    final updated = UserProfileModel(
      id: current.id,
      role: role ?? current.role,
      displayName: displayName ?? current.displayName,
      email: email ?? current.email,
      createdAt: current.createdAt,
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
}
