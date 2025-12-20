/// VitalsRepositoryHive - Hive implementation of VitalsRepository.
///
/// Part of PHASE 2: Backend is the only source of truth.
/// Updated in PHASE 3: Data validation at write boundaries.
/// Updated in PHASE 1 BLOCKER FIX: HiveError handling.
///
/// Data Flow:
/// UI → vitalsProvider → VitalsRepositoryHive → BoxAccessor.vitals() → Hive
library;

import 'package:hive/hive.dart';
import '../../models/vitals_model.dart';
import '../../persistence/box_registry.dart';
import '../../persistence/errors/errors.dart';
import '../../persistence/wrappers/box_accessor.dart';
import '../../services/telemetry_service.dart';
import '../vitals_repository.dart';

/// Hive-backed implementation of VitalsRepository.
class VitalsRepositoryHive implements VitalsRepository {
  final BoxAccessor _boxAccessor;

  VitalsRepositoryHive({BoxAccessor? boxAccessor})
      : _boxAccessor = boxAccessor ?? BoxAccessor();

  Box<VitalsModel> get _box => _boxAccessor.vitals();

  @override
  Stream<List<VitalsModel>> watchAll() async* {
    // Emit current state immediately
    yield _box.values.toList();
    // Then emit on every change
    yield* _box.watch().map((_) => _box.values.toList());
  }

  @override
  Stream<List<VitalsModel>> watchForUser(String userId) async* {
    List<VitalsModel> _filterForUser() =>
        _box.values.where((v) => v.userId == userId).toList()
          ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    // Emit current state immediately
    yield _filterForUser();
    // Then emit on every change
    yield* _box.watch().map((_) => _filterForUser());
  }

  @override
  Future<List<VitalsModel>> getAll() async {
    return _box.values.toList();
  }

  @override
  Future<List<VitalsModel>> getForUser(String userId) async {
    return _box.values.where((v) => v.userId == userId).toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  }

  @override
  Future<VitalsModel?> getById(String id) async {
    return _box.get(id);
  }

  @override
  Future<void> save(VitalsModel vital) async {
    // PHASE 3 STEP 3.4: Validate at write boundary
    // PHASE 1 BLOCKER FIX: Safe HiveError handling
    try {
      final validated = vital.validated();
      final result = await SafeBoxOps.put(
        _box,
        validated.id,
        validated,
        boxName: BoxRegistry.vitalsBox,
      );
      if (result.isFailure) {
        TelemetryService.I.increment('vitals.save.hive_error');
        throw result.error!;
      }
      TelemetryService.I.increment('vitals.save.success');
    } on VitalsValidationError catch (e) {
      TelemetryService.I.increment('vitals.save.validation_failed');
      rethrow;
    } on PersistenceError {
      // Already recorded by SafeBoxOps, rethrow for caller handling
      rethrow;
    }
  }

  @override
  Future<void> delete(String id) async {
    final result = await SafeBoxOps.delete(
      _box,
      id,
      boxName: BoxRegistry.vitalsBox,
    );
    if (result.isFailure) {
      throw result.error!;
    }
  }

  @override
  Future<void> deleteForUser(String userId) async {
    final toDelete = _box.values
        .where((v) => v.userId == userId)
        .map((v) => v.id)
        .toList();
    final result = await SafeBoxOps.deleteAll(
      _box,
      toDelete,
      boxName: BoxRegistry.vitalsBox,
    );
    if (result.isFailure) {
      throw result.error!;
    }
  }

  @override
  Future<VitalsModel?> getLatestForUser(String userId) async {
    final userVitals = await getForUser(userId);
    if (userVitals.isEmpty) return null;
    return userVitals.first; // Already sorted by recordedAt descending
  }

  @override
  Future<List<VitalsModel>> getInDateRange(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    return _box.values
        .where((v) =>
            v.userId == userId &&
            v.recordedAt.isAfter(start) &&
            v.recordedAt.isBefore(end))
        .toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  }
}
