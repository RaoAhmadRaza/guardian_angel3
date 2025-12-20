import 'dart:async';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'models/transaction_record.dart';
import 'telemetry_service.dart';
import '../persistence/wrappers/box_accessor.dart';

/// TransactionService provides atomic operations across multiple Hive boxes.
/// 
/// Since Hive doesn't support multi-box transactions, we emulate atomicity by:
/// 1. Writing a single TransactionRecord to transaction_log box (atomic)
/// 2. On commit, apply changes to target boxes
/// 3. On startup, recover incomplete transactions
/// 
/// This ensures crash consistency: either all changes apply or none do.
class TransactionService {
  static const String _boxName = 'transaction_log';
  static final _uuid = Uuid();
  
  final TelemetryService _telemetry;
  Box<TransactionRecord>? _box;
  TransactionRecord? _currentTransaction;
  
  /// Creates a TransactionService with optional injected TelemetryService.
  TransactionService({TelemetryService? telemetry})
      : _telemetry = telemetry ?? TelemetryService.I;

  /// Initialize the transaction service and recover incomplete transactions.
  Future<void> init() async {
    if (!Hive.isAdapterRegistered(30)) {
      Hive.registerAdapter(TransactionRecordAdapter());
    }
    if (!Hive.isAdapterRegistered(31)) {
      Hive.registerAdapter(TransactionStateAdapter());
    }

    if (!Hive.isBoxOpen(_boxName)) {
      _box = await Hive.openBox<TransactionRecord>(_boxName);
    } else {
      _box = Hive.box<TransactionRecord>(_boxName);
    }

    await _recoverIncompleteTransactions();
    await _purgeOldTransactions();
  }

  /// Begin a new transaction. Must call commit() or rollback() to complete.
  /// Returns the transaction ID for tracking.
  String beginTransaction() {
    if (_currentTransaction != null) {
      throw StateError('Transaction already in progress: ${_currentTransaction!.transactionId}');
    }

    final txId = 'tx_${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4().substring(0, 8)}';
    _currentTransaction = TransactionRecord.pending(txId);
    
    _telemetry.increment('transaction.begun');
    return txId;
  }

  /// Add a model state change to the current transaction.
  /// boxName: Target Hive box name (e.g., 'devices_v1')
  /// key: Entity key
  /// value: Entity value (must be Hive-serializable)
  void writeModelState(String boxName, String key, dynamic value) {
    if (_currentTransaction == null) {
      throw StateError('No transaction in progress');
    }

    _currentTransaction!.addModelChange(boxName, key, value);
  }

  /// Enqueue a pending operation in the current transaction.
  /// op: PendingOp as Map<String, dynamic> (will be stored in pending_ops box on commit)
  void enqueuePendingOp(Map<String, dynamic> op) {
    if (_currentTransaction == null) {
      throw StateError('No transaction in progress');
    }

    _currentTransaction!.setPendingOp(op);
  }

  /// Add an index entry to the current transaction.
  /// indexBoxName: Name of the index box (e.g., 'pending_index')
  /// opId: Operation ID to append to the index
  void addIndexEntry(String indexBoxName, String opId) {
    if (_currentTransaction == null) {
      throw StateError('No transaction in progress');
    }

    _currentTransaction!.addIndexEntry(indexBoxName, opId);
  }

  /// Commit the current transaction atomically.
  /// This writes the transaction record to the log box (atomic write),
  /// then applies changes to target boxes.
  Future<void> commitTransaction() async {
    if (_currentTransaction == null) {
      throw StateError('No transaction in progress');
    }
    if (_box == null) await init();

    final stopwatch = Stopwatch()..start();
    try {
      // Step 1: Mark as committed and write to transaction log (ATOMIC)
      _currentTransaction!.commit();
      await _box!.put(_currentTransaction!.transactionId, _currentTransaction!);

      // Step 2: Apply changes to target boxes
      await _applyTransaction(_currentTransaction!);

      // Step 3: Mark as applied
      _currentTransaction!.markApplied();
      await _box!.put(_currentTransaction!.transactionId, _currentTransaction!);

      stopwatch.stop();
      _telemetry.gauge('transaction.duration_ms', stopwatch.elapsedMilliseconds);
      _telemetry.increment('transaction.committed');
    } catch (e) {
      // Mark transaction as failed
      _currentTransaction!.markFailed(e.toString());
      await _box!.put(_currentTransaction!.transactionId, _currentTransaction!);

      _telemetry.increment('transaction.commit_failed');
      rethrow;
    } finally {
      _currentTransaction = null;
    }
  }

