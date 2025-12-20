/// Release Checklist Generator
/// 
/// Auto-populates a release checklist from validation and acceptance reports.
/// This creates a structured artifact that can be used for final sign-off.
///
/// Inputs:
///   - validation-report.json (from tool/run_all_tests.dart)
///   - acceptance-report.json (from tool/acceptance_runner.dart)
///
/// Output:
///   - release-checklist.json: comprehensive checklist with pass/fail status
///
/// Usage:
///   dart run scripts/generate_release_checklist.dart

import 'dart:convert';
import 'dart:io';

void main() {
  print('═══════════════════════════════════════════════════════════');
  print('  Release Checklist Generator');
  print('═══════════════════════════════════════════════════════════');
  print('');
  
  // Load validation report
  Map<String, dynamic> validationReport = {};
  final validationFile = File('validation-report.json');
  if (validationFile.existsSync()) {
    print('✓ Found validation-report.json');
    try {
      validationReport = jsonDecode(validationFile.readAsStringSync());
    } catch (e) {
      print('⚠️  Warning: Could not parse validation-report.json: $e');
    }
  } else {
    print('⚠️  Warning: validation-report.json not found');
    print('   Run: dart run tool/run_all_tests.dart');
  }
  
  // Load acceptance report
  Map<String, dynamic> acceptanceReport = {};
  final acceptanceFile = File('acceptance-report.json');
  if (acceptanceFile.existsSync()) {
    print('✓ Found acceptance-report.json');
    try {
      acceptanceReport = jsonDecode(acceptanceFile.readAsStringSync());
    } catch (e) {
      print('⚠️  Warning: Could not parse acceptance-report.json: $e');
    }
  } else {
    print('⚠️  Warning: acceptance-report.json not found');
    print('   Run: dart run tool/acceptance_runner.dart');
  }
  
  print('');
  print('[CHECKLIST] Generating release checklist...');
  print('');
  
  // Extract test results
  final unitTestsPass = _getTestResult(validationReport, 'unit_tests');
  final integrationTestsPass = _getTestResult(validationReport, 'integration_tests');
  final bootstrapTestsPass = _getTestResult(validationReport, 'bootstrap_tests');
  final acceptanceTestsPass = acceptanceReport['success'] == true;
  
  // Build comprehensive checklist
  final checklist = {
    'generated_at': DateTime.now().toIso8601String(),
    'release_ready': unitTestsPass && 
                     integrationTestsPass && 
                     acceptanceTestsPass,
    'automated_checks': {
      'unit_tests': {
        'status': unitTestsPass ? 'PASSED' : 'FAILED',
        'required': true,
        'description': 'All unit tests pass',
        'source': 'validation-report.json',
      },
      'integration_tests': {
        'status': integrationTestsPass ? 'PASSED' : 'FAILED',
        'required': true,
        'description': 'All integration tests pass',
        'source': 'validation-report.json',
      },
      'bootstrap_tests': {
        'status': bootstrapTestsPass ? 'PASSED' : 'FAILED',
        'required': true,
        'description': 'Test infrastructure validated',
        'source': 'validation-report.json',
      },
      'e2e_acceptance': {
        'status': acceptanceTestsPass ? 'PASSED' : 'FAILED',
        'required': true,
        'description': 'All acceptance scenarios pass',
        'source': 'acceptance-report.json',
        'scenarios': acceptanceReport['scenarios'] ?? {},
      },
      'critical_criteria': {
        'status': _validateCriticalCriteria(acceptanceReport) ? 'PASSED' : 'FAILED',
        'required': true,
        'description': 'Critical acceptance criteria met',
        'criteria': acceptanceReport['critical_acceptance_criteria'] ?? {},
      },
    },
    'manual_checks': {
      'metrics_dashboard': {
        'status': 'PENDING',
        'required': true,
        'description': 'Review SyncMetrics dashboard for anomalies',
        'instructions': [
          'Check success rate > 95%',
          'Verify average latency < 500ms',
          'Confirm no circuit breaker trips in production',
          'Review queue depth trends',
        ],
      },
      'security_review': {
        'status': 'PENDING',
        'required': true,
        'description': 'Security review completed',
        'instructions': [
          'Verify secure storage implementation',
          'Check auth token handling',
          'Review API error responses (no sensitive data leak)',
          'Confirm idempotency keys are properly generated',
        ],
      },
      'performance_profile': {
        'status': 'PENDING',
        'required': false,
        'description': 'Performance profiling completed',
        'instructions': [
          'Profile sync engine under load',
          'Check memory usage patterns',
          'Verify no memory leaks in long-running tests',
        ],
      },
      'documentation_review': {
        'status': 'PENDING',
        'required': true,
        'description': 'All documentation up to date',
        'instructions': [
          'README.md reflects current state',
          'API documentation complete',
          'Runbook covers all operational scenarios',
        ],
      },
    },
    'sign_off': {
      'ready_for_signoff': false,
      'approvals_required': ['tech_lead', 'qa_lead'],
      'approvals_received': [],
      'notes': '',
    },
    'release_metadata': {
      'validation_report_timestamp': validationReport['timestamp'],
      'acceptance_report_timestamp': acceptanceReport['timestamp'],
      'environment': acceptanceReport['environment'] ?? {},
    },
  };
  
  // Write checklist
  final checklistFile = File('release-checklist.json');
  checklistFile.writeAsStringSync(
    JsonEncoder.withIndent('  ').convert(checklist),
  );
  
  print('✅ Release checklist generated');
  print('📄 Saved to: release-checklist.json');
  print('');
  
  // Print summary
  print('═══════════════════════════════════════════════════════════');
  print('  AUTOMATED CHECKS SUMMARY');
  print('═══════════════════════════════════════════════════════════');
  
  final automated = checklist['automated_checks'] as Map<String, dynamic>;
  for (final entry in automated.entries) {
    final check = entry.value as Map<String, dynamic>;
    final status = check['status'];
    final icon = status == 'PASSED' ? '✅' : '❌';
    final required = check['required'] == true ? '(REQUIRED)' : '(OPTIONAL)';
    print('$icon ${entry.key.padRight(20)} $status $required');
  }
  
  print('');
  print('═══════════════════════════════════════════════════════════');
  print('  MANUAL CHECKS REQUIRED');
  print('═══════════════════════════════════════════════════════════');
  
  final manual = checklist['manual_checks'] as Map<String, dynamic>;
  for (final entry in manual.entries) {
    final check = entry.value as Map<String, dynamic>;
    final required = check['required'] == true ? '(REQUIRED)' : '(OPTIONAL)';
    print('⏳ ${entry.key.padRight(20)} PENDING $required');
    print('   ${check['description']}');
  }
  
  print('');
  print('═══════════════════════════════════════════════════════════');
  
  if (checklist['release_ready'] == true) {
    print('✅ RELEASE READY: All automated checks passed');
    print('📋 Complete manual checks before sign-off');
  } else {
    print('❌ NOT RELEASE READY: Fix failing automated checks first');
  }
  
  print('═══════════════════════════════════════════════════════════');
  print('');
  print('Next steps:');
  print('  1. Review release-checklist.json');
  print('  2. Complete all manual checks');
  print('  3. Run: bash scripts/mark_signoff.sh');
  print('');
}

/// Extract test result from validation report
bool _getTestResult(Map<String, dynamic> report, String suiteKey) {
  if (report.isEmpty) return false;
  
  final suites = report['test_suites'] as Map<String, dynamic>?;
  if (suites == null) return false;
  
  final suite = suites[suiteKey] as Map<String, dynamic>?;
  if (suite == null) return false;
  
  return suite['exit_code'] == 0;
}

/// Validate critical acceptance criteria
bool _validateCriticalCriteria(Map<String, dynamic> acceptanceReport) {
  if (acceptanceReport.isEmpty) return false;
  
  final criteria = acceptanceReport['critical_acceptance_criteria'] as Map<String, dynamic>?;
  if (criteria == null) return false;
  
  // All criteria must be true
  return criteria.values.every((value) => value == true);
}
