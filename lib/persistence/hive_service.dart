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
import '../models/vitals_model.dart';
import '../models/room_model.dart';
import '../models/pending_op.dart';
import '../models/failed_op_model.dart';
import '../models/audit_log_record.dart';
import '../models/settings_model.dart';
import 'box_registry.dart';
import '../services/telemetry_service.dart';

class HiveService {
  static const _secureKeyName = 'hive_enc_key_v1';
  static const _prevKeyName = 'hive_enc_key_prev';
  static const _rotationStateKey = 'rotation_state'; // stored in meta box
  final FlutterSecureStorage secureStorage;

  HiveService({required this.secureStorage});

  static Future<HiveService> create() async {
    const secure = FlutterSecureStorage();
    return HiveService(secureStorage: secure);
  }

  Future<void> init() async {
    await Hive.initFlutter();
    Hive
      ..registerAdapter(RoomAdapter())
      ..registerAdapter(PendingOpAdapter())
      ..registerAdapter(VitalsAdapter())
      ..registerAdapter(DeviceModelAdapter())
      ..registerAdapter(SessionModelAdapter())
      ..registerAdapter(UserProfileModelAdapter())
      ..registerAdapter(FailedOpModelAdapter())
      ..registerAdapter(AuditLogRecordAdapter())
      ..registerAdapter(SettingsModelAdapter())
      ..registerAdapter(AssetsCacheEntryAdapter());

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
    final meta = Hive.box(BoxRegistry.metaBox);
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
    TelemetryService.I.time('key_rotation.duration_ms', () => startSw.elapsed);
  }

  Future<void> resumeInterruptedRotation() async {
    final meta = Hive.box(BoxRegistry.metaBox);
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
    TelemetryService.I.time('key_rotation.duration_ms', () => sw.elapsed);
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
    TelemetryService.I.increment('key_rotation.box_completed');
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
        return Hive.box<RoomModel>(name);
      case BoxRegistry.pendingOpsBox:
        return Hive.box<PendingOp>(name);
      case BoxRegistry.vitalsBox:
        return Hive.box<VitalsModel>(name);
      case BoxRegistry.userProfileBox:
        return Hive.box(name); // could be UserProfileModel typed if defined
      case BoxRegistry.sessionsBox:
        return Hive.box(name); // SessionModel
      case BoxRegistry.failedOpsBox:
        return Hive.box<FailedOpModel>(name);
      case BoxRegistry.auditLogsBox:
        return Hive.box<AuditLogRecord>(name);
      case BoxRegistry.settingsBox:
        return Hive.box<SettingsModel>(name);
      default:
        return Hive.box(name);
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
    try {
      await Future.wait([
        Hive.openBox<RoomModel>(BoxRegistry.roomsBox, encryptionCipher: cipher),
        Hive.openBox<PendingOp>(BoxRegistry.pendingOpsBox, encryptionCipher: cipher),
        Hive.openBox<VitalsModel>(BoxRegistry.vitalsBox, encryptionCipher: cipher),
        Hive.openBox(BoxRegistry.userProfileBox, encryptionCipher: cipher),
        Hive.openBox(BoxRegistry.sessionsBox, encryptionCipher: cipher),
        Hive.openBox(BoxRegistry.failedOpsBox, encryptionCipher: cipher),
        Hive.openBox(BoxRegistry.auditLogsBox, encryptionCipher: cipher),
        Hive.openBox(BoxRegistry.assetsCacheBox),
        Hive.openBox(BoxRegistry.uiPreferencesBox),
        Hive.openBox(BoxRegistry.settingsBox, encryptionCipher: cipher),
        Hive.openBox(BoxRegistry.metaBox),
        Hive.openBox(BoxRegistry.pendingIndexBox),
      ]);
    } catch (e) {
      await _backupRawFiles();
      TelemetryService.I.increment('corruption.events');
      try {
        await Hive.openBox(BoxRegistry.metaBox);
        await Hive.openBox(BoxRegistry.uiPreferencesBox);
      } catch (_) {}
    }
    sw.stop();
    TelemetryService.I.time('hive.open.duration_ms', () => sw.elapsed);
  }

  Future<void> _backupRawFiles() async {
    // Determine Hive root by checking current directory for box files.
    final root = Directory.current.path;
    final backupDir = Directory('$root/corruption_backups');
    if (!backupDir.existsSync()) backupDir.createSync(recursive: true);
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    for (final name in BoxRegistry.allBoxes) {
      final f = File('$root/$name.hive');
      if (f.existsSync()) {
        f.copySync('${backupDir.path}/$name.$stamp.bak');
      }
    }
  }

  Future<void> closeAll() async {
    await Hive.close();
  }
}
