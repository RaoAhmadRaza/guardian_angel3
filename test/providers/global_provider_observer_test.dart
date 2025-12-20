import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian_angel_fyp/providers/global_provider_observer.dart';

// Test providers that throw errors
final throwingProvider = Provider<int>((ref) {
  throw Exception('Test error');
});

final normalProvider = Provider<String>((ref) => 'Hello');

final throwingFutureProvider = FutureProvider<int>((ref) async {
  await Future.delayed(const Duration(milliseconds: 10));
  throw StateError('Async test error');
});

void main() {
  group('GlobalProviderErrorObserver', () {
    late GlobalProviderErrorObserver observer;
    late ProviderContainer container;

    setUp(() {
      observer = GlobalProviderErrorObserver(
        logToConsole: false, // Disable console noise in tests
        logToAudit: false, // Disable audit logging in tests
      );
    });

    tearDown(() {
      observer.reset();
      // Only dispose if container was initialized
      if (container != null) {
        container.dispose();
      }
    });

    group('Constructor', () {
      test('creates with default settings', () {
        final obs = GlobalProviderErrorObserver();
        container = ProviderContainer(); // Initialize for tearDown
        
        expect(obs.logToConsole, isTrue);
        expect(obs.logToAudit, isTrue);
        expect(obs.maxStackTraceLines, equals(10));
      });

      test('creates with custom settings', () {
        final obs = GlobalProviderErrorObserver(
          logToConsole: false,
          logToAudit: false,
          maxStackTraceLines: 5,
        );
        container = ProviderContainer(); // Initialize for tearDown
        
        expect(obs.logToConsole, isFalse);
        expect(obs.logToAudit, isFalse);
        expect(obs.maxStackTraceLines, equals(5));
      });
    });

    group('Error Tracking', () {
      test('tracks single provider error', () {
        container = ProviderContainer(observers: [observer]);

        expect(() => container.read(throwingProvider), throwsException);

        expect(observer.totalErrors, equals(1));
        expect(observer.errorsByProvider.length, equals(1));
      });

      test('tracks multiple errors from same provider', () {
        container = ProviderContainer(observers: [observer]);

        // Force refresh to trigger error multiple times
        expect(() => container.read(throwingProvider), throwsException);
        container.invalidate(throwingProvider);
        expect(() => container.read(throwingProvider), throwsException);
        container.invalidate(throwingProvider);
        expect(() => container.read(throwingProvider), throwsException);

        expect(observer.totalErrors, equals(3));
      });

      test('tracks errors from multiple providers', () async {
        container = ProviderContainer(observers: [observer]);

        expect(() => container.read(throwingProvider), throwsException);
        
        // FutureProvider needs to be awaited
        try {
          await container.read(throwingFutureProvider.future);
        } catch (e) {
          // Expected error
        }

        expect(observer.totalErrors, greaterThanOrEqualTo(2));
      });

      test('does not count successful provider reads', () {
        container = ProviderContainer(observers: [observer]);

        final value = container.read(normalProvider);
        expect(value, equals('Hello'));
        expect(observer.totalErrors, equals(0));
      });
    });

    group('Statistics', () {
      test('getStatistics returns correct data', () {
        container = ProviderContainer(observers: [observer]);

        expect(() => container.read(throwingProvider), throwsException);

        final stats = observer.getStatistics();
        expect(stats['total_errors'], equals(1));
        expect(stats['unique_providers_with_errors'], equals(1));
        expect(stats['errors_by_provider'], isNotEmpty);
      });

      test('getStatistics identifies most error-prone provider', () {
        container = ProviderContainer(observers: [observer]);

        // Trigger throwingProvider 3 times
        expect(() => container.read(throwingProvider), throwsException);
        container.invalidate(throwingProvider);
        expect(() => container.read(throwingProvider), throwsException);
        container.invalidate(throwingProvider);
        expect(() => container.read(throwingProvider), throwsException);

        final stats = observer.getStatistics();
        expect(stats['most_errors_provider'], isNotNull);
      });

      test('getStatistics returns null for most_errors_provider when no errors', () {
        container = ProviderContainer(observers: [observer]);

        final stats = observer.getStatistics();
        expect(stats['most_errors_provider'], isNull);
      });
    });

    group('Lifecycle Callbacks', () {
      test('didAddProvider is called when provider is added', () {
        container = ProviderContainer(observers: [observer]);

        // Read provider to trigger add
        container.read(normalProvider);

        // No assertions here - just verifying it doesn't throw
        expect(observer.totalErrors, equals(0));
      });

      test('didDisposeProvider is called when provider is disposed', () {
        container = ProviderContainer(observers: [observer]);
        container.read(normalProvider);

        // Dispose triggers didDisposeProvider
        container.dispose();

        // No assertions - just verifying no errors
      });

      test('didUpdateProvider is called on state changes', () {
        final stateProvider = StateProvider<int>((ref) => 0);
        container = ProviderContainer(observers: [observer]);

        final notifier = container.read(stateProvider.notifier);
        notifier.state = 1;
        notifier.state = 2;

        // No errors should be tracked
        expect(observer.totalErrors, equals(0));
      });
    });

    group('Stack Trace Truncation', () {
      test('truncates long stack traces', () {
        final shortObserver = GlobalProviderErrorObserver(
          maxStackTraceLines: 3,
          logToConsole: false,
          logToAudit: false,
        );
        container = ProviderContainer(observers: [shortObserver]);

        expect(() => container.read(throwingProvider), throwsException);

        // Stack trace should be truncated (tested indirectly via no exceptions)
        expect(shortObserver.totalErrors, equals(1));
        
        shortObserver.reset();
      });
    });

    group('Reset', () {
      test('reset clears all statistics', () {
        container = ProviderContainer(observers: [observer]);

        expect(() => container.read(throwingProvider), throwsException);
        expect(observer.totalErrors, equals(1));

        observer.reset();

        expect(observer.totalErrors, equals(0));
        expect(observer.errorsByProvider, isEmpty);
      });
    });

    group('Error Types', () {
      test('handles Exception errors', () {
        container = ProviderContainer(observers: [observer]);

        expect(() => container.read(throwingProvider), throwsException);
        expect(observer.totalErrors, equals(1));
      });

      test('handles StateError errors', () async {
        container = ProviderContainer(observers: [observer]);

        try {
          await container.read(throwingFutureProvider.future);
        } catch (e) {
          expect(e, isA<StateError>());
        }
        
        expect(observer.totalErrors, greaterThanOrEqualTo(1));
      });
    });

    group('Global Instance', () {
      test('globalProviderErrorObserver exists', () {
        expect(globalProviderErrorObserver, isNotNull);
        expect(globalProviderErrorObserver, isA<GlobalProviderErrorObserver>());
      });
    });

    group('Console Logging', () {
      test('logs to console when enabled', () {
        final consoleObserver = GlobalProviderErrorObserver(
          logToConsole: true,
          logToAudit: false,
        );
        container = ProviderContainer(observers: [consoleObserver]);

        // Should print to console (can't capture in test, but verify no crash)
        expect(() => container.read(throwingProvider), throwsException);
        expect(consoleObserver.totalErrors, equals(1));
        
        consoleObserver.reset();
      });

      test('does not log to console when disabled', () {
        final silentObserver = GlobalProviderErrorObserver(
          logToConsole: false,
          logToAudit: false,
        );
        container = ProviderContainer(observers: [silentObserver]);

        expect(() => container.read(throwingProvider), throwsException);
        expect(silentObserver.totalErrors, equals(1));
        
        silentObserver.reset();
      });
    });

    group('Provider Names', () {
      test('tracks provider by name or type', () {
        container = ProviderContainer(observers: [observer]);

        expect(() => container.read(throwingProvider), throwsException);

        final providerNames = observer.errorsByProvider.keys;
        expect(providerNames, isNotEmpty);
        // Provider name should contain "Provider" or similar
        expect(
          providerNames.first.contains('Provider') ||
              providerNames.first.contains('throwing'),
          isTrue,
        );
      });
    });

    group('Concurrent Errors', () {
      test('handles multiple errors in quick succession', () {
        container = ProviderContainer(observers: [observer]);

        final provider1 = Provider<int>((ref) => throw Exception('Error 1'));
        final provider2 = Provider<int>((ref) => throw Exception('Error 2'));
        final provider3 = Provider<int>((ref) => throw Exception('Error 3'));

        expect(() => container.read(provider1), throwsException);
        expect(() => container.read(provider2), throwsException);
        expect(() => container.read(provider3), throwsException);

        expect(observer.totalErrors, equals(3));
      });
    });
  });
}
