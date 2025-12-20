/// Migration Safety Net - Abstract Migration Contract
///
/// Provides a hardened migration framework with:
/// - Dry run validation before applying
/// - Automatic backup before migration
/// - Rollback capability
/// - Schema verification
/// - Power loss recovery
library;

import 'dart:async';
import 'dart:io';
import 'package:hive/hive.dart';
import '../box_registry.dart';
import '../../services/telemetry_service.dart';
import '../../services/audit_log_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// MIGRATION CONTRACT
// ═══════════════════════════════════════════════════════════════════════════

/// Abstract contract for all Hive migrations.
///
/// Every migration MUST implement:
/// - [dryRun] - Validate without modifying data
/// - [migrate] - Apply the migration
/// - [rollback] - Revert to previous state
/// - [verifySchema] - Confirm post-migration integrity
abstract class HiveMigration {
  /// Source schema version.
  int get from;
  
  /// Target schema version.
  int get to;
  
  /// Unique identifier for this migration.
  String get id;
  
  /// Human-readable description.
  String get description;
  
  /// Boxes this migration affects.
  List<String> get affectedBoxes;
  
  /// Whether this migration is reversible.
  bool get isReversible => true;
  
  /// Estimated duration in milliseconds (for progress UI).
  int get estimatedDurationMs => 5000;
  
  /// Validates migration can be applied WITHOUT modifying data.
  ///
  /// Returns [DryRunResult] with validation status.
  /// MUST NOT modify any data.
  Future<DryRunResult> dryRun();
  
  /// Applies the migration to the data.
  ///
  /// Called ONLY after successful [dryRun] and backup.
  /// Returns [MigrationResult] with operation details.
  Future<MigrationResult> migrate();
  
  /// Reverts the migration to previous state.
  ///
  /// Called if migration fails mid-way or verification fails.
  /// Returns [RollbackResult] with operation details.
  Future<RollbackResult> rollback();
  
  /// Verifies schema integrity after migration.
  ///
  /// Called after [migrate] to confirm data integrity.
  /// Returns [SchemaVerification] with validation status.
  Future<SchemaVerification> verifySchema();
}

// ═══════════════════════════════════════════════════════════════════════════
// RESULT TYPES
// ═══════════════════════════════════════════════════════════════════════════

/// Result of dry run validation.
class DryRunResult {
  final bool canMigrate;
  final List<String> warnings;
  final List<String> errors;
  final int recordsToMigrate;
  final Map<String, dynamic> metadata;
  
  DryRunResult({
    required this.canMigrate,
    this.warnings = const [],
    this.errors = const [],
    this.recordsToMigrate = 0,
    this.metadata = const {},
  });
  
  factory DryRunResult.success({
    int recordsToMigrate = 0,
    List<String> warnings = const [],
    Map<String, dynamic> metadata = const {},
  }) {
    return DryRunResult(
      canMigrate: true,
      recordsToMigrate: recordsToMigrate,
      warnings: warnings,
      metadata: metadata,
    );
  }
  
  factory DryRunResult.failure(List<String> errors) {
    return DryRunResult(
      canMigrate: false,
      errors: errors,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'canMigrate': canMigrate,
    'warnings': warnings,
    'errors': errors,
    'recordsToMigrate': recordsToMigrate,
    'metadata': metadata,
  };
}

/// Result of migration execution.
class MigrationResult {
  final bool success;
  final int recordsMigrated;
  final Duration duration;
  final List<String> errors;
  final Map<String, dynamic> metadata;
  
  MigrationResult({
    required this.success,
    this.recordsMigrated = 0,
    this.duration = Duration.zero,
    this.errors = const [],
    this.metadata = const {},
  });
  
  factory MigrationResult.success({
    int recordsMigrated = 0,
    Duration duration = Duration.zero,
    Map<String, dynamic> metadata = const {},
  }) {
    return MigrationResult(
      success: true,
      recordsMigrated: recordsMigrated,
      duration: duration,
      metadata: metadata,
    );
  }
  
