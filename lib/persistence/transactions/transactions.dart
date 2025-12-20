/// Transaction support for crash-safe multi-box Hive operations.
///
/// This module provides:
/// - [TransactionJournal] - Low-level Write-Ahead Logging (WAL) for Hive
/// - [AtomicTransaction] - High-level API for atomic multi-box writes
///
/// ## Quick Start
/// ```dart
/// // Atomic multi-box write - all succeed or all rollback
/// await AtomicTransaction.executeOrThrow(
///   operationName: 'my_operation',
///   builder: (txn) async {
///     await txn.write(box1, key1, value1);
///     await txn.write(box2, key2, value2);
///   },
/// );
/// ```
///
/// ## Bootstrap
/// During app startup, call:
/// ```dart
/// await AtomicTransaction.initialize();
/// await AtomicTransaction.replayPendingTransactions();
/// ```
library;

export 'atomic_transaction.dart';
export 'transaction_journal.dart';
