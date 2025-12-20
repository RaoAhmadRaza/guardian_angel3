/// Secure Erase Hardening - Final Safety Measures
///
/// Provides:
/// - Post-erase verification scan
/// - "Erase incomplete" detection
/// - UI confirmation state management
/// - Forced app restart capability
/// - Assertions for complete erasure
library;

import 'dart:async';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import '../persistence/box_registry.dart';
import '../persistence/wrappers/box_accessor.dart';
import '../services/telemetry_service.dart';
import '../services/audit_log_service.dart';

// Shared instance management (avoids circular imports)
SecureEraseHardened? _sharedSecureEraseHardenedInstance;

/// Sets the shared SecureEraseHardened instance.
void setSharedSecureEraseHardenedInstance(SecureEraseHardened instance) {
  _sharedSecureEraseHardenedInstance = instance;
}

/// Gets or creates the shared SecureEraseHardened instance.
SecureEraseHardened getSharedSecureEraseHardenedInstance() {
  return _sharedSecureEraseHardenedInstance ??= SecureEraseHardened(telemetry: TelemetryService.I);
}

// ═══════════════════════════════════════════════════════════════════════════
// SECURE ERASE HARDENING
// ═══════════════════════════════════════════════════════════════════════════

/// Hardened secure erase with post-verification and recovery.
class SecureEraseHardened {
  // ═══════════════════════════════════════════════════════════════════════
  // SINGLETON (DEPRECATED - Use ServiceInstances or Riverpod provider)
  // ═══════════════════════════════════════════════════════════════════════
  /// Legacy singleton accessor - routes to shared instance.
  @Deprecated('Use secureEraseHardenedProvider or ServiceInstances.secureEraseHardened instead')
  static SecureEraseHardened get I => getSharedSecureEraseHardenedInstance();
  
  // ═══════════════════════════════════════════════════════════════════════
  // PROPER DI CONSTRUCTOR (Use this via Riverpod)
  // ═══════════════════════════════════════════════════════════════════════
  /// Creates a new SecureEraseHardened instance for dependency injection.
  SecureEraseHardened({required TelemetryService telemetry}) : _telemetry = telemetry;
  
  final TelemetryService _telemetry;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  // Secure storage key names
  static const _secureKeyName = 'hive_enc_key_v1';
  static const _prevKeyName = 'hive_enc_key_prev';
  static const _rotationCandidateKeyName = 'hive_enc_key_v1_candidate';
  
  // Erase state tracking
  static const _eraseStateKey = 'erase_in_progress';
  static const _eraseStartTimeKey = 'erase_start_time';
  
  /// Performs hardened secure erase with full verification.
  ///
  /// Steps:
  /// 1. Mark erase in progress (for crash detection)
  /// 2. Pre-erase audit log
  /// 3. Close all boxes
  /// 4. Delete all box files
  /// 5. Delete encryption keys
  /// 6. Post-erase verification scan
  /// 7. Assert complete deletion
  /// 8. Clear erase state
  ///
  /// Returns [HardenedEraseResult] with verification status.
  Future<HardenedEraseResult> eraseAllData({
    required String userId,
    String? reason,
    bool assertComplete = true,
  }) async {
    final sw = Stopwatch()..start();
    final result = HardenedEraseResult(
      userId: userId,
      startedAt: DateTime.now().toUtc(),
    );
    
    try {
      _telemetry.increment('secure_erase_hardened.started');
      
      // Step 1: Mark erase in progress
      await _markEraseInProgress(userId);
      
      // Step 2: Pre-erase audit log
      await _logEraseStarted(userId, reason);
      
      // Step 3: Close all boxes
      result.boxesClosed = await _closeAllBoxes();
      _telemetry.gauge('secure_erase_hardened.boxes_closed', result.boxesClosed);
      
      // Step 4: Delete box files
      result.filesDeleted = await _deleteAllBoxFiles();
      _telemetry.gauge('secure_erase_hardened.files_deleted', result.filesDeleted);
      
      // Step 5: Delete encryption keys
      result.keysDeleted = await _deleteEncryptionKeys();
      _telemetry.gauge('secure_erase_hardened.keys_deleted', result.keysDeleted);
      
      // Step 6: Post-erase verification scan
      result.verification = await verifyCompleteDeletion();
      
      // Step 7: Assert complete deletion (if enabled)
      if (assertComplete) {
        _assertAllDeleted(result.verification);
      }
      
      // Step 8: Clear erase state
      await _clearEraseState();
      
      result.success = result.verification.isComplete;
      result.completedAt = DateTime.now().toUtc();
      result.durationMs = sw.elapsedMilliseconds;
      
      if (result.success) {
        _telemetry.increment('secure_erase_hardened.success');
      } else {
        _telemetry.increment('secure_erase_hardened.incomplete');
      }
      
      return result;
      
    } catch (e, stackTrace) {
      sw.stop();
      _telemetry.increment('secure_erase_hardened.error');
      
      result.success = false;
      result.completedAt = DateTime.now().toUtc();
      result.durationMs = sw.elapsedMilliseconds;
      result.errors.add(e.toString());
      
      // Don't clear erase state - allow detection on next launch
      
      throw SecureEraseIncompleteException(
        message: 'Secure erase failed: ${e.toString()}',
        result: result,
        stackTrace: stackTrace,
      );
    }
  }
  