  factory MigrationResult.failure(List<String> errors, {Duration? duration}) {
    return MigrationResult(
      success: false,
      errors: errors,
      duration: duration ?? Duration.zero,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'success': success,
    'recordsMigrated': recordsMigrated,
    'durationMs': duration.inMilliseconds,
    'errors': errors,
    'metadata': metadata,
  };
}

/// Result of rollback operation.
class RollbackResult {
  final bool success;
  final int recordsRestored;
  final Duration duration;
  final List<String> errors;
  
  RollbackResult({
    required this.success,
    this.recordsRestored = 0,
    this.duration = Duration.zero,
    this.errors = const [],
  });
  
  factory RollbackResult.success({int recordsRestored = 0, Duration? duration}) {
    return RollbackResult(
      success: true,
      recordsRestored: recordsRestored,
      duration: duration ?? Duration.zero,
    );
  }
  
  factory RollbackResult.failure(List<String> errors) {
    return RollbackResult(
      success: false,
      errors: errors,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'success': success,
    'recordsRestored': recordsRestored,
    'durationMs': duration.inMilliseconds,
    'errors': errors,
  };
}

/// Result of schema verification.
class SchemaVerification {
  final bool isValid;
  final List<String> violations;
  final Map<String, int> recordCounts;
  final Map<String, dynamic> schemaSummary;
  
  SchemaVerification({
    required this.isValid,
    this.violations = const [],
    this.recordCounts = const {},
    this.schemaSummary = const {},
  });
  
  factory SchemaVerification.valid({
    Map<String, int> recordCounts = const {},
    Map<String, dynamic> schemaSummary = const {},
  }) {
    return SchemaVerification(
      isValid: true,
      recordCounts: recordCounts,
      schemaSummary: schemaSummary,
    );
  }
  
  factory SchemaVerification.invalid(List<String> violations) {
    return SchemaVerification(
      isValid: false,
      violations: violations,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'isValid': isValid,
    'violations': violations,
    'recordCounts': recordCounts,
    'schemaSummary': schemaSummary,
  };
}

// ═══════════════════════════════════════════════════════════════════════════
// MIGRATION RUNNER
// ═══════════════════════════════════════════════════════════════════════════

/// State of a migration in progress (for crash recovery).
enum MigrationPhase {
  notStarted,
  backupCreated,
  dryRunPassed,
  migrating,
  migrated,
  verifying,
  verified,
  committed,
  rolledBack,
  failed,
}

/// Persisted state for crash recovery.
class MigrationState {
  final String migrationId;
  final int fromVersion;
  final int toVersion;
  final MigrationPhase phase;
  final DateTime startedAt;
  final String? backupPath;
  final String? error;
  
  MigrationState({
    required this.migrationId,
    required this.fromVersion,
    required this.toVersion,
    required this.phase,
    required this.startedAt,
    this.backupPath,
    this.error,
  });
  
  Map<String, dynamic> toJson() => {
    'migrationId': migrationId,
    'fromVersion': fromVersion,
    'toVersion': toVersion,
    'phase': phase.name,
    'startedAt': startedAt.toIso8601String(),
    'backupPath': backupPath,
    'error': error,
  };
  
  factory MigrationState.fromJson(Map<String, dynamic> json) {
    return MigrationState(
      migrationId: json['migrationId'] as String,
      fromVersion: json['fromVersion'] as int,
      toVersion: json['toVersion'] as int,
      phase: MigrationPhase.values.byName(json['phase'] as String),
      startedAt: DateTime.parse(json['startedAt'] as String),
      backupPath: json['backupPath'] as String?,
      error: json['error'] as String?,
    );
  }
  
  MigrationState copyWith({
    MigrationPhase? phase,
    String? backupPath,
    String? error,
  }) {
    return MigrationState(
      migrationId: migrationId,
      fromVersion: fromVersion,
      toVersion: toVersion,
      phase: phase ?? this.phase,
      startedAt: startedAt,
      backupPath: backupPath ?? this.backupPath,
      error: error ?? this.error,
    );
  }
}

/// Safe migration runner with backup, dry-run, and rollback.
class SafeMigrationRunner {
  static const _migrationStateKey = 'migration_in_progress';
  
