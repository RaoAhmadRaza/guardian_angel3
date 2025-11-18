import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Simple secure credentials storage using platform Keychain/Keystore.
class CredentialsStore {
  final FlutterSecureStorage _storage;
  CredentialsStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<void> write(String key, String value) => _storage.write(key: key, value: value);
  Future<String?> read(String key) => _storage.read(key: key);
  Future<void> delete(String key) => _storage.delete(key: key);
}

final credentialsStoreProvider = Provider<CredentialsStore>((ref) => CredentialsStore());
