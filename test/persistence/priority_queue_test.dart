import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'dart:io';

import 'package:guardian_angel_fyp/persistence/queue/op_priority.dart';
import 'package:guardian_angel_fyp/persistence/queue/emergency_queue_service.dart';
import 'package:guardian_angel_fyp/persistence/queue/safety_fallback_service.dart';
import 'package:guardian_angel_fyp/models/pending_op.dart';
import 'package:guardian_angel_fyp/persistence/adapters/pending_op_adapter.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('priority_test_');
    Hive.init(tempDir.path);
    
    if (!Hive.isAdapterRegistered(11)) {
      Hive.registerAdapter(PendingOpAdapter());
    }
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  group('OpPriority', () {
    test('priority ordering is correct', () {
      expect(OpPriority.emergency.value, lessThan(OpPriority.high.value));
      expect(OpPriority.high.value, lessThan(OpPriority.normal.value));
      expect(OpPriority.normal.value, lessThan(OpPriority.low.value));
    });

    test('emergency bypasses backoff', () {
      expect(OpPriority.emergency.bypassesBackoff, isTrue);
      expect(OpPriority.high.bypassesBackoff, isFalse);
      expect(OpPriority.normal.bypassesBackoff, isFalse);
      expect(OpPriority.low.bypassesBackoff, isFalse);
    });

    test('fromString parses correctly', () {
      expect(OpPriority.fromString('emergency'), equals(OpPriority.emergency));
      expect(OpPriority.fromString('HIGH'), equals(OpPriority.high));
      expect(OpPriority.fromString('Normal'), equals(OpPriority.normal));
      expect(OpPriority.fromString('low'), equals(OpPriority.low));
      expect(OpPriority.fromString('unknown'), equals(OpPriority.normal));
    });
  });

  group('PendingOp with priority', () {
    test('default priority is normal', () {
      final op = PendingOp(
        id: 'test-1',
        opType: 'test',
        idempotencyKey: 'key-1',
        payload: const {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      expect(op.priority, equals(OpPriority.normal));
      expect(op.deliveryState, equals(DeliveryState.pending));
    });

    test('emergency ops bypass backoff in isEligibleNow', () {
      final now = DateTime.now().toUtc();
      final future = now.add(const Duration(hours: 1));
      
      final emergencyOp = PendingOp(
        id: 'emergency-1',
        opType: 'sos',
        idempotencyKey: 'key-1',
        payload: const {},
        createdAt: now,
        updatedAt: now,
        priority: OpPriority.emergency,
        nextEligibleAt: future, // Far in the future
      );
      
      final normalOp = PendingOp(
        id: 'normal-1',
        opType: 'test',
        idempotencyKey: 'key-2',
        payload: const {},
        createdAt: now,
        updatedAt: now,
        priority: OpPriority.normal,
        nextEligibleAt: future, // Far in the future
      );
      
      // Emergency bypasses backoff
      expect(emergencyOp.isEligibleNow, isTrue);
      
      // Normal respects backoff
      expect(normalOp.isEligibleNow, isFalse);
    });

    test('copyWith preserves priority and deliveryState', () {
      final op = PendingOp(
        id: 'test-1',
        opType: 'sos',
        idempotencyKey: 'key-1',
        payload: const {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        priority: OpPriority.emergency,
        deliveryState: DeliveryState.sent,
      );
      
      final updated = op.copyWith(attempts: 1);
      
      expect(updated.priority, equals(OpPriority.emergency));
      expect(updated.deliveryState, equals(DeliveryState.sent));
    });

    test('toJson/fromJson roundtrip preserves priority', () {
      final op = PendingOp(
        id: 'test-1',
        opType: 'sos',
        idempotencyKey: 'key-1',
        payload: const {'test': 'value'},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        priority: OpPriority.high,
        deliveryState: DeliveryState.acknowledged,
      );
      
      final json = op.toJson();
      final restored = PendingOp.fromJson(json);
      
      expect(restored.priority, equals(OpPriority.high));
      expect(restored.deliveryState, equals(DeliveryState.acknowledged));
    });
  });

  group('EmergencyQueueService', () {
    late EmergencyQueueService service;

    setUp(() async {
      service = EmergencyQueueService();
      await service.init();
      await service.clear();
    });

    tearDown(() {
      service.dispose();
    });

    test('only accepts emergency priority ops', () async {
      final emergencyOp = PendingOp(
        id: 'emergency-1',
        opType: 'sos',
        idempotencyKey: 'key-1',
        payload: const {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        priority: OpPriority.emergency,
      );
      
      final normalOp = PendingOp(
        id: 'normal-1',
        opType: 'test',
        idempotencyKey: 'key-2',
        payload: const {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        priority: OpPriority.normal,
      );
      
      expect(await service.enqueueEmergency(emergencyOp), isTrue);
      expect(await service.enqueueEmergency(normalOp), isFalse);
      expect(service.pendingCount, equals(1));
    });

    test('processAll invokes handler and removes on success', () async {
      final op = PendingOp(
        id: 'emergency-1',
        opType: 'sos',
        idempotencyKey: 'key-1',
        payload: const {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        priority: OpPriority.emergency,
      );
      
      await service.enqueueEmergency(op);
      expect(service.pendingCount, equals(1));
      
      int handlerCalls = 0;
      await service.processAll((op) async {
        handlerCalls++;
        return true; // Success
      });
      
      expect(handlerCalls, equals(1));
      expect(service.pendingCount, equals(0));
    });

    test('failed ops retry with incremented attempts', () async {
      final op = PendingOp(
        id: 'emergency-1',
        opType: 'sos',
        idempotencyKey: 'key-1',
        payload: const {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        priority: OpPriority.emergency,
      );
      
      await service.enqueueEmergency(op);
      
      await service.processAll((op) async => false); // Fail
      
      expect(service.pendingCount, equals(1));
      final pending = service.pendingOps;
      expect(pending.first.attempts, equals(1));
    });
  });

  group('SafetyFallbackService', () {
    late SafetyFallbackService service;

    setUp(() async {
      service = SafetyFallbackService(
        config: const SafetyFallbackConfig(
          maxEmergencyFailures: 3,
          networkUnavailableMinutes: 1,
        ),
      );
      await service.init();
    });

    tearDown(() {
      service.dispose();
    });

    test('starts in normal mode', () {
      expect(service.currentMode, equals(SafetyMode.normal));
      expect(service.isInSafetyMode, isFalse);
    });

    test('network unavailable triggers limited connectivity', () async {
      await service.reportNetworkState(isAvailable: false);
      
      expect(service.currentMode, equals(SafetyMode.limitedConnectivity));
      expect(service.isInSafetyMode, isTrue);
    });

    test('network restored returns to normal', () async {
      await service.reportNetworkState(isAvailable: false);
      expect(service.currentMode, equals(SafetyMode.limitedConnectivity));
      
      await service.reportNetworkState(isAvailable: true);
      expect(service.currentMode, equals(SafetyMode.normal));
    });

    test('emergency failures trigger escalation after threshold', () async {
      final op = PendingOp(
        id: 'emergency-1',
        opType: 'sos',
        idempotencyKey: 'key-1',
        payload: const {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        priority: OpPriority.emergency,
      );
      
      // Report failures
      await service.reportEmergencyOpResult(op, success: false);
      await service.reportEmergencyOpResult(op, success: false);
      expect(service.currentMode, equals(SafetyMode.normal)); // Not yet
      
      await service.reportEmergencyOpResult(op, success: false);
      expect(service.currentMode, equals(SafetyMode.emergency)); // Triggered
      expect(service.escalationHistory.length, equals(1));
    });

    test('acknowledge resets safety mode', () async {
      await service.reportNetworkState(isAvailable: false);
      expect(service.isInSafetyMode, isTrue);
      
      await service.acknowledgeSafetyMode();
      expect(service.currentMode, equals(SafetyMode.normal));
      expect(service.isInSafetyMode, isFalse);
    });
  });

  group('DeliveryState', () {
    test('delivery state transitions correctly', () {
      final op = PendingOp(
        id: 'test-1',
        opType: 'test',
        idempotencyKey: 'key-1',
        payload: const {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      expect(op.deliveryState, equals(DeliveryState.pending));
      
      final sent = op.copyWith(deliveryState: DeliveryState.sent);
      expect(sent.deliveryState, equals(DeliveryState.sent));
      
      final acked = sent.copyWith(deliveryState: DeliveryState.acknowledged);
      expect(acked.deliveryState, equals(DeliveryState.acknowledged));
    });
  });
}
