/// EmergencyRepository - Abstract interface for emergency state data access.
///
/// Part of PHASE 2: Backend is the only source of truth.
///
/// Data Flow:
/// UI → emergencyStateProvider → EmergencyRepository → BoxAccessor.emergencyOps() → Hive
library;

import '../persistence/models/pending_op.dart';

/// Emergency state summary for UI display.
class EmergencyState {
  final int pendingOpsCount;
  final int failedOpsCount;
  final bool isOfflineMode;
  final DateTime? lastSyncAttempt;
  final String? lastError;
  final List<PendingOp> criticalOps;

  const EmergencyState({
    this.pendingOpsCount = 0,
    this.failedOpsCount = 0,
    this.isOfflineMode = false,
    this.lastSyncAttempt,
    this.lastError,
    this.criticalOps = const [],
  });

  bool get hasUnsyncedData => pendingOpsCount > 0 || failedOpsCount > 0;
  bool get hasCriticalIssues => failedOpsCount > 0 || lastError != null;

  EmergencyState copyWith({
    int? pendingOpsCount,
    int? failedOpsCount,
    bool? isOfflineMode,
    DateTime? lastSyncAttempt,
    String? lastError,
    List<PendingOp>? criticalOps,
  }) =>
      EmergencyState(
        pendingOpsCount: pendingOpsCount ?? this.pendingOpsCount,
        failedOpsCount: failedOpsCount ?? this.failedOpsCount,
        isOfflineMode: isOfflineMode ?? this.isOfflineMode,
        lastSyncAttempt: lastSyncAttempt ?? this.lastSyncAttempt,
        lastError: lastError ?? this.lastError,
        criticalOps: criticalOps ?? this.criticalOps,
      );
}

/// Abstract repository for emergency operations.
///
/// All emergency state access MUST go through this interface.
abstract class EmergencyRepository {
  /// Watch emergency state as a reactive stream.
  Stream<EmergencyState> watchState();

  /// Get current emergency state (one-time read).
  Future<EmergencyState> getState();

  /// Get all pending emergency operations.
  Future<List<PendingOp>> getPendingOps();

  /// Get all failed operations.
  Future<List<PendingOp>> getFailedOps();

  /// Add an emergency operation.
  Future<void> addEmergencyOp(PendingOp op);

  /// Mark an operation as failed.
  Future<void> markAsFailed(String opId, String error);

  /// Retry a failed operation.
  Future<void> retryOp(String opId);

  /// Clear completed operations.
  Future<void> clearCompleted();

  /// Set offline mode status.
  Future<void> setOfflineMode(bool isOffline);

  /// Record a sync attempt.
  Future<void> recordSyncAttempt({String? error});
}