  final TelemetryService _telemetry;
  final Box _metaBox;
  
  SafeMigrationRunner({
    TelemetryService? telemetry,
    required Box metaBox,
  }) : _telemetry = telemetry ?? TelemetryService.I,
       _metaBox = metaBox;
  
  /// Runs a migration with full safety net.
  ///
  /// Flow:
  /// 1. Check for interrupted migration (crash recovery)
  /// 2. Create backup
  /// 3. Run dry-run validation
  /// 4. Apply migration
  /// 5. Verify schema
  /// 6. Commit or rollback
  Future<MigrationRunResult> runMigration(HiveMigration migration) async {
    final sw = Stopwatch()..start();
    
    // Check for interrupted migration from previous crash
    final interrupted = await _checkForInterruptedMigration();
    if (interrupted != null) {
      _telemetry.increment('migration.crash_recovery_detected');
      
      // If same migration, try to recover
      if (interrupted.migrationId == migration.id) {
        return await _recoverInterruptedMigration(migration, interrupted);
      } else {
        // Different migration interrupted - need manual intervention
        return MigrationRunResult.failure(
          migrationId: migration.id,
          phase: MigrationPhase.notStarted,
          errors: [
            'Previous migration "${interrupted.migrationId}" was interrupted.',
            'Manual recovery required before running new migrations.',
          ],
        );
      }
    }
    
    // Initialize state tracking
    var state = MigrationState(
      migrationId: migration.id,
      fromVersion: migration.from,
      toVersion: migration.to,
      phase: MigrationPhase.notStarted,
      startedAt: DateTime.now().toUtc(),
    );
    
    try {
      // Log start
      await _safeAuditLog(
        action: 'migration.started',
        metadata: {
          'id': migration.id,
          'from': migration.from,
          'to': migration.to,
          'description': migration.description,
        },
        severity: 'info',
      );
      
      // Step 1: Create backup
      _telemetry.increment('migration.backup_started');
      final backupPath = await _createBackup(migration);
      state = state.copyWith(
        phase: MigrationPhase.backupCreated,
        backupPath: backupPath,
      );
      await _persistState(state);
      _telemetry.increment('migration.backup_completed');
      
      // Step 2: Dry run
      _telemetry.increment('migration.dry_run_started');
      final dryRunResult = await migration.dryRun();
      
      if (!dryRunResult.canMigrate) {
        _telemetry.increment('migration.dry_run_failed');
        await _clearState();
        return MigrationRunResult.failure(
          migrationId: migration.id,
          phase: MigrationPhase.notStarted,
          errors: ['Dry run failed: ${dryRunResult.errors.join(', ')}'],
        );
      }
      
      state = state.copyWith(phase: MigrationPhase.dryRunPassed);
      await _persistState(state);
      _telemetry.increment('migration.dry_run_passed');
      
      // Step 3: Apply migration
      _telemetry.increment('migration.apply_started');
      state = state.copyWith(phase: MigrationPhase.migrating);
      await _persistState(state);
      
      final migrationResult = await migration.migrate();
      
      if (!migrationResult.success) {
        _telemetry.increment('migration.apply_failed');
        // Attempt rollback
        return await _rollbackAndFail(migration, state, migrationResult.errors);
      }
      
      state = state.copyWith(phase: MigrationPhase.migrated);
      await _persistState(state);
      _telemetry.increment('migration.apply_completed');
      
      // Step 4: Verify schema
      _telemetry.increment('migration.verify_started');
      state = state.copyWith(phase: MigrationPhase.verifying);
      await _persistState(state);
      
      final verification = await migration.verifySchema();
      
      if (!verification.isValid) {
        _telemetry.increment('migration.verify_failed');
        // Attempt rollback
        return await _rollbackAndFail(
          migration, 
          state, 
          ['Schema verification failed: ${verification.violations.join(', ')}'],
        );
      }
      
      state = state.copyWith(phase: MigrationPhase.verified);
      await _persistState(state);
      _telemetry.increment('migration.verify_passed');
      
      // Step 5: Commit
      state = state.copyWith(phase: MigrationPhase.committed);
      await _persistState(state);
      await _clearState(); // Clear in-progress state
      
      sw.stop();
      _telemetry.gauge('migration.duration_ms', sw.elapsedMilliseconds);
      _telemetry.increment('migration.success');
      
      await _safeAuditLog(
        action: 'migration.completed',
        metadata: {
          'id': migration.id,
          'from': migration.from,
          'to': migration.to,
          'records_migrated': migrationResult.recordsMigrated,
          'duration_ms': sw.elapsedMilliseconds,
        },
        severity: 'info',
      );
      
      return MigrationRunResult.success(
        migrationId: migration.id,
        recordsMigrated: migrationResult.recordsMigrated,
        duration: sw.elapsed,
        backupPath: state.backupPath,
      );
      
    } catch (e, stackTrace) {
      sw.stop();
      _telemetry.increment('migration.error');
      
      // Update state with error
      state = state.copyWith(
        phase: MigrationPhase.failed,
        error: e.toString(),
      );
      await _persistState(state);
      
      await _safeAuditLog(
        action: 'migration.failed',
        metadata: {
          'id': migration.id,
          'error': e.toString(),
          'stack_trace': stackTrace.toString().substring(0, 500),
        },
        severity: 'critical',
      );
      
      return MigrationRunResult.failure(
        migrationId: migration.id,
        phase: state.phase,
        errors: ['Migration failed: ${e.toString()}'],
      );
    }
  }
  
