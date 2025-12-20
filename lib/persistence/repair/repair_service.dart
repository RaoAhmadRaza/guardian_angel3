/// Repair Service - Admin Console Surgical Kit
///
/// Provides controlled repair actions for the local backend.
/// Each action:
/// - Requires explicit confirmation token
/// - Logs to audit trail
/// - Is idempotent and safe to retry
/// - Emits telemetry for observability
///
/// SECURITY: All repair actions are logged with full context.
/// SAFETY: Actions are designed to be non-destructive where possible.
///
/// See also: docs/ADMIN_UI_RUNBOOK.md
library;

import 'dart:async';
import 'package:hive/hive.dart';
import '../../models/pending_op.dart';
import '../../models/failed_op_model.dart';
import '../../services/audit_log_service.dart';
import '../../services/telemetry_service.dart';
import '../box_registry.dart';
import '../index/pending_index.dart';
import '../locking/processing_lock.dart';
import '../queue/pending_queue_service.dart';
import '../encryption_policy.dart';
import '../wrappers/box_accessor.dart';

// ═══════════════════════════════════════════════════════════════════════════
// REPAIR ACTION ENUM
// ═══════════════════════════════════════════════════════════════════════════

/// Available repair actions in the admin surgical kit.
enum RepairAction {
  /// Rebuild the pending operations index from source of truth (Hive box).
  rebuildPendingIndex,
  
  /// Retry all failed operations by moving them back to pending queue.
  retryFailedOps,
  
  /// Permanently delete poison operations (ops that always fail).
  purgePoisonOps,
  
  /// Verify encryption keys and re-encrypt if needed.
  verifyEncryption,
  
  /// Release stale processing locks.
  releaseStaleLocks,
  
  /// Clear all entity ordering locks.
  releaseEntityLocks,
  
  /// Force queue state to idle.
  resetQueueState,
  
  /// Compact all Hive boxes.
  compactBoxes,
}

extension RepairActionExtension on RepairAction {
  /// Human-readable description of the action.
  String get description {
    switch (this) {
      case RepairAction.rebuildPendingIndex:
        return 'Rebuild pending operations index from Hive box';
      case RepairAction.retryFailedOps:
        return 'Move all failed operations back to pending queue for retry';
      case RepairAction.purgePoisonOps:
        return 'Permanently delete operations that exceeded max attempts';
      case RepairAction.verifyEncryption:
        return 'Verify encryption keys and check box integrity';
      case RepairAction.releaseStaleLocks:
        return 'Release any stale processing locks';
      case RepairAction.releaseEntityLocks:
        return 'Clear all entity ordering locks';
      case RepairAction.resetQueueState:
        return 'Force queue state back to idle';
      case RepairAction.compactBoxes:
        return 'Compact all Hive boxes to reclaim space';
    }
  }
  
  /// Severity level (info, warning, critical).
  String get severity {
    switch (this) {
      case RepairAction.rebuildPendingIndex:
      case RepairAction.compactBoxes:
        return 'info';
      case RepairAction.retryFailedOps:
      case RepairAction.releaseStaleLocks:
      case RepairAction.releaseEntityLocks:
      case RepairAction.resetQueueState:
        return 'warning';
      case RepairAction.purgePoisonOps:
      case RepairAction.verifyEncryption:
        return 'critical';
    }
  }
  
