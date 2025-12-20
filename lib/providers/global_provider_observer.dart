/// Global Provider Error Boundary
///
/// Monitors all Riverpod provider errors and logs them to audit trail.
/// Part of FINAL 10% CLIMB Phase 2: Long-term survivability.
///
/// Features:
/// - Catches all provider errors globally
/// - Logs to audit service with full context
/// - Tracks error statistics
/// - Helps debug provider issues in production
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/audit_log_service.dart';
import '../services/telemetry_service.dart';

/// Global observer for all Riverpod provider errors.
///
/// Wire this into your ProviderScope:
/// ```dart
/// runApp(
///   ProviderScope(
///     observers: [GlobalProviderErrorObserver()],
///     child: MyApp(),
///   ),
/// );
/// ```
class GlobalProviderErrorObserver extends ProviderObserver {
  GlobalProviderErrorObserver({
    this.logToConsole = true,
    this.logToAudit = true,
    this.maxStackTraceLines = 10,
    TelemetryService? telemetry,
  }) : _telemetry = telemetry ?? TelemetryService.I;

  /// Whether to print errors to debug console.
  final bool logToConsole;

  /// Whether to log errors to audit service.
  final bool logToAudit;

  /// Maximum number of stack trace lines to log.
  final int maxStackTraceLines;
  
  final TelemetryService _telemetry;

  int _totalErrors = 0;
  final Map<String, int> _errorsByProvider = {};

  /// Total number of errors observed.
  int get totalErrors => _totalErrors;

  /// Error counts grouped by provider name.
  Map<String, int> get errorsByProvider => Map.unmodifiable(_errorsByProvider);

  @override
  void didAddProvider(
    ProviderBase<Object?> provider,
    Object? value,
    ProviderContainer container,
  ) {
    if (kDebugMode && logToConsole) {
      debugPrint('[Provider] Added: ${provider.name ?? provider.runtimeType}');
    }
  }

  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    // Only log in verbose debug mode to avoid noise
    // debugPrint('[Provider] Updated: ${provider.name ?? provider.runtimeType}');
  }

  @override
  void didDisposeProvider(
    ProviderBase<Object?> provider,
    ProviderContainer container,
  ) {
    if (kDebugMode && logToConsole) {
      debugPrint('[Provider] Disposed: ${provider.name ?? provider.runtimeType}');
    }
  }

  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    _totalErrors++;
    final providerName = provider.name ?? provider.runtimeType.toString();
    _errorsByProvider[providerName] = (_errorsByProvider[providerName] ?? 0) + 1;

    // Log to console
    if (logToConsole) {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🔴 PROVIDER ERROR: $providerName');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('Error: $error');
      debugPrint('Stack Trace:');
      debugPrint(_truncateStackTrace(stackTrace, maxStackTraceLines));
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }

    // Log to audit service
    if (logToAudit) {
      try {
        AuditLogService.I.log(
          userId: 'system',
          action: 'provider_error',
          entityType: 'provider',
          entityId: providerName,
          metadata: {
            'provider': providerName,
            'error': error.toString(),
            'error_type': error.runtimeType.toString(),
            'stack_trace': _truncateStackTrace(stackTrace, maxStackTraceLines),
            'total_errors': _totalErrors,
            'provider_error_count': _errorsByProvider[providerName],
          },
          severity: 'error',
        );
      } catch (e) {
        // Fallback if audit service fails
        debugPrint('[GlobalProviderErrorObserver] Failed to log to audit: $e');
      }
    }

    // Report to telemetry
    try {
      _telemetry.increment('provider.error');
      _telemetry.increment('provider.error.$providerName');
      _telemetry.gauge('provider.total_errors', _totalErrors);
    } catch (e) {
      debugPrint('[GlobalProviderErrorObserver] Failed to report telemetry: $e');
    }
  }

  /// Truncates stack trace to specified number of lines.
  String _truncateStackTrace(StackTrace stackTrace, int maxLines) {
    final lines = stackTrace.toString().split('\n');
    if (lines.length <= maxLines) {
      return stackTrace.toString();
    }
    final truncated = lines.take(maxLines).join('\n');
    return '$truncated\n... (${lines.length - maxLines} more lines)';
  }

  /// Returns statistics about observed errors.
  Map<String, dynamic> getStatistics() {
    return {
      'total_errors': _totalErrors,
      'unique_providers_with_errors': _errorsByProvider.length,
      'errors_by_provider': Map.from(_errorsByProvider),
      'most_errors_provider': _errorsByProvider.isNotEmpty
          ? _errorsByProvider.entries
              .reduce((a, b) => a.value > b.value ? a : b)
              .key
          : null,
    };
  }

  /// Resets error statistics (useful for testing).
  @visibleForTesting
  void reset() {
    _totalErrors = 0;
    _errorsByProvider.clear();
  }
}

/// Global instance of the error observer for app-wide access.
final globalProviderErrorObserver = GlobalProviderErrorObserver();
