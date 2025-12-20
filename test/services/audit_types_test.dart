import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_angel_fyp/services/models/audit_types.dart';

/// Tests for Audit Types and AuditEvent.
void main() {
  group('AuditType', () {
    test('all types have action strings', () {
      for (final type in AuditType.values) {
        expect(type.action, isNotEmpty);
        expect(type.action, type.name);
      }
    });

    test('all types have severity levels', () {
      for (final type in AuditType.values) {
        expect(['info', 'warning', 'critical'], contains(type.severity));
      }
    });

    test('emergency types are critical or warning', () {
      expect(AuditType.sosTrigger.severity, 'critical');
      expect(AuditType.sosEscalated.severity, 'critical');
      expect(AuditType.emergencyEscalated.severity, 'critical');
      expect(AuditType.emergencyEnqueued.severity, 'warning');
    });

    test('security types have appropriate severity', () {
      expect(AuditType.secureEraseStarted.severity, 'critical');
      expect(AuditType.secureEraseCompleted.severity, 'critical');
      expect(AuditType.encryptionFailed.severity, 'critical');
      expect(AuditType.encryptionVerified.severity, 'info');
    });

    test('isMandatory is true for critical events', () {
      expect(AuditType.sosTrigger.isMandatory, true);
      expect(AuditType.sosEscalated.isMandatory, true);
      expect(AuditType.secureEraseStarted.isMandatory, true);
      expect(AuditType.repairStarted.isMandatory, true);
      
      // Regular ops are not mandatory
      expect(AuditType.opEnqueued.isMandatory, false);
      expect(AuditType.syncStarted.isMandatory, false);
    });

    test('defaultEntityType groups events correctly', () {
      // SOS events
      expect(AuditType.sosTrigger.defaultEntityType, 'sos');
      expect(AuditType.sosEscalated.defaultEntityType, 'sos');
      
      // Emergency ops
      expect(AuditType.emergencyEnqueued.defaultEntityType, 'emergency_op');
      expect(AuditType.emergencyEscalated.defaultEntityType, 'emergency_op');
      
      // Queue
      expect(AuditType.queueStallDetected.defaultEntityType, 'queue');
      expect(AuditType.queueResumed.defaultEntityType, 'queue');
      
      // Security
      expect(AuditType.encryptionKeyRotated.defaultEntityType, 'security');
    });
  });

  group('AuditEvent', () {
    test('creates event with type properties', () {
      final event = AuditEvent(
        type: AuditType.sosTrigger,
        userId: 'user123',
        entityId: 'sos_456',
      );

      expect(event.action, 'sosTrigger');
      expect(event.severity, 'critical');
      expect(event.entityType, 'sos');
      expect(event.isMandatory, true);
      expect(event.userId, 'user123');
      expect(event.entityId, 'sos_456');
    });

    test('sosTrigger factory', () {
      final event = AuditEvent.sosTrigger(
        userId: 'user123',
        sosId: 'sos_789',
        location: 'Home',
        deviceInfo: 'iPhone 14',
      );

      expect(event.type, AuditType.sosTrigger);
      expect(event.entityId, 'sos_789');
      expect(event.metadata['location'], 'Home');
      expect(event.metadata['triggered_at'], isNotNull);
      expect(event.deviceInfo, 'iPhone 14');
    });

    test('emergency factory', () {
      final event = AuditEvent.emergency(
        type: AuditType.emergencyEscalated,
        userId: 'user123',
        opId: 'op_123',
        opType: 'sos_alert',
        error: 'Network timeout',
        attempts: 5,
      );

      expect(event.type, AuditType.emergencyEscalated);
      expect(event.entityId, 'op_123');
      expect(event.metadata['op_type'], 'sos_alert');
      expect(event.metadata['error'], 'Network timeout');
      expect(event.metadata['attempts'], 5);
    });

    test('queueStall factory', () {
      final event = AuditEvent.queueStall(
        type: AuditType.queueStallDetected,
        userId: 'system',
        stallDuration: const Duration(minutes: 15),
        oldestOpId: 'old_op_1',
        pendingCount: 10,
        autoRecovered: false,
      );

      expect(event.type, AuditType.queueStallDetected);
      expect(event.metadata['stall_duration_seconds'], 900);
      expect(event.metadata['oldest_op_id'], 'old_op_1');
      expect(event.metadata['pending_count'], 10);
    });

    test('repair factory', () {
      final event = AuditEvent.repair(
        type: AuditType.repairCompleted,
        userId: 'admin',
        action: 'rebuildPendingIndex',
        confirmationToken: 'CONFIRM_123',
        affectedCount: 50,
        duration: const Duration(milliseconds: 250),
      );

      expect(event.type, AuditType.repairCompleted);
      expect(event.entityId, 'CONFIRM_123');
      expect(event.metadata['action'], 'rebuildPendingIndex');
      expect(event.metadata['affected_count'], 50);
      expect(event.metadata['duration_ms'], 250);
    });

    test('secureErase factory', () {
      final event = AuditEvent.secureErase(
        type: AuditType.secureEraseStarted,
        userId: 'user123',
        reason: 'User requested data deletion',
        boxesAffected: ['pending_ops_box', 'failed_ops_box'],
        itemsErased: 100,
      );

      expect(event.type, AuditType.secureEraseStarted);
      expect(event.metadata['reason'], 'User requested data deletion');
      expect(event.metadata['boxes_affected'], ['pending_ops_box', 'failed_ops_box']);
      expect(event.metadata['items_erased'], 100);
    });

    test('optional metadata fields are omitted when null', () {
      final event = AuditEvent.emergency(
        type: AuditType.emergencyProcessed,
        userId: 'user123',
        opId: 'op_456',
        // No optional fields
      );

      expect(event.metadata.containsKey('op_type'), false);
      expect(event.metadata.containsKey('error'), false);
      expect(event.metadata.containsKey('attempts'), false);
    });
  });
}
