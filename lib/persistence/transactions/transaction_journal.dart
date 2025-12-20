/// TransactionJournal - Atomic Multi-Box Transactions for Hive
///
/// Provides ACID-like semantics for operations spanning multiple Hive boxes.
/// Uses Write-Ahead Logging (WAL) pattern to ensure crash recovery.
///
/// DESIGN:
/// 1. begin() - Creates a new transaction, returns TransactionHandle
/// 2. record() - Records each box write in the journal before applying
/// 3. commit() - Marks transaction complete, deletes journal entry
/// 4. rollback() - Reverts all recorded changes using saved snapshots
///
/// ON STARTUP:
/// - replayPendingJournals() checks for incomplete transactions
/// - If found, automatically rolls them back (restore to pre-transaction state)
///
/// USAGE:
/// ```dart
/// final txn = await TransactionJournal.I.begin('sync_batch_123');
/// try {
///   await TransactionJournal.I.record(txn, 'pending_ops', key, oldValue);
///   await pendingBox.put(key, newValue);
///   await TransactionJournal.I.record(txn, 'vitals', vitalKey, oldVital);
///   await vitalsBox.put(vitalKey, newVital);
///   await TransactionJournal.I.commit(txn);
/// } catch (e) {
///   await TransactionJournal.I.rollback(txn);
///   rethrow;
/// }
/// ```
library;

import 'dart:convert';
import 'package:hive/hive.dart';
import '../../services/telemetry_service.dart';
import '../wrappers/box_accessor.dart';

/// State of a transaction in the journal.
enum TransactionState {
  /// Transaction is active, writes are being recorded.
  active,
  /// Transaction is being committed (all writes applied).
  committing,
  /// Transaction committed successfully.
  committed,
  /// Transaction is being rolled back.
  rollingBack,
  /// Transaction rolled back (aborted).
  rolledBack,
}

/// Handle returned by begin() to track a transaction.
class TransactionHandle {
  final String id;
  final DateTime startedAt;
  TransactionState state;
  final List<JournalEntry> entries;