  /// Whether this action requires queue to be stopped.
  bool get requiresQueueStopped {
    switch (this) {
      case RepairAction.rebuildPendingIndex:
      case RepairAction.purgePoisonOps:
      case RepairAction.compactBoxes:
        return true;
      case RepairAction.retryFailedOps:
      case RepairAction.verifyEncryption:
      case RepairAction.releaseStaleLocks:
      case RepairAction.releaseEntityLocks:
      case RepairAction.resetQueueState:
        return false;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// REPAIR RESULT
// ═══════════════════════════════════════════════════════════════════════════

/// Result of a repair action.
class RepairResult {
  /// Whether the action completed successfully.
  final bool success;
  
  /// The action that was executed.
  final RepairAction action;
  
  /// Human-readable message about the result.
  final String message;
  
  /// Number of items affected (if applicable).
  final int? affectedCount;
  
  /// Duration the action took.
  final Duration duration;
  
  /// Error details (if failed).
  final String? error;
  
  /// Timestamp when the action was executed.
  final DateTime executedAt;
  
  const RepairResult({
    required this.success,
    required this.action,
    required this.message,
    this.affectedCount,
    required this.duration,
    this.error,
    required this.executedAt,
  });
  
  factory RepairResult.success({
    required RepairAction action,
    required String message,
    int? affectedCount,
    required Duration duration,
  }) {
    return RepairResult(
      success: true,
      action: action,
      message: message,
      affectedCount: affectedCount,
      duration: duration,
      executedAt: DateTime.now().toUtc(),
    );
  }
  
  factory RepairResult.failure({
    required RepairAction action,
    required String error,
    required Duration duration,
  }) {
    return RepairResult(
      success: false,
      action: action,
      message: 'Action failed',
      error: error,
      duration: duration,
      executedAt: DateTime.now().toUtc(),
    );
  }
  
  @override
  String toString() => success
      ? 'RepairResult.success(${action.name}: $message, affected=$affectedCount)'
      : 'RepairResult.failure(${action.name}: $error)';
}

// ═══════════════════════════════════════════════════════════════════════════
// REPAIR SERVICE
// ═══════════════════════════════════════════════════════════════════════════

/// Repair Service for controlled admin operations.
///
/// All repair operations:
/// 1. Require confirmation token
/// 2. Log to audit trail
/// 3. Emit telemetry
/// 4. Are idempotent
class RepairService {
  final PendingQueueService? _queueService;
  final TelemetryService _telemetry;
  final AuditLogService _auditLog;
  
  /// Confirmation tokens for critical actions.
  static const String _confirmationPrefix = 'CONFIRM_REPAIR_';
  
  RepairService({
    PendingQueueService? queueService,
    TelemetryService? telemetry,
    AuditLogService? auditLog,
  }) : _queueService = queueService,
       _telemetry = telemetry ?? TelemetryService.I,
       _auditLog = auditLog ?? AuditLogService.I;

  /// Safe audit log wrapper that handles uninitialized service.
  Future<void> _safeAuditLog({
    required String userId,
    required String action,
    String? entityType,
    String? entityId,
    Map<String, dynamic>? metadata,
    String severity = 'info',
  }) async {
    try {
      await _auditLog.log(
        userId: userId,
        action: action,
        entityType: entityType,
        entityId: entityId,
        metadata: metadata,
        severity: severity,
      );
    } catch (e) {
      // Audit log may not be initialized - continue without logging
      _telemetry.increment('repair.audit_log_unavailable');
    }
  }

  /// Generate a confirmation token for a repair action.
  String generateConfirmationToken(RepairAction action) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$_confirmationPrefix${action.name.toUpperCase()}_$timestamp';
  }
  
  /// Validate a confirmation token.
  bool validateToken(RepairAction action, String token) {
    // Token must start with prefix and contain action name
    final expectedPrefix = '$_confirmationPrefix${action.name.toUpperCase()}_';
    return token.startsWith(expectedPrefix);
  }

  /// Execute a repair action with confirmation.
  ///
  /// [userId] - The user executing the action (for audit).
  /// [confirmationToken] - Token from generateConfirmationToken().
  Future<RepairResult> execute({
    required RepairAction action,
    required String userId,
    required String confirmationToken,
    String? reason,
  }) async {
    final sw = Stopwatch()..start();
    
    // Validate confirmation token
    if (!validateToken(action, confirmationToken)) {
      return RepairResult.failure(
        action: action,
        error: 'Invalid confirmation token',
        duration: sw.elapsed,
      );
    }
    
    // Log start of action (gracefully handle if audit service not initialized)
    await _safeAuditLog(
      userId: userId,
      action: 'repair.${action.name}.started',
      entityType: 'repair_action',
      entityId: confirmationToken,
      metadata: {
        'reason': reason ?? 'No reason provided',
        'severity': action.severity,
      },
      severity: action.severity,
    );
    
    _telemetry.increment('repair.${action.name}.started');
    
    try {
      final result = await _executeAction(action, userId);
      
      // Log completion
      await _safeAuditLog(
        userId: userId,
        action: 'repair.${action.name}.completed',
        entityType: 'repair_action',
        entityId: confirmationToken,
        metadata: {
          'success': result.success,
          'affected_count': result.affectedCount,
          'duration_ms': result.duration.inMilliseconds,
          'message': result.message,
        },
        severity: 'info',
      );
      
      _telemetry.increment('repair.${action.name}.completed');
      _telemetry.gauge('repair.${action.name}.duration_ms', sw.elapsedMilliseconds);
      if (result.affectedCount != null) {
        _telemetry.gauge('repair.${action.name}.affected', result.affectedCount!);
      }
      
      return result;
    } catch (e, stackTrace) {
      sw.stop();
      
      // Log failure
      await _safeAuditLog(
        userId: userId,
        action: 'repair.${action.name}.failed',
        entityType: 'repair_action',
        entityId: confirmationToken,
        metadata: {
          'error': e.toString(),
          'stack_trace': stackTrace.toString().substring(0, 500),
        },
        severity: 'critical',
      );
      
      _telemetry.increment('repair.${action.name}.failed');
      
      return RepairResult.failure(
        action: action,
        error: e.toString(),
        duration: sw.elapsed,
      );
    }
  }
  
  /// Execute the specific action.
  Future<RepairResult> _executeAction(RepairAction action, String userId) async {
    final sw = Stopwatch()..start();
    
    switch (action) {
      case RepairAction.rebuildPendingIndex:
        return await _rebuildPendingIndex(sw);
      
      case RepairAction.retryFailedOps:
        return await _retryFailedOps(sw);
      
      case RepairAction.purgePoisonOps:
        return await _purgePoisonOps(sw);
      
      case RepairAction.verifyEncryption:
        return await _verifyEncryption(sw);
      
      case RepairAction.releaseStaleLocks:
        return await _releaseStaleLocks(sw);
      
      case RepairAction.releaseEntityLocks:
        return await _releaseEntityLocks(sw);
      
      case RepairAction.resetQueueState:
        return await _resetQueueState(sw);
      
      case RepairAction.compactBoxes:
        return await _compactBoxes(sw);
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // ACTION IMPLEMENTATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Rebuild the pending index from the Hive box.
  Future<RepairResult> _rebuildPendingIndex(Stopwatch sw) async {
    final index = await PendingIndex.create();
    await index.rebuild();
    
    // Count entries
    if (!Hive.isBoxOpen(BoxRegistry.pendingOpsBox)) {
      return RepairResult.success(
        action: RepairAction.rebuildPendingIndex,
        message: 'Pending box not open, nothing to rebuild',
        affectedCount: 0,
        duration: sw.elapsed,
      );
    }
    
    final pendingBox = Hive.box<PendingOp>(BoxRegistry.pendingOpsBox);
    final count = pendingBox.length;
    
    return RepairResult.success(
      action: RepairAction.rebuildPendingIndex,
      message: 'Index rebuilt successfully from $count operations',
      affectedCount: count,
      duration: sw.elapsed,
    );
  }
  
  /// Retry all failed operations.
  Future<RepairResult> _retryFailedOps(Stopwatch sw) async {
    if (!Hive.isBoxOpen(BoxRegistry.failedOpsBox)) {
      return RepairResult.success(
        action: RepairAction.retryFailedOps,
        message: 'Failed ops box not open, nothing to retry',
        affectedCount: 0,
        duration: sw.elapsed,
      );
    }
    
    if (!Hive.isBoxOpen(BoxRegistry.pendingOpsBox)) {
      return RepairResult.failure(
        action: RepairAction.retryFailedOps,
        error: 'Pending ops box not open',
        duration: sw.elapsed,
      );
    }
    
    final failedBox = Hive.box<FailedOpModel>(BoxRegistry.failedOpsBox);
    final pendingBox = Hive.box<PendingOp>(BoxRegistry.pendingOpsBox);
    
    int movedCount = 0;
    final failedOps = failedBox.values.toList();
    
    for (final failedOp in failedOps) {
      // Convert back to PendingOp with reset attempts
      final pendingOp = PendingOp(
        id: failedOp.id,
        opType: failedOp.opType,
        payload: failedOp.payload,
        createdAt: failedOp.createdAt,
        updatedAt: DateTime.now().toUtc(),
        attempts: 0, // Reset attempts
        status: 'pending',
        idempotencyKey: failedOp.idempotencyKey ?? failedOp.id,
      );
      
      await pendingBox.put(pendingOp.id, pendingOp);
      await failedBox.delete(failedOp.id);
      movedCount++;
    }
    
    return RepairResult.success(
      action: RepairAction.retryFailedOps,
      message: 'Moved $movedCount failed operations back to pending queue',
      affectedCount: movedCount,
      duration: sw.elapsed,
    );
  }
  
  /// Purge poison operations (exceed max attempts).
  Future<RepairResult> _purgePoisonOps(Stopwatch sw) async {
    if (!Hive.isBoxOpen(BoxRegistry.failedOpsBox)) {
      return RepairResult.success(
        action: RepairAction.purgePoisonOps,
        message: 'Failed ops box not open, nothing to purge',
        affectedCount: 0,
        duration: sw.elapsed,
      );
    }
    
    final failedBox = Hive.box<FailedOpModel>(BoxRegistry.failedOpsBox);
    
    // Find and delete poison ops
    int purgedCount = 0;
    final poisonOps = failedBox.values
        .where((op) => op.errorCode == 'POISON_OP')
        .toList();
    
    for (final op in poisonOps) {
      await failedBox.delete(op.id);
      purgedCount++;
    }
    
    return RepairResult.success(
      action: RepairAction.purgePoisonOps,
      message: 'Purged $purgedCount poison operations',
      affectedCount: purgedCount,
      duration: sw.elapsed,
    );
  }
  
  /// Verify encryption keys.
  Future<RepairResult> _verifyEncryption(Stopwatch sw) async {
    final summary = BoxPolicyRegistry.getSummary();
    
    if (summary.isHealthy) {
      return RepairResult.success(
        action: RepairAction.verifyEncryption,
        message: 'All ${summary.compliantCount} encrypted boxes are healthy',
        affectedCount: summary.compliantCount,
        duration: sw.elapsed,
      );
    }
    
    // Report issues
    return RepairResult.failure(
      action: RepairAction.verifyEncryption,
      error: 'Encryption health check failed: ${summary.violatedBoxes.join(", ")}',
      duration: sw.elapsed,
    );
  }
  
  /// Release stale processing locks.
  Future<RepairResult> _releaseStaleLocks(Stopwatch sw) async {
    if (!Hive.isBoxOpen(BoxRegistry.metaBox)) {
      return RepairResult.success(
        action: RepairAction.releaseStaleLocks,
        message: 'Meta box not open, no locks to release',
        affectedCount: 0,
        duration: sw.elapsed,
      );
    }
    
    final metaBox = BoxAccess.I.meta();
    final lockData = metaBox.get('processing_lock') as Map?;
    
    if (lockData == null) {
      return RepairResult.success(
        action: RepairAction.releaseStaleLocks,
        message: 'No active processing lock found',
        affectedCount: 0,
        duration: sw.elapsed,
      );
    }
    
    // Force release the lock
    await metaBox.delete('processing_lock');
    
    return RepairResult.success(
      action: RepairAction.releaseStaleLocks,
      message: 'Released processing lock held by ${lockData['pid']}',
      affectedCount: 1,
      duration: sw.elapsed,
    );
  }
  
  /// Release all entity ordering locks.
  Future<RepairResult> _releaseEntityLocks(Stopwatch sw) async {
    if (_queueService == null) {
      return RepairResult.failure(
        action: RepairAction.releaseEntityLocks,
        error: 'Queue service not available',
        duration: sw.elapsed,
      );
    }
    
    final lockCount = _queueService.lockedEntityCount;
    await _queueService.releaseAllEntityLocks();
    
    return RepairResult.success(
      action: RepairAction.releaseEntityLocks,
      message: 'Released $lockCount entity locks',
      affectedCount: lockCount,
      duration: sw.elapsed,
    );
  }
  
  /// Reset queue state to idle.
  Future<RepairResult> _resetQueueState(Stopwatch sw) async {
    if (_queueService == null) {
      return RepairResult.failure(
        action: RepairAction.resetQueueState,
        error: 'Queue service not available',
        duration: sw.elapsed,
      );
    }
    
    _queueService.resume(); // This sets state to idle
    
    return RepairResult.success(
      action: RepairAction.resetQueueState,
      message: 'Queue state reset to idle',
      affectedCount: 1,
      duration: sw.elapsed,
    );
  }
  
  /// Compact all Hive boxes.
  Future<RepairResult> _compactBoxes(Stopwatch sw) async {
    int compactedCount = 0;
    
    for (final boxName in BoxRegistry.allBoxes) {
      if (Hive.isBoxOpen(boxName)) {
        try {
          final box = BoxAccess.I.boxUntyped(boxName);
          await box.compact();
          compactedCount++;
        } catch (e) {
          // Log but continue with other boxes
          _telemetry.increment('repair.compact.box_error');
        }
      }
    }
    
    return RepairResult.success(
      action: RepairAction.compactBoxes,
      message: 'Compacted $compactedCount Hive boxes',
      affectedCount: compactedCount,
      duration: sw.elapsed,
    );
  }
}
