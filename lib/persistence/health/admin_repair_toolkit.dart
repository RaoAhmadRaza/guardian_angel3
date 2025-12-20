/// Admin Repair Toolkit - Strict Operations
///
/// Provides controlled repair actions for the admin console.
/// All operations are:
/// - CONFIRMED: Require explicit confirmation via biometric or token
/// - AUDITED: Full audit trail with before/after state
/// - IDEMPOTENT: Safe to retry multiple times
///
/// ALLOWED ACTIONS:
/// 1. Rebuild index - Reconstruct pending ops index from Hive box
/// 2. Retry failed ops - Move failed ops back to pending queue
/// 3. Verify encryption - Check encryption keys and policy compliance
/// 4. Compact boxes - Reclaim storage space in Hive boxes
///
/// SECURITY:
/// - All actions require biometric confirmation in production
/// - Full audit trail for compliance
/// - Telemetry for operational monitoring
///
/// Usage:
/// ```dart
/// final toolkit = AdminRepairToolkit(
///   auditLog: auditLogService,
///   telemetry: TelemetryService.I,
/// );
///
/// final token = toolkit.generateConfirmationToken(RepairActionType.rebuildIndex);
/// final result = await toolkit.execute(
///   action: RepairActionType.rebuildIndex,
///   userId: currentUserId,
///   confirmationToken: token,
///   reason: 'Index corrupted after crash',
/// );
/// ```
library;

import 'dart:async';
import 'package:hive/hive.dart';
import '../../models/pending_op.dart';
import '../../models/failed_op_model.dart';
import '../../services/audit_log_service.dart';
import '../../services/telemetry_service.dart';
import '../box_registry.dart';
import '../encryption_policy.dart';
import '../index/pending_index.dart';
import '../wrappers/box_accessor.dart';
import 'backend_health.dart';

// ═══════════════════════════════════════════════════════════════════════════
// REPAIR ACTION TYPES (Toolkit subset)
// ═══════════════════════════════════════════════════════════════════════════

/// Allowed repair actions in the admin toolkit.
/// 
/// This is a strict subset of all possible repair actions,
/// limited to safe, auditable operations.
enum RepairActionType {
  /// Rebuild the pending operations index from Hive box.
  /// IDEMPOTENT: Rebuilding again produces same result.
  rebuildIndex,
  
  /// Retry all failed operations.
  /// IDEMPOTENT: Re-retrying already moved ops is no-op.
  retryFailedOps,
  
  /// Verify encryption keys and policy compliance.
  /// IDEMPOTENT: Read-only verification.
  verifyEncryption,
  
  /// Compact all Hive boxes to reclaim space.
  /// IDEMPOTENT: Compacting already compacted box is no-op.
  compactBoxes,
}

extension RepairActionTypeExtension on RepairActionType {
  /// Human-readable action name.
  String get displayName {
    switch (this) {
      case RepairActionType.rebuildIndex:
        return 'Rebuild Index';
      case RepairActionType.retryFailedOps:
        return 'Retry Failed Ops';
      case RepairActionType.verifyEncryption:
        return 'Verify Encryption';
      case RepairActionType.compactBoxes:
        return 'Compact Boxes';
    }
  }

  /// Detailed description of what the action does.
  String get description {
    switch (this) {
      case RepairActionType.rebuildIndex:
        return 'Reconstructs the pending operations index from the Hive box. '
               'Safe to run at any time - will not lose data.';
      case RepairActionType.retryFailedOps:
        return 'Moves all failed operations back to the pending queue for retry. '
               'Resets attempt counters to allow fresh processing.';
      case RepairActionType.verifyEncryption:
        return 'Verifies encryption keys exist and all policies are satisfied. '
               'Read-only check with no modifications.';
      case RepairActionType.compactBoxes:
        return 'Compacts all Hive boxes to reclaim unused storage space. '
               'May improve performance for large boxes.';
    }
  }

  /// Risk level for UI display.
  String get riskLevel {
    switch (this) {
      case RepairActionType.verifyEncryption:
        return 'low'; // Read-only
      case RepairActionType.rebuildIndex:
      case RepairActionType.compactBoxes:
        return 'medium'; // Modifies indexes/storage
      case RepairActionType.retryFailedOps:
        return 'medium'; // Re-queues operations
    }
  }

