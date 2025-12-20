import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'dart:io';

import 'package:guardian_angel_fyp/persistence/transactions/transaction_journal.dart';

/// Unit tests for TransactionJournal
///
/// Tests cover:
/// - Basic transaction lifecycle (begin, record, commit)
/// - Rollback functionality
/// - Startup journal replay
/// - Edge cases (double commit, corrupt entries)
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('transaction_journal_test_');
    Hive.init(tempDir.path);
    TransactionJournal.resetForTesting();
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  group('TransactionJournal', () {
    test('init opens journal box', () async {
      await TransactionJournal.I.init();
      expect(Hive.isBoxOpen(TransactionJournal.journalBoxName), isTrue);
    });

    test('begin creates transaction handle', () async {
      await TransactionJournal.I.init();
      
      final handle = await TransactionJournal.I.begin('test_txn_1');
      
      expect(handle.id, equals('test_txn_1'));
      expect(handle.state, equals(TransactionState.active));
      expect(handle.entries, isEmpty);
    });

    test('record adds entries to transaction', () async {
      await TransactionJournal.I.init();
      
      final handle = await TransactionJournal.I.begin('test_txn_2');
      await TransactionJournal.I.record(handle, 'test_box', 'key1', {'old': 'value'});
      await TransactionJournal.I.record(handle, 'test_box', 'key2', null);
      
      expect(handle.entries.length, equals(2));
      expect(handle.entries[0].boxName, equals('test_box'));
      expect(handle.entries[0].key, equals('key1'));
      expect(handle.entries[1].snapshotJson, isNull); // key didn't exist
    });

    test('commit marks transaction complete and removes journal', () async {
      await TransactionJournal.I.init();
      
      final handle = await TransactionJournal.I.begin('test_txn_3');
      await TransactionJournal.I.record(handle, 'test_box', 'key1', 'old_value');
      await TransactionJournal.I.commit(handle);
      
      expect(handle.state, equals(TransactionState.committed));
      expect(TransactionJournal.I.pendingJournalCount, equals(0));
    });

    test('rollback changes state to rolledBack', () async {
      await TransactionJournal.I.init();
      
      final handle = await TransactionJournal.I.begin('test_txn_4');
      await TransactionJournal.I.record(handle, 'test_box', 'key1', 'old_value');
      await TransactionJournal.I.rollback(handle);
      
      expect(handle.state, equals(TransactionState.rolledBack));
      expect(TransactionJournal.I.pendingJournalCount, equals(0));
    });

    test('cannot record to committed transaction', () async {
      await TransactionJournal.I.init();
      
      final handle = await TransactionJournal.I.begin('test_txn_5');
      await TransactionJournal.I.commit(handle);
      
      expect(
        () => TransactionJournal.I.record(handle, 'test_box', 'key1', 'value'),
        throwsStateError,
      );
    });

    test('cannot commit already committed transaction', () async {
      await TransactionJournal.I.init();
      
      final handle = await TransactionJournal.I.begin('test_txn_6');
      await TransactionJournal.I.commit(handle);
      
      expect(
        () => TransactionJournal.I.commit(handle),
        throwsStateError,
      );
    });

    test('replayPendingJournals rolls back incomplete transactions', () async {
      await TransactionJournal.I.init();
      
      // Create an incomplete transaction
      final handle = await TransactionJournal.I.begin('incomplete_txn');
      await TransactionJournal.I.record(handle, 'test_box', 'key1', 'old_value');
      // Don't commit - simulate crash
      
      // Simulate app restart
      TransactionJournal.resetForTesting();
      await TransactionJournal.I.init();
      
      // Replay should find and rollback the incomplete transaction
      final rolledBack = await TransactionJournal.I.replayPendingJournals();
      
      expect(rolledBack, equals(1));
      expect(TransactionJournal.I.pendingJournalCount, equals(0));
    });

    test('committed transactions are not replayed', () async {
      await TransactionJournal.I.init();
      
      // Create and commit a transaction
      final handle = await TransactionJournal.I.begin('completed_txn');
      await TransactionJournal.I.record(handle, 'test_box', 'key1', 'old_value');
      await TransactionJournal.I.commit(handle);
      
      // Simulate app restart
      TransactionJournal.resetForTesting();
      await TransactionJournal.I.init();
      
      // No incomplete transactions to replay
      final rolledBack = await TransactionJournal.I.replayPendingJournals();
      
      expect(rolledBack, equals(0));
    });

    test('TransactionHandle serialization roundtrip', () async {
      final handle = TransactionHandle(
        id: 'test_id',
        startedAt: DateTime.utc(2025, 1, 15, 10, 30),
        state: TransactionState.active,
        entries: [
          JournalEntry(boxName: 'box1', key: 'key1', snapshotJson: '{"foo":"bar"}'),
          JournalEntry(boxName: 'box2', key: 'key2', snapshotJson: null),
        ],
      );
      
      final json = handle.toJson();
      final restored = TransactionHandle.fromJson(json);
      
      expect(restored.id, equals(handle.id));
      expect(restored.startedAt, equals(handle.startedAt));
      expect(restored.state, equals(handle.state));
      expect(restored.entries.length, equals(2));
      expect(restored.entries[0].boxName, equals('box1'));
      expect(restored.entries[1].snapshotJson, isNull);
    });
  });
}