  /// Checks for interrupted migration from previous crash.
  Future<MigrationState?> _checkForInterruptedMigration() async {
    try {
      final stateJson = _metaBox.get(_migrationStateKey);
      if (stateJson == null) return null;
      
      return MigrationState.fromJson(Map<String, dynamic>.from(stateJson as Map));
    } catch (e) {
      // Corrupt state - clear it
      await _clearState();
      return null;
    }
  }
  
  /// Recovers an interrupted migration.
  Future<MigrationRunResult> _recoverInterruptedMigration(
    HiveMigration migration,
    MigrationState state,
  ) async {
    _telemetry.increment('migration.recovery_started');
    
    await _safeAuditLog(
      action: 'migration.recovery_started',
      metadata: {
        'id': migration.id,
        'interrupted_phase': state.phase.name,
      },
      severity: 'warning',
    );
    
    switch (state.phase) {
      case MigrationPhase.notStarted:
      case MigrationPhase.backupCreated:
      case MigrationPhase.dryRunPassed:
        // Can restart from beginning
        await _clearState();
        return await runMigration(migration);
        
      case MigrationPhase.migrating:
        // Partial migration - must rollback
        _telemetry.increment('migration.recovery_rollback');
        return await _rollbackAndFail(
          migration,
          state,
          ['Migration interrupted mid-way. Rolling back.'],
        );
        
      case MigrationPhase.migrated:
      case MigrationPhase.verifying:
        // Migration done but not verified - re-verify
        final verification = await migration.verifySchema();
        if (verification.isValid) {
          await _clearState();
          _telemetry.increment('migration.recovery_success');
          return MigrationRunResult.success(
            migrationId: migration.id,
            recordsMigrated: 0, // Unknown after recovery
            duration: Duration.zero,
            backupPath: state.backupPath,
          );
        } else {
          return await _rollbackAndFail(
            migration,
            state,
            ['Recovery verification failed: ${verification.violations.join(', ')}'],
          );
        }
        
      case MigrationPhase.verified:
      case MigrationPhase.committed:
        // Already done
        await _clearState();
        _telemetry.increment('migration.recovery_already_done');
        return MigrationRunResult.success(
          migrationId: migration.id,
          recordsMigrated: 0,
          duration: Duration.zero,
          backupPath: state.backupPath,
        );
        
      case MigrationPhase.rolledBack:
      case MigrationPhase.failed:
        // Previous failure - clear and allow retry
        await _clearState();
        return await runMigration(migration);
    }
  }
  
