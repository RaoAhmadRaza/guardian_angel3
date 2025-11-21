import 'package:hive/hive.dart';

part 'transaction_record.g.dart';

/// Transaction states for recovery tracking.
enum TransactionState {
  pending,   // Transaction begun but not committed
  committed, // Ready to apply
  applied,   // Successfully applied to target boxes
  failed,    // Failed during application
}

/// Atomic transaction record containing all operations for a single logical transaction.
/// Stored in a single Hive box to ensure atomicity via Hive's write guarantee.
@HiveType(typeId: 30)
class TransactionRecord {
  @HiveField(0)
  final String transactionId;

  @HiveField(1)
  final DateTime createdAt;

  @HiveField(2)
  TransactionState state;

  @HiveField(3)
  DateTime? committedAt;

  @HiveField(4)
  DateTime? appliedAt;

  /// Model state changes: { boxName: { key: value } }
  /// e.g., { 'devices_v1': { 'd1': DeviceModelHive(...) } }
  @HiveField(5)
  final Map<String, Map<String, dynamic>> modelChanges;

  /// Pending operation to enqueue
  @HiveField(6)
  Map<String, dynamic>? pendingOp;

  /// Index entries to append: { indexBoxName: [opId1, opId2, ...] }
  @HiveField(7)
  final Map<String, List<String>> indexEntries;

  /// Error message if failed
  @HiveField(8)
  String? errorMessage;

  TransactionRecord({
    required this.transactionId,
    required this.createdAt,
    required this.state,
    this.committedAt,
    this.appliedAt,
    required this.modelChanges,
    this.pendingOp,
    required this.indexEntries,
    this.errorMessage,
  });

  /// Create a new pending transaction
  factory TransactionRecord.pending(String transactionId) {
    return TransactionRecord(
      transactionId: transactionId,
      createdAt: DateTime.now(),
      state: TransactionState.pending,
      modelChanges: {},
      indexEntries: {},
    );
  }

  /// Add a model state change
  void addModelChange(String boxName, String key, dynamic value) {
    modelChanges.putIfAbsent(boxName, () => {});
    modelChanges[boxName]![key] = value;
  }

  /// Set the pending operation
  void setPendingOp(Map<String, dynamic> op) {
    pendingOp = Map<String, dynamic>.from(op);
  }

  /// Add an index entry
  void addIndexEntry(String indexBoxName, String opId) {
    indexEntries.putIfAbsent(indexBoxName, () => []);
    indexEntries[indexBoxName]!.add(opId);
  }

  /// Mark as committed (ready to apply)
  void commit() {
    state = TransactionState.committed;
    committedAt = DateTime.now();
  }

  /// Mark as applied successfully
  void markApplied() {
    state = TransactionState.applied;
    appliedAt = DateTime.now();
  }

  /// Mark as failed
  void markFailed(String error) {
    state = TransactionState.failed;
    errorMessage = error;
  }

  /// Check if transaction is incomplete (crashed before apply)
  bool get isIncomplete {
    return state == TransactionState.committed && appliedAt == null;
  }

  /// Check if transaction can be garbage collected
  bool get canPurge {
    // Purge applied transactions older than 1 hour
    if (state == TransactionState.applied && appliedAt != null) {
      return DateTime.now().difference(appliedAt!).inHours >= 1;
    }
    // Purge failed transactions older than 24 hours
    if (state == TransactionState.failed) {
      return DateTime.now().difference(createdAt).inHours >= 24;
    }
    return false;
  }

  @override
  String toString() {
    return 'TransactionRecord(id: $transactionId, state: $state, '
        'modelChanges: ${modelChanges.length}, pendingOp: ${pendingOp != null}, '
        'indexEntries: ${indexEntries.length})';
  }
}

/// Adapter for TransactionState enum
class TransactionStateAdapter extends TypeAdapter<TransactionState> {
  @override
  final int typeId = 31;

  @override
  TransactionState read(BinaryReader reader) {
    final index = reader.readByte();
    return TransactionState.values[index];
  }

  @override
  void write(BinaryWriter writer, TransactionState obj) {
    writer.writeByte(obj.index);
  }
}
