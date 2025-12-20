/// AtomicTransaction - Wrapper for crash-safe multi-box Hive operations
///
/// This module provides a clean API for executing multiple Hive writes
/// atomically using Write-Ahead Logging (WAL). If a crash occurs mid-way,
/// incomplete transactions are automatically rolled back on next startup.
///
/// ## Problem Solved
/// Hive doesn't support multi-box transactions. If you write to box A then
/// box B, and a crash occurs between them, you get inconsistent state.
///
/// ## Solution
/// Uses [TransactionJournal] to:
/// 1. Record old values BEFORE each write
/// 2. Apply all writes
/// 3. Mark transaction complete
/// 4. On startup, rollback any incomplete transactions
///
/// ## Usage
/// ```dart
/// // Simple API - just wrap your operations
/// await AtomicTransaction.run(
///   operationName: 'enqueue_op',
///   operations: [
///     BoxWrite(box: pendingBox, key: opId, oldValue: null, newValue: op),
///     BoxWrite(box: indexBox, key: 'order', oldValue: oldIndex, newValue: newIndex),
///   ],
/// );
///
/// // Or use the builder pattern for dynamic operations
/// await AtomicTransaction.execute(
///   operationName: 'sync_batch',
///   builder: (txn) async {
///     final oldPending = pendingBox.get(opId);
///     txn.record(pendingBox.name, opId, oldPending);
///     await pendingBox.delete(opId);
///
///     final oldIndex = indexBox.get('order');
///     txn.record(indexBox.name, 'order', oldIndex);
///     await indexBox.put('order', newIndex);
///   },
/// );
/// ```
library;

import 'dart:async';
import 'package:hive/hive.dart';
import '../../services/telemetry_service.dart';
import 'transaction_journal.dart';

/// Represents a single box write operation.
class BoxWrite<T> {
  /// The Hive box to write to.
  final Box<T> box;

  /// The key to write.
  final dynamic key;

  /// The old value (for rollback). Pass null if key doesn't exist.
  final T? oldValue;

  /// The new value to write. Pass null to delete the key.
  final T? newValue;

  const BoxWrite({
    required this.box,
    required this.key,
    required this.oldValue,
    required this.newValue,
  });

  /// Create a write operation that adds a new key.
  factory BoxWrite.create({
    required Box<T> box,
    required dynamic key,
    required T value,
  }) {
    return BoxWrite(
      box: box,
      key: key,
      oldValue: null, // Didn't exist before
      newValue: value,
    );
  }

  /// Create a write operation that updates an existing key.
  factory BoxWrite.update({
    required Box<T> box,
    required dynamic key,
    required T oldValue,
    required T newValue,
  }) {
    return BoxWrite(
      box: box,
      key: key,
      oldValue: oldValue,
      newValue: newValue,
    );
  }

  /// Create a write operation that deletes a key.
  factory BoxWrite.delete({
    required Box<T> box,
    required dynamic key,
    required T oldValue,
  }) {
    return BoxWrite(
      box: box,
      key: key,
      oldValue: oldValue,
      newValue: null,
    );
  }
}

/// Untyped version for mixed-type operations.
class BoxWriteUntyped {
  final Box box;
  final dynamic key;
  final dynamic oldValue;
  final dynamic newValue;

  const BoxWriteUntyped({
    required this.box,
    required this.key,
    required this.oldValue,
    required this.newValue,
  });
}

/// Result of an atomic transaction.
sealed class AtomicResult {
  const AtomicResult();
}

/// Transaction completed successfully.
class AtomicSuccess extends AtomicResult {
  /// Number of operations applied.
  final int operationCount;

  /// Duration of the transaction.
  final Duration duration;

  const AtomicSuccess({
    required this.operationCount,
    required this.duration,
  });

  @override
  String toString() =>
      'AtomicSuccess(operationCount: $operationCount, duration: ${duration.inMilliseconds}ms)';
}

/// Transaction failed and was rolled back.
class AtomicFailure extends AtomicResult {
  /// The error that caused the failure.
  final Object error;

  /// Stack trace of the error.
  final StackTrace? stackTrace;

