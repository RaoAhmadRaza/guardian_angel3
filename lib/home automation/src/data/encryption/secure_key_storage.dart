import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

/// Securely manages Hive AES keys using platform keychains.
class SecureKeyStorage {
  static const _keyPrefix = 'hive_key_';
  static final IOSOptions _iosOptions = IOSOptions();
  static final AndroidOptions _androidOptions = const AndroidOptions(encryptedSharedPreferences: true);

  static final FlutterSecureStorage _storage = FlutterSecureStorage(iOptions: _iosOptions, aOptions: _androidOptions);

  /// Returns a 256-bit key for [name], creating and persisting one if missing.
  static Future<Uint8List> getOrCreateKey(String name) async {
    final keyName = '$_keyPrefix$name';
    final existing = await _storage.read(key: keyName);
    if (existing != null && existing.isNotEmpty) {
      return base64Decode(existing);
    }
    final key = Hive.generateSecureKey();
    await _storage.write(key: keyName, value: base64Encode(key));
    return Uint8List.fromList(key);
  }

  /// Builds a HiveAesCipher for the named key.
  static Future<HiveAesCipher> getCipher(String name) async {
    final key = await getOrCreateKey(name);
    return HiveAesCipher(key);
  }

  /// Deletes the stored key (use with caution; encrypted boxes will be unreadable after deletion).
  static Future<void> deleteKey(String name) async {
    final keyName = '$_keyPrefix$name';
    await _storage.delete(key: keyName);
  }
}