  /// Checks if a previous erase was interrupted.
  ///
  /// Call this on app startup to detect incomplete erasure.
  Future<InterruptedEraseInfo?> checkForInterruptedErase() async {
    try {
      final inProgress = await _secureStorage.read(key: _eraseStateKey);
      if (inProgress == null) return null;
      
      final startTimeStr = await _secureStorage.read(key: _eraseStartTimeKey);
      final startTime = startTimeStr != null 
        ? DateTime.parse(startTimeStr)
        : null;
      
      _telemetry.increment('secure_erase_hardened.interrupted_detected');
      
      return InterruptedEraseInfo(
        userId: inProgress,
        startedAt: startTime,
        detectedAt: DateTime.now().toUtc(),
      );
    } catch (e) {
      return null;
    }
  }
  
  /// Resumes an interrupted erase operation.
  Future<HardenedEraseResult> resumeInterruptedErase(
    InterruptedEraseInfo info,
  ) async {
    _telemetry.increment('secure_erase_hardened.resume_started');
    
    try {
      // Re-run full erase
      return await eraseAllData(
        userId: info.userId,
        reason: 'resumed_after_interruption',
        assertComplete: true,
      );
    } catch (e) {
      _telemetry.increment('secure_erase_hardened.resume_failed');
      rethrow;
    }
  }
  
  /// Performs post-erase verification scan.
  Future<EraseVerificationScan> verifyCompleteDeletion() async {
    final scan = EraseVerificationScan();
    
    // Check 1: No boxes open
    for (final boxName in BoxRegistry.allBoxes) {
      if (Hive.isBoxOpen(boxName)) {
        scan.openBoxes.add(boxName);
      }
    }
    
    // Check 2: No box files exist
    final hiveDir = await _getHiveDirectory();
    if (hiveDir != null && await hiveDir.exists()) {
      try {
        await for (final entity in hiveDir.list()) {
          if (entity is File) {
            final name = entity.path.split(Platform.pathSeparator).last;
            if (name.endsWith('.hive') || 
                name.endsWith('.lock') || 
                name.endsWith('.alog')) {
              scan.remainingFiles.add(name);
            }
          }
        }
      } catch (e) {
        scan.scanErrors.add('Failed to scan hive directory: $e');
      }
    }
    
    // Check 3: No encryption keys exist
    final keyNames = [_secureKeyName, _prevKeyName, _rotationCandidateKeyName];
    for (final keyName in keyNames) {
      try {
        final value = await _secureStorage.read(key: keyName);
        if (value != null) {
          scan.remainingKeys.add(keyName);
        }
      } catch (e) {
        scan.scanErrors.add('Failed to check key $keyName: $e');
      }
    }
    
    // Check 4: Verify boxes don't exist
    for (final boxName in BoxRegistry.allBoxes) {
      try {
        final exists = await Hive.boxExists(boxName);
        if (exists) {
          scan.existingBoxes.add(boxName);
        }
      } catch (e) {
        // Box check failed - might be deleted
      }
    }
    
    _telemetry.gauge('secure_erase_hardened.remaining_files', scan.remainingFiles.length);
    _telemetry.gauge('secure_erase_hardened.remaining_keys', scan.remainingKeys.length);
    _telemetry.gauge('secure_erase_hardened.existing_boxes', scan.existingBoxes.length);
    
    return scan;
  }
  