  /// Rollback the current transaction (discard all changes).
  Future<void> rollbackTransaction() async {
    if (_currentTransaction == null) {
      throw StateError('No transaction in progress');
    }

    _currentTransaction!.markFailed('Rolled back by user');
    await _box!.put(_currentTransaction!.transactionId, _currentTransaction!);
    _currentTransaction = null;

    _telemetry.increment('transaction.rollbacks');
  }

  /// Apply a transaction's changes to target boxes.
  Future<void> _applyTransaction(TransactionRecord tx) async {
    // Apply model state changes
    for (final boxEntry in tx.modelChanges.entries) {
      final boxName = boxEntry.key;
      final changes = boxEntry.value;

      final box = Hive.isBoxOpen(boxName) ? BoxAccess.I.boxUntyped(boxName) : await Hive.openBox(boxName);
      for (final change in changes.entries) {
        await box.put(change.key, change.value);
      }
    }

    // Apply pending operation
    if (tx.pendingOp != null) {
      final pendingBox = Hive.isBoxOpen('pending_ops_v1') ? BoxAccess.I.boxUntyped('pending_ops_v1') : await Hive.openBox('pending_ops_v1');
      final opId = tx.pendingOp!['opId'] as String;
      await pendingBox.put(opId, tx.pendingOp);
    }

    // Apply index entries
    for (final indexEntry in tx.indexEntries.entries) {
      final indexBoxName = indexEntry.key;
      final opIds = indexEntry.value;

      final indexBox = Hive.isBoxOpen(indexBoxName) ? BoxAccess.I.boxUntyped(indexBoxName) : await Hive.openBox(indexBoxName);
      final existingIndex = indexBox.get('opIds', defaultValue: <String>[]) ?? <String>[];
      existingIndex.addAll(opIds);
      await indexBox.put('opIds', existingIndex);
    }
  }

  /// Recover incomplete transactions on startup (crash recovery).
  Future<void> _recoverIncompleteTransactions() async {
    if (_box == null) return;

    final stopwatch = Stopwatch()..start();
    int recoveredCount = 0;

    for (final tx in _box!.values) {
      if (tx.isIncomplete) {
        try {
          await _applyTransaction(tx);
          tx.markApplied();
          await _box!.put(tx.transactionId, tx);
          recoveredCount++;

          _telemetry.increment('transaction.recovery.applied');
        } catch (e) {
          tx.markFailed('Recovery failed: $e');
          await _box!.put(tx.transactionId, tx);

          _telemetry.increment('transaction.recovery.failed');
        }
      }
    }

    stopwatch.stop();
    if (recoveredCount > 0) {
      _telemetry.gauge('transaction.recovery.duration_ms', stopwatch.elapsedMilliseconds);
      _telemetry.gauge('transaction.recovery.incomplete_found', recoveredCount);
      print('[TransactionService] Recovered $recoveredCount incomplete transactions in ${stopwatch.elapsedMilliseconds}ms');
    }
  }

  /// Purge old applied/failed transactions to prevent unbounded growth.
  Future<void> _purgeOldTransactions() async {
    if (_box == null) return;

    final toPurge = <String>[];
    for (final tx in _box!.values) {
      if (tx.canPurge) {
        toPurge.add(tx.transactionId);
      }
    }

    for (final txId in toPurge) {
      await _box!.delete(txId);
    }

    if (toPurge.isNotEmpty) {
      _telemetry.gauge('transaction.purged_count', toPurge.length);
      print('[TransactionService] Purged ${toPurge.length} old transactions');
    }
  }

  /// Get transaction statistics for monitoring.
  Map<String, dynamic> getStats() {
    if (_box == null) return {};

    int pending = 0;
    int committed = 0;
    int applied = 0;
    int failed = 0;

    for (final tx in _box!.values) {
      switch (tx.state) {
        case TransactionState.pending:
          pending++;
          break;
        case TransactionState.committed:
          committed++;
          break;
        case TransactionState.applied:
          applied++;
          break;
        case TransactionState.failed:
          failed++;
          break;
      }
    }

    return {
      'pending': pending,
      'committed': committed,
      'applied': applied,
      'failed': failed,
      'total': _box!.length,
    };
  }

  /// Manually trigger recovery (for testing/debugging).
  Future<void> recoverNow() async {
    await _recoverIncompleteTransactions();
  }

  /// Manually trigger purge (for testing/debugging).
  Future<void> purgeNow() async {
    await _purgeOldTransactions();
  }

  /// Close the transaction log box.
  Future<void> dispose() async {
    await _box?.close();
    _box = null;
    _currentTransaction = null;
  }
}
