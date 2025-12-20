/// Startup Validator - Blocks app launch on critical failures
///
/// Performs comprehensive validation at app startup:
/// - Schema validation
/// - Adapter registration check
/// - Box integrity verification
/// - Recovery from previous failures
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'schema_validator.dart';
import '../box_registry.dart';
import '../../services/telemetry_service.dart';
import '../../services/audit_log_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// STARTUP VALIDATOR
// ═══════════════════════════════════════════════════════════════════════════

/// Startup validation result and status.
enum StartupStatus {
  /// Validation passed, app can launch.
  ready,
  
  /// Validation failed, app MUST NOT launch normally.
  blocked,
  
  /// Needs migration before app can launch.
  needsMigration,
  
  /// Needs recovery actions before app can launch.
  needsRecovery,
}

/// Result of startup validation.
class StartupValidationResult {
  final StartupStatus status;
  final SchemaValidationResult? schemaValidation;
  final List<String> blockers;
  final List<String> warnings;
  final List<RecoveryAction> recoveryActions;
  final int validationDurationMs;
  
  StartupValidationResult({
    required this.status,
    this.schemaValidation,
    this.blockers = const [],
    this.warnings = const [],
    this.recoveryActions = const [],
    this.validationDurationMs = 0,
  });
  
  bool get canLaunch => status == StartupStatus.ready;
  bool get needsUserAction => 
    status == StartupStatus.blocked || 
    status == StartupStatus.needsRecovery;
  
  Map<String, dynamic> toJson() => {
    'status': status.name,
    'canLaunch': canLaunch,
    'blockers': blockers,
    'warnings': warnings,
    'recoveryActions': recoveryActions.map((a) => a.toJson()).toList(),
    'validationDurationMs': validationDurationMs,
    'schemaValidation': schemaValidation?.toJson(),
  };
}

/// A recovery action that can be performed.
class RecoveryAction {
  final String id;
  final String title;
  final String description;
  final RecoveryActionType type;
  final bool isDestructive;
  
  RecoveryAction({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    this.isDestructive = false,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'type': type.name,
    'isDestructive': isDestructive,
  };
}

enum RecoveryActionType {
  clearCorruptedBox,
  clearAllData,
  runMigration,
  restoreBackup,
  updateApp,
}

/// Validates app can start safely.
class StartupValidator {
  final TelemetryService _telemetry;
  
  StartupValidator({TelemetryService? telemetry}) 
    : _telemetry = telemetry ?? TelemetryService.I;
  
  /// Performs full startup validation.
  ///
  /// Returns [StartupValidationResult] with status and any required actions.
  Future<StartupValidationResult> validate() async {
    final sw = Stopwatch()..start();
    final blockers = <String>[];
    final warnings = <String>[];
    final recoveryActions = <RecoveryAction>[];
    
    try {
      _telemetry.increment('startup_validator.started');
      
      // 1. Schema validation
      final schemaResult = await SchemaValidator.verify(strict: false);
      
      if (!schemaResult.isValid) {
        // Add blockers from schema validation
        blockers.addAll(schemaResult.errors);
        
        // Determine recovery actions
        if (schemaResult.missingAdapters.isNotEmpty) {
          // This is a code bug - no user recovery possible
          blockers.add('Critical: Missing adapters. App update required.');
        }
        
        if (schemaResult.collisions.isNotEmpty) {
          // This is a code bug - no user recovery possible
          blockers.add('Critical: TypeId collision detected. App update required.');
        }
        
        if (schemaResult.corruptedBoxes.isNotEmpty) {
          for (final box in schemaResult.corruptedBoxes) {
            recoveryActions.add(RecoveryAction(
              id: 'clear_box_$box',
              title: 'Clear corrupted box: $box',
              description: 'Delete the corrupted "$box" data. Some data may be lost.',
              type: RecoveryActionType.clearCorruptedBox,
              isDestructive: true,
            ));
          }
        }
        
        if (schemaResult.storedSchemaVersion != null &&
            schemaResult.storedSchemaVersion! > SchemaValidator.currentSchemaVersion) {
          recoveryActions.add(RecoveryAction(
            id: 'update_app',
            title: 'Update App',
            description: 'Your data was created by a newer app version. Please update.',
            type: RecoveryActionType.updateApp,
          ));
          
          recoveryActions.add(RecoveryAction(
            id: 'clear_all_data',
            title: 'Clear All Data',
            description: 'Delete all app data and start fresh. ALL DATA WILL BE LOST.',
            type: RecoveryActionType.clearAllData,
            isDestructive: true,
          ));
        }
      }
      
      // Add warnings from schema validation
      warnings.addAll(schemaResult.warnings);
      
      // Determine migration needs
      if (schemaResult.needsMigration) {
        recoveryActions.add(RecoveryAction(
          id: 'run_migration',
          title: 'Run Migration',
          description: 'Upgrade data to latest version. This is automatic and safe.',
          type: RecoveryActionType.runMigration,
        ));
      }
      
      sw.stop();
      
      // Determine final status
      StartupStatus status;
      if (blockers.isNotEmpty && recoveryActions.isEmpty) {
        status = StartupStatus.blocked;
        _telemetry.increment('startup_validator.blocked');
      } else if (recoveryActions.isNotEmpty) {
        if (schemaResult.needsMigration && blockers.isEmpty) {
          status = StartupStatus.needsMigration;
          _telemetry.increment('startup_validator.needs_migration');
        } else {
          status = StartupStatus.needsRecovery;
          _telemetry.increment('startup_validator.needs_recovery');
        }
      } else {
        status = StartupStatus.ready;
        _telemetry.increment('startup_validator.ready');
      }
      
      _telemetry.gauge('startup_validator.duration_ms', sw.elapsedMilliseconds);
      
      // Log critical if blocked
      if (status == StartupStatus.blocked) {
        await _safeAuditLog(
          action: 'startup_validation.blocked',
          metadata: {
            'blockers': blockers,
            'schema_errors': schemaResult.errors,
          },
          severity: 'critical',
        );
      }
      
      return StartupValidationResult(
        status: status,
        schemaValidation: schemaResult,
        blockers: blockers,
        warnings: warnings,
        recoveryActions: recoveryActions,
        validationDurationMs: sw.elapsedMilliseconds,
      );
      
    } catch (e, stackTrace) {
      sw.stop();
      _telemetry.increment('startup_validator.error');
      
      blockers.add('Validation error: ${e.toString()}');
      
      await _safeAuditLog(
        action: 'startup_validation.error',
        metadata: {
          'error': e.toString(),
          'stack_trace': stackTrace.toString().substring(0, 500),
        },
        severity: 'critical',
      );
      
      return StartupValidationResult(
        status: StartupStatus.blocked,
        blockers: blockers,
        warnings: warnings,
        recoveryActions: [
          RecoveryAction(
            id: 'clear_all_data',
            title: 'Clear All Data',
            description: 'Delete all app data and start fresh. ALL DATA WILL BE LOST.',
            type: RecoveryActionType.clearAllData,
            isDestructive: true,
          ),
        ],
        validationDurationMs: sw.elapsedMilliseconds,
      );
    }
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
      _telemetry.increment('startup_validator.audit_log_unavailable');
    }
  }
}
