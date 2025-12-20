// test/bootstrap.dart
// Test bootstrap utilities for Guardian Angel sync engine tests
// Provides: temp Hive initialization, mock secure storage, deterministic RNG

import 'dart:io';
import 'dart:math';
import 'package:hive/hive.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:guardian_angel_fyp/persistence/adapters/pending_op_adapter.dart';

/// In-memory secure storage for testing
/// Avoids real keychain/keystore access in tests
class InMemorySecureStorage extends FlutterSecureStorage {
  final Map<String, String> _store = {};
  
  InMemorySecureStorage() : super();

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _store[key] = value;
    } else {
      _store.remove(key);
    }
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _store[key];
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _store.remove(key);
  }

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _store.clear();
  }

  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return Map.from(_store);
  }

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _store.containsKey(key);
  }
}

/// Initialize Hive with temporary directory for tests
/// Returns path to temp directory (cleanup required by caller)
Future<String> initTestHive() async {
  final tmp = Directory.systemTemp.createTempSync('guardian_hive_test_');
  Hive.init(tmp.path);
  
  // Register required adapters for sync engine
  if (!Hive.isAdapterRegistered(100)) {
    Hive.registerAdapter(PendingOpAdapter());
  }
  
  return tmp.path;
}

/// Clean up test Hive directory
Future<void> cleanupTestHive(String hivePath) async {
  try {
    // Close all boxes first
    await Hive.close();
    
    // Delete temp directory
    final dir = Directory(hivePath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  } catch (e) {
    // Ignore cleanup errors in tests
    print('Warning: Failed to cleanup test Hive: $e');
  }
}

/// Deterministic Random for testing
/// Allows reproducible test runs with fixed seed
class DeterministicRandom implements Random {
  final Random _inner;
  
  DeterministicRandom([int? seed]) : _inner = Random(seed ?? 42);

  @override
  bool nextBool() => _inner.nextBool();

  @override
  double nextDouble() => _inner.nextDouble();

  @override
  int nextInt(int max) => _inner.nextInt(max);
}

/// Create deterministic RNG with fixed seed
Random createDeterministicRng([int seed = 42]) {
  return DeterministicRandom(seed);
}

/// Test utilities for common assertions
class TestUtils {
  /// Wait for condition with timeout
  static Future<void> waitFor(
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 5),
    Duration pollInterval = const Duration(milliseconds: 100),
  }) async {
    final start = DateTime.now();
    while (!condition()) {
      if (DateTime.now().difference(start) > timeout) {
        throw TimeoutException('Condition not met within $timeout');
      }
      await Future.delayed(pollInterval);
    }
  }

  /// Wait for async condition with timeout
  static Future<void> waitForAsync(
    Future<bool> Function() condition, {
    Duration timeout = const Duration(seconds: 5),
    Duration pollInterval = const Duration(milliseconds: 100),
  }) async {
    final start = DateTime.now();
    while (!(await condition())) {
      if (DateTime.now().difference(start) > timeout) {
        throw TimeoutException('Async condition not met within $timeout');
      }
      await Future.delayed(pollInterval);
    }
  }

  /// Create temp file for testing
  static File createTempFile(String prefix, [String? content]) {
    final file = File('${Directory.systemTemp.path}/$prefix-${DateTime.now().millisecondsSinceEpoch}.tmp');
    if (content != null) {
      file.writeAsStringSync(content);
    }
    return file;
  }
}

/// Test timeout exception
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  
  @override
  String toString() => 'TimeoutException: $message';
}
