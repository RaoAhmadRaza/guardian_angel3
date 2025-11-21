import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:hive/hive.dart';
import '../../services/telemetry_service.dart';
import '../audit/audit_service.dart';
import '../../security/key_derivation.dart';

class BackupService {
  /// Export selected boxes into encrypted tarball at [destinationPath].
  /// Uses AES key bytes provided. Adds simple metadata (schemaVersion, timestamp).
  static Future<File> exportEncryptedBackup({
    required List<String> boxNames,
    required String destinationPath,
    required List<int> aesKey,
    required int schemaVersion,
  }) async {
    final sw = Stopwatch()..start();
    final encoder = TarFileEncoder();
    encoder.open(destinationPath);

    // Serialize box contents as JSON lines per box.
    for (final name in boxNames) {
      final box = Hive.box(name);
      final records = <Map<String, dynamic>>[];
      for (final k in box.keys) {
        records.add({'key': k, 'value': box.get(k)});
      }
      final data = jsonEncode(records);
      final fileName = '$name.json';
      encoder.addFile(_inMemoryToFile(fileName, utf8.encode(data)));
    }

    // Metadata file
    final meta = jsonEncode({
      'schemaVersion': schemaVersion,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'boxes': boxNames,
    });
    encoder.addFile(_inMemoryToFile('backup_meta.json', utf8.encode(meta)));
    encoder.close();

    final tarFile = File(destinationPath);
    final tarBytes = await tarFile.readAsBytes();
    final gzBytes = GZipEncoder().encode(tarBytes)!;

    // Encrypt gzipped tar
    final key = enc.Key(Uint8List.fromList(aesKey));
    final iv = enc.IV.fromLength(16); // For production, use random IV + store
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(gzBytes, iv: iv).bytes;
    final outFile = File('$destinationPath.enc');
    await outFile.writeAsBytes(encrypted, flush: true);
    sw.stop();
    TelemetryService.I.time('backup.duration_ms', () => sw.elapsed);
    TelemetryService.I.gauge('backup.size_bytes', outFile.lengthSync());
    return outFile;
  }

  /// Export using password-derived key (PBKDF2 HMAC-SHA256).
  /// Output file format: [16 bytes salt][16 bytes iv][ciphertext]
  static Future<File> exportPasswordEncryptedBackup({
    required List<String> boxNames,
    required String destinationPath,
    required String password,
    required int schemaVersion,
    AuditService? audit,
    int iterations = 150000,
  }) async {
    final sw = Stopwatch()..start();
    final encoder = TarFileEncoder();
    encoder.open(destinationPath);
    for (final name in boxNames) {
      final box = Hive.box(name);
      final records = <Map<String, dynamic>>[];
      for (final k in box.keys) {
        records.add({'key': k, 'value': box.get(k)});
      }
      final data = jsonEncode(records);
      encoder.addFile(_inMemoryToFile('$name.json', utf8.encode(data)));
    }
    final salt = randomBytes(16);
    final iv = randomBytes(16);
    final meta = jsonEncode({
      'schemaVersion': schemaVersion,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'boxes': boxNames,
      'kdf': {
        'algorithm': 'pbkdf2-hmac-sha256',
        'iterations': iterations,
        'salt_b64': base64Encode(salt),
        'derived_key_len': 32,
      },
      'cipher': {'mode': 'aes-cbc', 'iv_b64': base64Encode(iv)},
    });
    encoder.addFile(_inMemoryToFile('backup_meta.json', utf8.encode(meta)));
    encoder.close();
    final tarFile = File(destinationPath);
    final tarBytes = await tarFile.readAsBytes();
    final gzBytes = GZipEncoder().encode(tarBytes)!;
    final keyBytes = deriveKey(password: password, salt: salt, iterations: iterations, length: 32);
    final key = enc.Key(keyBytes);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(gzBytes, iv: enc.IV(iv)).bytes;
    final outFile = File('$destinationPath.penc');
    final sink = outFile.openWrite();
    sink.add(salt);
    sink.add(iv);
    sink.add(encrypted);
    await sink.close();
    sw.stop();
    TelemetryService.I.time('backup.duration_ms', () => sw.elapsed);
    TelemetryService.I.gauge('backup.size_bytes', outFile.lengthSync());
    if (audit != null) {
      await audit.append(
        type: 'backup_export',
        actor: 'system',
        payload: {
          'schemaVersion': schemaVersion,
          'boxes': boxNames,
          'iterations': iterations,
          'size_bytes': outFile.lengthSync(),
        },
      );
    }
    return outFile;
  }

