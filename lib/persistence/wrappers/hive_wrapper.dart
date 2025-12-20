import 'package:hive/hive.dart';
import '../../services/telemetry_service.dart';
import '../transactions/atomic_transaction.dart';

class HiveWrapper {
  static Future<void> safePut<T>(Box<T> box, dynamic key, T value) async {
    try {
      await box.put(key, value);
    } catch (e) {
      rethrow;
    }
  }

  /// **WARNING: This is NOT atomic across boxes.**
  ///
  /// @deprecated Use [AtomicTransaction.execute] instead for true atomicity.
  ///
  /// Hive does not support multi-box transactions. This method executes
  /// the callback as a best-effort sequential write. If a failure occurs
  /// mid-way, earlier writes will persist while later ones will not.
  ///
  /// **Callers MUST tolerate partial failure.**
  ///
  /// Failure scenarios this does NOT protect against:
  /// - Crash between index write and data write
  /// - Power loss during callback execution
  /// - Exception after first write completes
  ///
  /// For critical operations requiring atomicity, use [AtomicTransaction]:
  /// ```dart
  /// await AtomicTransaction.execute(
  ///   operationName: 'my_operation',
  ///   builder: (txn) async {
  ///     await txn.write(box1, key1, value1);
  ///     await txn.write(box2, key2, value2);
  ///   },
  /// );
  /// ```
  ///
  /// Telemetry: Non-atomic failures are recorded to `hive.best_effort_write.partial_failure`.
  @Deprecated('Use AtomicTransaction.execute for true atomicity. '
      'bestEffortWrite does NOT protect against partial failures.')
  static Future<void> bestEffortWrite(
    Future<void> Function() cb, {
    String? operationName,
  }) async {
    final opName = operationName ?? 'unknown';
    try {
      await cb();
    } catch (e) {
      // Record failure with operation context for debugging
      TelemetryService.I.increment('hive.best_effort_write.partial_failure');
      TelemetryService.I.increment('hive.best_effort_write.error.$opName');
      // Log for debugging (error details available in catch at call site)
      rethrow;
    }
  }

  /// @Deprecated('Use bestEffortWrite instead. transactionalWrite is misleading - Hive has no transactions.')
  /// Alias for backward compatibility. Will be removed in a future version.
  @Deprecated('Use AtomicTransaction.execute instead. This method name is misleading - Hive does not support transactions.')
  static Future<void> transactionalWrite(Future<void> Function() cb) async {
    // ignore: deprecated_member_use_from_same_package
    await bestEffortWrite(cb, operationName: 'legacy_transactional_write');
  }

  static Box<T> getBox<T>(String name) => Hive.box<T>(name);
}