  /// Number of operations that were rolled back.
  final int rolledBackCount;

  /// Whether rollback succeeded.
  final bool rollbackSucceeded;

  const AtomicFailure({
    required this.error,
    this.stackTrace,
    required this.rolledBackCount,
    required this.rollbackSucceeded,
  });

  @override
  String toString() =>
      'AtomicFailure(error: $error, rolledBack: $rolledBackCount, rollbackSucceeded: $rollbackSucceeded)';
}

/// Builder for recording operations during a transaction.
class TransactionBuilder {
  final TransactionHandle _handle;
  final TransactionJournal _journal;
  final List<_DeferredWrite> _deferredWrites = [];

  TransactionBuilder._(this._handle, this._journal);

  /// Record a value that will be modified.
  ///
  /// Call this BEFORE each box write so the old value is captured for rollback.
  Future<void> record(String boxName, dynamic key, dynamic oldValue) async {
    await _journal.record(_handle, boxName, key, oldValue);
  }

  /// Record and immediately write a value.
  ///
  /// Combines record + write in one call for convenience.
  Future<void> write<T>(Box<T> box, dynamic key, T? newValue) async {
    final oldValue = box.get(key);
    await record(box.name, key, oldValue);

    if (newValue == null) {
      await box.delete(key);
    } else {
      await box.put(key, newValue);
    }
  }

  /// Record and immediately delete a key.
  Future<void> delete<T>(Box<T> box, dynamic key) async {
    final oldValue = box.get(key);
    await record(box.name, key, oldValue);
    await box.delete(key);
  }
}

class _DeferredWrite {
  final String boxName;
  final dynamic key;
  final dynamic newValue;
  final bool isDelete;

  _DeferredWrite({
    required this.boxName,
    required this.key,
    required this.newValue,
    required this.isDelete,
  });
}

/// Static utility class for atomic multi-box transactions.
///
/// Wraps [TransactionJournal] with a simpler API for common use cases.
class AtomicTransaction {
  AtomicTransaction._();

  static TransactionJournal? _journalOverride;

  /// Override the journal for testing.
  static void setJournalForTesting(TransactionJournal journal) {
    _journalOverride = journal;
  }

  /// Reset testing override.
  static void resetForTesting() {
    _journalOverride = null;
  }

  static TransactionJournal get _journal =>
      _journalOverride ?? TransactionJournal.I;

  /// Execute a list of box writes atomically.
  ///
  /// All writes succeed or all are rolled back.
  ///
  /// Example:
  /// ```dart
  /// await AtomicTransaction.run(
  ///   operationName: 'enqueue_op',
  ///   operations: [
  ///     BoxWrite(box: pendingBox, key: opId, oldValue: null, newValue: op),
  ///     BoxWrite(box: indexBox, key: 'order', oldValue: oldIndex, newValue: newIndex),
  ///   ],
  /// );
  /// ```
  static Future<AtomicResult> run({
    required String operationName,
    required List<BoxWriteUntyped> operations,
  }) async {
    if (operations.isEmpty) {
      return const AtomicSuccess(operationCount: 0, duration: Duration.zero);
    }

    final sw = Stopwatch()..start();
    final txnId = '${operationName}_${DateTime.now().microsecondsSinceEpoch}';
    final handle = await _journal.begin(txnId);

    try {
      // Phase 1: Record all old values in journal
      for (final op in operations) {
        await _journal.record(handle, op.box.name, op.key, op.oldValue);
      }

      // Phase 2: Apply all writes
      for (final op in operations) {
        if (op.newValue == null) {
          await op.box.delete(op.key);
        } else {
          await op.box.put(op.key, op.newValue);
        }
      }

      // Phase 3: Commit - removes journal entry
      await _journal.commit(handle);

      sw.stop();
      TelemetryService.I.increment('atomic_transaction.success');
      TelemetryService.I.time('atomic_transaction.duration', () => sw.elapsed);

      return AtomicSuccess(
        operationCount: operations.length,
        duration: sw.elapsed,
      );
    } catch (e, st) {
      // Rollback on any failure
      bool rollbackSucceeded = true;
      try {
        await _journal.rollback(handle);
      } catch (rollbackError) {
        rollbackSucceeded = false;
        TelemetryService.I.increment('atomic_transaction.rollback_failed');
        // ignore: avoid_print
        print('[AtomicTransaction] CRITICAL: Rollback failed: $rollbackError');
      }

      sw.stop();
      TelemetryService.I.increment('atomic_transaction.failure');
      TelemetryService.I.increment('atomic_transaction.failure.$operationName');

      return AtomicFailure(
        error: e,
        stackTrace: st,
        rolledBackCount: handle.entries.length,
        rollbackSucceeded: rollbackSucceeded,
      );
    }
  }

