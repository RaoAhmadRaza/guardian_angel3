import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'adapters/room_adapter.dart';
import 'adapters/pending_op_adapter.dart';
import 'adapters/vitals_adapter.dart';
import 'adapters/device_adapter.dart';
import 'adapters/session_adapter.dart';
import 'adapters/user_profile_adapter.dart';
import 'adapters/failed_op_adapter.dart';
import 'adapters/audit_log_adapter.dart';
import 'adapters/settings_adapter.dart';
import 'adapters/assets_cache_adapter.dart';
// Onboarding adapters
import 'adapters/user_base_adapter.dart';
import 'adapters/caregiver_user_adapter.dart';
import 'adapters/caregiver_details_adapter.dart';
import 'adapters/patient_user_adapter.dart';
import 'adapters/patient_details_adapter.dart';
import 'adapters/relationship_adapter.dart';
// Chat adapters
import 'adapters/chat_adapter.dart';
import '../models/vitals_model.dart';
import '../models/room_model.dart';
import '../models/pending_op.dart';
import '../models/failed_op_model.dart';
import '../models/audit_log_record.dart';
import '../models/settings_model.dart';
// Onboarding models
import '../onboarding/models/user_base_model.dart';
import '../onboarding/models/caregiver_user_model.dart';
import '../onboarding/models/caregiver_details_model.dart';
import '../onboarding/models/patient_user_model.dart';
import '../onboarding/models/patient_details_model.dart';
import '../relationships/models/relationship_model.dart';
// Chat models
import '../chat/models/chat_thread_model.dart';
import '../chat/models/chat_message_model.dart';
// Additional adapters required by schema validation
import '../models/sync_failure.dart';
import '../services/models/transaction_record.dart';
import '../services/models/lock_record.dart';
import '../services/models/audit_log_entry.dart';
// Home Automation generated adapters (TypeIds 0-1)
import '../home automation/src/data/hive_adapters/room_model_hive.dart';
import '../home automation/src/data/hive_adapters/device_model_hive.dart';
import 'box_registry.dart';
import 'encryption_policy.dart';
import 'wrappers/box_accessor.dart';
import '../services/telemetry_service.dart';
import 'type_ids.dart';

class HiveService {
  static const _secureKeyName = 'hive_enc_key_v1';
  static const _prevKeyName = 'hive_enc_key_prev';
  static const _rotationStateKey = 'rotation_state'; // stored in meta box
  final FlutterSecureStorage secureStorage;
  final TelemetryService _telemetry;

  HiveService({required this.secureStorage, TelemetryService? telemetry})
      : _telemetry = telemetry ?? TelemetryService.I;

  static Future<HiveService> create({TelemetryService? telemetry}) async {
    const secure = FlutterSecureStorage();
    return HiveService(secureStorage: secure, telemetry: telemetry);
  }

