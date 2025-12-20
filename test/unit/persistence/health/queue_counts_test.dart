import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_angel_fyp/persistence/health/queue_status_ui.dart';

void main() {
  group('QueueCounts', () {
    test('creates with correct values', () {
      final counts = QueueCounts(
        pending: 5,
        failed: 2,
        emergency: 1,
        escalated: 0,
      );

      expect(counts.pending, equals(5));
      expect(counts.failed, equals(2));
      expect(counts.emergency, equals(1));
      expect(counts.escalated, equals(0));
    });

    test('total sums pending, failed, and emergency', () {
      final counts = QueueCounts(
        pending: 10,
        failed: 5,
        emergency: 3,
        escalated: 2,
      );

      expect(counts.total, equals(18)); // 10 + 5 + 3
    });

    test('isEmpty returns true when all counts are zero', () {
      final empty = QueueCounts(
        pending: 0,
        failed: 0,
        emergency: 0,
        escalated: 0,
      );

      expect(empty.isEmpty, isTrue);
      expect(empty.total, equals(0));
    });

    test('isEmpty returns false when any count is non-zero', () {
      expect(
        QueueCounts(pending: 1, failed: 0, emergency: 0, escalated: 0).isEmpty,
        isFalse,
      );
      expect(
        QueueCounts(pending: 0, failed: 1, emergency: 0, escalated: 0).isEmpty,
        isFalse,
      );
      expect(
        QueueCounts(pending: 0, failed: 0, emergency: 1, escalated: 0).isEmpty,
        isFalse,
      );
    });

    test('hasFailed returns true only when failed > 0', () {
      expect(
        QueueCounts(pending: 0, failed: 0, emergency: 0, escalated: 0).hasFailed,
        isFalse,
      );
      expect(
        QueueCounts(pending: 10, failed: 0, emergency: 5, escalated: 0).hasFailed,
        isFalse,
      );
      expect(
        QueueCounts(pending: 0, failed: 1, emergency: 0, escalated: 0).hasFailed,
        isTrue,
      );
    });

    test('hasEmergency returns true only when emergency > 0', () {
      expect(
        QueueCounts(pending: 0, failed: 0, emergency: 0, escalated: 0).hasEmergency,
        isFalse,
      );
      expect(
        QueueCounts(pending: 10, failed: 5, emergency: 0, escalated: 0).hasEmergency,
        isFalse,
      );
      expect(
        QueueCounts(pending: 0, failed: 0, emergency: 1, escalated: 0).hasEmergency,
        isTrue,
      );
    });

    test('toString provides readable format', () {
      final counts = QueueCounts(
        pending: 5,
        failed: 2,
        emergency: 1,
        escalated: 0,
      );

      final str = counts.toString();
      expect(str, contains('pending=5'));
      expect(str, contains('failed=2'));
      expect(str, contains('emergency=1'));
    });

    test('handles large counts', () {
      final counts = QueueCounts(
        pending: 1000000,
        failed: 500000,
        emergency: 100,
        escalated: 50,
      );

      expect(counts.total, equals(1500100));
      expect(counts.isEmpty, isFalse);
      expect(counts.hasFailed, isTrue);
      expect(counts.hasEmergency, isTrue);
    });
  });
}
