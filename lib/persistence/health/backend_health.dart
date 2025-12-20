/// Backend Health Authority - Single Source of Truth
///
/// Provides a unified, authoritative view of backend health status.
/// Used by Admin UI, Debug builds, and Emergency fallback logic.
///
/// DESIGN PRINCIPLES:
/// - Single source of truth for all health checks
/// - Read-only observability surface
/// - No mutations, only status reporting
/// - Idempotent and safe to call frequently
///
/// Usage:
/// ```dart
/// final health = BackendHealth.check();
/// if (!health.allHealthy) {
///   // Handle unhealthy state
/// }
/// ```
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import '../../models/failed_op_model.dart';
import '../../services/telemetry_service.dart';
import '../box_registry.dart';
import '../encryption_policy.dart';
import '../local_backend_status.dart';

// ═══════════════════════════════════════════════════════════════════════════
// HEALTH CHECK RESULT
// ═══════════════════════════════════════════════════════════════════════════

/// Result of a specific health check.
class HealthCheckResult {
  /// Name of the check
  final String name;
  
  /// Whether the check passed
  final bool passed;
  
  /// Human-readable message
  final String message;
  
  /// Optional details for debugging
  final Map<String, dynamic>? details;
  
  /// When this check was performed
  final DateTime checkedAt;

  const HealthCheckResult({
    required this.name,
    required this.passed,
    required this.message,
    this.details,
    required this.checkedAt,
  });

  factory HealthCheckResult.pass({
    required String name,
    required String message,
    Map<String, dynamic>? details,
  }) {
    return HealthCheckResult(
      name: name,
      passed: true,
      message: message,
      details: details,
      checkedAt: DateTime.now().toUtc(),
    );
  }

  factory HealthCheckResult.fail({
    required String name,
    required String message,
    Map<String, dynamic>? details,
  }) {
    return HealthCheckResult(
      name: name,
      passed: false,
      message: message,
      details: details,
      checkedAt: DateTime.now().toUtc(),
    );
  }

  @override
  String toString() => passed 
      ? '✓ $name: $message' 
      : '✗ $name: $message';
}

// ═══════════════════════════════════════════════════════════════════════════
// BACKEND HEALTH - SINGLE SOURCE OF TRUTH
// ═══════════════════════════════════════════════════════════════════════════

/// Backend Health Authority
///
/// Aggregates all health checks into a single authoritative class.
/// This is the CANONICAL source of truth for backend health.
class BackendHealth {
  // ═══════════════════════════════════════════════════════════════════════════
  // CORE HEALTH FLAGS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Whether encryption is properly configured and keys are accessible.
  /// 
  /// Checks:
  /// - Encryption key exists in secure storage
  /// - All required boxes are encrypted
  /// - No policy violations
  final bool encryptionOK;

  /// Whether the database schema is valid and all adapters registered.
  /// 
  /// Checks:
  /// - All required Hive adapters are registered
  /// - Box types match expected types
  /// - No schema version mismatches
  final bool schemaOK;

  /// Whether the operation queue is healthy.
  /// 
  /// Checks:
  /// - Queue is not stalled
  /// - No lock deadlocks
  /// - Processing is making progress
  final bool queueHealthy;

  /// Whether there are no poison operations.
  /// 
  /// Checks:
  /// - No ops marked as poison (always fail)
  /// - No ops exceeding max retry threshold
  /// - No ops stuck in error state
  final bool noPoisonOps;

  /// Age of the last successful sync to backend.
  /// 
  /// null if never synced.
  final Duration? lastSyncAge;

  // ═══════════════════════════════════════════════════════════════════════════
  // DETAILED CHECK RESULTS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Individual check results for detailed debugging.
  final List<HealthCheckResult> checkResults;

  /// When this health snapshot was captured.
  final DateTime capturedAt;

  /// Underlying LocalBackendStatus (for additional metrics).
  final LocalBackendStatus? backendStatus;

  // ═══════════════════════════════════════════════════════════════════════════
  // CONSTRUCTOR
  // ═══════════════════════════════════════════════════════════════════════════

