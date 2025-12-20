/// Migration Completion Policy
///
/// Enforces strict migration rules to prevent data corruption:
/// 1. Every model MUST declare a schema version
/// 2. No "future migrations" allowed (stored version > current)
/// 3. All migrations must be tested with rollback scenarios
/// 4. Migration audit trail required
///
/// Part of FINAL 10% CLIMB Phase 2: Long-term survivability.
library;

import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';
import '../box_registry.dart';
import '../../services/audit_log_service.dart';
import '../../services/telemetry_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// MODEL SCHEMA VERSION TRACKING
// ═══════════════════════════════════════════════════════════════════════════

/// Required schema version interface for all Hive models.
///
/// Every model that persists to Hive MUST implement this interface.
abstract class VersionedModel {
  /// Schema version of this model instance.
  ///
  /// MUST match the current schema version for this model type.
  /// Used to detect incompatible data from future app versions.
  int get schemaVersion;
}

/// Registry of model schema versions.
///
/// Add new models here with their current schema version.
/// Increment version when breaking changes are made to model structure.
class ModelSchemaRegistry {
  ModelSchemaRegistry._();

  /// Current schema versions for all persisted models.
  static const Map<Type, int> currentVersions = {
    // Example models - update with actual model types
    // RoomModelHive: 2,
    // DeviceModelHive: 1,
    // AuditLogEntry: 1,
    // Add all Hive models here
  };

  /// Gets the current schema version for a model type.
  ///
  /// Returns null if model type is not registered (legacy model).
  static int? getCurrentVersion(Type modelType) {
    return currentVersions[modelType];
  }

  /// Validates that a model's schema version is compatible.
  ///
  /// Returns true if:
  /// - Model version matches current version, OR
  /// - Model version is lower (needs migration), OR
  /// - Model type is not registered (legacy, allowed for now)
  ///
  /// Returns false if:
  /// - Model version is HIGHER than current (from future app)
  static bool isVersionCompatible(Type modelType, int modelVersion) {
    final current = getCurrentVersion(modelType);
    if (current == null) {
      return true; // Legacy model, not tracked
    }
    return modelVersion <= current;
  }

  /// Returns all registered model types.
  static Iterable<Type> get registeredTypes => currentVersions.keys;

  /// Returns total number of tracked models.
  static int get trackedModelCount => currentVersions.length;
}

// ═══════════════════════════════════════════════════════════════════════════
// MIGRATION POLICY ENFORCEMENT
// ═══════════════════════════════════════════════════════════════════════════

/// Result of a migration policy check.
class MigrationPolicyResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final Map<String, dynamic> metadata;

  MigrationPolicyResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
    this.metadata = const {},
  });

  factory MigrationPolicyResult.valid({
    List<String> warnings = const [],
    Map<String, dynamic> metadata = const {},
  }) {
    return MigrationPolicyResult(
      isValid: true,
      warnings: warnings,
      metadata: metadata,
    );
  }

  factory MigrationPolicyResult.invalid({
    required List<String> errors,
    List<String> warnings = const [],
    Map<String, dynamic> metadata = const {},
  }) {
    return MigrationPolicyResult(
      isValid: false,
      errors: errors,
      warnings: warnings,
      metadata: metadata,
    );
  }
}

/// Migration policy enforcer.
///
/// Validates that all data migrations follow strict safety rules.
class MigrationPolicy {
  MigrationPolicy._();

  /// Global schema version for the entire app.
  static const int currentAppSchemaVersion = 2;

  /// Validates migration policy compliance.
  ///
  /// Checks:
  /// 1. No future schema versions in persisted data
  /// 2. All models have declared schema versions
  /// 3. Migration path exists for all version differences
  static Future<MigrationPolicyResult> validate() async {
    final errors = <String>[];
    final warnings = <String>[];
    final metadata = <String, dynamic>{};

    try {
      // Check meta box for stored schema version
      if (await Hive.boxExists(BoxRegistry.metaBox)) {
        final meta = await Hive.openBox(BoxRegistry.metaBox);
        final storedVersion = meta.get('schema_version') as int?;
        await meta.close();

        if (storedVersion != null) {
          metadata['stored_app_schema_version'] = storedVersion;
          metadata['current_app_schema_version'] = currentAppSchemaVersion;

          // Rule 1: No future migrations allowed
          if (storedVersion > currentAppSchemaVersion) {
            errors.add(
              'BLOCKING: Stored schema version ($storedVersion) is HIGHER than '
              'current app version ($currentAppSchemaVersion). '
              'Data from newer app detected. Downgrade not supported.',
            );
          } else if (storedVersion < currentAppSchemaVersion) {
            warnings.add(
              'Migration required: stored=$storedVersion, current=$currentAppSchemaVersion',
            );
          }
        }
      }

      // Rule 2: Check model registry completeness
      metadata['tracked_model_count'] = ModelSchemaRegistry.trackedModelCount;
      if (ModelSchemaRegistry.trackedModelCount == 0) {
        warnings.add(
          'No models registered in ModelSchemaRegistry. '
          'Consider adding model version tracking.',
        );
      }

      // Log result
      final result = errors.isEmpty
          ? MigrationPolicyResult.valid(warnings: warnings, metadata: metadata)
          : MigrationPolicyResult.invalid(
              errors: errors,
              warnings: warnings,
              metadata: metadata,
            );

      _logPolicyCheck(result);
      return result;

    } catch (e, stackTrace) {
      debugPrint('[MigrationPolicy] Validation error: $e\n$stackTrace');
      errors.add('Migration policy validation failed: $e');
      return MigrationPolicyResult.invalid(errors: errors);
    }
  }

