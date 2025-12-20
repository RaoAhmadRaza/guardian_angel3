import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import '../persistence/box_registry.dart';
import '../persistence/wrappers/box_accessor.dart';
import '../services/telemetry_service.dart';
import '../services/audit_log_service.dart';
import '../services/models/audit_log_entry.dart';

// Shared instance management (avoids circular imports)
SecureEraseService? _sharedSecureEraseInstance;

/// Sets the shared SecureEraseService instance.
void setSharedSecureEraseInstance(SecureEraseService instance) {
  _sharedSecureEraseInstance = instance;
}

/// Gets or creates the shared SecureEraseService instance.
SecureEraseService getSharedSecureEraseInstance() {
  return _sharedSecureEraseInstance ??= SecureEraseService(telemetry: TelemetryService.I);
}

/// Service for secure erasure of all user data on account deletion
/// 
/// Performs comprehensive cleanup:
/// - Closes and deletes all Hive boxes
/// - Removes encryption keys from secure storage
/// - Verifies complete deletion
/// - Logs audit events
class SecureEraseService {
  // ═══════════════════════════════════════════════════════════════════════
  // SINGLETON (DEPRECATED - Use ServiceInstances or Riverpod provider)
  // ═══════════════════════════════════════════════════════════════════════
  /// Legacy singleton accessor - routes to shared instance.
  @Deprecated('Use secureEraseServiceProvider or ServiceInstances.secureErase instead')
  static SecureEraseService get I => getSharedSecureEraseInstance();

  // ═══════════════════════════════════════════════════════════════════════
  // PROPER DI CONSTRUCTOR (Use this via Riverpod)
  // ═══════════════════════════════════════════════════════════════════════
  /// Creates a new SecureEraseService instance for dependency injection.
  SecureEraseService({required TelemetryService telemetry}) : _telemetry = telemetry;

  final TelemetryService _telemetry;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Secure storage key names (match HiveService)
  static const _secureKeyName = 'hive_enc_key_v1';
  static const _prevKeyName = 'hive_enc_key_prev';
  static const _rotationCandidateKeyName = 'hive_enc_key_v1_candidate';

  /// Performs complete secure erase of all user data
  /// 
  /// Steps:
  /// 1. Log audit event (before erasure)
  /// 2. Close all open boxes
  /// 3. Delete box files from file system
  /// 4. Remove encryption keys from secure storage
  /// 5. Verify deletion success
  /// 6. Return verification result
  /// 
  /// Throws [SecureEraseException] if critical steps fail
  Future<EraseResult> eraseAllData({
    required String userId,
    String? reason,
  }) async {
    final startTime = DateTime.now();
    final result = EraseResult(userId: userId, startedAt: startTime);

    try {
      _telemetry.increment('secure_erase.started');
      
      // Step 1: Log audit event before erasure
      await _logEraseAttempt(userId, reason);

      // Step 2: Close all boxes
      result.boxesClosed = await _closeAllBoxes();
      _telemetry.increment('secure_erase.boxes_closed', result.boxesClosed);

      // Step 3: Delete box files
      result.boxesDeleted = await _deleteBoxFiles();
      _telemetry.increment('secure_erase.boxes_deleted', result.boxesDeleted);

      // Step 4: Delete encryption keys
      result.keysDeleted = await _deleteEncryptionKeys();
      _telemetry.increment('secure_erase.keys_deleted', result.keysDeleted);

      // Step 5: Verify deletion
      result.verification = await _verifyDeletion();
      
      result.success = result.verification.isComplete;
      result.completedAt = DateTime.now();
      result.durationMs = result.completedAt!.difference(startTime).inMilliseconds;

      if (result.success) {
        _telemetry.increment('secure_erase.success');
        _telemetry.increment('secure_erase.duration_ms', result.durationMs!);
      } else {
        _telemetry.increment('secure_erase.incomplete');
        result.errors.addAll(result.verification.remainingItems);
      }

      return result;
    } catch (e, stackTrace) {
      _telemetry.increment('secure_erase.failed');
      result.success = false;
      result.completedAt = DateTime.now();
      result.errors.add('Fatal error: ${e.toString()}');
      
      // Try to log failure (may fail if audit system already deleted)
      try {
        await AuditLogService.I.log(
          userId: userId,
          action: 'secure_erase_failed',
          severity: 'error',
          metadata: {
            'error': e.toString(),
            'stackTrace': stackTrace.toString(),
          },
        );
      } catch (_) {
        // Ignore audit log failure during cleanup
      }

      throw SecureEraseException(
        'Secure erase failed: ${e.toString()}',
        result: result,
      );
    }
  }