  /// Estimated duration.
  String get estimatedDuration {
    switch (this) {
      case RepairActionType.verifyEncryption:
        return '< 1s';
      case RepairActionType.rebuildIndex:
        return '1-5s';
      case RepairActionType.retryFailedOps:
        return '1-10s (depends on count)';
      case RepairActionType.compactBoxes:
        return '5-30s (depends on size)';
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// REPAIR RESULT (Detailed)
// ═══════════════════════════════════════════════════════════════════════════

/// Result of a repair action with full context.
class RepairActionResult {
  /// Whether the action succeeded.
  final bool success;
  
  /// The action that was executed.
  final RepairActionType action;
  
  /// Human-readable result message.
  final String message;
  
  /// Number of items affected (operations moved, boxes compacted, etc).
  final int affectedCount;
  
  /// Duration the action took.
  final Duration duration;
  
  /// Error message (if failed).
  final String? error;
  
  /// State before the action (for audit).
  final Map<String, dynamic>? beforeState;
  
  /// State after the action (for audit).
  final Map<String, dynamic>? afterState;
  
  /// When the action was executed.
  final DateTime executedAt;
  
  /// Confirmation token used.
  final String confirmationToken;
  
  /// User who executed the action.
  final String userId;
  
  /// Reason provided for the action.
  final String? reason;

  const RepairActionResult({
    required this.success,
    required this.action,
    required this.message,
    required this.affectedCount,
    required this.duration,
    this.error,
    this.beforeState,
    this.afterState,
    required this.executedAt,
    required this.confirmationToken,
    required this.userId,
    this.reason,
  });

  /// Create a success result.
  factory RepairActionResult.success({
    required RepairActionType action,
    required String message,
    required int affectedCount,
    required Duration duration,
    required String confirmationToken,
    required String userId,
    Map<String, dynamic>? beforeState,
    Map<String, dynamic>? afterState,
    String? reason,
  }) {
    return RepairActionResult(
      success: true,
      action: action,
      message: message,
      affectedCount: affectedCount,
      duration: duration,
      beforeState: beforeState,
      afterState: afterState,
      executedAt: DateTime.now().toUtc(),
      confirmationToken: confirmationToken,
      userId: userId,
      reason: reason,
    );
  }

  /// Create a failure result.
  factory RepairActionResult.failure({
    required RepairActionType action,
    required String error,
    required Duration duration,
    required String confirmationToken,
    required String userId,
    String? reason,
  }) {
    return RepairActionResult(
      success: false,
      action: action,
      message: 'Action failed',
      affectedCount: 0,
      duration: duration,
      error: error,
      executedAt: DateTime.now().toUtc(),
      confirmationToken: confirmationToken,
      userId: userId,
      reason: reason,
    );
  }

  @override
  String toString() => success
      ? 'RepairActionResult.success(${action.name}: $message, affected=$affectedCount)'
      : 'RepairActionResult.failure(${action.name}: $error)';

  /// Convert to audit log metadata.
  Map<String, dynamic> toAuditMetadata() => {
    'action': action.name,
    'success': success,
    'message': message,
    'affected_count': affectedCount,
    'duration_ms': duration.inMilliseconds,
    'error': error,
    'before_state': beforeState,
    'after_state': afterState,
    'confirmation_token': confirmationToken,
    'reason': reason,
  };
}

// ═══════════════════════════════════════════════════════════════════════════
// ADMIN REPAIR TOOLKIT
// ═══════════════════════════════════════════════════════════════════════════

/// Admin Repair Toolkit - Strict operations with confirmation and audit.
///
/// All operations are:
/// - CONFIRMED: Require explicit confirmation token
/// - AUDITED: Full before/after state logging
/// - IDEMPOTENT: Safe to retry multiple times
class AdminRepairToolkit {
  final AuditLogService _auditLog;
  final TelemetryService _telemetry;
  
  /// Token prefix for validation.
  static const String _tokenPrefix = 'REPAIR_';
  
  /// Token validity duration.
  static const Duration _tokenValidityDuration = Duration(minutes: 5);

  AdminRepairToolkit({
    AuditLogService? auditLog,
    TelemetryService? telemetry,
  }) : _auditLog = auditLog ?? AuditLogService.I,
       _telemetry = telemetry ?? TelemetryService.I;

  /// Factory to create with default services.
  static AdminRepairToolkit create() => AdminRepairToolkit();

  // ═══════════════════════════════════════════════════════════════════════════
  // CONFIRMATION TOKEN MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════════

  /// Generate a confirmation token for an action.
  /// 
  /// Tokens are time-limited and action-specific.
  String generateConfirmationToken(RepairActionType action) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$_tokenPrefix${action.name.toUpperCase()}_$timestamp';
  }

  /// Validate a confirmation token.
  /// 
  /// Returns true if:
  /// - Token has correct prefix
  /// - Token is for the correct action
  /// - Token is not expired (within 5 minutes)
  bool validateToken(RepairActionType action, String token) {
    final expectedPrefix = '$_tokenPrefix${action.name.toUpperCase()}_';
    if (!token.startsWith(expectedPrefix)) return false;
    
    // Extract timestamp and check expiry
    final timestampStr = token.substring(expectedPrefix.length);
    final timestamp = int.tryParse(timestampStr);
    if (timestamp == null) return false;
    
    final tokenTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final age = DateTime.now().difference(tokenTime);
    
    return age <= _tokenValidityDuration;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACTION EXECUTION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Execute a repair action.
  /// 
  /// All actions are:
  /// - Validated against the confirmation token
  /// - Audited with before/after state
  /// - Measured with telemetry
  /// - Idempotent (safe to retry)
  Future<RepairActionResult> execute({
    required RepairActionType action,
    required String userId,
    required String confirmationToken,
    String? reason,
  }) async {
    final sw = Stopwatch()..start();
    
    // 1. Validate confirmation token
    if (!validateToken(action, confirmationToken)) {
      _telemetry.increment('admin_repair.invalid_token');
      return RepairActionResult.failure(
        action: action,
        error: 'Invalid or expired confirmation token',
        duration: sw.elapsed,
        confirmationToken: confirmationToken,
        userId: userId,
        reason: reason,
      );
    }

    // 2. Capture before state
    final beforeState = await _captureState(action);
    
    // 3. Log action start
    await _safeAuditLog(
      userId: userId,
      auditAction: 'admin_repair.${action.name}.started',
      entityType: 'repair_toolkit',
      entityId: confirmationToken,
      metadata: {
        'action': action.name,
        'reason': reason ?? 'No reason provided',
        'risk_level': action.riskLevel,
        'before_state': beforeState,
      },
      severity: 'warning',
    );
    
    _telemetry.increment('admin_repair.${action.name}.started');

    try {
      // 4. Execute the action
      final result = await _executeAction(
        action: action,
        userId: userId,
        confirmationToken: confirmationToken,
        beforeState: beforeState,
        reason: reason,
        sw: sw,
      );

      // 5. Capture after state
      final afterState = await _captureState(action);

      // 6. Log completion
      await _safeAuditLog(
        userId: userId,
        auditAction: 'admin_repair.${action.name}.completed',
        entityType: 'repair_toolkit',
        entityId: confirmationToken,
        metadata: result.toAuditMetadata()..['after_state'] = afterState,
        severity: result.success ? 'info' : 'critical',
      );

      _telemetry.increment('admin_repair.${action.name}.${result.success ? "success" : "failed"}');
      _telemetry.gauge('admin_repair.${action.name}.duration_ms', sw.elapsedMilliseconds);
      _telemetry.gauge('admin_repair.${action.name}.affected', result.affectedCount);

      return result;
    } catch (e, stackTrace) {
      sw.stop();

      // Log failure
      await _safeAuditLog(
        userId: userId,
        auditAction: 'admin_repair.${action.name}.error',
        entityType: 'repair_toolkit',
        entityId: confirmationToken,
        metadata: {
          'error': e.toString(),
          'stack_trace': stackTrace.toString().take(500),
          'before_state': beforeState,
        },
        severity: 'critical',
      );

      _telemetry.increment('admin_repair.${action.name}.error');

      return RepairActionResult.failure(
        action: action,
        error: e.toString(),
        duration: sw.elapsed,
        confirmationToken: confirmationToken,
        userId: userId,
        reason: reason,
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACTION IMPLEMENTATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<RepairActionResult> _executeAction({
    required RepairActionType action,
    required String userId,
    required String confirmationToken,
    required Map<String, dynamic> beforeState,
    required Stopwatch sw,
    String? reason,
  }) async {
    switch (action) {
      case RepairActionType.rebuildIndex:
        return await _rebuildIndex(userId, confirmationToken, beforeState, sw, reason);
      case RepairActionType.retryFailedOps:
        return await _retryFailedOps(userId, confirmationToken, beforeState, sw, reason);
      case RepairActionType.verifyEncryption:
        return await _verifyEncryption(userId, confirmationToken, beforeState, sw, reason);
      case RepairActionType.compactBoxes:
        return await _compactBoxes(userId, confirmationToken, beforeState, sw, reason);
    }
  }

  /// Rebuild the pending operations index.
  /// IDEMPOTENT: Running multiple times produces same result.
  Future<RepairActionResult> _rebuildIndex(
    String userId,
    String confirmationToken,
    Map<String, dynamic> beforeState,
    Stopwatch sw,
    String? reason,
  ) async {
    final index = await PendingIndex.create();
    await index.rebuild();

    int indexedCount = 0;
    if (Hive.isBoxOpen(BoxRegistry.pendingOpsBox)) {
      final pendingBox = Hive.box<PendingOp>(BoxRegistry.pendingOpsBox);
      indexedCount = pendingBox.length;
    }

    return RepairActionResult.success(
      action: RepairActionType.rebuildIndex,
      message: 'Index rebuilt with $indexedCount operations',
      affectedCount: indexedCount,
      duration: sw.elapsed,
      confirmationToken: confirmationToken,
      userId: userId,
      beforeState: beforeState,
      reason: reason,
    );
  }

  /// Retry all failed operations.
  /// IDEMPOTENT: Re-running when no failed ops does nothing.
  Future<RepairActionResult> _retryFailedOps(
    String userId,
    String confirmationToken,
    Map<String, dynamic> beforeState,
    Stopwatch sw,
    String? reason,
  ) async {
    if (!Hive.isBoxOpen(BoxRegistry.failedOpsBox)) {
      return RepairActionResult.success(
        action: RepairActionType.retryFailedOps,
        message: 'Failed ops box not open, nothing to retry',
        affectedCount: 0,
        duration: sw.elapsed,
        confirmationToken: confirmationToken,
        userId: userId,
        beforeState: beforeState,
        reason: reason,
      );
    }

    if (!Hive.isBoxOpen(BoxRegistry.pendingOpsBox)) {
      return RepairActionResult.failure(
        action: RepairActionType.retryFailedOps,
        error: 'Pending ops box not open',
        duration: sw.elapsed,
        confirmationToken: confirmationToken,
        userId: userId,
        reason: reason,
      );
    }

    final failedBox = Hive.box<FailedOpModel>(BoxRegistry.failedOpsBox);
    final pendingBox = Hive.box<PendingOp>(BoxRegistry.pendingOpsBox);

    int movedCount = 0;
    final failedOps = failedBox.values.toList();

    for (final failedOp in failedOps) {
      // Skip if already exists in pending (idempotent)
      if (pendingBox.containsKey(failedOp.id)) {
        continue;
      }

      // Convert to PendingOp with reset attempts
      final pendingOp = PendingOp(
        id: failedOp.id,
        opType: failedOp.opType,
        payload: failedOp.payload,
        createdAt: failedOp.createdAt,
        updatedAt: DateTime.now().toUtc(),
        attempts: 0, // Reset
        status: 'pending',
        idempotencyKey: failedOp.idempotencyKey ?? failedOp.id,
      );

      await pendingBox.put(pendingOp.id, pendingOp);
      await failedBox.delete(failedOp.id);
      movedCount++;
    }

    return RepairActionResult.success(
      action: RepairActionType.retryFailedOps,
      message: 'Moved $movedCount failed operations to pending queue',
      affectedCount: movedCount,
      duration: sw.elapsed,
      confirmationToken: confirmationToken,
      userId: userId,
      beforeState: beforeState,
      reason: reason,
    );
  }

  /// Verify encryption configuration.
  /// IDEMPOTENT: Read-only verification.
  Future<RepairActionResult> _verifyEncryption(
    String userId,
    String confirmationToken,
    Map<String, dynamic> beforeState,
    Stopwatch sw,
    String? reason,
  ) async {
    final health = await BackendHealth.check();
    
    final summary = BoxPolicyRegistry.getSummary();
    
    if (health.encryptionOK) {
      return RepairActionResult.success(
        action: RepairActionType.verifyEncryption,
        message: 'Encryption verified: ${summary.compliantCount} boxes compliant',
        affectedCount: summary.compliantCount,
        duration: sw.elapsed,
        confirmationToken: confirmationToken,
        userId: userId,
        beforeState: beforeState,
        afterState: {
          'compliant_count': summary.compliantCount,
          'violation_count': summary.violationCount,
          'encryption_ok': true,
        },
        reason: reason,
      );
    }

    return RepairActionResult.failure(
      action: RepairActionType.verifyEncryption,
      error: 'Encryption verification failed: ${summary.violatedBoxes.join(", ")}',
      duration: sw.elapsed,
      confirmationToken: confirmationToken,
      userId: userId,
      reason: reason,
    );
  }

  /// Compact all Hive boxes.
  /// IDEMPOTENT: Compacting already-compact boxes is safe.
  Future<RepairActionResult> _compactBoxes(
    String userId,
    String confirmationToken,
    Map<String, dynamic> beforeState,
    Stopwatch sw,
    String? reason,
  ) async {
    int compactedCount = 0;
    final errors = <String>[];

    for (final boxName in BoxRegistry.allBoxes) {
      if (Hive.isBoxOpen(boxName)) {
        try {
          final box = BoxAccess.I.boxUntyped(boxName);
          await box.compact();
          compactedCount++;;
        } catch (e) {
          errors.add('$boxName: $e');
          _telemetry.increment('admin_repair.compact.box_error');
        }
      }
    }

    if (errors.isNotEmpty) {
      return RepairActionResult.success(
        action: RepairActionType.compactBoxes,
        message: 'Compacted $compactedCount boxes with ${errors.length} errors',
        affectedCount: compactedCount,
        duration: sw.elapsed,
        confirmationToken: confirmationToken,
        userId: userId,
        beforeState: beforeState,
        afterState: {
          'compacted_count': compactedCount,
          'errors': errors,
        },
        reason: reason,
      );
    }

    return RepairActionResult.success(
      action: RepairActionType.compactBoxes,
      message: 'Compacted $compactedCount Hive boxes',
      affectedCount: compactedCount,
      duration: sw.elapsed,
      confirmationToken: confirmationToken,
      userId: userId,
      beforeState: beforeState,
      reason: reason,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Capture current state for audit trail.
  Future<Map<String, dynamic>> _captureState(RepairActionType action) async {
    final state = <String, dynamic>{
      'captured_at': DateTime.now().toUtc().toIso8601String(),
    };

    switch (action) {
      case RepairActionType.rebuildIndex:
        if (Hive.isBoxOpen(BoxRegistry.pendingOpsBox)) {
          state['pending_count'] = BoxAccess.I.pendingOps().length;
        }
        if (Hive.isBoxOpen(BoxRegistry.pendingIndexBox)) {
          state['index_count'] = BoxAccess.I.pendingIndex().length;
        }
        break;

      case RepairActionType.retryFailedOps:
        if (Hive.isBoxOpen(BoxRegistry.failedOpsBox)) {
          state['failed_count'] = BoxAccess.I.failedOps().length;
        }
        if (Hive.isBoxOpen(BoxRegistry.pendingOpsBox)) {
          state['pending_count'] = BoxAccess.I.pendingOps().length;
        }
        break;

      case RepairActionType.verifyEncryption:
        final summary = BoxPolicyRegistry.getSummary();
        state['compliant_count'] = summary.compliantCount;
        state['violated_count'] = summary.violatedBoxes.length;
        break;

      case RepairActionType.compactBoxes:
        int openCount = 0;
        for (final boxName in BoxRegistry.allBoxes) {
          if (Hive.isBoxOpen(boxName)) openCount++;
        }
        state['open_boxes'] = openCount;
        break;
    }

    return state;
  }

  /// Safe audit log wrapper.
  Future<void> _safeAuditLog({
    required String userId,
    required String auditAction,
    String? entityType,
    String? entityId,
    Map<String, dynamic>? metadata,
    String severity = 'info',
  }) async {
    try {
      await _auditLog.log(
        userId: userId,
        action: auditAction,
        entityType: entityType,
        entityId: entityId,
        metadata: metadata,
        severity: severity,
      );
    } catch (e) {
      // Audit service may not be initialized
      _telemetry.increment('admin_repair.audit_log_unavailable');
    }
  }
}

/// Extension for String.take (truncate helper).
extension StringTakeExtension on String {
  String take(int count) => length <= count ? this : substring(0, count);
}
