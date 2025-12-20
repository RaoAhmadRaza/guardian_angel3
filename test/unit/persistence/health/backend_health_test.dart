import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_angel_fyp/persistence/health/backend_health.dart';

void main() {
  group('HealthCheckResult', () {
    test('pass factory creates passing result', () {
      final result = HealthCheckResult.pass(
        name: 'test_check',
        message: 'Everything is fine',
        details: {'foo': 'bar'},
      );

      expect(result.passed, isTrue);
      expect(result.name, equals('test_check'));
      expect(result.message, equals('Everything is fine'));
      expect(result.details, equals({'foo': 'bar'}));
      expect(result.checkedAt, isNotNull);
    });

    test('fail factory creates failing result', () {
      final result = HealthCheckResult.fail(
        name: 'test_check',
        message: 'Something broke',
        details: {'error_code': 42},
      );

      expect(result.passed, isFalse);
      expect(result.name, equals('test_check'));
      expect(result.message, equals('Something broke'));
      expect(result.details, equals({'error_code': 42}));
    });

    test('toString formats correctly', () {
      final pass = HealthCheckResult.pass(
        name: 'encryption',
        message: 'Keys valid',
      );
      final fail = HealthCheckResult.fail(
        name: 'schema',
        message: 'Missing adapters',
      );

      expect(pass.toString(), equals('✓ encryption: Keys valid'));
      expect(fail.toString(), equals('✗ schema: Missing adapters'));
    });
  });

  group('BackendHealth', () {
    test('allHealthy returns true when all checks pass', () {
      final health = BackendHealth(
        encryptionOK: true,
        schemaOK: true,
        queueHealthy: true,
        noPoisonOps: true,
        lastSyncAge: const Duration(minutes: 5),
        checkResults: [],
        capturedAt: DateTime.now(),
      );

      expect(health.allHealthy, isTrue);
      expect(health.hasCriticalFailure, isFalse);
      expect(health.needsAttention, isFalse);
      expect(health.healthScore, equals(100));
      expect(health.severity, equals(0));
    });

    test('hasCriticalFailure detects encryption issues', () {
      final health = BackendHealth(
        encryptionOK: false,
        schemaOK: true,
        queueHealthy: true,
        noPoisonOps: true,
        checkResults: [],
        capturedAt: DateTime.now(),
      );

      expect(health.allHealthy, isFalse);
      expect(health.hasCriticalFailure, isTrue);
      expect(health.severity, equals(2));
    });

    test('hasCriticalFailure detects schema issues', () {
      final health = BackendHealth(
        encryptionOK: true,
        schemaOK: false,
        queueHealthy: true,
        noPoisonOps: true,
        checkResults: [],
        capturedAt: DateTime.now(),
      );

      expect(health.allHealthy, isFalse);
      expect(health.hasCriticalFailure, isTrue);
      expect(health.severity, equals(2));
    });

    test('needsAttention detects queue issues', () {
      final health = BackendHealth(
        encryptionOK: true,
        schemaOK: true,
        queueHealthy: false,
        noPoisonOps: true,
        checkResults: [],
        capturedAt: DateTime.now(),
      );

      expect(health.allHealthy, isFalse);
      expect(health.hasCriticalFailure, isFalse);
      expect(health.needsAttention, isTrue);
      expect(health.severity, equals(1));
    });

    test('needsAttention detects poison ops', () {
      final health = BackendHealth(
        encryptionOK: true,
        schemaOK: true,
        queueHealthy: true,
        noPoisonOps: false,
        checkResults: [],
        capturedAt: DateTime.now(),
      );

      expect(health.allHealthy, isFalse);
      expect(health.hasCriticalFailure, isFalse);
      expect(health.needsAttention, isTrue);
      expect(health.severity, equals(1));
    });

    test('healthScore calculates correctly', () {
      // All pass = 100
      expect(
        BackendHealth(
          encryptionOK: true,
          schemaOK: true,
          queueHealthy: true,
          noPoisonOps: true,
          checkResults: [],
          capturedAt: DateTime.now(),
        ).healthScore,
        equals(100),
      );

      // Only encryption fails = 70 (lost 30)
      expect(
        BackendHealth(
          encryptionOK: false,
          schemaOK: true,
          queueHealthy: true,
          noPoisonOps: true,
          checkResults: [],
          capturedAt: DateTime.now(),
        ).healthScore,
        equals(70),
      );

      // Only schema fails = 70 (lost 30)
      expect(
        BackendHealth(
          encryptionOK: true,
          schemaOK: false,
          queueHealthy: true,
          noPoisonOps: true,
          checkResults: [],
          capturedAt: DateTime.now(),
        ).healthScore,
        equals(70),
      );

      // Only queue fails = 75 (lost 25)
      expect(
        BackendHealth(
          encryptionOK: true,
          schemaOK: true,
          queueHealthy: false,
          noPoisonOps: true,
          checkResults: [],
          capturedAt: DateTime.now(),
        ).healthScore,
        equals(75),
      );

      // Only poison = 85 (lost 15)
      expect(
        BackendHealth(
          encryptionOK: true,
          schemaOK: true,
          queueHealthy: true,
          noPoisonOps: false,
          checkResults: [],
          capturedAt: DateTime.now(),
        ).healthScore,
        equals(85),
      );

      // All fail = 0
      expect(
        BackendHealth(
          encryptionOK: false,
          schemaOK: false,
          queueHealthy: false,
          noPoisonOps: false,
          checkResults: [],
          capturedAt: DateTime.now(),
        ).healthScore,
        equals(0),
      );
    });

    test('checkResults tracks individual checks', () {
      final results = [
        HealthCheckResult.pass(name: 'encryption', message: 'OK'),
        HealthCheckResult.fail(name: 'schema', message: 'Missing adapter'),
        HealthCheckResult.pass(name: 'queue', message: 'OK'),
      ];

      final health = BackendHealth(
        encryptionOK: true,
        schemaOK: false,
        queueHealthy: true,
        noPoisonOps: true,
        checkResults: results,
        capturedAt: DateTime.now(),
      );

      expect(health.passedCheckCount, equals(2));
      expect(health.failedCheckCount, equals(1));
    });

    test('summary provides correct format', () {
      final health = BackendHealth(
        encryptionOK: true,
        schemaOK: true,
        queueHealthy: true,
        noPoisonOps: true,
        lastSyncAge: const Duration(minutes: 3),
        checkResults: [],
        capturedAt: DateTime.now(),
      );

      expect(health.summary, contains('score=100%'));
      expect(health.summary, contains('encryption=true'));
      expect(health.summary, contains('schema=true'));
      expect(health.summary, contains('queue=true'));
      expect(health.summary, contains('poison=true'));
      expect(health.summary, contains('lastSync=3m'));
    });

    test('summary handles null lastSyncAge', () {
      final health = BackendHealth(
        encryptionOK: true,
        schemaOK: true,
        queueHealthy: true,
        noPoisonOps: true,
        lastSyncAge: null,
        checkResults: [],
        capturedAt: DateTime.now(),
      );

      expect(health.summary, contains('lastSync=neverm'));
    });
  });

  group('BackendHealthExtension', () {
    test('statusIndicator shows correct emoji', () {
      expect(
        BackendHealth(
          encryptionOK: true,
          schemaOK: true,
          queueHealthy: true,
          noPoisonOps: true,
          checkResults: [],
          capturedAt: DateTime.now(),
        ).statusIndicator,
        equals('🟢'),
      );

      expect(
        BackendHealth(
          encryptionOK: false,
          schemaOK: true,
          queueHealthy: true,
          noPoisonOps: true,
          checkResults: [],
          capturedAt: DateTime.now(),
        ).statusIndicator,
        equals('🔴'),
      );

      expect(
        BackendHealth(
          encryptionOK: true,
          schemaOK: true,
          queueHealthy: false,
          noPoisonOps: true,
          checkResults: [],
          capturedAt: DateTime.now(),
        ).statusIndicator,
        equals('🟡'),
      );
    });

    test('statusText shows correct label', () {
      expect(
        BackendHealth(
          encryptionOK: true,
          schemaOK: true,
          queueHealthy: true,
          noPoisonOps: true,
          checkResults: [],
          capturedAt: DateTime.now(),
        ).statusText,
        equals('Healthy'),
      );

      expect(
        BackendHealth(
          encryptionOK: false,
          schemaOK: true,
          queueHealthy: true,
          noPoisonOps: true,
          checkResults: [],
          capturedAt: DateTime.now(),
        ).statusText,
        equals('Critical'),
      );

      expect(
        BackendHealth(
          encryptionOK: true,
          schemaOK: true,
          queueHealthy: false,
          noPoisonOps: true,
          checkResults: [],
          capturedAt: DateTime.now(),
        ).statusText,
        equals('Degraded'),
      );
    });

    test('detailedReport includes all sections', () {
      final health = BackendHealth(
        encryptionOK: true,
        schemaOK: true,
        queueHealthy: true,
        noPoisonOps: true,
        lastSyncAge: const Duration(minutes: 5),
        checkResults: [
          HealthCheckResult.pass(name: 'test', message: 'OK'),
        ],
        capturedAt: DateTime.now(),
      );

      final report = health.detailedReport;
      expect(report, contains('Backend Health Report'));
      expect(report, contains('Status:'));
      expect(report, contains('Core Checks:'));
      expect(report, contains('Detailed Results:'));
      expect(report, contains('Encryption: ✓'));
    });
  });
}
