/// Tests for Mixed Singleton/DI Pattern Fix (Blocker #3)
///
/// Verifies that:
/// 1. All services use shared instances (not private singletons)
/// 2. ServiceInstances provides consistent access
/// 3. Legacy `.I` accessors route to shared instances
/// 4. Test overrides work correctly
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_angel_fyp/services/telemetry_service.dart';
import 'package:guardian_angel_fyp/services/audit_log_service.dart';
import 'package:guardian_angel_fyp/services/sync_failure_service.dart';
import 'package:guardian_angel_fyp/services/secure_erase_service.dart';
import 'package:guardian_angel_fyp/services/secure_erase_hardened.dart';
import 'package:guardian_angel_fyp/services/service_instances.dart';
import 'package:guardian_angel_fyp/persistence/guardrails/production_guardrails.dart';
import 'package:guardian_angel_fyp/persistence/wrappers/box_accessor.dart';
import 'package:guardian_angel_fyp/persistence/sync/conflict_resolver.dart';

void main() {
  group('ServiceInstances Registry', () {
    test('provides telemetry service', () {
      final telemetry = ServiceInstances.telemetry;
      expect(telemetry, isA<TelemetryService>());
    });
    
    test('provides audit log service', () {
      final auditLog = ServiceInstances.auditLog;
      expect(auditLog, isA<AuditLogService>());
    });
    
    test('provides sync failure service', () {
      final syncFailure = ServiceInstances.syncFailure;
      expect(syncFailure, isA<SyncFailureService>());
    });
    
    test('provides secure erase service', () {
      final secureErase = ServiceInstances.secureErase;
      expect(secureErase, isA<SecureEraseService>());
    });
    
    test('provides secure erase hardened service', () {
      final secureEraseHardened = ServiceInstances.secureEraseHardened;
      expect(secureEraseHardened, isA<SecureEraseHardened>());
    });
    
    test('provides production guardrails', () {
      final guardrails = ServiceInstances.guardrails;
      expect(guardrails, isA<ProductionGuardrails>());
    });
    
    test('provides box accessor', () {
      final boxAccessor = ServiceInstances.boxAccessor;
      expect(boxAccessor, isA<BoxAccessor>());
    });
    
    test('provides conflict resolver', () {
      final conflictResolver = ServiceInstances.conflictResolver;
      expect(conflictResolver, isA<ConflictResolver>());
    });
  });
  
  group('Shared Instance Consistency', () {
    test('telemetry: .I returns same instance as ServiceInstances', () {
      // ignore: deprecated_member_use_from_same_package
      final fromI = TelemetryService.I;
      final fromServiceInstances = ServiceInstances.telemetry;
      
      expect(identical(fromI, fromServiceInstances), isTrue,
        reason: 'TelemetryService.I should return the same instance as ServiceInstances.telemetry');
    });
    
    test('auditLog: .I returns same instance as ServiceInstances', () {
      // ignore: deprecated_member_use_from_same_package
      final fromI = AuditLogService.I;
      final fromServiceInstances = ServiceInstances.auditLog;
      
      expect(identical(fromI, fromServiceInstances), isTrue,
        reason: 'AuditLogService.I should return the same instance as ServiceInstances.auditLog');
    });
    
    test('syncFailure: .I returns same instance as ServiceInstances', () {
      // ignore: deprecated_member_use_from_same_package
      final fromI = SyncFailureService.I;
      final fromServiceInstances = ServiceInstances.syncFailure;
      
      expect(identical(fromI, fromServiceInstances), isTrue,
        reason: 'SyncFailureService.I should return the same instance as ServiceInstances.syncFailure');
    });
    
    test('secureErase: .I returns same instance as ServiceInstances', () {
      // ignore: deprecated_member_use_from_same_package
      final fromI = SecureEraseService.I;
      final fromServiceInstances = ServiceInstances.secureErase;
      
      expect(identical(fromI, fromServiceInstances), isTrue,
        reason: 'SecureEraseService.I should return the same instance as ServiceInstances.secureErase');
    });
    
    test('secureEraseHardened: .I returns same instance as ServiceInstances', () {
      // ignore: deprecated_member_use_from_same_package
      final fromI = SecureEraseHardened.I;
      final fromServiceInstances = ServiceInstances.secureEraseHardened;
      
      expect(identical(fromI, fromServiceInstances), isTrue,
        reason: 'SecureEraseHardened.I should return the same instance as ServiceInstances.secureEraseHardened');
    });
    
    test('guardrails: .I returns same instance as ServiceInstances', () {
      // ignore: deprecated_member_use_from_same_package
      final fromI = ProductionGuardrails.I;
      final fromServiceInstances = ServiceInstances.guardrails;
      
      expect(identical(fromI, fromServiceInstances), isTrue,
        reason: 'ProductionGuardrails.I should return the same instance as ServiceInstances.guardrails');
    });
    
    test('boxAccessor: .I returns same instance as ServiceInstances', () {
      // ignore: deprecated_member_use_from_same_package
      final fromI = BoxAccess.I;
      final fromServiceInstances = ServiceInstances.boxAccessor;
      
      expect(identical(fromI, fromServiceInstances), isTrue,
        reason: 'BoxAccess.I should return the same instance as ServiceInstances.boxAccessor');
    });
    
    test('conflictResolver: .I returns same instance as ServiceInstances', () {
      // ignore: deprecated_member_use_from_same_package
      final fromI = ConflictResolver.I;
      final fromServiceInstances = ServiceInstances.conflictResolver;
      
      expect(identical(fromI, fromServiceInstances), isTrue,
        reason: 'ConflictResolver.I should return the same instance as ServiceInstances.conflictResolver');
    });
  });
  
  group('DI Constructors Work', () {
    test('TelemetryService can be created via DI', () {
      final telemetry = TelemetryService(maxEvents: 100);
      expect(telemetry, isA<TelemetryService>());
      telemetry.increment('test_event');
      expect(telemetry.snapshot()['counters']['test_event'], equals(1));
    });
    
    test('AuditLogService can be created via DI', () {
      final telemetry = TelemetryService();
      final auditLog = AuditLogService(telemetry: telemetry);
      expect(auditLog, isA<AuditLogService>());
    });
    
    test('SyncFailureService can be created via DI', () {
      final telemetry = TelemetryService();
      final syncFailure = SyncFailureService(telemetry: telemetry);
      expect(syncFailure, isA<SyncFailureService>());
    });
    
    test('SecureEraseService can be created via DI', () {
      final telemetry = TelemetryService();
      final secureErase = SecureEraseService(telemetry: telemetry);
      expect(secureErase, isA<SecureEraseService>());
    });
    
    test('SecureEraseHardened can be created via DI', () {
      final telemetry = TelemetryService();
      final secureEraseHardened = SecureEraseHardened(telemetry: telemetry);
      expect(secureEraseHardened, isA<SecureEraseHardened>());
    });
    
    test('ProductionGuardrails can be created via DI', () {
      final telemetry = TelemetryService();
      final guardrails = ProductionGuardrails(telemetry: telemetry);
      expect(guardrails, isA<ProductionGuardrails>());
    });
    
    test('BoxAccessor can be created via DI', () {
      final boxAccessor = BoxAccessor();
      expect(boxAccessor, isA<BoxAccessor>());
    });
    
    test('ConflictResolver can be created via factory', () {
      final resolver = ConflictResolver.forTest();
      expect(resolver, isA<ConflictResolver>());
      
      // Verify it works
      final result = resolver.resolve(localVersion: 1, remoteVersion: 2);
      expect(result.resolution, equals(ConflictResolution.remoteWins));
    });
  });
  
  group('Test Override Support', () {
    test('can override telemetry for testing', () {
      // Create a fresh instance
      final mockTelemetry = TelemetryService(maxEvents: 50);
      
      // Override
      setSharedTelemetryInstance(mockTelemetry);
      
      // Verify
      expect(identical(ServiceInstances.telemetry, mockTelemetry), isTrue);
      // ignore: deprecated_member_use_from_same_package
      expect(identical(TelemetryService.I, mockTelemetry), isTrue);
    });
    
    test('ServiceInstances.overrideForTest works', () {
      final mockTelemetry = TelemetryService(maxEvents: 25);
      
      ServiceInstances.overrideForTest(telemetry: mockTelemetry);
      
      expect(identical(ServiceInstances.telemetry, mockTelemetry), isTrue);
    });
  });
  
  group('ServiceInstances Lifecycle', () {
    test('initializeAll creates all instances', () {
      // Reset first
      ServiceInstances.reset();
      
      // Initialize
      ServiceInstances.initializeAll();
      
      // All should be accessible
      expect(ServiceInstances.telemetry, isA<TelemetryService>());
      expect(ServiceInstances.auditLog, isA<AuditLogService>());
      expect(ServiceInstances.syncFailure, isA<SyncFailureService>());
      expect(ServiceInstances.secureErase, isA<SecureEraseService>());
      expect(ServiceInstances.secureEraseHardened, isA<SecureEraseHardened>());
      expect(ServiceInstances.guardrails, isA<ProductionGuardrails>());
      expect(ServiceInstances.boxAccessor, isA<BoxAccessor>());
      expect(ServiceInstances.conflictResolver, isA<ConflictResolver>());
      
      expect(ServiceInstances.isInitialized, isTrue);
    });
    
    test('reset clears initialization flag', () {
      ServiceInstances.initializeAll();
      expect(ServiceInstances.isInitialized, isTrue);
      
      ServiceInstances.reset();
      expect(ServiceInstances.isInitialized, isFalse);
    });
  });
  
  group('Architecture Verification', () {
    test('no private static singletons leak separate instances', () {
      // Access via both paths multiple times
      // ignore: deprecated_member_use_from_same_package
      final i1 = TelemetryService.I;
      final s1 = ServiceInstances.telemetry;
      // ignore: deprecated_member_use_from_same_package
      final i2 = TelemetryService.I;
      final s2 = ServiceInstances.telemetry;
      
      // All should be the same instance
      expect(identical(i1, i2), isTrue);
      expect(identical(s1, s2), isTrue);
      expect(identical(i1, s1), isTrue);
    });
    
    test('services share telemetry dependency', () {
      // Initialize to ensure fresh state
      ServiceInstances.initializeAll();
      
      // Get services
      final telemetry = ServiceInstances.telemetry;
      
      // Increment via telemetry
      telemetry.increment('shared_test');
      
      // The counter should be visible in snapshot
      final snapshot = telemetry.snapshot();
      expect(snapshot['counters']['shared_test'], isNotNull);
    });
  });
}