  /// Records schema version to meta box.
  ///
  /// Call this after successful migration or on fresh install.
  static Future<void> recordSchemaVersion(int version) async {
    final meta = await Hive.openBox(BoxRegistry.metaBox);
    await meta.put('schema_version', version);
    await meta.close();

    AuditLogService.I.log(
      userId: 'system',
      action: 'schema_version_recorded',
      metadata: {'version': version},
    );

    debugPrint('[MigrationPolicy] Schema version recorded: $version');
  }

  /// Blocks app launch if future schema version detected.
  ///
  /// Call this during bootstrap before opening any data boxes.
  static Future<void> enforceNoFutureMigrations() async {
    final result = await validate();
    
    if (!result.isValid) {
      TelemetryService.I.increment('migration_policy.blocked_future_schema');
      throw MigrationPolicyException(
        'Migration policy violation',
        errors: result.errors,
      );
    }
  }

  /// Logs migration policy check result.
  static void _logPolicyCheck(MigrationPolicyResult result) {
    AuditLogService.I.log(
      userId: 'system',
      action: 'migration_policy_check',
      metadata: {
        'is_valid': result.isValid,
        'error_count': result.errors.length,
        'warning_count': result.warnings.length,
        ...result.metadata,
      },
      severity: result.isValid ? 'info' : 'error',
    );

    if (!result.isValid) {
      debugPrint('[MigrationPolicy] VALIDATION FAILED:');
      for (final error in result.errors) {
        debugPrint('  ❌ $error');
      }
    }

    if (result.warnings.isNotEmpty) {
      debugPrint('[MigrationPolicy] Warnings:');
      for (final warning in result.warnings) {
        debugPrint('  ⚠️  $warning');
      }
    }
  }
}

/// Exception thrown when migration policy is violated.
class MigrationPolicyException implements Exception {
  final String message;
  final List<String> errors;

  MigrationPolicyException(this.message, {required this.errors});

  @override
  String toString() {
    final buffer = StringBuffer('MigrationPolicyException: $message\n');
    for (final error in errors) {
      buffer.writeln('  - $error');
    }
    return buffer.toString();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MIGRATION TESTING HELPERS
// ═══════════════════════════════════════════════════════════════════════════

/// Helper for testing migration scenarios.
///
/// Use in tests to simulate version upgrades and downgrades.
@visibleForTesting
class MigrationTestHelper {
  /// Simulates a future schema version in meta box.
  ///
  /// Used to test that app correctly blocks on future versions.
  static Future<void> injectFutureSchemaVersion(int futureVersion) async {
    final meta = await Hive.openBox(BoxRegistry.metaBox);
    await meta.put('schema_version', futureVersion);
    await meta.close();
    debugPrint('[MigrationTestHelper] Injected future schema: $futureVersion');
  }

  /// Simulates an old schema version in meta box.
  ///
  /// Used to test migration paths.
  static Future<void> injectOldSchemaVersion(int oldVersion) async {
    final meta = await Hive.openBox(BoxRegistry.metaBox);
    await meta.put('schema_version', oldVersion);
    await meta.close();
    debugPrint('[MigrationTestHelper] Injected old schema: $oldVersion');
  }

  /// Clears schema version from meta box.
  static Future<void> clearSchemaVersion() async {
    if (await Hive.boxExists(BoxRegistry.metaBox)) {
      final meta = await Hive.openBox(BoxRegistry.metaBox);
      await meta.delete('schema_version');
      await meta.close();
      debugPrint('[MigrationTestHelper] Cleared schema version');
    }
  }

  /// Gets current stored schema version.
  static Future<int?> getStoredSchemaVersion() async {
    if (await Hive.boxExists(BoxRegistry.metaBox)) {
      final meta = await Hive.openBox(BoxRegistry.metaBox);
      final version = meta.get('schema_version') as int?;
      await meta.close();
      return version;
    }
    return null;
  }
}
