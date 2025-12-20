/// Schema Validator - Adapter & Box Self-Validation
///
/// On startup, validates that:
/// - All expected adapters are registered
/// - All expected boxes exist and are accessible
/// - No TypeId collisions exist
/// - Schema versions are consistent
///
/// On failure:
/// - Blocks app launch (safe fail)
/// - Shows recovery instructions
/// - Logs critical audit event
library;

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../box_registry.dart';
import '../type_ids.dart';
import '../adapter_collision_guard.dart';
import '../../services/telemetry_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SCHEMA VALIDATOR
// ═══════════════════════════════════════════════════════════════════════════

/// Validates Hive schema integrity on startup.
///
/// Throws [SchemaValidationException] if validation fails.
/// This MUST be called before opening any boxes.
class SchemaValidator {
  SchemaValidator._();
  
  /// Expected schema version for the app.
  static const int currentSchemaVersion = 2;
  
  /// Expected adapter TypeIds and their names.
  /// Sourced from the authoritative TypeIds registry.
  static Map<int, String> get expectedAdapters => TypeIds.registry;
  
  /// Expected boxes that must exist.
  static List<String> get expectedBoxes => BoxRegistry.allBoxes;
  
  /// Performs full schema validation.
  ///
  /// Call this BEFORE opening boxes but AFTER registering adapters.
  /// 
  /// Returns [SchemaValidationResult] with validation status.
  /// In strict mode, throws [SchemaValidationException] on failure.
  static Future<SchemaValidationResult> verify({
    bool strict = true,
    TelemetryService? telemetry,
  }) async {
    final tel = telemetry ?? TelemetryService.I;
    final sw = Stopwatch()..start();
    
    final result = SchemaValidationResult();
    
    try {
      // 1. Validate adapters registered
      _validateAdapters(result);
      
      // 2. Check for TypeId collisions
      _checkCollisions(result);
      
      // 3. Validate box accessibility (if they exist)
      await _validateBoxes(result);
      
      // 4. Check schema version consistency
      await _checkSchemaVersion(result);
      
      sw.stop();
      result.validationDurationMs = sw.elapsedMilliseconds;
      
      tel.gauge('schema_validator.duration_ms', sw.elapsedMilliseconds);
      tel.gauge('schema_validator.error_count', result.errors.length);
      tel.gauge('schema_validator.warning_count', result.warnings.length);
      
      if (result.isValid) {
        tel.increment('schema_validator.success');
      } else {
        tel.increment('schema_validator.failure');
        
        if (strict) {
          throw SchemaValidationException(result);
        }
      }
      
      return result;
      
    } catch (e) {
      sw.stop();
      
      if (e is SchemaValidationException) {
        rethrow;
      }
      
      result.errors.add('Unexpected validation error: ${e.toString()}');
      tel.increment('schema_validator.unexpected_error');
      
      if (strict) {
        throw SchemaValidationException(result);
      }
      
      return result;
    }
  }
  
  /// Validates that all expected adapters are registered.
  static void _validateAdapters(SchemaValidationResult result) {
    // Check each expected adapter from the authoritative TypeIds registry
    for (final entry in expectedAdapters.entries) {
      final typeId = entry.key;
      final name = entry.value;
      
      if (!Hive.isAdapterRegistered(typeId)) {
        result.missingAdapters.add(AdapterInfo(typeId: typeId, name: name));
        result.errors.add('Missing adapter: $name (TypeId: $typeId)');
      } else {
        result.registeredAdapters.add(AdapterInfo(typeId: typeId, name: name));
      }
    }
    
    // Check for unexpected adapters (not in TypeIds registry - potential conflicts)
    for (int id = 0; id < 100; id++) {
      if (Hive.isAdapterRegistered(id) && !TypeIds.isRegistered(id)) {
        result.unexpectedAdapters.add(AdapterInfo(typeId: id, name: 'UNKNOWN'));
        result.warnings.add('Unexpected adapter registered with TypeId: $id (not in TypeIds registry)');
      }
    }
  }
  