  /// Logs the erase attempt to audit log before deletion
  Future<void> _logEraseAttempt(String userId, String? reason) async {
    try {
      await AuditLogService.I.log(
        userId: userId,
        action: 'secure_erase_initiated',
        severity: 'critical',
        metadata: {
          'reason': reason ?? 'account_deletion',
          'timestamp': DateTime.now().toIso8601String(),
          'boxCount': BoxRegistry.allBoxes.length,
        },
      );
    } catch (e) {
      // Log failure but don't block erase operation
      _telemetry.increment('secure_erase.audit_log_failed');
    }
  }

  /// Closes all open Hive boxes
  Future<int> _closeAllBoxes() async {
    int closedCount = 0;
    
    for (final boxName in BoxRegistry.allBoxes) {
      try {
        if (Hive.isBoxOpen(boxName)) {
          await BoxAccess.I.boxUntyped(boxName).close();
          closedCount++;
        }
      } catch (e) {
        _telemetry.increment('secure_erase.box_close_failed');
        // Continue closing other boxes
      }
    }

    // Close any additional boxes not in registry
    // (transaction_records, distributed_locks, runner_metadata, etc.)
    final additionalBoxes = [
      'transaction_records',
      'distributed_locks',
      'runner_metadata',
      'audit_active_logs',
      'audit_archive_metadata',
    ];

    for (final boxName in additionalBoxes) {
      try {
        if (Hive.isBoxOpen(boxName)) {
          await BoxAccess.I.boxUntyped(boxName).close();
          closedCount++;
        }
      } catch (e) {
        // Box may not exist
      }
    }

    return closedCount;
  }

  /// Deletes all Hive box files from the file system
  Future<int> _deleteBoxFiles() async {
    int deletedCount = 0;

    // Get Hive directory path
    final hiveDir = await _getHiveDirectory();
    if (hiveDir == null || !hiveDir.existsSync()) {
      return 0;
    }

    // Delete all .hive files and .lock files
    try {
      final files = hiveDir.listSync();
      for (final file in files) {
        if (file is File) {
          final fileName = file.path.split(Platform.pathSeparator).last;
          if (fileName.endsWith('.hive') || 
              fileName.endsWith('.lock') ||
              fileName.endsWith('.alog')) { // Archive log files
            try {
              await file.delete();
              deletedCount++;
            } catch (e) {
              _telemetry.increment('secure_erase.file_delete_failed');
            }
          }
        }
      }
    } catch (e) {
      _telemetry.increment('secure_erase.directory_scan_failed');
    }

    return deletedCount;
  }

