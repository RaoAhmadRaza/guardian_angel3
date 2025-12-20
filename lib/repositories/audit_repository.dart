/// AuditRepository - Abstract interface for audit log data access.
///
/// Part of PHASE 2: Backend is the only source of truth.
///
/// Data Flow:
/// UI → auditLogProvider → AuditRepository → BoxAccessor.auditLogs() → Hive
library;

import '../../../models/audit_log_record.dart';

/// Abstract repository for audit log operations.
///
/// All audit log access MUST go through this interface.
abstract class AuditRepository {
  /// Watch all audit logs as a reactive stream.
  Stream<List<AuditLogRecord>> watchAll();

  /// Watch audit logs for a specific actor.
  Stream<List<AuditLogRecord>> watchForActor(String actor);

  /// Get all audit logs (one-time read).
  Future<List<AuditLogRecord>> getAll();

  /// Get audit logs for a specific actor.
  Future<List<AuditLogRecord>> getForActor(String actor);

  /// Get audit logs by type.
  Future<List<AuditLogRecord>> getByType(String type);

  /// Log a new audit record.
  Future<void> log(AuditLogRecord record);

  /// Delete audit logs older than a date.
  Future<int> deleteOlderThan(DateTime date);

  /// Get audit logs in a date range.
  Future<List<AuditLogRecord>> getInDateRange(DateTime start, DateTime end);

  /// Get count of audit logs.
  Future<int> getCount();

  /// Clear all audit logs.
  Future<void> clearAll();
}