  /// Checks for TypeId collisions.
  static void _checkCollisions(SchemaValidationResult result) {
    final collisionResult = AdapterCollisionGuard.checkForCollisions();
    
    if (collisionResult.hasCollisions) {
      for (final collision in collisionResult.collisions) {
        result.collisions.add(collision);
        result.errors.add(
          'TypeId collision detected: TypeId ${collision.typeId} used by '
          '${collision.adapterNames.join(', ')}',
        );
      }
    }
  }
  
  /// Validates that boxes can be accessed.
  static Future<void> _validateBoxes(SchemaValidationResult result) async {
    for (final boxName in expectedBoxes) {
      try {
        final exists = await Hive.boxExists(boxName);
        
        if (exists) {
          result.existingBoxes.add(boxName);
        } else {
          result.newBoxes.add(boxName);
          // Not an error - boxes will be created on first open
        }
      } catch (e) {
        result.corruptedBoxes.add(boxName);
        result.errors.add('Box check failed for "$boxName": ${e.toString()}');
      }
    }
  }
  
  /// Checks schema version consistency.
  static Future<void> _checkSchemaVersion(SchemaValidationResult result) async {
    try {
      // Check if meta box exists and has version info
      if (await Hive.boxExists(BoxRegistry.metaBox)) {
        final meta = await Hive.openBox(BoxRegistry.metaBox);
        final storedVersion = meta.get('schema_version') as int?;
        await meta.close();
        
        if (storedVersion != null) {
          result.storedSchemaVersion = storedVersion;
          
          if (storedVersion > currentSchemaVersion) {
            // Future version - data from newer app
            result.errors.add(
              'Schema version mismatch: stored=$storedVersion, '
              'current=$currentSchemaVersion. Data may be from a newer app version.',
            );
          } else if (storedVersion < currentSchemaVersion) {
            // Needs migration
            result.needsMigration = true;
            result.warnings.add(
              'Migration needed: stored=$storedVersion, '
              'current=$currentSchemaVersion',
            );
          }
        }
      }
      
      result.currentSchemaVersion = currentSchemaVersion;
      
    } catch (e) {
      result.errors.add('Schema version check failed: ${e.toString()}');
    }
  }
  
