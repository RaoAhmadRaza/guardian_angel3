import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'dart:io';

import 'package:guardian_angel_fyp/persistence/transactions/atomic_transaction.dart';
import 'package:guardian_angel_fyp/persistence/transactions/transaction_journal.dart';

/// Unit tests for AtomicTransaction
///
/// Tests cover:
/// - Basic atomic operations (run, execute)
/// - Rollback on failure
/// - BoxWrite factories
/// - TransactionBuilder API
/// - Integration with TransactionJournal
/// - Edge cases and error handling
void main() {
  late Directory tempDir;
  late Box<String> testBox1;
  late Box<int> testBox2;
  late Box untypedBox;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('atomic_transaction_test_');
    Hive.init(tempDir.path);
    TransactionJournal.resetForTesting();
    AtomicTransaction.resetForTesting();
    
    // Open test boxes
    testBox1 = await Hive.openBox<String>('test_box_1');
    testBox2 = await Hive.openBox<int>('test_box_2');
    untypedBox = await Hive.openBox('untyped_box');
    
    // Initialize transaction journal
    await TransactionJournal.I.init();
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  group('BoxWrite', () {
    test('create factory sets correct values', () {
      final write = BoxWrite<String>.create(
        box: testBox1,
        key: 'key1',
        value: 'value1',
      );
      
      expect(write.key, equals('key1'));
      expect(write.oldValue, isNull); // Didn't exist before
      expect(write.newValue, equals('value1'));
    });

    test('update factory sets correct values', () {
      final write = BoxWrite<String>.update(
        box: testBox1,
        key: 'key1',
        oldValue: 'old',
        newValue: 'new',
      );
      
      expect(write.oldValue, equals('old'));
      expect(write.newValue, equals('new'));
    });

    test('delete factory sets newValue to null', () {
      final write = BoxWrite<String>.delete(
        box: testBox1,
        key: 'key1',
        oldValue: 'existing',
      );
      
      expect(write.oldValue, equals('existing'));
      expect(write.newValue, isNull);
    });
  });

  group('BoxWriteUntyped', () {
    test('can hold different types', () {
      final write = BoxWriteUntyped(
        box: untypedBox,
        key: 'mixed',
        oldValue: 'string',
        newValue: 42,
      );
      
      expect(write.oldValue, equals('string'));
      expect(write.newValue, equals(42));
    });
  });

  group('AtomicResult', () {
    test('AtomicSuccess contains operation count and duration', () {
      const result = AtomicSuccess(
        operationCount: 3,
        duration: Duration(milliseconds: 50),
      );
      
      expect(result.operationCount, equals(3));
      expect(result.duration.inMilliseconds, equals(50));
      expect(result.toString(), contains('3'));
      expect(result.toString(), contains('50ms'));
    });

    test('AtomicFailure contains error and rollback info', () {
      final result = AtomicFailure(
        error: Exception('test error'),
        rolledBackCount: 2,
        rollbackSucceeded: true,
      );
      
      expect(result.rolledBackCount, equals(2));
      expect(result.rollbackSucceeded, isTrue);
      expect(result.toString(), contains('test error'));
    });
  });

  group('AtomicTransaction.run', () {
    test('empty operations returns success immediately', () async {
      final result = await AtomicTransaction.run(
        operationName: 'empty',
        operations: [],
      );
      
      expect(result, isA<AtomicSuccess>());
      expect((result as AtomicSuccess).operationCount, equals(0));
    });

    test('single operation writes and commits', () async {
      final result = await AtomicTransaction.run(
        operationName: 'single_write',
        operations: [
          BoxWriteUntyped(
            box: testBox1,
            key: 'key1',
            oldValue: null,
            newValue: 'value1',
          ),
        ],
      );
      
      expect(result, isA<AtomicSuccess>());
      expect(testBox1.get('key1'), equals('value1'));
      expect(TransactionJournal.I.pendingJournalCount, equals(0));
    });

    test('multiple operations all write on success', () async {
      final result = await AtomicTransaction.run(
        operationName: 'multi_write',
        operations: [
          BoxWriteUntyped(box: testBox1, key: 'k1', oldValue: null, newValue: 'v1'),
          BoxWriteUntyped(box: testBox1, key: 'k2', oldValue: null, newValue: 'v2'),
          BoxWriteUntyped(box: testBox2, key: 'num', oldValue: null, newValue: 42),
        ],
      );
      
      expect(result, isA<AtomicSuccess>());
      expect((result as AtomicSuccess).operationCount, equals(3));
      expect(testBox1.get('k1'), equals('v1'));
      expect(testBox1.get('k2'), equals('v2'));
      expect(testBox2.get('num'), equals(42));
    });

    test('delete operation removes key', () async {
      // Setup: add key first
      await testBox1.put('to_delete', 'exists');
      expect(testBox1.get('to_delete'), equals('exists'));
      
      final result = await AtomicTransaction.run(
        operationName: 'delete',
        operations: [
          BoxWriteUntyped(
            box: testBox1,
            key: 'to_delete',
            oldValue: 'exists',
            newValue: null, // null = delete
          ),
        ],
      );
      
      expect(result, isA<AtomicSuccess>());
      expect(testBox1.get('to_delete'), isNull);
    });

    test('no pending journals after successful commit', () async {
      await AtomicTransaction.run(
        operationName: 'test',
        operations: [
          BoxWriteUntyped(box: testBox1, key: 'k', oldValue: null, newValue: 'v'),
        ],
      );
      
      expect(TransactionJournal.I.pendingJournalCount, equals(0));
    });
  });

  group('AtomicTransaction.execute', () {
    test('builder pattern writes correctly', () async {
      final result = await AtomicTransaction.execute(
        operationName: 'builder_test',
        builder: (txn) async {
          await txn.write(testBox1, 'key1', 'value1');
          await txn.write(testBox2, 'num', 99);
        },
      );
      
      expect(result, isA<AtomicSuccess>());
      expect(testBox1.get('key1'), equals('value1'));
      expect(testBox2.get('num'), equals(99));
    });

    test('builder delete removes key', () async {
      await testBox1.put('to_delete', 'exists');
      
      final result = await AtomicTransaction.execute(
        operationName: 'builder_delete',
        builder: (txn) async {
          await txn.delete(testBox1, 'to_delete');
        },
      );
      
      expect(result, isA<AtomicSuccess>());
      expect(testBox1.get('to_delete'), isNull);
    });

    test('builder record allows manual write', () async {
      final result = await AtomicTransaction.execute(
        operationName: 'manual_write',
        builder: (txn) async {
          final oldValue = testBox1.get('key');
          await txn.record(testBox1.name, 'key', oldValue);
          await testBox1.put('key', 'manual_value');
        },
      );
      
      expect(result, isA<AtomicSuccess>());
      expect(testBox1.get('key'), equals('manual_value'));
    });
  });

  group('AtomicTransaction.runOrThrow', () {
    test('returns normally on success', () async {
      await AtomicTransaction.runOrThrow(
        operationName: 'throw_test',
        operations: [
          BoxWriteUntyped(box: testBox1, key: 'k', oldValue: null, newValue: 'v'),
        ],
      );
      
      expect(testBox1.get('k'), equals('v'));
    });

    test('throws on failure', () async {
      // Create a closed box to force failure
      final failBox = await Hive.openBox('fail_box');
      await failBox.close();
      
      expect(
        () => AtomicTransaction.runOrThrow(
          operationName: 'fail_test',
          operations: [
            BoxWriteUntyped(box: failBox, key: 'k', oldValue: null, newValue: 'v'),
          ],
        ),
        throwsA(isA<HiveError>()),
      );
    });
  });

  group('AtomicTransaction.executeOrThrow', () {
    test('returns normally on success', () async {
      await AtomicTransaction.executeOrThrow(
        operationName: 'execute_throw_test',
        builder: (txn) async {
          await txn.write(testBox1, 'key', 'value');
        },
      );
      
      expect(testBox1.get('key'), equals('value'));
    });

    test('throws on failure', () async {
      expect(
        () => AtomicTransaction.executeOrThrow(
          operationName: 'fail',
          builder: (txn) async {
            throw Exception('forced failure');
          },
        ),
        throwsException,
      );
    });
  });

  group('Rollback behavior', () {
    test('failure returns AtomicFailure with rollback info', () async {
      // Add data that will be modified
      await testBox1.put('existing', 'original');
      
      final result = await AtomicTransaction.execute(
        operationName: 'rollback_test',
        builder: (txn) async {
          await txn.write(testBox1, 'existing', 'modified');
          throw Exception('mid-transaction failure');
        },
      );
      
      expect(result, isA<AtomicFailure>());
      final failure = result as AtomicFailure;
      expect(failure.rollbackSucceeded, isTrue);
      expect(failure.rolledBackCount, greaterThan(0));
    });

    test('no pending journals after rollback', () async {
      await AtomicTransaction.execute(
        operationName: 'rollback_journal_test',
        builder: (txn) async {
          await txn.write(testBox1, 'key', 'value');
          throw Exception('failure');
        },
      );
      
      expect(TransactionJournal.I.pendingJournalCount, equals(0));
    });
  });

  group('Integration tests', () {
    test('simulate enqueue operation pattern', () async {
      // This simulates the pending_queue_service.enqueue pattern
      final pendingBox = testBox1;
      final indexBox = untypedBox;
      
      const opId = 'op_123';
      const opData = 'pending_op_data';
      
      final result = await AtomicTransaction.execute(
        operationName: 'pending_queue.enqueue',
        builder: (txn) async {
          await txn.write(pendingBox, opId, opData);
          // Simulate index update
          final currentIndex = (indexBox.get('order') as List?) ?? [];
          final newIndex = [...currentIndex, opId];
          await txn.write(indexBox, 'order', newIndex);
        },
      );
      
      expect(result, isA<AtomicSuccess>());
      expect(pendingBox.get(opId), equals(opData));
      expect((indexBox.get('order') as List), contains(opId));
    });

    test('simulate mark_processed operation pattern', () async {
      // Setup
      await testBox1.put('op_123', 'data');
      await untypedBox.put('order', ['op_123', 'op_456']);
      
      final result = await AtomicTransaction.execute(
        operationName: 'pending_queue.mark_processed',
        builder: (txn) async {
          await txn.delete(testBox1, 'op_123');
          final index = List<String>.from(untypedBox.get('order') as List);
          index.remove('op_123');
          await txn.write(untypedBox, 'order', index);
        },
      );
      
      expect(result, isA<AtomicSuccess>());
      expect(testBox1.get('op_123'), isNull);
      expect((untypedBox.get('order') as List), isNot(contains('op_123')));
    });

    test('simulate move_to_failed operation pattern', () async {
      // Setup pending
      await testBox1.put('poison_op', 'pending_data');
      await untypedBox.put('order', ['poison_op']);
      
      // testBox2 acts as failed_ops box (stores int but we simulate)
      final result = await AtomicTransaction.execute(
        operationName: 'pending_queue.move_to_poison',
        builder: (txn) async {
          // Add to failed
          await txn.write(testBox2, 'poison_op'.hashCode, 1); // Mark as failed
          // Remove from pending
          await txn.delete(testBox1, 'poison_op');
          // Update index
          await txn.write(untypedBox, 'order', <String>[]);
        },
      );
      
      expect(result, isA<AtomicSuccess>());
      expect(testBox1.get('poison_op'), isNull);
      expect(testBox2.get('poison_op'.hashCode), equals(1));
      expect((untypedBox.get('order') as List), isEmpty);
    });
  });

  group('TransactionBuilder', () {
    test('write captures old value automatically', () async {
      await testBox1.put('existing', 'old_value');
      
      // The builder should automatically capture 'old_value' for rollback
      final result = await AtomicTransaction.execute(
        operationName: 'auto_capture',
        builder: (txn) async {
          await txn.write(testBox1, 'existing', 'new_value');
        },
      );
      
      expect(result, isA<AtomicSuccess>());
      expect(testBox1.get('existing'), equals('new_value'));
    });

    test('delete captures old value automatically', () async {
      await testBox1.put('to_delete', 'value');
      
      final result = await AtomicTransaction.execute(
        operationName: 'auto_delete',
        builder: (txn) async {
          await txn.delete(testBox1, 'to_delete');
        },
      );
      
      expect(result, isA<AtomicSuccess>());
      expect(testBox1.get('to_delete'), isNull);
    });
  });

  group('Edge cases', () {
    test('writing to same key multiple times in one transaction', () async {
      final result = await AtomicTransaction.execute(
        operationName: 'multi_write_same_key',
        builder: (txn) async {
          await txn.write(testBox1, 'key', 'first');
          await txn.write(testBox1, 'key', 'second');
          await txn.write(testBox1, 'key', 'final');
        },
      );
      
      expect(result, isA<AtomicSuccess>());
      expect(testBox1.get('key'), equals('final'));
    });

    test('transaction with many operations', () async {
      final operations = List.generate(
        50,
        (i) => BoxWriteUntyped(
          box: testBox1,
          key: 'key_$i',
          oldValue: null,
          newValue: 'value_$i',
        ),
      );
      
      final result = await AtomicTransaction.run(
        operationName: 'bulk_write',
        operations: operations,
      );
      
      expect(result, isA<AtomicSuccess>());
      expect((result as AtomicSuccess).operationCount, equals(50));
      
      for (int i = 0; i < 50; i++) {
        expect(testBox1.get('key_$i'), equals('value_$i'));
      }
    });

    test('update existing value', () async {
      await testBox1.put('key', 'original');
      
      final result = await AtomicTransaction.run(
        operationName: 'update',
        operations: [
          BoxWriteUntyped(
            box: testBox1,
            key: 'key',
            oldValue: 'original',
            newValue: 'updated',
          ),
        ],
      );
      
      expect(result, isA<AtomicSuccess>());
      expect(testBox1.get('key'), equals('updated'));
    });
  });

  group('Startup recovery', () {
    test('replayPendingTransactions returns 0 when no pending', () async {
      final count = await AtomicTransaction.replayPendingTransactions();
      expect(count, equals(0));
    });

    test('initialize creates journal box', () async {
      // Already initialized in setUp, but test explicit call
      await AtomicTransaction.initialize();
      expect(Hive.isBoxOpen(TransactionJournal.journalBoxName), isTrue);
    });
  });
}