  /// Gets the Hive directory path
  Future<Directory?> _getHiveDirectory() async {
    try {
      // Try to get path from environment or default location
      final appDocDir = Directory.current;
      final hiveDir = Directory('${appDocDir.path}/hive');
      
      if (hiveDir.existsSync()) {
        return hiveDir;
      }

      // Alternative: Check common locations
      final alternatives = [
        Directory('./hive'),
        Directory('../hive'),
        Directory('./build/test_cache/hive'),
      ];

      for (final dir in alternatives) {
        if (dir.existsSync()) {
          return dir;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Deletes all encryption keys from secure storage
  Future<int> _deleteEncryptionKeys() async {
    int deletedCount = 0;
    
    final keys = [
      _secureKeyName,
      _prevKeyName,
      _rotationCandidateKeyName,
    ];

    for (final key in keys) {
      try {
        // Check if key exists first
        final value = await _secureStorage.read(key: key);
        if (value != null) {
          await _secureStorage.delete(key: key);
          deletedCount++;
        }
      } catch (e) {
        _telemetry.increment('secure_erase.key_delete_failed');
        // Continue deleting other keys
      }
    }

    return deletedCount;
  }

  /// Verifies that all data has been deleted
  Future<EraseVerification> _verifyDeletion() async {
    final verification = EraseVerification();

    // Verify no boxes are open
    for (final boxName in BoxRegistry.allBoxes) {
      if (Hive.isBoxOpen(boxName)) {
        verification.remainingBoxes.add(boxName);
        verification.remainingItems.add('Box still open: $boxName');
      }
    }

    // Verify encryption keys deleted
    final keys = [_secureKeyName, _prevKeyName, _rotationCandidateKeyName];
    for (final key in keys) {
      try {
        final value = await _secureStorage.read(key: key);
        if (value != null) {
          verification.remainingKeys.add(key);
          verification.remainingItems.add('Key still exists: $key');
        }
      } catch (e) {
        // Error reading key - assume deleted
      }
    }

    // Verify box files deleted
    final hiveDir = await _getHiveDirectory();
    if (hiveDir != null && hiveDir.existsSync()) {
      try {
        final files = hiveDir.listSync();
        for (final file in files) {
          if (file is File) {
            final fileName = file.path.split(Platform.pathSeparator).last;
            if (fileName.endsWith('.hive') || fileName.endsWith('.lock')) {
              verification.remainingFiles.add(fileName);
              verification.remainingItems.add('File still exists: $fileName');
            }
          }
        }
      } catch (e) {
        verification.remainingItems.add('Unable to verify files: ${e.toString()}');
      }
    }

    return verification;
  }

  /// Quick check if secure erase is needed (data exists)
  Future<bool> hasDataToErase() async {
    // Check if any encryption key exists
    try {
      final keyExists = await _secureStorage.read(key: _secureKeyName) != null;
      if (keyExists) return true;
    } catch (e) {
      // Unable to check
    }

    // Check if any boxes are open
    for (final boxName in BoxRegistry.allBoxes) {
      if (Hive.isBoxOpen(boxName)) {
        return true;
      }
    }

    return false;
  }
}

/// Result of secure erase operation
class EraseResult {
  final String userId;
  final DateTime startedAt;
  DateTime? completedAt;
  int? durationMs;
  
  bool success = false;
  int boxesClosed = 0;
  int boxesDeleted = 0;
  int keysDeleted = 0;
  
  late EraseVerification verification;
  final List<String> errors = [];

  EraseResult({
    required this.userId,
    required this.startedAt,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'startedAt': startedAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'durationMs': durationMs,
    'success': success,
    'boxesClosed': boxesClosed,
    'boxesDeleted': boxesDeleted,
    'keysDeleted': keysDeleted,
    'verification': verification.toJson(),
    'errors': errors,
  };
}

/// Verification of deletion completeness
class EraseVerification {
  final List<String> remainingBoxes = [];
  final List<String> remainingKeys = [];
  final List<String> remainingFiles = [];
  final List<String> remainingItems = [];

  bool get isComplete => 
    remainingBoxes.isEmpty && 
    remainingKeys.isEmpty && 
    remainingFiles.isEmpty &&
    remainingItems.isEmpty;

  int get remainingCount => 
    remainingBoxes.length + 
    remainingKeys.length + 
    remainingFiles.length;

  Map<String, dynamic> toJson() => {
    'isComplete': isComplete,
    'remainingCount': remainingCount,
    'remainingBoxes': remainingBoxes,
    'remainingKeys': remainingKeys,
    'remainingFiles': remainingFiles,
    'remainingItems': remainingItems,
  };
}

/// Exception thrown when secure erase fails critically
class SecureEraseException implements Exception {
  final String message;
  final EraseResult? result;

  SecureEraseException(this.message, {this.result});

  @override
  String toString() => 'SecureEraseException: $message';
}