  /// Gets recovery instructions for a validation failure.
  static List<String> getRecoveryInstructions(SchemaValidationResult result) {
    final instructions = <String>[];
    
    if (result.missingAdapters.isNotEmpty) {
      instructions.add('MISSING ADAPTERS:');
      instructions.add('The following adapters are not registered:');
      for (final adapter in result.missingAdapters) {
        instructions.add('  - ${adapter.name} (TypeId: ${adapter.typeId})');
      }
      instructions.add('Ensure all adapters are registered before calling Hive.init()');
      instructions.add('');
    }
    
    if (result.collisions.isNotEmpty) {
      instructions.add('TYPEID COLLISIONS:');
      instructions.add('Multiple adapters are using the same TypeId:');
      for (final collision in result.collisions) {
        instructions.add(
          '  - TypeId ${collision.typeId}: ${collision.adapterNames.join(', ')}',
        );
      }
      instructions.add('This causes data corruption. Fix adapter TypeIds immediately.');
      instructions.add('');
    }
    
    if (result.corruptedBoxes.isNotEmpty) {
      instructions.add('CORRUPTED BOXES:');
      instructions.add('The following boxes may be corrupted:');
      for (final box in result.corruptedBoxes) {
        instructions.add('  - $box');
      }
      instructions.add('Options:');
      instructions.add('  1. Delete corrupted box files and restart');
      instructions.add('  2. Restore from backup');
      instructions.add('  3. Clear all app data');
      instructions.add('');
    }
    
    if (result.storedSchemaVersion != null && 
        result.storedSchemaVersion! > currentSchemaVersion) {
      instructions.add('VERSION MISMATCH:');
      instructions.add(
        'Data was created by a newer app version '
        '(v${result.storedSchemaVersion}) than current (v$currentSchemaVersion).',
      );
      instructions.add('Options:');
      instructions.add('  1. Update the app to the latest version');
      instructions.add('  2. Clear all app data (DATA LOSS)');
      instructions.add('');
    }
    
    if (result.needsMigration) {
      instructions.add('MIGRATION NEEDED:');
      instructions.add(
        'Data version (${result.storedSchemaVersion}) needs migration '
        'to current version ($currentSchemaVersion).',
      );
      instructions.add('Migration will run automatically on next startup.');
      instructions.add('');
    }
    
    return instructions;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// RESULT TYPES
// ═══════════════════════════════════════════════════════════════════════════

/// Information about an adapter.
class AdapterInfo {
  final int typeId;
  final String name;
  
  AdapterInfo({required this.typeId, required this.name});
  
  Map<String, dynamic> toJson() => {
    'typeId': typeId,
    'name': name,
  };
}

/// Result of schema validation.
class SchemaValidationResult {
  /// Whether validation passed.
  bool get isValid => errors.isEmpty;
  
  /// Validation errors (blocking).
  final List<String> errors = [];
  
  /// Validation warnings (non-blocking).
  final List<String> warnings = [];
  
  /// Adapters that are registered.
  final List<AdapterInfo> registeredAdapters = [];
  
  /// Adapters that should be registered but aren't.
  final List<AdapterInfo> missingAdapters = [];
  
  /// Unexpected adapters (potential conflicts).
  final List<AdapterInfo> unexpectedAdapters = [];
  
  /// TypeId collisions detected.
  final List<TypeIdCollision> collisions = [];
  
  /// Boxes that exist.
  final List<String> existingBoxes = [];
  
  /// Boxes that will be created (new).
  final List<String> newBoxes = [];
  
  /// Boxes that appear corrupted.
  final List<String> corruptedBoxes = [];
  
  /// Stored schema version (if any).
  int? storedSchemaVersion;
  
  /// Current app schema version.
  int currentSchemaVersion = 0;
  
  /// Whether migration is needed.
  bool needsMigration = false;
  
  /// Duration of validation.
  int validationDurationMs = 0;
  
  Map<String, dynamic> toJson() => {
    'isValid': isValid,
    'errors': errors,
    'warnings': warnings,
    'registeredAdapters': registeredAdapters.map((a) => a.toJson()).toList(),
    'missingAdapters': missingAdapters.map((a) => a.toJson()).toList(),
    'unexpectedAdapters': unexpectedAdapters.map((a) => a.toJson()).toList(),
    'collisions': collisions.map((c) => c.toJson()).toList(),
    'existingBoxes': existingBoxes,
    'newBoxes': newBoxes,
    'corruptedBoxes': corruptedBoxes,
    'storedSchemaVersion': storedSchemaVersion,
    'currentSchemaVersion': currentSchemaVersion,
    'needsMigration': needsMigration,
    'validationDurationMs': validationDurationMs,
  };
}

/// Exception thrown when schema validation fails.
class SchemaValidationException implements Exception {
  final SchemaValidationResult result;
  
  SchemaValidationException(this.result);
  
  @override
  String toString() {
    final sb = StringBuffer();
    sb.writeln('SchemaValidationException: Schema validation failed');
    sb.writeln('');
    sb.writeln('Errors:');
    for (final error in result.errors) {
      sb.writeln('  - $error');
    }
    sb.writeln('');
    sb.writeln('Recovery Instructions:');
    for (final instruction in SchemaValidator.getRecoveryInstructions(result)) {
      sb.writeln(instruction);
    }
    return sb.toString();
  }
  
  /// Gets recovery instructions for display.
  List<String> get recoveryInstructions => 
    SchemaValidator.getRecoveryInstructions(result);
}