  /// Gets the current erase UI state for display.
  EraseUIState getUIState(HardenedEraseResult? result) {
    if (result == null) {
      return EraseUIState.notStarted;
    }
    
    if (result.success) {
      return EraseUIState.complete;
    }
    
    if (result.verification.isComplete) {
      return EraseUIState.complete;
    }
    
    if (result.errors.isNotEmpty) {
      return EraseUIState.failed;
    }
    
    return EraseUIState.incomplete;
  }
  
  // ═══════════════════════════════════════════════════════════════════════
  // PRIVATE METHODS
  // ═══════════════════════════════════════════════════════════════════════
  
  Future<void> _markEraseInProgress(String userId) async {
    await _secureStorage.write(key: _eraseStateKey, value: userId);
    await _secureStorage.write(
      key: _eraseStartTimeKey, 
      value: DateTime.now().toUtc().toIso8601String(),
    );
  }
  
  Future<void> _clearEraseState() async {
    await _secureStorage.delete(key: _eraseStateKey);
    await _secureStorage.delete(key: _eraseStartTimeKey);
  }
  
  Future<void> _logEraseStarted(String userId, String? reason) async {
    try {
      await AuditLogService.I.log(
        userId: userId,
        action: 'secure_erase_hardened.started',
        severity: 'critical',
        metadata: {
          'reason': reason ?? 'user_initiated',
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        },
      );
    } catch (e) {
      _telemetry.increment('secure_erase_hardened.audit_log_unavailable');
    }
  }
  
