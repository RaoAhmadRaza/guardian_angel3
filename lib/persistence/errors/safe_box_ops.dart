/// Safe Box Operations
///
/// Wraps all Hive box operations with error handling.
/// ALL repository code should use these methods instead of raw box calls.
///
/// PHASE 1 BLOCKER FIX: Prevents app crashes from HiveError.
library;

import 'package:hive/hive.dart';
import 'hive_error_handler.dart';
import '../../services/telemetry_service.dart';

/// Result of a safe box operation.
sealed class BoxOpResult<T> {
  const BoxOpResult();
}

/// Operation succeeded with a value.
class BoxOpSuccess<T> extends BoxOpResult<T> {
  final T value;
  const BoxOpSuccess(this.value);
}

/// Operation succeeded with no return value (void operations).
class BoxOpVoid<T> extends BoxOpResult<T> {
  const BoxOpVoid();
}

/// Operation failed with a categorized error.
class BoxOpFailure<T> extends BoxOpResult<T> {
  final PersistenceError error;
  const BoxOpFailure(this.error);
}

/// Extension on BoxOpResult for convenient handling.
extension BoxOpResultX<T> on BoxOpResult<T> {
  /// Returns the value if success, throws if failure.
  T get valueOrThrow {
    return switch (this) {
      BoxOpSuccess(:final value) => value,
      BoxOpVoid() => throw StateError('Operation returned void, not a value'),
      BoxOpFailure(:final error) => throw error,
    };
  }

  /// Returns the value if success, null if failure or void.
  T? get valueOrNull {
    return switch (this) {
      BoxOpSuccess(:final value) => value,
      BoxOpVoid() => null,
      BoxOpFailure() => null,
    };
  }

  /// Returns true if operation succeeded.
  bool get isSuccess => this is BoxOpSuccess || this is BoxOpVoid;

  /// Returns true if operation failed.
  bool get isFailure => this is BoxOpFailure;

  /// Returns the error if failure, null otherwise.
  PersistenceError? get error {
    return switch (this) {
      BoxOpFailure(:final error) => error,
      _ => null,
    };
  }

  /// Execute callback on success.
  BoxOpResult<T> onSuccess(void Function(T? value) callback) {
    if (this is BoxOpSuccess<T>) {
      callback((this as BoxOpSuccess<T>).value);
    } else if (this is BoxOpVoid) {
      callback(null);
    }
    return this;
  }

  /// Execute callback on failure.
  BoxOpResult<T> onFailure(void Function(PersistenceError error) callback) {
    if (this is BoxOpFailure<T>) {
      callback((this as BoxOpFailure<T>).error);
    }
    return this;
  }
}

/// Safe wrapper for all Hive box operations.
///
/// Usage:
/// ```dart
/// final result = await SafeBoxOps.put(box, 'key', value, boxName: 'my_box');
/// result.onSuccess((_) => print('Saved!'))
///       .onFailure((e) => showError(e.userMessage));
/// ```
class SafeBoxOps {
  /// Safely put a value into a box.
  static Future<BoxOpResult<void>> put<T>(
    Box<T> box,
    dynamic key,
    T value, {
    required String boxName,
  }) async {
    try {
      await box.put(key, value);
      TelemetryService.I.increment('hive.op.put.success.$boxName');
      return const BoxOpVoid();
    } catch (e, st) {
      final error = HiveErrorHandler.categorize(e, st, boxName: boxName);
      HiveErrorHandler.record(error);
      return BoxOpFailure(error);
    }
  }

  /// Safely put multiple values into a box.
  static Future<BoxOpResult<void>> putAll<T>(
    Box<T> box,
    Map<dynamic, T> entries, {
    required String boxName,
  }) async {
    try {
      await box.putAll(entries);
      TelemetryService.I.increment('hive.op.putAll.success.$boxName');
      return const BoxOpVoid();
    } catch (e, st) {
      final error = HiveErrorHandler.categorize(e, st, boxName: boxName);
      HiveErrorHandler.record(error);
      return BoxOpFailure(error);
    }
  }

  /// Safely get a value from a box.
  static BoxOpResult<T?> get<T>(
    Box<T> box,
    dynamic key, {
    required String boxName,
    T? defaultValue,
  }) {
    try {
      final value = box.get(key, defaultValue: defaultValue);
      TelemetryService.I.increment('hive.op.get.success.$boxName');
      return BoxOpSuccess(value);
    } catch (e, st) {
      final error = HiveErrorHandler.categorize(e, st, boxName: boxName);
      HiveErrorHandler.record(error);
      return BoxOpFailure(error);
    }
  }

  /// Safely get all values from a box.
  static BoxOpResult<Iterable<T>> getAll<T>(
    Box<T> box, {
    required String boxName,
  }) {
    try {
      final values = box.values;
      TelemetryService.I.increment('hive.op.getAll.success.$boxName');
      return BoxOpSuccess(values);
    } catch (e, st) {
      final error = HiveErrorHandler.categorize(e, st, boxName: boxName);
      HiveErrorHandler.record(error);
      return BoxOpFailure(error);
    }
  }

  /// Safely delete a value from a box.
  static Future<BoxOpResult<void>> delete<T>(
    Box<T> box,
    dynamic key, {
    required String boxName,
  }) async {
    try {
      await box.delete(key);
      TelemetryService.I.increment('hive.op.delete.success.$boxName');
      return const BoxOpVoid();
    } catch (e, st) {
      final error = HiveErrorHandler.categorize(e, st, boxName: boxName);
      HiveErrorHandler.record(error);
      return BoxOpFailure(error);
    }
  }