  /// Preview password-encrypted backup without restoring. Returns metadata + counts.
  static Future<Map<String, dynamic>> previewPasswordEncryptedBackup({
    required String encryptedPath,
    required String password,
  }) async {
    final sw = Stopwatch()..start();
    final file = File(encryptedPath);
    if (!await file.exists()) throw StateError('File not found: $encryptedPath');
    final bytes = await file.readAsBytes();
    if (bytes.length < 32) throw StateError('Corrupt backup file');
    final salt = Uint8List.sublistView(bytes, 0, 16);
    final iv = Uint8List.sublistView(bytes, 16, 32);
    final ciphertext = Uint8List.sublistView(bytes, 32);
    final keyBytes = deriveKey(password: password, salt: salt, iterations: 150000, length: 32);
    final key = enc.Key(keyBytes);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final gzBytes = encrypter.decryptBytes(enc.Encrypted(ciphertext), iv: enc.IV(iv));
    final tarBytes = GZipDecoder().decodeBytes(gzBytes);
    final archive = TarDecoder().decodeBytes(tarBytes);
    Map<String, dynamic>? meta;
    final counts = <String, int>{};
    for (final f in archive.files) {
      if (f.name == 'backup_meta.json') {
        meta = jsonDecode(utf8.decode(f.content)) as Map<String, dynamic>;
      } else if (f.name.endsWith('.json')) {
        final list = jsonDecode(utf8.decode(f.content)) as List<dynamic>;
        counts[f.name.replaceAll('.json', '')] = list.length;
      }
    }
    if (meta == null) throw StateError('Missing metadata');
    sw.stop();
    TelemetryService.I.time('backup.preview.duration_ms', () => sw.elapsed);
    TelemetryService.I.gauge('backup.restore.preview.count_boxes', counts.length);
    return {
      'meta': meta,
      'recordCounts': counts,
    };
  }

  /// Restore from password-encrypted backup file produced by exportPasswordEncryptedBackup.
  static Future<List<String>> restorePasswordEncryptedBackup({
    required String encryptedPath,
    required String password,
    required int expectedSchemaVersion,
    bool overwriteExisting = false,
    AuditService? audit,
  }) async {
    final file = File(encryptedPath);
    if (!await file.exists()) throw StateError('File not found: $encryptedPath');
    final bytes = await file.readAsBytes();
    if (bytes.length < 32) throw StateError('Corrupt backup file');
    final salt = Uint8List.sublistView(bytes, 0, 16);
    final iv = Uint8List.sublistView(bytes, 16, 32);
    final ciphertext = Uint8List.sublistView(bytes, 32);
    final keyBytes = deriveKey(password: password, salt: salt, iterations: 150000, length: 32);
    final key = enc.Key(keyBytes);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final gzBytes = encrypter.decryptBytes(enc.Encrypted(ciphertext), iv: enc.IV(iv));
    final tarBytes = GZipDecoder().decodeBytes(gzBytes);
    final sw = Stopwatch()..start();
    final archive = TarDecoder().decodeBytes(tarBytes);
    Map<String, dynamic>? meta;
    final restoredBoxes = <String>[];
    for (final f in archive.files) {
      if (f.name == 'backup_meta.json') {
        meta = jsonDecode(utf8.decode(f.content)) as Map<String, dynamic>;
        continue;
      }
      if (f.name.endsWith('.json')) {
        final boxName = f.name.replaceAll('.json', '');
        if (!overwriteExisting && Hive.isBoxOpen(boxName) && Hive.box(boxName).isNotEmpty) {
          continue;
        }
        final records = jsonDecode(utf8.decode(f.content)) as List<dynamic>;
        final box = Hive.box(boxName);
        for (final rec in records) {
          final map = rec as Map<String, dynamic>;
          await box.put(map['key'], map['value']);
        }
        restoredBoxes.add(boxName);
      }
    }
    if (meta == null) throw StateError('Missing backup_meta.json');
    final sv = meta['schemaVersion'] as int? ?? -1;
    if (sv != expectedSchemaVersion) {
      throw StateError('Schema version mismatch backup=$sv expected=$expectedSchemaVersion');
    }
    sw.stop();
    TelemetryService.I.time('backup.restore.duration_ms', () => sw.elapsed);
    if (audit != null) {
      await audit.append(
        type: 'backup_restore',
        actor: 'system',
        payload: {
          'schemaVersion': sv,
          'restoredBoxes': restoredBoxes,
        },
      );
    }
    return restoredBoxes;
  }