  Future<void> init() async {
    await Hive.initFlutter();
    // Idempotent adapter registration: register only if not already registered.
    if (!Hive.isAdapterRegistered(TypeIds.roomHive)) {
      Hive.registerAdapter(RoomModelHiveAdapter());
    }
    if (!Hive.isAdapterRegistered(TypeIds.deviceHive)) {
      Hive.registerAdapter(DeviceModelHiveAdapter());
    }
    if (!Hive.isAdapterRegistered(TypeIds.room)) {
      Hive.registerAdapter(RoomAdapter());
    }
    if (!Hive.isAdapterRegistered(TypeIds.pendingOp)) {
      Hive.registerAdapter(PendingOpAdapter());
    }
    if (!Hive.isAdapterRegistered(TypeIds.vitals)) {
      Hive.registerAdapter(VitalsAdapter());
    }
    if (!Hive.isAdapterRegistered(TypeIds.device)) {
      Hive.registerAdapter(DeviceModelAdapter());
    }
    if (!Hive.isAdapterRegistered(TypeIds.session)) {
      Hive.registerAdapter(SessionModelAdapter());
    }
    if (!Hive.isAdapterRegistered(TypeIds.userProfile)) {
      Hive.registerAdapter(UserProfileModelAdapter());
    }
    if (!Hive.isAdapterRegistered(TypeIds.failedOp)) {
      Hive.registerAdapter(FailedOpModelAdapter());
    }
    if (!Hive.isAdapterRegistered(TypeIds.auditLogRecord)) {
      Hive.registerAdapter(AuditLogRecordAdapter());
    }
    if (!Hive.isAdapterRegistered(TypeIds.settings)) {
      Hive.registerAdapter(SettingsModelAdapter());
    }
    if (!Hive.isAdapterRegistered(TypeIds.assetsCache)) {
      Hive.registerAdapter(AssetsCacheEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(TypeIds.syncFailure)) {
      Hive.registerAdapter(SyncFailureAdapter());
    }
    if (!Hive.isAdapterRegistered(TypeIds.syncFailureStatus)) {
      Hive.registerAdapter(SyncFailureStatusAdapter());
    }
    if (!Hive.isAdapterRegistered(TypeIds.syncFailureSeverity)) {
      Hive.registerAdapter(SyncFailureSeverityAdapter());
    }
    if (!Hive.isAdapterRegistered(TypeIds.transactionRecord)) {
      Hive.registerAdapter(TransactionRecordAdapter());
    }
    if (!Hive.isAdapterRegistered(TypeIds.lockRecord)) {
      Hive.registerAdapter(LockRecordAdapter());
    }
    if (!Hive.isAdapterRegistered(TypeIds.auditLogEntry)) {
      Hive.registerAdapter(AuditLogEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(TypeIds.auditLogArchive)) {
      Hive.registerAdapter(AuditLogArchiveAdapter());
    }
    // Onboarding adapters (40-49)
    if (!Hive.isAdapterRegistered(TypeIds.userBase)) {
      Hive.registerAdapter(UserBaseAdapter());
    }
    if (!Hive.isAdapterRegistered(TypeIds.caregiverUser)) {
      Hive.registerAdapter(CaregiverUserAdapter());
    }
    if (!Hive.isAdapterRegistered(TypeIds.caregiverDetails)) {
      Hive.registerAdapter(CaregiverDetailsAdapter());
    }
    if (!Hive.isAdapterRegistered(TypeIds.patientUser)) {
      Hive.registerAdapter(PatientUserAdapter());
    }
    if (!Hive.isAdapterRegistered(TypeIds.patientDetails)) {
      Hive.registerAdapter(PatientDetailsAdapter());
    }
    // Relationship adapters (45-46)
    if (!Hive.isAdapterRegistered(TypeIds.relationship)) {
      Hive.registerAdapter(RelationshipAdapter());
    }
    if (!Hive.isAdapterRegistered(TypeIds.relationshipStatus)) {
      Hive.registerAdapter(RelationshipStatusAdapter());
    }
    // Chat adapters (47-50)
    if (!Hive.isAdapterRegistered(TypeIds.chatThread)) {
      Hive.registerAdapter(ChatThreadAdapter());
    }
    if (!Hive.isAdapterRegistered(TypeIds.chatMessage)) {
      Hive.registerAdapter(ChatMessageAdapter());
    }
    if (!Hive.isAdapterRegistered(TypeIds.chatMessageType)) {
      Hive.registerAdapter(ChatMessageTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(TypeIds.chatMessageLocalStatus)) {
      Hive.registerAdapter(ChatMessageLocalStatusAdapter());
    }

    final key = await _getOrCreateKey();
    await _openBoxes(key);
  }

  Future<List<int>> _getOrCreateKey() async {
    final base64Key = await secureStorage.read(key: _secureKeyName);
    if (base64Key != null) {
      try {
        return base64.decode(base64Key);
      } catch (_) {
        // Corrupt key -> regenerate
      }
    }
    final secureKey = Hive.generateSecureKey();
    await secureStorage.write(key: _secureKeyName, value: base64.encode(secureKey));
    return secureKey;
  }

  List<String> encryptedBoxes() => [
        BoxRegistry.roomsBox,
        BoxRegistry.pendingOpsBox,
        BoxRegistry.vitalsBox,
        BoxRegistry.userProfileBox,
        BoxRegistry.sessionsBox,
        BoxRegistry.failedOpsBox,
        BoxRegistry.auditLogsBox,
        BoxRegistry.settingsBox,
      ]; // meta & index left unencrypted

  Future<void> rotateEncryptionKey() async {
    final oldKeyB64 = await secureStorage.read(key: _secureKeyName);
    if (oldKeyB64 == null) {
      throw StateError('No existing key to rotate');
    }
    final oldKey = base64.decode(oldKeyB64);
    final newKey = Hive.generateSecureKey();
    // Persist new key TEMPORARILY under prev name for resume capability.
    await secureStorage.write(key: _prevKeyName, value: base64.encode(oldKey));
    await secureStorage.write(key: '${_secureKeyName}_candidate', value: base64.encode(newKey));
    final meta = BoxAccess.I.meta();
    meta.put(_rotationStateKey, {
      'status': 'in_progress',
      'started_at': DateTime.now().toUtc().toIso8601String(),
      'boxes_completed': <String>[],
    });
    final startSw = Stopwatch()..start();
    for (final boxName in encryptedBoxes()) {
      await _rotateSingleBox(boxName, oldKey, newKey, meta);
    }
    startSw.stop();
    // Commit new key replacing old
    await secureStorage.write(key: _secureKeyName, value: base64.encode(newKey));
    // Optionally keep old key for limited time or delete
    await secureStorage.delete(key: '${_secureKeyName}_candidate');
    meta.put(_rotationStateKey, {
      'status': 'completed',
      'completed_at': DateTime.now().toUtc().toIso8601String(),
    });
    _telemetry.time('key_rotation.duration_ms', () => startSw.elapsed);
  }

  Future<void> resumeInterruptedRotation() async {
    final meta = BoxAccess.I.meta();
    final state = meta.get(_rotationStateKey);
    if (state is! Map || state['status'] != 'in_progress') return;
    final oldKeyB64 = await secureStorage.read(key: _prevKeyName);
    final candidateB64 = await secureStorage.read(key: '${_secureKeyName}_candidate');
    if (oldKeyB64 == null || candidateB64 == null) {
      throw StateError('Rotation state inconsistent: missing keys');
    }
    final oldKey = base64.decode(oldKeyB64);
    final newKey = base64.decode(candidateB64);
    final completed = (state['boxes_completed'] as List).cast<String>();
    final pending = encryptedBoxes().where((b) => !completed.contains(b));
    final sw = Stopwatch()..start();
    for (final boxName in pending) {
      await _rotateSingleBox(boxName, oldKey, newKey, meta, completedBoxes: completed);
    }
    sw.stop();
    await secureStorage.write(key: _secureKeyName, value: candidateB64);
    await secureStorage.delete(key: '${_secureKeyName}_candidate');
    meta.put(_rotationStateKey, {
      'status': 'completed',
      'resumed_at': DateTime.now().toUtc().toIso8601String(),
    });
    _telemetry.time('key_rotation.duration_ms', () => sw.elapsed);
  }

  Future<void> _rotateSingleBox(String boxName, List<int> oldKey, List<int> newKey, Box meta,
      {List<String>? completedBoxes}) async {
    if (!Hive.isBoxOpen(boxName)) return; // skip unopened
    final box = _typedBox(boxName);
    final originalPath = box.path;
    final backupFile = originalPath != null ? File(originalPath).copySync('$originalPath.pre_rotate') : null;
    // Extract entries
    final entries = <dynamic, dynamic>{};
    for (final k in box.keys) {
      entries[k] = box.get(k);
    }
    await box.close();
    // Delete original file so new cipher writes fresh
    if (originalPath != null) {
      try {
        File(originalPath).deleteSync();
      } catch (_) {}
    }
    final newCipher = HiveAesCipher(newKey);
    final reopened = await _openTypedBox(boxName, newCipher);
    for (final e in entries.entries) {
      await reopened.put(e.key, e.value);
    }
    if (reopened.length != entries.length) {
      // Restore from backup if mismatch
      await reopened.close();
      if (originalPath != null && backupFile != null && backupFile.existsSync()) {
        // rollback: delete failed new file, restore backup
        try { File(originalPath).deleteSync(); } catch (_) {}
        backupFile.copySync(originalPath);
        await Hive.openBox(boxName, encryptionCipher: HiveAesCipher(oldKey));
      }
      throw StateError('Key rotation validation failed for $boxName');
    }
    // Append telemetry for each box
    _telemetry.increment('key_rotation.box_completed');
    final state = meta.get(_rotationStateKey) as Map?;
    if (state != null) {
      final list = (state['boxes_completed'] as List?)?.cast<String>() ?? <String>[];
      list.add(boxName);
      meta.put(_rotationStateKey, {
        'status': 'in_progress',
        'started_at': state['started_at'],
        'boxes_completed': list,
      });
    }
  }

  Box _typedBox(String name) {
    switch (name) {
      case BoxRegistry.roomsBox:
        return BoxAccess.I.rooms();
      case BoxRegistry.pendingOpsBox:
        return BoxAccess.I.pendingOps();
      case BoxRegistry.vitalsBox:
        return BoxAccess.I.vitals();
      case BoxRegistry.userProfileBox:
        return BoxAccess.I.boxUntyped(name); // could be UserProfileModel typed if defined
      case BoxRegistry.sessionsBox:
        return BoxAccess.I.boxUntyped(name); // SessionModel
      case BoxRegistry.failedOpsBox:
        return BoxAccess.I.failedOps();
      case BoxRegistry.auditLogsBox:
        return BoxAccess.I.auditLogs();
      case BoxRegistry.settingsBox:
        return BoxAccess.I.settings();
      default:
        return BoxAccess.I.boxUntyped(name);
    }
  }

  Future<Box> _openTypedBox(String name, HiveAesCipher cipher) async {
    switch (name) {
      case BoxRegistry.roomsBox:
        return Hive.openBox<RoomModel>(name, encryptionCipher: cipher);
      case BoxRegistry.pendingOpsBox:
        return Hive.openBox<PendingOp>(name, encryptionCipher: cipher);
      case BoxRegistry.vitalsBox:
        return Hive.openBox<VitalsModel>(name, encryptionCipher: cipher);
      case BoxRegistry.failedOpsBox:
        return Hive.openBox<FailedOpModel>(name, encryptionCipher: cipher);
      case BoxRegistry.auditLogsBox:
        return Hive.openBox<AuditLogRecord>(name, encryptionCipher: cipher);
      case BoxRegistry.settingsBox:
        return Hive.openBox<SettingsModel>(name, encryptionCipher: cipher);
      case BoxRegistry.userProfileBox:
        return Hive.openBox(name, encryptionCipher: cipher); // user profile
      case BoxRegistry.sessionsBox:
        return Hive.openBox(name, encryptionCipher: cipher); // session
      default:
        return Hive.openBox(name, encryptionCipher: cipher);
    }
  }

  Future<void> _openBoxes(List<int> key) async {
    final cipher = HiveAesCipher(key);
    final sw = Stopwatch()..start();
    
    // Open boxes with individual error handling and recovery
    // All typed boxes must specify their type to avoid Box<dynamic> conflicts
    await _openBoxSafely<RoomModel>(BoxRegistry.roomsBox, cipher: cipher);
    await _openBoxSafely<PendingOp>(BoxRegistry.pendingOpsBox, cipher: cipher);
    await _openBoxSafely<VitalsModel>(BoxRegistry.vitalsBox, cipher: cipher);
    await _openBoxSafely<dynamic>(BoxRegistry.userProfileBox, cipher: cipher);
    await _openBoxSafely<dynamic>(BoxRegistry.sessionsBox, cipher: cipher);
    await _openBoxSafely<FailedOpModel>(BoxRegistry.failedOpsBox, cipher: cipher);
    await _openBoxSafely<AuditLogRecord>(BoxRegistry.auditLogsBox, cipher: cipher);
    await _openBoxSafely<dynamic>(BoxRegistry.assetsCacheBox, cipher: null);
    await _openBoxSafely<dynamic>(BoxRegistry.uiPreferencesBox, cipher: null);
    await _openBoxSafely<SettingsModel>(BoxRegistry.settingsBox, cipher: cipher);
    await _openBoxSafely<dynamic>(BoxRegistry.metaBox, cipher: null);
    await _openBoxSafely<dynamic>(BoxRegistry.pendingIndexBox, cipher: null);
    
    // Onboarding boxes (encrypted - contains PII)
    await _openBoxSafely<UserBaseModel>(BoxRegistry.userBaseBox, cipher: cipher);
    await _openBoxSafely<CaregiverUserModel>(BoxRegistry.caregiverUserBox, cipher: cipher);
    await _openBoxSafely<CaregiverDetailsModel>(BoxRegistry.caregiverDetailsBox, cipher: cipher);
    await _openBoxSafely<PatientUserModel>(BoxRegistry.patientUserBox, cipher: cipher);
    await _openBoxSafely<PatientDetailsModel>(BoxRegistry.patientDetailsBox, cipher: cipher);
    
    // Relationships box (encrypted - contains PII)
    await _openBoxSafely<RelationshipModel>(BoxRegistry.relationshipsBox, cipher: cipher);
    
    // Chat boxes (encrypted - contains conversation content)
    await _openBoxSafely<ChatThreadModel>(BoxRegistry.chatThreadsBox, cipher: cipher);
    await _openBoxSafely<ChatMessageModel>(BoxRegistry.chatMessagesBox, cipher: cipher);
    
    sw.stop();
    _telemetry.time('hive.open.duration_ms', () => sw.elapsed);
  }

  /// Opens a single box with try/catch recovery.
  /// 
  /// On corruption:
  /// 1. Marks box as corrupted (telemetry)
  /// 2. Attempts backup of corrupt file
  /// 3. Attempts to delete and recreate empty box
  /// 4. If all fails, logs and continues (non-fatal for most boxes)
  Future<Box<T>?> _openBoxSafely<T>(
    String boxName, {
    HiveAesCipher? cipher,
  }) async {
    try {
      if (Hive.isBoxOpen(boxName)) {
        return BoxAccess.I.box<T>(boxName);
      }
      
      final box = await Hive.openBox<T>(
        boxName,
        encryptionCipher: cipher,
      );
      
      // Register box encryption status for policy enforcement
      if (cipher != null) {
        EncryptionPolicyEnforcer.registerEncryptedBox(boxName);
      }
      
      _telemetry.increment('hive.box_open.success.$boxName');
      return box;
    } catch (e) {
      // Mark box as corrupted
      _telemetry.increment('hive.box_open.failed.$boxName');
      _telemetry.increment('corruption.events');
      print('[HiveService] Box "$boxName" failed to open: $e');
      
      // Attempt recovery
      await _attemptBoxRecovery<T>(boxName, cipher, e);
      return null;
    }
  }
  
  /// Attempts to recover a corrupted box.
  /// 
  /// Recovery steps:
  /// 1. Backup the corrupt file
  /// 2. Delete the corrupt file
  /// 3. Try to open fresh empty box
  Future<void> _attemptBoxRecovery<T>(
    String boxName,
    HiveAesCipher? cipher,
    Object originalError,
  ) async {
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    
    try {
      // Find and backup corrupt file
      String? boxPath;
      try {
        // Try to determine Hive's path from an open box or app documents
        if (Hive.isBoxOpen(BoxRegistry.metaBox)) {
          final metaBox = BoxAccess.I.meta();
          boxPath = metaBox.path?.replaceAll('/${BoxRegistry.metaBox}.hive', '/$boxName.hive');
        }
      } catch (_) {}
      
      if (boxPath != null) {
        final corruptFile = File(boxPath);
        if (corruptFile.existsSync()) {
          // Create backup directory
          final backupDir = Directory('${corruptFile.parent.path}/corruption_backups');
          if (!backupDir.existsSync()) {
            backupDir.createSync(recursive: true);
          }
          
          // Backup corrupt file
          final backupPath = '${backupDir.path}/$boxName.$stamp.corrupt.bak';
          corruptFile.copySync(backupPath);
          print('[HiveService] Backed up corrupt box to: $backupPath');
          _telemetry.increment('hive.box_recovery.backup_success.$boxName');
          
          // Delete corrupt file
          corruptFile.deleteSync();
          print('[HiveService] Deleted corrupt box file: $boxPath');
          
          // Attempt to open fresh box
          await Hive.openBox<T>(boxName, encryptionCipher: cipher);
          print('[HiveService] Recovered box "$boxName" (data lost)');
          _telemetry.increment('hive.box_recovery.success.$boxName');
          return;
        }
      }
      
      // If we couldn't find/backup the file, still try to open fresh
      await Hive.openBox<T>(boxName, encryptionCipher: cipher);
      _telemetry.increment('hive.box_recovery.success_no_backup.$boxName');
    } catch (recoveryError) {
      _telemetry.increment('hive.box_recovery.failed.$boxName');
      print('[HiveService] Recovery failed for "$boxName": $recoveryError');
      print('[HiveService] Original error was: $originalError');
      // Don't rethrow - let app continue with degraded functionality
    }
  }

  Future<void> closeAll() async {
    await Hive.close();
  }
}