  /// Safely delete multiple values from a box.
  static Future<BoxOpResult<void>> deleteAll<T>(
    Box<T> box,
    Iterable<dynamic> keys, {
    required String boxName,
  }) async {
    try {
      await box.deleteAll(keys);
      TelemetryService.I.increment('hive.op.deleteAll.success.$boxName');
      return const BoxOpVoid();
    } catch (e, st) {
      final error = HiveErrorHandler.categorize(e, st, boxName: boxName);
      HiveErrorHandler.record(error);
      return BoxOpFailure(error);
    }
  }

  /// Safely clear all values from a box.
  static Future<BoxOpResult<void>> clear<T>(
    Box<T> box, {
    required String boxName,
  }) async {
    try {
      await box.clear();
      TelemetryService.I.increment('hive.op.clear.success.$boxName');
      return const BoxOpVoid();
    } catch (e, st) {
      final error = HiveErrorHandler.categorize(e, st, boxName: boxName);
      HiveErrorHandler.record(error);
      return BoxOpFailure(error);
    }
  }

  /// Safely add a value to a box (auto-increment key).
  static Future<BoxOpResult<int>> add<T>(
    Box<T> box,
    T value, {
    required String boxName,
  }) async {
    try {
      final key = await box.add(value);
      TelemetryService.I.increment('hive.op.add.success.$boxName');
      return BoxOpSuccess(key);
    } catch (e, st) {
      final error = HiveErrorHandler.categorize(e, st, boxName: boxName);
      HiveErrorHandler.record(error);
      return BoxOpFailure(error);
    }
  }

  /// Safely compact a box.
  static Future<BoxOpResult<void>> compact<T>(
    Box<T> box, {
    required String boxName,
  }) async {
    try {
      await box.compact();
      TelemetryService.I.increment('hive.op.compact.success.$boxName');
      return const BoxOpVoid();
    } catch (e, st) {
      final error = HiveErrorHandler.categorize(e, st, boxName: boxName);
      HiveErrorHandler.record(error);
      return BoxOpFailure(error);
    }
  }

  /// Safely check if a key exists in a box.
  static BoxOpResult<bool> containsKey<T>(
    Box<T> box,
    dynamic key, {
    required String boxName,
  }) {
    try {
      final contains = box.containsKey(key);
      return BoxOpSuccess(contains);
    } catch (e, st) {
      final error = HiveErrorHandler.categorize(e, st, boxName: boxName);
      HiveErrorHandler.record(error);
      return BoxOpFailure(error);
    }
  }

  /// Safely get box length.
  static BoxOpResult<int> length<T>(
    Box<T> box, {
    required String boxName,
  }) {
    try {
      final len = box.length;
      return BoxOpSuccess(len);
    } catch (e, st) {
      final error = HiveErrorHandler.categorize(e, st, boxName: boxName);
      HiveErrorHandler.record(error);
      return BoxOpFailure(error);
    }
  }

  /// Safely get all keys from a box.
  static BoxOpResult<Iterable<dynamic>> keys<T>(
    Box<T> box, {
    required String boxName,
  }) {
    try {
      final boxKeys = box.keys;
      return BoxOpSuccess(boxKeys);
    } catch (e, st) {
      final error = HiveErrorHandler.categorize(e, st, boxName: boxName);
      HiveErrorHandler.record(error);
      return BoxOpFailure(error);
    }
  }
}

/// Extension methods on Box for inline safe operations.
///
/// Usage:
/// ```dart
/// final result = await box.safePut('key', value, boxName: 'my_box');
/// ```
extension SafeBoxExtension<T> on Box<T> {
  Future<BoxOpResult<void>> safePut(
    dynamic key,
    T value, {
    required String boxName,
  }) =>
      SafeBoxOps.put(this, key, value, boxName: boxName);

  Future<BoxOpResult<void>> safePutAll(
    Map<dynamic, T> entries, {
    required String boxName,
  }) =>
      SafeBoxOps.putAll(this, entries, boxName: boxName);

  BoxOpResult<T?> safeGet(
    dynamic key, {
    required String boxName,
    T? defaultValue,
  }) =>
      SafeBoxOps.get(this, key, boxName: boxName, defaultValue: defaultValue);

  BoxOpResult<Iterable<T>> safeGetAll({required String boxName}) =>
      SafeBoxOps.getAll(this, boxName: boxName);

  Future<BoxOpResult<void>> safeDelete(
    dynamic key, {
    required String boxName,
  }) =>
      SafeBoxOps.delete(this, key, boxName: boxName);

  Future<BoxOpResult<void>> safeDeleteAll(
    Iterable<dynamic> keys, {
    required String boxName,
  }) =>
      SafeBoxOps.deleteAll(this, keys, boxName: boxName);

  Future<BoxOpResult<void>> safeClear({required String boxName}) =>
      SafeBoxOps.clear(this, boxName: boxName);

  Future<BoxOpResult<int>> safeAdd(
    T value, {
    required String boxName,
  }) =>
      SafeBoxOps.add(this, value, boxName: boxName);

  Future<BoxOpResult<void>> safeCompact({required String boxName}) =>
      SafeBoxOps.compact(this, boxName: boxName);

  BoxOpResult<bool> safeContainsKey(
    dynamic key, {
    required String boxName,
  }) =>
      SafeBoxOps.containsKey(this, key, boxName: boxName);

  BoxOpResult<int> safeLength({required String boxName}) =>
      SafeBoxOps.length(this, boxName: boxName);

  BoxOpResult<Iterable<dynamic>> safeKeys({required String boxName}) =>
      SafeBoxOps.keys(this, boxName: boxName);
}
