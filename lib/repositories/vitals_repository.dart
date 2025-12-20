/// VitalsRepository - Abstract interface for vitals data access.
///
/// Part of PHASE 2: Backend is the only source of truth.
///
/// Data Flow:
/// UI → vitalsProvider → VitalsRepository → BoxAccessor.vitals() → Hive
library;

import '../../../models/vitals_model.dart';

/// Abstract repository for vitals operations.
///
/// All vitals access MUST go through this interface.
abstract class VitalsRepository {
  /// Watch all vitals as a reactive stream.
  Stream<List<VitalsModel>> watchAll();

  /// Watch vitals for a specific user.
  Stream<List<VitalsModel>> watchForUser(String userId);

  /// Get all vitals (one-time read).
  Future<List<VitalsModel>> getAll();

  /// Get vitals for a specific user.
  Future<List<VitalsModel>> getForUser(String userId);

  /// Get a single vital by ID.
  Future<VitalsModel?> getById(String id);

  /// Save a vital record.
  Future<void> save(VitalsModel vital);

  /// Delete a vital record.
  Future<void> delete(String id);

  /// Delete all vitals for a user.
  Future<void> deleteForUser(String userId);

  /// Get the latest vital for a user.
  Future<VitalsModel?> getLatestForUser(String userId);

  /// Get vitals within a date range.
  Future<List<VitalsModel>> getInDateRange(
    String userId,
    DateTime start,
    DateTime end,
  );
}