  /// Restore from encrypted backup. Returns list of restored box names.
  static Future<List<String>> restoreEncryptedBackup({
    required String encryptedPath,
    required List<int> aesKey,
    required int expectedSchemaVersion,
    bool overwriteExisting = false,
  }) async {
    final encryptedFile = File(encryptedPath);
    if (!await encryptedFile.exists()) {
      throw StateError('Encrypted backup not found: $encryptedPath');
    }
    final encryptedBytes = await encryptedFile.readAsBytes();
    final key = enc.Key(Uint8List.fromList(aesKey));
    final iv = enc.IV.fromLength(16); // Must match export IV strategy
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final decrypted = encrypter.decryptBytes(enc.Encrypted(encryptedBytes), iv: iv);
    final tarBytes = GZipDecoder().decodeBytes(decrypted);
    final sw = Stopwatch()..start();

    // Write temp tar
    final tmpTar = File('$encryptedPath.tmp.tar');
    await tmpTar.writeAsBytes(tarBytes, flush: true);

    final archive = TarDecoder().decodeBytes(tarBytes);
    Map<String, dynamic>? meta;
    final restoredBoxes = <String>[];
    for (final f in archive.files) {
      if (f.name == 'backup_meta.json') {
        meta = jsonDecode(utf8.decode(f.content)) as Map<String, dynamic>;
        continue;
      }
      if (f.name.endsWith('.json')) {
        final boxName = f.name.replaceAll('.json', '');
        if (!overwriteExisting && Hive.isBoxOpen(boxName) && Hive.box(boxName).isNotEmpty) {
          // Skip existing box to avoid overwrite.
          continue;
        }
        final records = jsonDecode(utf8.decode(f.content)) as List<dynamic>;
        final box = Hive.box(boxName);
        for (final rec in records) {
          final map = rec as Map<String, dynamic>;
          await box.put(map['key'], map['value']);
        }
        restoredBoxes.add(boxName);
      }
    }
    if (meta == null) throw StateError('Missing backup_meta.json');
    final sv = meta['schemaVersion'] as int? ?? -1;
    if (sv != expectedSchemaVersion) {
      throw StateError('Schema version mismatch backup=$sv expected=$expectedSchemaVersion');
    }
    sw.stop();
    TelemetryService.I.time('backup.restore.duration_ms', () => sw.elapsed);
    return restoredBoxes;
  }

  /// Helper: create a TarFile from in-memory bytes.
  static File _inMemoryToFile(String name, List<int> bytes) {
    final file = File('${Directory.systemTemp.path}/$name');
    file.writeAsBytesSync(bytes, flush: true);
    return file;
  }
}