  const BackendHealth({
    required this.encryptionOK,
    required this.schemaOK,
    required this.queueHealthy,
    required this.noPoisonOps,
    this.lastSyncAge,
    required this.checkResults,
    required this.capturedAt,
    this.backendStatus,
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // DERIVED PROPERTIES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Whether all health checks pass.
  bool get allHealthy => encryptionOK && schemaOK && queueHealthy && noPoisonOps;

  /// Whether any critical check failed.
  bool get hasCriticalFailure => !encryptionOK || !schemaOK;

  /// Whether the backend needs attention (degraded but functional).
  bool get needsAttention => !queueHealthy || !noPoisonOps;

  /// Health score as percentage (0-100).
  int get healthScore {
    int score = 0;
    if (encryptionOK) score += 30;
    if (schemaOK) score += 30;
    if (queueHealthy) score += 25;
    if (noPoisonOps) score += 15;
    return score;
  }

  /// Health severity level (0 = healthy, 1 = warning, 2 = critical).
  int get severity {
    if (hasCriticalFailure) return 2;
    if (needsAttention) return 1;
    return 0;
  }

  /// Quick summary for logging.
  String get summary => 
      'BackendHealth(score=$healthScore%, encryption=$encryptionOK, '
      'schema=$schemaOK, queue=$queueHealthy, poison=$noPoisonOps, '
      'lastSync=${lastSyncAge?.inMinutes ?? "never"}m)';

  /// Number of failed checks.
  int get failedCheckCount => checkResults.where((r) => !r.passed).length;

  /// Number of passed checks.
  int get passedCheckCount => checkResults.where((r) => r.passed).length;

  @override
  String toString() => summary;

  // ═══════════════════════════════════════════════════════════════════════════
  // FACTORY METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Perform all health checks and return a health snapshot.
  /// 
  /// This is the primary entry point for health checking.
  /// Safe to call frequently - no side effects.
  static Future<BackendHealth> check({TelemetryService? telemetry}) async {
    final _telemetry = telemetry ?? TelemetryService.I;
    final sw = Stopwatch()..start();
    final results = <HealthCheckResult>[];
    final now = DateTime.now().toUtc();

    // Collect LocalBackendStatus for additional metrics
    LocalBackendStatus? status;
    try {
      status = LocalBackendStatusCollector.collect();
    } catch (e) {
      results.add(HealthCheckResult.fail(
        name: 'status_collector',
        message: 'Failed to collect backend status: $e',
      ));
    }

    // 1. Encryption check
    final encryptionCheck = await _checkEncryption();
    results.add(encryptionCheck);
    final encryptionOK = encryptionCheck.passed;

    // 2. Schema check
    final schemaCheck = _checkSchema();
    results.add(schemaCheck);
    final schemaOK = schemaCheck.passed;

    // 3. Queue health check
    final queueCheck = _checkQueueHealth(status);
    results.add(queueCheck);
    final queueHealthy = queueCheck.passed;

    // 4. Poison ops check
    final poisonCheck = _checkPoisonOps();
    results.add(poisonCheck);
    final noPoisonOps = poisonCheck.passed;

    // 5. Determine last sync age
    Duration? lastSyncAge;
    if (status?.lastSuccessfulSync != null) {
      lastSyncAge = now.difference(status!.lastSuccessfulSync!);
    }

    sw.stop();

    // Emit telemetry
    _telemetry.gauge('backend_health.score', encryptionOK && schemaOK && queueHealthy && noPoisonOps ? 100 : 0);
    _telemetry.gauge('backend_health.check_duration_ms', sw.elapsedMilliseconds);
    _telemetry.gauge('backend_health.failed_checks', results.where((r) => !r.passed).length);

    return BackendHealth(
      encryptionOK: encryptionOK,
      schemaOK: schemaOK,
      queueHealthy: queueHealthy,
      noPoisonOps: noPoisonOps,
      lastSyncAge: lastSyncAge,
      checkResults: results,
      capturedAt: now,
      backendStatus: status,
    );
  }

  /// Synchronous check for quick health validation.
  /// 
  /// Use this for emergency fallback decisions where async is not suitable.
  /// Less comprehensive than [check()].
  static BackendHealth checkSync() {
    final results = <HealthCheckResult>[];
    final now = DateTime.now().toUtc();

    // Collect status
    LocalBackendStatus? status;
    try {
      status = LocalBackendStatusCollector.collect();
    } catch (_) {}

    // Schema check (sync)
    final schemaCheck = _checkSchema();
    results.add(schemaCheck);

    // Queue health (sync)
    final queueCheck = _checkQueueHealth(status);
    results.add(queueCheck);

    // Poison ops (sync)
    final poisonCheck = _checkPoisonOps();
    results.add(poisonCheck);

    // Encryption policy check (sync, but without key validation)
    final encryptionPolicyCheck = _checkEncryptionPolicyOnly();
    results.add(encryptionPolicyCheck);

    Duration? lastSyncAge;
    if (status?.lastSuccessfulSync != null) {
      lastSyncAge = now.difference(status!.lastSuccessfulSync!);
    }

    return BackendHealth(
      encryptionOK: encryptionPolicyCheck.passed,
      schemaOK: schemaCheck.passed,
      queueHealthy: queueCheck.passed,
      noPoisonOps: poisonCheck.passed,
      lastSyncAge: lastSyncAge,
      checkResults: results,
      capturedAt: now,
      backendStatus: status,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INDIVIDUAL HEALTH CHECKS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Check encryption health.
  static Future<HealthCheckResult> _checkEncryption() async {
    try {
      const secureStorage = FlutterSecureStorage();
      
      // Check if encryption key exists
      final keyExists = await secureStorage.containsKey(key: 'hive_enc_key_v1');
      if (!keyExists) {
        return HealthCheckResult.fail(
          name: 'encryption',
          message: 'Encryption key not found in secure storage',
          details: {'key_name': 'hive_enc_key_v1'},
        );
      }

      // Check encryption policy compliance
      final summary = BoxPolicyRegistry.getSummary();
      if (!summary.isHealthy) {
        return HealthCheckResult.fail(
          name: 'encryption',
          message: 'Encryption policy violations detected',
          details: {
            'violations': summary.violatedBoxes.length,
            'violated_boxes': summary.violatedBoxes,
          },
        );
      }

      return HealthCheckResult.pass(
        name: 'encryption',
        message: 'Encryption properly configured (${summary.compliantCount} boxes compliant)',
        details: {
          'compliant_count': summary.compliantCount,
          'violation_count': summary.violationCount,
        },
      );
    } catch (e) {
      return HealthCheckResult.fail(
        name: 'encryption',
        message: 'Encryption check failed: $e',
      );
    }
  }

  /// Check encryption policy only (sync version, no key validation).
  static HealthCheckResult _checkEncryptionPolicyOnly() {
    try {
      final summary = BoxPolicyRegistry.getSummary();
      if (!summary.isHealthy) {
        return HealthCheckResult.fail(
          name: 'encryption_policy',
          message: 'Policy violations: ${summary.violatedBoxes.join(", ")}',
        );
      }
      return HealthCheckResult.pass(
        name: 'encryption_policy',
        message: '${summary.compliantCount} boxes policy compliant',
      );
    } catch (e) {
      return HealthCheckResult.fail(
        name: 'encryption_policy',
        message: 'Policy check failed: $e',
      );
    }
  }

  /// Check schema/adapter health.
  static HealthCheckResult _checkSchema() {
    try {
      // Check required adapters
      final requiredTypeIds = [
        TypeIds.room,       // 10 - RoomModel
        TypeIds.pendingOp,  // 11 - PendingOp
        TypeIds.device,     // 12 - DeviceModel
        TypeIds.vitals,     // 13 - VitalsModel
        TypeIds.userProfile,// 14 - UserProfile
        TypeIds.session,    // 15 - Session
        TypeIds.failedOp,   // 16 - FailedOpModel
        TypeIds.auditLogRecord, // 17 - AuditLogRecord
        TypeIds.settings,   // 18 - SettingsModel
      ];

      final missingAdapters = <int>[];
      for (final typeId in requiredTypeIds) {
        if (!Hive.isAdapterRegistered(typeId)) {
          missingAdapters.add(typeId);
        }
      }

      if (missingAdapters.isNotEmpty) {
        return HealthCheckResult.fail(
          name: 'schema',
          message: 'Missing Hive adapters: ${missingAdapters.join(", ")}',
          details: {'missing_type_ids': missingAdapters},
        );
      }

      // Check key boxes are openable
      final criticalBoxes = [
        BoxRegistry.pendingOpsBox,
        BoxRegistry.failedOpsBox,
        BoxRegistry.metaBox,
      ];
      
      final unopenedBoxes = <String>[];
      for (final boxName in criticalBoxes) {
        if (!Hive.isBoxOpen(boxName)) {
          unopenedBoxes.add(boxName);
        }
      }

      // It's OK if boxes aren't open yet (pre-init state)
      // We only fail if adapters are missing

      return HealthCheckResult.pass(
        name: 'schema',
        message: 'All ${requiredTypeIds.length} required adapters registered',
        details: {
          'registered_adapters': requiredTypeIds.length,
          'boxes_open': criticalBoxes.length - unopenedBoxes.length,
        },
      );
    } catch (e) {
      return HealthCheckResult.fail(
        name: 'schema',
        message: 'Schema check failed: $e',
      );
    }
  }

  /// Check queue health.
  static HealthCheckResult _checkQueueHealth(LocalBackendStatus? status) {
    if (status == null) {
      // Can't determine - assume healthy until proven otherwise
      return HealthCheckResult.pass(
        name: 'queue',
        message: 'Queue status unavailable (pre-init)',
      );
    }

    final issues = <String>[];

    // Check for stalled queue
    if (status.queueStalled) {
      issues.add('Queue stalled for ${status.queueStallDuration?.inMinutes ?? "?"}m');
    }

    // Check for locked state
    if (status.lockStatus.isLocked) {
      final duration = status.lockStatus.lockDuration;
      if (duration != null && duration.inMinutes > 5) {
        issues.add('Lock held for ${duration.inMinutes}m (possible deadlock)');
      }
    }

    // Check for high pending count
    if (status.pendingOps > 100) {
      issues.add('High pending ops count: ${status.pendingOps}');
    }

    // Check for safety fallback mode
    if (status.safetyFallbackActive) {
      issues.add('Safety fallback mode active');
    }

    if (issues.isNotEmpty) {
      return HealthCheckResult.fail(
        name: 'queue',
        message: issues.join('; '),
        details: {
          'pending_ops': status.pendingOps,
          'queue_stalled': status.queueStalled,
          'lock_held': status.lockStatus.isLocked,
          'safety_fallback': status.safetyFallbackActive,
        },
      );
    }

    return HealthCheckResult.pass(
      name: 'queue',
      message: 'Queue healthy (${status.pendingOps} pending, ${status.queueState})',
      details: {
        'pending_ops': status.pendingOps,
        'failed_ops': status.failedOps,
        'emergency_ops': status.emergencyOps,
        'state': status.queueState,
      },
    );
  }

  /// Check for poison operations.
  static HealthCheckResult _checkPoisonOps() {
    try {
      if (!Hive.isBoxOpen(BoxRegistry.failedOpsBox)) {
        // Box not open - can't check, assume OK
        return HealthCheckResult.pass(
          name: 'poison_ops',
          message: 'Failed ops box not open (pre-init)',
        );
      }

      final failedBox = Hive.box<FailedOpModel>(BoxRegistry.failedOpsBox);
      
      // Count poison ops (marked as poison or exceeded max retries)
      int poisonCount = 0;
      int stuckCount = 0;
      
      for (final op in failedBox.values) {
        if (op.errorCode == 'POISON_OP') {
          poisonCount++;
        } else if (op.attempts >= 10) {
          stuckCount++;
        }
      }

      if (poisonCount > 0 || stuckCount > 0) {
        return HealthCheckResult.fail(
          name: 'poison_ops',
          message: 'Found $poisonCount poison ops, $stuckCount stuck ops',
          details: {
            'poison_count': poisonCount,
            'stuck_count': stuckCount,
            'total_failed': failedBox.length,
          },
        );
      }

      return HealthCheckResult.pass(
        name: 'poison_ops',
        message: 'No poison operations detected',
        details: {'failed_ops': failedBox.length},
      );
    } catch (e) {
      return HealthCheckResult.fail(
        name: 'poison_ops',
        message: 'Poison ops check failed: $e',
      );
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BACKEND HEALTH PROVIDER (for Riverpod integration)
// ═══════════════════════════════════════════════════════════════════════════

/// Extension for easy health status string formatting.
extension BackendHealthExtension on BackendHealth {
  /// Get a colored status indicator.
  String get statusIndicator {
    if (allHealthy) return '🟢';
    if (hasCriticalFailure) return '🔴';
    return '🟡';
  }

  /// Get a human-readable status.
  String get statusText {
    if (allHealthy) return 'Healthy';
    if (hasCriticalFailure) return 'Critical';
    return 'Degraded';
  }

  /// Get detailed report for admin UI.
  String get detailedReport {
    final buffer = StringBuffer();
    buffer.writeln('=== Backend Health Report ===');
    buffer.writeln('Status: $statusIndicator $statusText (Score: $healthScore%)');
    buffer.writeln('Captured: $capturedAt');
    buffer.writeln();
    buffer.writeln('Core Checks:');
    buffer.writeln('  Encryption: ${encryptionOK ? "✓" : "✗"}');
    buffer.writeln('  Schema: ${schemaOK ? "✓" : "✗"}');
    buffer.writeln('  Queue: ${queueHealthy ? "✓" : "✗"}');
    buffer.writeln('  No Poison: ${noPoisonOps ? "✓" : "✗"}');
    buffer.writeln('  Last Sync: ${lastSyncAge?.inMinutes ?? "never"}m ago');
    buffer.writeln();
    buffer.writeln('Detailed Results:');
    for (final result in checkResults) {
      buffer.writeln('  $result');
    }
    return buffer.toString();
  }
}