  /// Execute a transaction using a builder function.
  ///
  /// More flexible than [run] - allows dynamic operations.
  ///
  /// Example:
  /// ```dart
  /// await AtomicTransaction.execute(
  ///   operationName: 'sync_batch',
  ///   builder: (txn) async {
  ///     await txn.write(pendingBox, opId, null); // delete
  ///     await txn.write(indexBox, 'order', newIndex);
  ///   },
  /// );
  /// ```
  static Future<AtomicResult> execute({
    required String operationName,
    required Future<void> Function(TransactionBuilder txn) builder,
  }) async {
    final sw = Stopwatch()..start();
    final txnId = '${operationName}_${DateTime.now().microsecondsSinceEpoch}';
    final handle = await _journal.begin(txnId);
    final txnBuilder = TransactionBuilder._(handle, _journal);

    try {
      // Execute the builder function which records and writes
      await builder(txnBuilder);

      // Commit - removes journal entry
      await _journal.commit(handle);

      sw.stop();
      TelemetryService.I.increment('atomic_transaction.success');
      TelemetryService.I.time('atomic_transaction.duration', () => sw.elapsed);

      return AtomicSuccess(
        operationCount: handle.entries.length,
        duration: sw.elapsed,
      );
    } catch (e, st) {
      // Rollback on any failure
      bool rollbackSucceeded = true;
      try {
        await _journal.rollback(handle);
      } catch (rollbackError) {
        rollbackSucceeded = false;
        TelemetryService.I.increment('atomic_transaction.rollback_failed');
        // ignore: avoid_print
        print('[AtomicTransaction] CRITICAL: Rollback failed: $rollbackError');
      }

      sw.stop();
      TelemetryService.I.increment('atomic_transaction.failure');
      TelemetryService.I.increment('atomic_transaction.failure.$operationName');

      return AtomicFailure(
        error: e,
        stackTrace: st,
        rolledBackCount: handle.entries.length,
        rollbackSucceeded: rollbackSucceeded,
      );
    }
  }

  /// Convenience method that throws on failure.
  ///
  /// Use when you want the atomic transaction to behave like a normal
  /// async operation that throws on failure.
  static Future<void> runOrThrow({
    required String operationName,
    required List<BoxWriteUntyped> operations,
  }) async {
    final result = await run(operationName: operationName, operations: operations);
    switch (result) {
      case AtomicSuccess():
        return;
      case AtomicFailure(error: final e, stackTrace: final st):
        Error.throwWithStackTrace(e, st ?? StackTrace.current);
    }
  }

  /// Convenience method for execute that throws on failure.
  static Future<void> executeOrThrow({
    required String operationName,
    required Future<void> Function(TransactionBuilder txn) builder,
  }) async {
    final result = await execute(operationName: operationName, builder: builder);
    switch (result) {
      case AtomicSuccess():
        return;
      case AtomicFailure(error: final e, stackTrace: final st):
        Error.throwWithStackTrace(e, st ?? StackTrace.current);
    }
  }

  /// Initialize the transaction journal. Call during app bootstrap.
  static Future<void> initialize() async {
    await _journal.init();
  }

  /// Replay and rollback any pending transactions from previous crash.
  /// Call during app bootstrap AFTER all boxes are opened.
  static Future<int> replayPendingTransactions() async {
    return _journal.replayPendingJournals();
  }
}
