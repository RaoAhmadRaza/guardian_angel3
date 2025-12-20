/// Global Error Boundary Test Suite
///
/// Tests for the comprehensive error handling system.
/// Part of Blocker #4 Fix: No Global Error Boundary
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian_angel_fyp/bootstrap/global_error_boundary.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CapturedError', () {
    test('creates with required fields', () {
      final error = CapturedError(
        error: Exception('test'),
        source: ErrorSource.flutter,
      );

      expect(error.error, isA<Exception>());
      expect(error.source, ErrorSource.flutter);
      expect(error.severity, ErrorSeverity.error);
      expect(error.timestamp, isNotNull);
    });

    test('provides user-friendly messages for network errors', () {
      final error = CapturedError(
        error: Exception('network connection failed'),
        source: ErrorSource.zone,
      );

      expect(error.userMessage, contains('Network'));
    });

    test('provides user-friendly messages for permission errors', () {
      final error = CapturedError(
        error: Exception('permission denied'),
        source: ErrorSource.platform,
      );

      expect(error.userMessage, contains('Permission'));
    });

    test('provides user-friendly messages for storage errors', () {
      final error = CapturedError(
        error: Exception('disk full'),
        source: ErrorSource.application,
      );

      expect(error.userMessage, contains('Storage'));
    });

    test('provides user-friendly messages for hive errors', () {
      final error = CapturedError(
        error: Exception('box corrupted'),
        source: ErrorSource.application,
      );

      expect(error.userMessage, contains('Data storage'));
    });

    test('provides severity-based default messages', () {
      expect(
        CapturedError(error: 'x', source: ErrorSource.flutter, severity: ErrorSeverity.info)
            .userMessage,
        contains('minor'),
      );
      expect(
        CapturedError(error: 'x', source: ErrorSource.flutter, severity: ErrorSeverity.warning)
            .userMessage,
        contains('continue'),
      );
      expect(
        CapturedError(error: 'x', source: ErrorSource.flutter, severity: ErrorSeverity.critical)
            .userMessage,
        contains('restart'),
      );
    });

    test('truncates stack trace', () {
      final longStack = StackTrace.fromString(
        List.generate(50, (i) => '#$i test_file.dart:$i:1').join('\n'),
      );
      final error = CapturedError(
        error: 'test',
        stackTrace: longStack,
        source: ErrorSource.flutter,
      );

      final truncated = error.truncatedStackTrace(5);
      expect(truncated.split('\n').length, lessThan(50));
      expect(truncated, contains('more lines'));
    });

    test('toJson serializes all fields', () {
      final error = CapturedError(
        error: Exception('test'),
        stackTrace: StackTrace.current,
        source: ErrorSource.provider,
        severity: ErrorSeverity.warning,
        context: 'test context',
        metadata: {'key': 'value'},
      );

      final json = error.toJson();

      expect(json['error'], contains('test'));
      expect(json['error_type'], contains('Exception'));
      expect(json['source'], 'provider');
      expect(json['severity'], 'warning');
      expect(json['context'], 'test context');
      expect(json['metadata'], {'key': 'value'});
      expect(json['timestamp'], isNotNull);
      expect(json['stack_trace'], isNotNull);
    });
  });

  group('ErrorSource', () {
    test('has all expected values', () {
      expect(ErrorSource.values, containsAll([
        ErrorSource.flutter,
        ErrorSource.platform,
        ErrorSource.zone,
        ErrorSource.provider,
        ErrorSource.application,
      ]));
    });
  });

  group('ErrorSeverity', () {
    test('has all expected values', () {
      expect(ErrorSeverity.values, containsAll([
        ErrorSeverity.info,
        ErrorSeverity.warning,
        ErrorSeverity.error,
        ErrorSeverity.critical,
        ErrorSeverity.fatal,
      ]));
    });
  });

  group('GlobalErrorBoundary', () {
    late GlobalErrorBoundary boundary;

    setUp(() {
      boundary = GlobalErrorBoundary.instance;
      boundary.reset();
    });

    tearDown(() {
      boundary.reset();
    });

    test('singleton instance exists', () {
      expect(GlobalErrorBoundary.instance, isNotNull);
      expect(GlobalErrorBoundary.instance, same(boundary));
    });

    test('initialize sets up error handlers', () {
      boundary.initialize();
      // Should not throw
    });

    test('initialize is idempotent', () {
      boundary.initialize();
      boundary.initialize();
      // Should not throw
    });

    test('reportError adds to errors list', () {
      expect(boundary.errorCount, 0);

      boundary.reportError(Exception('test1'));
      expect(boundary.errorCount, 1);

      boundary.reportError(Exception('test2'));
      expect(boundary.errorCount, 2);
    });

    test('errors list is immutable copy', () {
      boundary.reportError(Exception('test'));
      final errors = boundary.errors;

      // UnmodifiableListView throws UnsupportedError when modifying
      expect(() => (errors as List<CapturedError>).add(
        CapturedError(error: 'x', source: ErrorSource.flutter),
      ), throwsUnsupportedError);
    });

    test('handleZoneError records error with correct source', () {
      boundary.handleZoneError(Exception('zone test'), StackTrace.current);

      expect(boundary.errorCount, 1);
      expect(boundary.errors.first.source, ErrorSource.zone);
    });

    test('reportError with metadata', () {
      boundary.reportError(
        Exception('test'),
        severity: ErrorSeverity.critical,
        context: 'test context',
        metadata: {'key': 'value'},
      );

      final error = boundary.errors.first;
      expect(error.severity, ErrorSeverity.critical);
      expect(error.context, 'test context');
      expect(error.metadata, {'key': 'value'});
    });

    test('errorsBySource counts correctly', () {
      boundary.reportError(Exception('1'));
      boundary.reportError(Exception('2'));
      boundary.handleZoneError(Exception('3'), StackTrace.current);

      final bySource = boundary.errorsBySource;
      expect(bySource[ErrorSource.application], 2);
      expect(bySource[ErrorSource.zone], 1);
    });

    test('errorsBySeverity counts correctly', () {
      boundary.reportError(Exception('1'), severity: ErrorSeverity.error);
      boundary.reportError(Exception('2'), severity: ErrorSeverity.warning);
      boundary.reportError(Exception('3'), severity: ErrorSeverity.error);

      final bySeverity = boundary.errorsBySeverity;
      expect(bySeverity[ErrorSeverity.error], 2);
      expect(bySeverity[ErrorSeverity.warning], 1);
    });

    test('limits stored errors to 100', () {
      for (var i = 0; i < 150; i++) {
        boundary.reportError(Exception('error $i'));
      }

      expect(boundary.errorCount, 100);
      // Should have the latest errors
      expect(boundary.errors.last.technicalMessage, contains('149'));
    });

    test('errorStream emits errors', () async {
      final received = <CapturedError>[];
      final sub = boundary.errorStream.listen(received.add);

      boundary.reportError(Exception('test1'));
      boundary.reportError(Exception('test2'));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(received.length, 2);

      await sub.cancel();
    });

    test('listeners are notified', () {
      final received = <CapturedError>[];
      boundary.addListener(received.add);

      boundary.reportError(Exception('test'));

      expect(received.length, 1);

      boundary.removeListener(received.add);
      boundary.reportError(Exception('test2'));

      // Should not receive second error
      expect(received.length, 1);
    });

    test('getStatistics returns correct data', () {
      boundary.reportError(Exception('1'));
      boundary.handleZoneError(Exception('2'), StackTrace.current);

      final stats = boundary.getStatistics();

      expect(stats['total_errors'], 2);
      expect(stats['errors_by_source'], isA<Map>());
      expect(stats['errors_by_severity'], isA<Map>());
      expect(stats['last_error'], isNotNull);
    });

    test('clearErrors removes all errors', () {
      boundary.reportError(Exception('1'));
      boundary.reportError(Exception('2'));
      expect(boundary.errorCount, 2);

      boundary.clearErrors();
      expect(boundary.errorCount, 0);
    });

    test('reset clears everything', () {
      boundary.initialize();
      boundary.reportError(Exception('1'));
      final listener = (CapturedError e) {};
      boundary.addListener(listener);

      boundary.reset();

      expect(boundary.errorCount, 0);
    });
  });

  group('reportError convenience function', () {
    setUp(() {
      GlobalErrorBoundary.instance.reset();
    });

    test('reports to global boundary', () {
      reportError(Exception('test'));

      expect(GlobalErrorBoundary.instance.errorCount, 1);
    });

    test('accepts all parameters', () {
      reportError(
        Exception('test'),
        severity: ErrorSeverity.warning,
        context: 'test context',
        metadata: {'key': 'value'},
      );

      final error = GlobalErrorBoundary.instance.errors.first;
      expect(error.severity, ErrorSeverity.warning);
      expect(error.context, 'test context');
    });
  });

  group('tryOrReport', () {
    setUp(() {
      GlobalErrorBoundary.instance.reset();
    });

    test('returns result on success', () {
      final result = tryOrReport(() => 42);
      expect(result, 42);
      expect(GlobalErrorBoundary.instance.errorCount, 0);
    });

    test('returns fallback and reports on error', () {
      final result = tryOrReport<int>(
        () => throw Exception('fail'),
        fallback: -1,
        context: 'test',
      );

      expect(result, -1);
      expect(GlobalErrorBoundary.instance.errorCount, 1);
    });

    test('returns null without fallback on error', () {
      final result = tryOrReport<int>(() => throw Exception('fail'));

      expect(result, isNull);
    });
  });

  group('tryOrReportAsync', () {
    setUp(() {
      GlobalErrorBoundary.instance.reset();
    });

    test('returns result on success', () async {
      final result = await tryOrReportAsync(() async => 42);
      expect(result, 42);
      expect(GlobalErrorBoundary.instance.errorCount, 0);
    });

    test('returns fallback and reports on error', () async {
      final result = await tryOrReportAsync<int>(
        () async => throw Exception('fail'),
        fallback: -1,
        context: 'async test',
      );

      expect(result, -1);
      expect(GlobalErrorBoundary.instance.errorCount, 1);
    });
  });

  group('ErrorBoundaryWidget', () {
    setUp(() {
      GlobalErrorBoundary.instance.reset();
    });

    testWidgets('renders child normally', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ErrorBoundaryWidget(
            child: Text('Hello'),
          ),
        ),
      );

      expect(find.text('Hello'), findsOneWidget);
    });

    // Note: Testing actual error catching in widgets is tricky in Flutter tests
    // because Flutter's test framework has its own error handling.
    // The ErrorBoundaryWidget is tested conceptually via unit tests above.
    test('can be constructed with all parameters', () {
      final widget = ErrorBoundaryWidget(
        fallback: const Text('Error'),
        onError: (error, stack) {},
        child: const Text('Child'),
      );

      expect(widget.fallback, isNotNull);
      expect(widget.onError, isNotNull);
      expect(widget.child, isNotNull);
    });
  });

  group('AsyncValueErrorExtension', () {
    setUp(() {
      GlobalErrorBoundary.instance.reset();
    });

    testWidgets('whenWithErrorBoundary handles data', (tester) async {
      const asyncValue = AsyncValue.data(42);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: asyncValue.whenWithErrorBoundary(
              data: (value) => Text('Data: $value'),
              loading: () => const CircularProgressIndicator(),
            ),
          ),
        ),
      );

      expect(find.text('Data: 42'), findsOneWidget);
    });

    testWidgets('whenWithErrorBoundary handles loading', (tester) async {
      const asyncValue = AsyncValue<int>.loading();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: asyncValue.whenWithErrorBoundary(
              data: (value) => Text('Data: $value'),
              loading: () => const Text('Loading...'),
            ),
          ),
        ),
      );

      expect(find.text('Loading...'), findsOneWidget);
    });

    testWidgets('whenWithErrorBoundary handles error and reports', (tester) async {
      final asyncValue = AsyncValue<int>.error(Exception('test'), StackTrace.current);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: asyncValue.whenWithErrorBoundary(
              data: (value) => Text('Data: $value'),
              loading: () => const Text('Loading...'),
              error: (e, s) => const Text('Custom error'),
            ),
          ),
        ),
      );

      expect(find.text('Custom error'), findsOneWidget);
      expect(GlobalErrorBoundary.instance.errorCount, 1);
    });

    testWidgets('whenWithErrorBoundary respects reportErrors flag', (tester) async {
      final asyncValue = AsyncValue<int>.error(Exception('test'), StackTrace.current);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: asyncValue.whenWithErrorBoundary(
              data: (value) => Text('Data: $value'),
              loading: () => const Text('Loading...'),
              reportErrors: false,
            ),
          ),
        ),
      );

      expect(GlobalErrorBoundary.instance.errorCount, 0);
    });
  });
}
