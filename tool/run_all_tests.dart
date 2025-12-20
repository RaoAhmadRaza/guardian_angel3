// tool/run_all_tests.dart
// Test orchestrator - runs all test suites and generates validation report
// Usage: dart run tool/run_all_tests.dart

import 'dart:convert';
import 'dart:io';

/// Test suite configuration
class TestSuite {
  final String name;
  final String command;
  final List<String> args;
  final Duration timeout;

  TestSuite({
    required this.name,
    required this.command,
    required this.args,
    this.timeout = const Duration(minutes: 10),
  });
}

/// Test result
class TestResult {
  final String suiteName;
  final int exitCode;
  final Duration duration;
  final String output;
  final String? error;

  TestResult({
    required this.suiteName,
    required this.exitCode,
    required this.duration,
    required this.output,
    this.error,
  });

  bool get passed => exitCode == 0;

  Map<String, dynamic> toJson() => {
    'suite_name': suiteName,
    'exit_code': exitCode,
    'passed': passed,
    'duration_ms': duration.inMilliseconds,
    'output_lines': output.split('\n').length,
    if (error != null) 'error': error,
  };
}

/// Run a test suite
Future<TestResult> runTestSuite(TestSuite suite) async {
  print('\n${'=' * 80}');
  print('Running: ${suite.name}');
  print('Command: ${suite.command} ${suite.args.join(' ')}');
  print('=' * 80);
  
  final startTime = DateTime.now();
  final output = StringBuffer();
  final errorOutput = StringBuffer();
  
  try {
    final process = await Process.start(
      suite.command,
      suite.args,
      runInShell: true,
    );
    
    // Capture stdout
    process.stdout
        .transform(utf8.decoder)
        .listen((data) {
          stdout.write(data);
          output.write(data);
        });
    
    // Capture stderr
    process.stderr
        .transform(utf8.decoder)
        .listen((data) {
          stderr.write(data);
          errorOutput.write(data);
        });
    
    // Wait with timeout
    final exitCode = await process.exitCode.timeout(
      suite.timeout,
      onTimeout: () {
        process.kill(ProcessSignal.sigterm);
        return -1;
      },
    );
    
    final duration = DateTime.now().difference(startTime);
    
    final result = TestResult(
      suiteName: suite.name,
      exitCode: exitCode,
      duration: duration,
      output: output.toString(),
      error: errorOutput.isEmpty ? null : errorOutput.toString(),
    );
    
    print('\n${result.passed ? '✅' : '❌'} ${suite.name}: ${result.passed ? 'PASSED' : 'FAILED'} (${duration.inSeconds}s)');
    
    return result;
  } catch (e) {
    final duration = DateTime.now().difference(startTime);
    print('\n❌ ${suite.name}: ERROR - $e');
    
    return TestResult(
      suiteName: suite.name,
      exitCode: -1,
      duration: duration,
      output: output.toString(),
      error: e.toString(),
    );
  }
}

/// Main test orchestrator
Future<void> main(List<String> args) async {
  print('🧪 Guardian Angel - Test Orchestrator');
  print('=' * 80);
  
  final startTime = DateTime.now();
  final results = <TestResult>[];
  
  // Define test suites
  final suites = [
    // Unit tests - Sync engine
    TestSuite(
      name: 'Unit Tests - Sync Engine',
      command: 'flutter',
      args: ['test', 'test/sync/', '--reporter', 'compact'],
      timeout: Duration(minutes: 5),
    ),
    
    // Unit tests - Models
    TestSuite(
      name: 'Unit Tests - Models',
      command: 'flutter',
      args: ['test', 'test/models/', '--reporter', 'compact'],
      timeout: Duration(minutes: 3),
    ),
    
    // Unit tests - Persistence
    TestSuite(
      name: 'Unit Tests - Persistence',
      command: 'flutter',
      args: ['test', 'test/persistence/', '--reporter', 'compact'],
      timeout: Duration(minutes: 3),
    ),
    
    // Integration tests - E2E
    TestSuite(
      name: 'Integration Tests - E2E',
      command: 'flutter',
      args: ['test', 'test/integration/', '--reporter', 'compact'],
      timeout: Duration(minutes: 5),
    ),
    
    // Bootstrap & Mocks tests
    TestSuite(
      name: 'Bootstrap & Mocks Tests',
      command: 'flutter',
      args: ['test', 'test/bootstrap_test.dart', '--reporter', 'compact'],
      timeout: Duration(minutes: 2),
    ),
  ];
  
  // Run test suites sequentially
  for (final suite in suites) {
    final result = await runTestSuite(suite);
    results.add(result);
    
    // Optional: fail fast mode
    if (args.contains('--fail-fast') && !result.passed) {
      print('\n❌ Fail-fast mode: Stopping after first failure');
      break;
    }
  }
  
  // Generate summary
  final totalDuration = DateTime.now().difference(startTime);
  final passed = results.where((r) => r.passed).length;
  final failed = results.where((r) => !r.passed).length;
  
  print('\n' + '=' * 80);
  print('📊 TEST SUMMARY');
  print('=' * 80);
  print('Total Suites: ${results.length}');
  print('Passed: $passed');
  print('Failed: $failed');
  print('Total Duration: ${totalDuration.inSeconds}s');
  print('=' * 80);
  
  // Print individual results
  print('\nDetailed Results:');
  for (final result in results) {
    final status = result.passed ? '✅ PASS' : '❌ FAIL';
    print('  $status - ${result.suiteName} (${result.duration.inSeconds}s)');
  }
  
  // Generate validation report
  final report = {
    'timestamp': DateTime.now().toUtc().toIso8601String(),
    'summary': {
      'total_suites': results.length,
      'passed': passed,
      'failed': failed,
      'success_rate': passed / results.length,
      'total_duration_ms': totalDuration.inMilliseconds,
    },
    'suites': results.map((r) => r.toJson()).toList(),
    'environment': {
      'dart_version': Platform.version,
      'os': Platform.operatingSystem,
      'os_version': Platform.operatingSystemVersion,
    },
  };
  
  // Write validation report
  final reportFile = File('validation-report.json');
  await reportFile.writeAsString(
    JsonEncoder.withIndent('  ').convert(report),
  );
  
  print('\n📄 Validation report written to: validation-report.json');
  
  // Exit with appropriate code
  if (failed > 0) {
    print('\n❌ Tests failed. Exiting with code 1.');
    exit(1);
  } else {
    print('\n✅ All tests passed!');
    exit(0);
  }
}