  TransactionHandle({
    required this.id,
    required this.startedAt,
    this.state = TransactionState.active,
    List<JournalEntry>? entries,
  }) : entries = entries ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'startedAt': startedAt.toIso8601String(),
        'state': state.name,
        'entries': entries.map((e) => e.toJson()).toList(),
      };

  factory TransactionHandle.fromJson(Map<String, dynamic> json) {
    return TransactionHandle(
      id: json['id'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      state: TransactionState.values.firstWhere(
        (s) => s.name == json['state'],
        orElse: () => TransactionState.active,
      ),
      entries: (json['entries'] as List<dynamic>?)
              ?.map((e) => JournalEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// A single recorded write in the journal.
class JournalEntry {
  final String boxName;
  final dynamic key;
  final String? snapshotJson; // JSON-encoded old value, null if key didn't exist

  JournalEntry({
    required this.boxName,
    required this.key,
    this.snapshotJson,
  });

  Map<String, dynamic> toJson() => {
        'boxName': boxName,
        'key': key?.toString(),
        'snapshotJson': snapshotJson,
      };

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      boxName: json['boxName'] as String,
      key: json['key'],
      snapshotJson: json['snapshotJson'] as String?,
    );
  }
}

/// Transaction Journal - Singleton for managing atomic multi-box transactions.
class TransactionJournal {
  @Deprecated('Use transactionJournalProvider from domain_providers.dart instead')
  static TransactionJournal? _instance;
  @Deprecated('Use transactionJournalProvider from domain_providers.dart instead')
  static TransactionJournal get I => _instance ??= TransactionJournal._();

  TransactionJournal._() : _telemetry = TelemetryService.I;
  
  /// DI constructor for testing and proper injection.
  TransactionJournal({TelemetryService? telemetry})
      : _telemetry = telemetry ?? TelemetryService.I;

  /// For testing - reset singleton
  static void resetForTesting() {
    _instance = null;
  }

  final TelemetryService _telemetry;
  Box? _journalBox;
  
  /// Name of the dedicated journal box.
  static const String journalBoxName = 'transaction_journal_box';

  /// Initialize the journal box. Call during app bootstrap.
  Future<void> init() async {
    if (_journalBox != null && _journalBox!.isOpen) return;
    _journalBox = await Hive.openBox(journalBoxName);
    _telemetry.increment('transaction_journal.initialized');
  }

  /// Ensure journal is ready.
  Box get _box {
    if (_journalBox == null || !_journalBox!.isOpen) {
      throw StateError('TransactionJournal not initialized. Call init() first.');
    }
    return _journalBox!;
  }

  /// Begin a new transaction.
  ///
  /// [transactionId] should be unique (e.g., 'sync_batch_$timestamp' or UUID).
  Future<TransactionHandle> begin(String transactionId) async {
    final handle = TransactionHandle(
      id: transactionId,
      startedAt: DateTime.now().toUtc(),
      state: TransactionState.active,
    );
    
    // Persist the transaction to the journal
    await _box.put(transactionId, jsonEncode(handle.toJson()));
    _telemetry.increment('transaction_journal.begun');
    
    return handle;
  }

  /// Record a write before applying it.
  ///
  /// Call this BEFORE writing to the Hive box. Pass the current value
  /// (or null if key doesn't exist) so we can rollback if needed.
  Future<void> record(
    TransactionHandle handle,
    String boxName,
    dynamic key,
    dynamic currentValue,
  ) async {
    if (handle.state != TransactionState.active) {
      throw StateError('Cannot record to transaction in state: ${handle.state}');
    }

    String? snapshotJson;
    if (currentValue != null) {
      try {
        // Try to serialize. For Hive models, they should have toJson().
        if (currentValue is Map || currentValue is List) {
          snapshotJson = jsonEncode(currentValue);
        } else if (currentValue is HiveObject) {
          // Many Hive objects have toJson - try via reflection or known models
          snapshotJson = _serializeHiveObject(currentValue);
        } else {
          snapshotJson = currentValue.toString();
        }
      } catch (_) {
        // If serialization fails, we can't rollback this entry
        snapshotJson = null;
      }
    }

    final entry = JournalEntry(
      boxName: boxName,
      key: key,
      snapshotJson: snapshotJson,
    );

    handle.entries.add(entry);
    
    // Update persisted journal
    await _box.put(handle.id, jsonEncode(handle.toJson()));
    _telemetry.increment('transaction_journal.entry_recorded');
  }

  /// Commit the transaction - mark as complete and remove journal entry.
  Future<void> commit(TransactionHandle handle) async {
    if (handle.state != TransactionState.active) {
      throw StateError('Cannot commit transaction in state: ${handle.state}');
    }

    handle.state = TransactionState.committing;
    await _box.put(handle.id, jsonEncode(handle.toJson()));

    // All writes succeeded - delete journal entry
    handle.state = TransactionState.committed;
    await _box.delete(handle.id);
    
    _telemetry.increment('transaction_journal.committed');
  }

  /// Rollback the transaction - restore all recorded entries to their snapshots.
  Future<void> rollback(TransactionHandle handle) async {
    handle.state = TransactionState.rollingBack;
    await _box.put(handle.id, jsonEncode(handle.toJson()));
    _telemetry.increment('transaction_journal.rollback_started');

    int restoredCount = 0;
    int failedCount = 0;

    // Rollback in reverse order (LIFO)
    for (final entry in handle.entries.reversed) {
      try {
        await _restoreEntry(entry);
        restoredCount++;
      } catch (e) {
        failedCount++;
        print('[TransactionJournal] Failed to restore entry: ${entry.boxName}/${entry.key}: $e');
      }
    }

    handle.state = TransactionState.rolledBack;
    await _box.delete(handle.id);

    _telemetry.increment('transaction_journal.rollback_completed');
    _telemetry.gauge('transaction_journal.rollback.restored_count', restoredCount);
    _telemetry.gauge('transaction_journal.rollback.failed_count', failedCount);
  }

  /// Replay and rollback any pending (incomplete) transactions on startup.
  ///
  /// Call this during app bootstrap AFTER all boxes are open.
  Future<int> replayPendingJournals() async {
    if (!_box.isOpen) return 0;
    
    int rolledBackCount = 0;
    final pendingIds = _box.keys.toList();

    for (final txnId in pendingIds) {
      try {
        final jsonStr = _box.get(txnId) as String?;
        if (jsonStr == null) continue;

        final handle = TransactionHandle.fromJson(
          jsonDecode(jsonStr) as Map<String, dynamic>,
        );

        // Any transaction that's not committed/rolledBack is incomplete
        if (handle.state != TransactionState.committed &&
            handle.state != TransactionState.rolledBack) {
          print('[TransactionJournal] Found incomplete transaction: ${handle.id}, rolling back...');
          await rollback(handle);
          rolledBackCount++;
        }
      } catch (e) {
        print('[TransactionJournal] Failed to process pending journal $txnId: $e');
        // Delete corrupt entry
        await _box.delete(txnId);
        _telemetry.increment('transaction_journal.corrupt_entry_deleted');
      }
    }

    if (rolledBackCount > 0) {
      _telemetry.gauge('transaction_journal.startup_rollbacks', rolledBackCount);
      print('[TransactionJournal] Rolled back $rolledBackCount incomplete transactions on startup');
    }

    return rolledBackCount;
  }

  /// Restore a single journal entry.
  Future<void> _restoreEntry(JournalEntry entry) async {
    final box = _getBox(entry.boxName);
    if (box == null) {
      throw StateError('Box ${entry.boxName} not open, cannot restore');
    }

    if (entry.snapshotJson == null) {
      // Key didn't exist before - delete it
      await box.delete(entry.key);
    } else {
      // Restore the old value
      // Note: For complex types, we'd need model-specific deserialization
      // This is a simplified version that works for basic types and Maps
      final oldValue = jsonDecode(entry.snapshotJson!);
      await box.put(entry.key, oldValue);
    }
  }

  /// Get an open Hive box by name.
  Box? _getBox(String boxName) {
    if (!Hive.isBoxOpen(boxName)) return null;
    return BoxAccess.I.boxUntyped(boxName);
  }

  /// Serialize a HiveObject to JSON string.
  String? _serializeHiveObject(dynamic obj) {
    // Try common patterns for our models
    try {
      // Most of our models should have a toJson method
      if (obj.runtimeType.toString().contains('Model') ||
          obj.runtimeType.toString().contains('Record')) {
        final dynamic asMap = (obj as dynamic).toJson();
        return jsonEncode(asMap);
      }
    } catch (_) {}
    return null;
  }

  /// Check if there are pending journals (for health checks).
  int get pendingJournalCount => _box.length;

  /// Close the journal box.
  Future<void> close() async {
    if (_journalBox?.isOpen == true) {
      await _journalBox!.close();
    }
  }
}
