import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_angel_fyp/bootstrap/fatal_startup_error.dart';
import 'package:guardian_angel_fyp/bootstrap/app_bootstrap.dart';

void main() {
  group('FatalStartupError', () {
    test('schemaValidation factory creates error with correct properties', () {
      final error = FatalStartupError.schemaValidation(
        details: 'Missing adapter: RoomAdapter (TypeId: 10)',
      );
      
      expect(error.component, 'SchemaValidator');
      expect(error.message, contains('Schema validation failed'));
      expect(error.message, contains('Missing adapter'));
      expect(error.isUserRecoverable, true);
      expect(error.recoverySteps, isNotEmpty);
      expect(error.telemetryKey, 'fatal_startup.schemavalidator');
    });
    
    test('adapterCollision factory creates error with collision details', () {
      final error = FatalStartupError.adapterCollision(
        details: 'TypeId 12 used by multiple adapters',
        collidingAdapters: ['DeviceModel', 'LockRecord'],
      );
      
      expect(error.component, 'AdapterCollisionGuard');
      expect(error.message, contains('TypeId collision'));
      expect(error.isUserRecoverable, false); // Bug, not user-recoverable
      expect(error.recoverySteps.join(' '), contains('DeviceModel'));
      expect(error.recoverySteps.join(' '), contains('LockRecord'));
    });
    
    test('hiveInit factory creates error with cause', () {
      final cause = Exception('Storage full');
      final stackTrace = StackTrace.current;
      
      final error = FatalStartupError.hiveInit(
        details: 'Failed to open box',
        cause: cause,
        causeStackTrace: stackTrace,
      );
      
      expect(error.component, 'HiveService');
      expect(error.cause, cause);
      expect(error.causeStackTrace, stackTrace);
      expect(error.recoverySteps, contains('Ensure the device has sufficient storage'));
    });
    
    test('encryptionKey factory creates error for key issues', () {
      final error = FatalStartupError.encryptionKey(
        details: 'Key not found in secure storage',
      );
      
      expect(error.component, 'EncryptionService');
      expect(error.message, contains('Encryption key error'));
      expect(error.recoverySteps, contains('Clear app data to reset encryption'));
    });
    
    test('guardrailViolation factory creates error for invariants', () {
      final error = FatalStartupError.guardrailViolation(
        invariant: 'pendingOpsNonNegative',
        details: 'pendingOps count is -5',
      );
      
      expect(error.component, 'ProductionGuardrails');
      expect(error.message, contains('Guardrail violation'));
      expect(error.message, contains('pendingOpsNonNegative'));
    });
    
    test('localBackendBootstrap factory creates error with details', () {
      final error = FatalStartupError.localBackendBootstrap(
        details: 'HomeAutomationHiveBridge.open failed',
      );
      
      expect(error.component, 'LocalBackendBootstrap');
      expect(error.message, contains('Local backend bootstrap failed'));
    });
    
    test('toString includes all error details', () {
      final error = FatalStartupError.schemaValidation(
        details: 'Test error',
        cause: Exception('Root cause'),
      );
      
      final str = error.toString();
      expect(str, contains('FATAL STARTUP ERROR'));
      expect(str, contains('SchemaValidator'));
      expect(str, contains('Test error'));
      expect(str, contains('Recovery Steps'));
      expect(str, contains('Root cause'));
    });
    
    test('custom telemetry key overrides default', () {
      final error = FatalStartupError(
        message: 'Test',
        component: 'TestComponent',
        telemetryKey: 'custom.telemetry.key',
      );
      
      expect(error.telemetryKey, 'custom.telemetry.key');
    });
  });
  
  group('BootstrapState', () {
    test('initial state is notStarted', () {
      final state = BootstrapState();
      expect(state.phase, BootstrapPhase.notStarted);
      expect(state.isCompleted, false);
      expect(state.isFailed, false);
    });
    
    test('statusMessage returns human-readable status', () {
      final state = BootstrapState();
      
      state.phase = BootstrapPhase.hiveInit;
      expect(state.statusMessage, 'Initializing database...');
      
      state.phase = BootstrapPhase.schemaValidation;
      expect(state.statusMessage, 'Validating schema...');
      
      state.phase = BootstrapPhase.adapterGuard;
      expect(state.statusMessage, 'Checking adapters...');
      
      state.phase = BootstrapPhase.completed;
      expect(state.statusMessage, contains('Ready'));
    });
    
    test('reset clears all state', () {
      final state = BootstrapState();
      state.phase = BootstrapPhase.completed;
      state.startedAt = DateTime.now();
      state.completedAt = DateTime.now();
      state.completedSteps.add('TestStep');
      state.bufferedAuditEvents.add('TestEvent');
      state.error = FatalStartupError(
        message: 'Test',
        component: 'Test',
      );
      
      state.reset();
      
      expect(state.phase, BootstrapPhase.notStarted);
      expect(state.startedAt, isNull);
      expect(state.completedAt, isNull);
      expect(state.completedSteps, isEmpty);
      expect(state.bufferedAuditEvents, isEmpty);
      expect(state.error, isNull);
    });
    
    test('durationMs calculates correct duration', () {
      final state = BootstrapState();
      state.startedAt = DateTime(2024, 1, 1, 12, 0, 0);
      state.completedAt = DateTime(2024, 1, 1, 12, 0, 1, 500); // 1500ms later
      
      expect(state.durationMs, 1500);
    });
    
    test('durationMs returns null when not complete', () {
      final state = BootstrapState();
      state.startedAt = DateTime.now();
      
      expect(state.durationMs, isNull);
    });
  });
  
  group('BootstrapPhase', () {
    test('all phases are defined', () {
      expect(BootstrapPhase.values, contains(BootstrapPhase.notStarted));
      expect(BootstrapPhase.values, contains(BootstrapPhase.hiveInit));
      expect(BootstrapPhase.values, contains(BootstrapPhase.schemaValidation));
      expect(BootstrapPhase.values, contains(BootstrapPhase.adapterGuard));
      expect(BootstrapPhase.values, contains(BootstrapPhase.localBackend));
      expect(BootstrapPhase.values, contains(BootstrapPhase.auditService));
      expect(BootstrapPhase.values, contains(BootstrapPhase.homeAutomation));
      expect(BootstrapPhase.values, contains(BootstrapPhase.completed));
      expect(BootstrapPhase.values, contains(BootstrapPhase.failed));
    });
  });
  
  group('FatalErrorRecoveryResult', () {
    test('all recovery results are defined', () {
      expect(FatalErrorRecoveryResult.values, contains(FatalErrorRecoveryResult.recovered));
      expect(FatalErrorRecoveryResult.values, contains(FatalErrorRecoveryResult.failed));
      expect(FatalErrorRecoveryResult.values, contains(FatalErrorRecoveryResult.inProgress));
    });
  });
}