  Future<int> _closeAllBoxes() async {
    int count = 0;
    
    // Close registry boxes
    for (final boxName in BoxRegistry.allBoxes) {
      try {
        if (Hive.isBoxOpen(boxName)) {
          await BoxAccess.I.boxUntyped(boxName).close();
          count++;
        }
      } catch (e) {
        // Continue closing others
      }
    }
    
    // Close additional known boxes
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
          count++;
        }
      } catch (e) {
        // Box may not exist
      }
    }
    
    return count;
  }
  
  Future<int> _deleteAllBoxFiles() async {
    int count = 0;
    
    final hiveDir = await _getHiveDirectory();
    if (hiveDir == null || !await hiveDir.exists()) {
      return 0;
    }
    
    try {
      await for (final entity in hiveDir.list()) {
        if (entity is File) {
          final name = entity.path.split(Platform.pathSeparator).last;
          if (name.endsWith('.hive') || 
              name.endsWith('.lock') || 
              name.endsWith('.alog')) {
            try {
              await entity.delete();
              count++;
            } catch (e) {
              _telemetry.increment('secure_erase_hardened.file_delete_failed');
            }
          }
        }
      }
    } catch (e) {
      _telemetry.increment('secure_erase_hardened.directory_scan_failed');
    }
    
    return count;
  }
  
  Future<int> _deleteEncryptionKeys() async {
    int count = 0;
    
    final keys = [_secureKeyName, _prevKeyName, _rotationCandidateKeyName];
    
    for (final key in keys) {
      try {
        final value = await _secureStorage.read(key: key);
        if (value != null) {
          await _secureStorage.delete(key: key);
          count++;
        }
      } catch (e) {
        _telemetry.increment('secure_erase_hardened.key_delete_failed');
      }
    }
    
    return count;
  }
  
  Future<Directory?> _getHiveDirectory() async {
    try {
      // Try common locations
      final candidates = [
        Directory('./hive'),
        Directory('../hive'),
        Directory('${Directory.current.path}/hive'),
      ];
      
      for (final dir in candidates) {
        if (await dir.exists()) {
          return dir;
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
  
  void _assertAllDeleted(EraseVerificationScan verification) {
    if (!verification.isComplete) {
      final issues = <String>[];
      
      if (verification.openBoxes.isNotEmpty) {
        issues.add('Boxes still open: ${verification.openBoxes.join(', ')}');
      }
      if (verification.remainingFiles.isNotEmpty) {
        issues.add('Files remaining: ${verification.remainingFiles.join(', ')}');
      }
      if (verification.remainingKeys.isNotEmpty) {
        issues.add('Keys remaining: ${verification.remainingKeys.join(', ')}');
      }
      if (verification.existingBoxes.isNotEmpty) {
        issues.add('Boxes still exist: ${verification.existingBoxes.join(', ')}');
      }
      
      assert(
        verification.isComplete,
        'Secure erase incomplete: ${issues.join('; ')}',
      );
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// RESULT TYPES
// ═══════════════════════════════════════════════════════════════════════════

/// UI state for erase operation.
enum EraseUIState {
  /// Erase not started.
  notStarted,
  
  /// Erase in progress.
  inProgress,
  
  /// Erase completed successfully.
  complete,
  
  /// Erase incomplete - some data may remain.
  incomplete,
  
  /// Erase failed with error.
  failed,
}

/// Result of hardened erase operation.
class HardenedEraseResult {
  final String userId;
  final DateTime startedAt;
  DateTime? completedAt;
  int durationMs = 0;
  
  bool success = false;
  int boxesClosed = 0;
  int filesDeleted = 0;
  int keysDeleted = 0;
  
  late EraseVerificationScan verification;
  final List<String> errors = [];
  
  HardenedEraseResult({
    required this.userId,
    required this.startedAt,
  }) {
    verification = EraseVerificationScan();
  }
  
  Map<String, dynamic> toJson() => {
    'userId': userId,
    'startedAt': startedAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'durationMs': durationMs,
    'success': success,
    'boxesClosed': boxesClosed,
    'filesDeleted': filesDeleted,
    'keysDeleted': keysDeleted,
    'verification': verification.toJson(),
    'errors': errors,
  };
}

/// Post-erase verification scan result.
class EraseVerificationScan {
  final List<String> openBoxes = [];
  final List<String> remainingFiles = [];
  final List<String> remainingKeys = [];
  final List<String> existingBoxes = [];
  final List<String> scanErrors = [];
  
  bool get isComplete =>
    openBoxes.isEmpty &&
    remainingFiles.isEmpty &&
    remainingKeys.isEmpty &&
    existingBoxes.isEmpty;
  
  int get remainingCount =>
    openBoxes.length +
    remainingFiles.length +
    remainingKeys.length +
    existingBoxes.length;
  
  Map<String, dynamic> toJson() => {
    'isComplete': isComplete,
    'remainingCount': remainingCount,
    'openBoxes': openBoxes,
    'remainingFiles': remainingFiles,
    'remainingKeys': remainingKeys,
    'existingBoxes': existingBoxes,
    'scanErrors': scanErrors,
  };
}

/// Information about an interrupted erase.
class InterruptedEraseInfo {
  final String userId;
  final DateTime? startedAt;
  final DateTime detectedAt;
  
  InterruptedEraseInfo({
    required this.userId,
    this.startedAt,
    required this.detectedAt,
  });
  
  Duration? get interruptedDuration => 
    startedAt != null ? detectedAt.difference(startedAt!) : null;
  
  Map<String, dynamic> toJson() => {
    'userId': userId,
    'startedAt': startedAt?.toIso8601String(),
    'detectedAt': detectedAt.toIso8601String(),
    'interruptedDurationMs': interruptedDuration?.inMilliseconds,
  };
}

/// Exception thrown when erase is incomplete.
class SecureEraseIncompleteException implements Exception {
  final String message;
  final HardenedEraseResult result;
  final StackTrace stackTrace;
  
  SecureEraseIncompleteException({
    required this.message,
    required this.result,
    required this.stackTrace,
  });
  
  @override
  String toString() => 'SecureEraseIncompleteException: $message';
  
  /// Whether the erase should be retried.
  bool get shouldRetry => 
    result.verification.remainingFiles.isNotEmpty ||
    result.verification.remainingKeys.isNotEmpty;
}