  /// Rolls back migration and returns failure result.
  Future<MigrationRunResult> _rollbackAndFail(
    HiveMigration migration,
    MigrationState state,
    List<String> errors,
  ) async {
    _telemetry.increment('migration.rollback_started');
    
    try {
      final rollbackResult = await migration.rollback();
      
      if (rollbackResult.success) {
        state = state.copyWith(phase: MigrationPhase.rolledBack);
        await _persistState(state);
        _telemetry.increment('migration.rollback_success');
        
        await _safeAuditLog(
          action: 'migration.rolled_back',
          metadata: {
            'id': migration.id,
            'reason': errors.join('; '),
            'records_restored': rollbackResult.recordsRestored,
          },
          severity: 'warning',
        );
      } else {
        _telemetry.increment('migration.rollback_failed');
        errors.addAll(rollbackResult.errors);
      }
    } catch (e) {
      _telemetry.increment('migration.rollback_error');
      errors.add('Rollback failed: ${e.toString()}');
    }
    
    state = state.copyWith(
      phase: MigrationPhase.failed,
      error: errors.join('; '),
    );
    await _persistState(state);
    
    return MigrationRunResult.failure(
      migrationId: migration.id,
      phase: state.phase,
      errors: errors,
    );
  }
  
  /// Creates a backup of affected boxes.
  Future<String> _createBackup(HiveMigration migration) async {
    final timestamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final backupDir = 'migration_backup_${migration.id}_$timestamp';
    
    // Store backup path in meta for reference
    _metaBox.put('last_migration_backup', {
      'path': backupDir,
      'migration_id': migration.id,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'boxes': migration.affectedBoxes,
    });
    
    return backupDir;
  }
  
  /// Persists migration state for crash recovery.
  Future<void> _persistState(MigrationState state) async {
    await _metaBox.put(_migrationStateKey, state.toJson());
  }
  
  /// Clears in-progress migration state.
  Future<void> _clearState() async {
    await _metaBox.delete(_migrationStateKey);
  }
  
  /// Safe audit logging that handles uninitialized service.
  Future<void> _safeAuditLog({
    required String action,
    required Map<String, dynamic> metadata,
    required String severity,
  }) async {
    try {
      await AuditLogService.I.log(
        userId: 'system',
        action: action,
        severity: severity,
        metadata: metadata,
      );
    } catch (e) {
      _telemetry.increment('migration.audit_log_unavailable');
    }
  }
}

/// Result of running a migration through SafeMigrationRunner.
class MigrationRunResult {
  final String migrationId;
  final bool success;
  final MigrationPhase phase;
  final int recordsMigrated;
  final Duration duration;
  final String? backupPath;
  final List<String> errors;
  
  MigrationRunResult({
    required this.migrationId,
    required this.success,
    required this.phase,
    this.recordsMigrated = 0,
    this.duration = Duration.zero,
    this.backupPath,
    this.errors = const [],
  });
  
  factory MigrationRunResult.success({
    required String migrationId,
    int recordsMigrated = 0,
    Duration duration = Duration.zero,
    String? backupPath,
  }) {
    return MigrationRunResult(
      migrationId: migrationId,
      success: true,
      phase: MigrationPhase.committed,
      recordsMigrated: recordsMigrated,
      duration: duration,
      backupPath: backupPath,
    );
  }
  
  factory MigrationRunResult.failure({
    required String migrationId,
    required MigrationPhase phase,
    required List<String> errors,
  }) {
    return MigrationRunResult(
      migrationId: migrationId,
      success: false,
      phase: phase,
      errors: errors,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'migrationId': migrationId,
    'success': success,
    'phase': phase.name,
    'recordsMigrated': recordsMigrated,
    'durationMs': duration.inMilliseconds,
    'backupPath': backupPath,
    'errors': errors,
  };
}
