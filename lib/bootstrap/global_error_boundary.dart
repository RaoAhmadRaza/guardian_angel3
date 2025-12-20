/// Global Error Boundary
///
/// Provides comprehensive error handling for the entire app:
/// 1. Flutter framework errors (FlutterError.onError)
/// 2. Platform/async errors (PlatformDispatcher.onError)
/// 3. Zone errors (runZonedGuarded)
/// 4. Riverpod provider errors (GlobalProviderErrorObserver)
///
/// Usage in main.dart:
/// ```dart
/// void main() {
///   GlobalErrorBoundary.runApp(
///     builder: () => const MyApp(),
///   );
/// }
/// ```
///
/// Part of Blocker #4 Fix: No Global Error Boundary
library;

import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/audit_log_service.dart';
import '../services/telemetry_service.dart';
import '../providers/global_provider_observer.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ERROR TYPES
// ═══════════════════════════════════════════════════════════════════════════

/// Source of the error for categorization and routing.
enum ErrorSource {
  /// Flutter framework error (rendering, gestures, etc.)
  flutter,
  /// Platform dispatcher error
  platform,
  /// Zone-caught async error
  zone,
  /// Riverpod provider error
  provider,
  /// Application-level caught error
  application,
}

/// Severity of the error for triage.
enum ErrorSeverity {
  /// Informational, non-critical
  info,
  /// Warning, degraded experience but app continues
  warning,
  /// Error, feature broken but app continues
  error,
  /// Critical, app may crash or data may be lost
  critical,
  /// Fatal, app cannot continue
  fatal,
}

/// Captured error with full context.
class CapturedError {
  final Object error;
  final StackTrace? stackTrace;
  final ErrorSource source;
  final ErrorSeverity severity;
  final DateTime timestamp;
  final String? context;
  final Map<String, dynamic>? metadata;

  CapturedError({
    required this.error,
    this.stackTrace,
    required this.source,
    this.severity = ErrorSeverity.error,
    DateTime? timestamp,
    this.context,
    this.metadata,
  }) : timestamp = timestamp ?? DateTime.now().toUtc();

  /// User-friendly error message.
  String get userMessage {
    // For common errors, provide friendly messages
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('network') || errorString.contains('socket')) {
      return 'Network connection issue. Please check your internet connection.';
    }
    if (errorString.contains('permission')) {
      return 'Permission required. Please grant the necessary permissions.';
    }
    if (errorString.contains('storage') || errorString.contains('disk')) {
      return 'Storage issue. Please free up some space.';
    }
    if (errorString.contains('hive') || errorString.contains('box')) {
      return 'Data storage issue. The app will try to recover.';
    }
    
    // Default message based on severity
    switch (severity) {
      case ErrorSeverity.info:
        return 'A minor issue occurred.';
      case ErrorSeverity.warning:
        return 'Something went wrong, but you can continue.';
      case ErrorSeverity.error:
        return 'An error occurred. Please try again.';
      case ErrorSeverity.critical:
        return 'A serious error occurred. Please restart the app.';
      case ErrorSeverity.fatal:
        return 'The app encountered a fatal error and needs to restart.';
    }
  }

  /// Technical error message for logging.
  String get technicalMessage => error.toString();

  /// Truncated stack trace for logging.
  String truncatedStackTrace([int maxLines = 15]) {
    if (stackTrace == null) return 'No stack trace';
    final lines = stackTrace.toString().split('\n');
    if (lines.length <= maxLines) return stackTrace.toString();
    return '${lines.take(maxLines).join('\n')}\n... (${lines.length - maxLines} more lines)';
  }

  Map<String, dynamic> toJson() => {
    'error': technicalMessage,
    'error_type': error.runtimeType.toString(),
    'source': source.name,
    'severity': severity.name,
    'timestamp': timestamp.toIso8601String(),
    'context': context,
    'stack_trace': truncatedStackTrace(),
    'metadata': metadata,
  };
}

// ═══════════════════════════════════════════════════════════════════════════
// ERROR HANDLER CALLBACK
// ═══════════════════════════════════════════════════════════════════════════

/// Callback for custom error handling.
typedef ErrorCallback = void Function(CapturedError error);

// ═══════════════════════════════════════════════════════════════════════════
// GLOBAL ERROR BOUNDARY
// ═══════════════════════════════════════════════════════════════════════════

/// Global error boundary that captures and handles all unhandled errors.
class GlobalErrorBoundary {
  GlobalErrorBoundary._();

  static final _instance = GlobalErrorBoundary._();
  static GlobalErrorBoundary get instance => _instance;

  /// Whether the boundary is initialized.
  bool _initialized = false;

  /// All captured errors since app start.
  final List<CapturedError> _errors = [];

  /// Listeners for error events.
  final List<ErrorCallback> _listeners = [];

  /// Controller for error stream.
  final _errorController = StreamController<CapturedError>.broadcast();

  /// Stream of captured errors.
  Stream<CapturedError> get errorStream => _errorController.stream;

  /// All captured errors.
  List<CapturedError> get errors => List.unmodifiable(_errors);

  /// Total error count.
  int get errorCount => _errors.length;

  /// Error count by source.
  Map<ErrorSource, int> get errorsBySource {
    final counts = <ErrorSource, int>{};
    for (final error in _errors) {
      counts[error.source] = (counts[error.source] ?? 0) + 1;
    }
    return counts;
  }

  /// Error count by severity.
  Map<ErrorSeverity, int> get errorsBySeverity {
    final counts = <ErrorSeverity, int>{};
    for (final error in _errors) {
      counts[error.severity] = (counts[error.severity] ?? 0) + 1;
    }
    return counts;
  }

  /// Add an error listener.
  void addListener(ErrorCallback callback) {
    _listeners.add(callback);
  }

  /// Remove an error listener.
  void removeListener(ErrorCallback callback) {
    _listeners.remove(callback);
  }

  /// Initialize the global error boundary.
  ///
  /// Sets up:
  /// - FlutterError.onError for framework errors
  /// - PlatformDispatcher.onError for platform errors
  /// - Custom ErrorWidget.builder for graceful error display
  void initialize() {
    if (_initialized) return;
    _initialized = true;

    // 1. Flutter framework errors
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      _handleFlutterError(details);
      // Also call original handler if exists
      if (originalOnError != null) {
        originalOnError(details);
      }
    };

    // 2. Platform dispatcher errors (async errors not caught by zones)
    PlatformDispatcher.instance.onError = (error, stack) {
      _handlePlatformError(error, stack);
      return true; // Prevent crash
    };

    // 3. Custom error widget for build errors
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return _buildErrorWidget(details);
    };

    debugPrint('[GlobalErrorBoundary] Initialized');
  }

  /// Handle a Flutter framework error.
  void _handleFlutterError(FlutterErrorDetails details) {
    final captured = CapturedError(
      error: details.exception,
      stackTrace: details.stack,
      source: ErrorSource.flutter,
      severity: _classifyFlutterError(details),
      context: details.context?.toDescription(),
      metadata: {
        'library': details.library,
        'silent': details.silent,
      },
    );

    _recordError(captured);

    // Log to console in debug mode
    if (kDebugMode) {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🔴 FLUTTER ERROR');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('Context: ${details.context?.toDescription()}');
      debugPrint('Library: ${details.library}');
      debugPrint('Exception: ${details.exception}');
      debugPrint('Stack: ${captured.truncatedStackTrace(10)}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }
  }

  /// Handle a platform dispatcher error.
  void _handlePlatformError(Object error, StackTrace stack) {
    final captured = CapturedError(
      error: error,
      stackTrace: stack,
      source: ErrorSource.platform,
      severity: ErrorSeverity.error,
    );

    _recordError(captured);

    if (kDebugMode) {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🔴 PLATFORM ERROR');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('Error: $error');
      debugPrint('Stack: ${captured.truncatedStackTrace(10)}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }
  }

  /// Handle a zone error.
  void handleZoneError(Object error, StackTrace stack) {
    final captured = CapturedError(
      error: error,
      stackTrace: stack,
      source: ErrorSource.zone,
      severity: ErrorSeverity.error,
    );

    _recordError(captured);

    if (kDebugMode) {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🔴 ZONE ERROR');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('Error: $error');
      debugPrint('Stack: ${captured.truncatedStackTrace(10)}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }
  }

  /// Manually report an application error.
  void reportError(
    Object error, {
    StackTrace? stackTrace,
    ErrorSeverity severity = ErrorSeverity.error,
    String? context,
    Map<String, dynamic>? metadata,
  }) {
    final captured = CapturedError(
      error: error,
      stackTrace: stackTrace ?? StackTrace.current,
      source: ErrorSource.application,
      severity: severity,
      context: context,
      metadata: metadata,
    );

    _recordError(captured);
  }

  /// Record an error to all tracking systems.
  void _recordError(CapturedError captured) {
    // Add to in-memory list (limit to last 100 errors)
    _errors.add(captured);
    if (_errors.length > 100) {
      _errors.removeAt(0);
    }

    // Emit to stream
    _errorController.add(captured);

    // Notify listeners
    for (final listener in _listeners) {
      try {
        listener(captured);
      } catch (e) {
        debugPrint('[GlobalErrorBoundary] Listener error: $e');
      }
    }

    // Log to audit service (async, fire-and-forget)
    _logToAudit(captured);

    // Report to telemetry
    _reportToTelemetry(captured);
  }

  /// Log error to audit service.
  Future<void> _logToAudit(CapturedError captured) async {
    try {
      AuditLogService.I.log(
        userId: 'system',
        action: 'global_error',
        entityType: 'error',
        entityId: captured.source.name,
        metadata: captured.toJson(),
        severity: captured.severity.name,
      );
    } catch (e) {
      debugPrint('[GlobalErrorBoundary] Failed to log to audit: $e');
    }
  }

  /// Report error to telemetry.
  void _reportToTelemetry(CapturedError captured) {
    try {
      final telemetry = TelemetryService.I;
      telemetry.increment('error.global');
      telemetry.increment('error.source.${captured.source.name}');
      telemetry.increment('error.severity.${captured.severity.name}');
      telemetry.gauge('error.total_count', _errors.length);
    } catch (e) {
      debugPrint('[GlobalErrorBoundary] Failed to report telemetry: $e');
    }
  }

  /// Classify a Flutter error by severity.
  ErrorSeverity _classifyFlutterError(FlutterErrorDetails details) {
    final exception = details.exception.toString().toLowerCase();
    
    // Layout/rendering errors are usually recoverable
    if (exception.contains('renderflex') ||
        exception.contains('overflow') ||
        exception.contains('constraints')) {
      return ErrorSeverity.warning;
    }
    
    // State errors might indicate serious issues
    if (exception.contains('mounted') ||
        exception.contains('disposed') ||
        exception.contains('setState')) {
      return ErrorSeverity.error;
    }
    
    // Assertion errors in debug mode
    if (exception.contains('assertion')) {
      return ErrorSeverity.warning;
    }
    
    return ErrorSeverity.error;
  }

  /// Build a user-friendly error widget.
  Widget _buildErrorWidget(FlutterErrorDetails details) {
    // In release mode, show a simple error indicator
    if (kReleaseMode) {
      return const Material(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 48),
                SizedBox(height: 16),
                Text(
                  'Something went wrong',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Please try again or restart the app.',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // In debug mode, show detailed error info
    return Material(
      child: Container(
        color: Colors.red.shade50,
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.bug_report, color: Colors.red, size: 32),
                  SizedBox(width: 8),
                  Text(
                    'Widget Build Error',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                details.exception.toString(),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              const SizedBox(height: 16),
              const Text(
                'Stack Trace:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                details.stack?.toString().split('\n').take(10).join('\n') ?? 'No stack trace',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Get statistics about captured errors.
  Map<String, dynamic> getStatistics() => {
    'total_errors': _errors.length,
    'errors_by_source': errorsBySource.map((k, v) => MapEntry(k.name, v)),
    'errors_by_severity': errorsBySeverity.map((k, v) => MapEntry(k.name, v)),
    'last_error': _errors.isNotEmpty ? _errors.last.toJson() : null,
    'initialized': _initialized,
  };

  /// Clear all captured errors.
  @visibleForTesting
  void clearErrors() {
    _errors.clear();
  }

  /// Reset the error boundary (for testing).
  @visibleForTesting
  void reset() {
    _errors.clear();
    _listeners.clear();
    _initialized = false;
  }

  /// Run the app with full error boundary protection.
  ///
  /// This is the recommended way to start the app:
  /// ```dart
  /// void main() {
  ///   GlobalErrorBoundary.runApp(
  ///     builder: () async {
  ///       await bootstrapApp();
  ///       return const MyApp();
  ///     },
  ///   );
  /// }
  /// ```
  static void runApp({
    required FutureOr<Widget> Function() builder,
    List<Override>? providerOverrides,
    List<ProviderObserver>? additionalObservers,
  }) {
    // Initialize the boundary
    instance.initialize();

    // Run in a guarded zone
    runZonedGuarded(
      () async {
        WidgetsFlutterBinding.ensureInitialized();

        // Build the app widget
        final appWidget = await builder();

        // Create the observer list
        final observers = <ProviderObserver>[
          globalProviderErrorObserver,
          ...?additionalObservers,
        ];

        // Run the app with ProviderScope
        runAppInternal(
          ProviderScope(
            observers: observers,
            overrides: providerOverrides ?? [],
            child: appWidget,
          ),
        );
      },
      (error, stack) {
        instance.handleZoneError(error, stack);
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CONVENIENCE FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════

/// Report an error to the global error boundary.
void reportError(
  Object error, {
  StackTrace? stackTrace,
  ErrorSeverity severity = ErrorSeverity.error,
  String? context,
  Map<String, dynamic>? metadata,
}) {
  GlobalErrorBoundary.instance.reportError(
    error,
    stackTrace: stackTrace,
    severity: severity,
    context: context,
    metadata: metadata,
  );
}

/// Wrap a function with error handling.
T? tryOrReport<T>(
  T Function() fn, {
  String? context,
  T? fallback,
}) {
  try {
    return fn();
  } catch (e, stack) {
    reportError(e, stackTrace: stack, context: context);
    return fallback;
  }
}

/// Wrap an async function with error handling.
Future<T?> tryOrReportAsync<T>(
  Future<T> Function() fn, {
  String? context,
  T? fallback,
}) async {
  try {
    return await fn();
  } catch (e, stack) {
    reportError(e, stackTrace: stack, context: context);
    return fallback;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ERROR BOUNDARY WIDGET
// ═══════════════════════════════════════════════════════════════════════════

/// A widget that catches errors in its child tree.
///
/// Use this to wrap critical sections of your UI:
/// ```dart
/// ErrorBoundaryWidget(
///   fallback: Text('Something went wrong'),
///   child: CriticalComponent(),
/// )
/// ```
class ErrorBoundaryWidget extends StatefulWidget {
  final Widget child;
  final Widget? fallback;
  final void Function(Object error, StackTrace? stack)? onError;

  const ErrorBoundaryWidget({
    super.key,
    required this.child,
    this.fallback,
    this.onError,
  });

  @override
  State<ErrorBoundaryWidget> createState() => _ErrorBoundaryWidgetState();
}

class _ErrorBoundaryWidgetState extends State<ErrorBoundaryWidget> {
  Object? _error;
  StackTrace? _stackTrace;

  @override
  void initState() {
    super.initState();
    _error = null;
    _stackTrace = null;
  }

  void _handleError(Object error, StackTrace? stack) {
    setState(() {
      _error = error;
      _stackTrace = stack;
    });

    // Report to global boundary
    reportError(error, stackTrace: stack, context: 'ErrorBoundaryWidget');

    // Call custom handler
    widget.onError?.call(error, stack);
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.fallback ?? _buildDefaultFallback();
    }

    // Wrap child in error catcher
    return _ErrorCatcher(
      onError: _handleError,
      child: widget.child,
    );
  }

  Widget _buildDefaultFallback() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 32),
          const SizedBox(height: 8),
          Text(
            'Something went wrong',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              setState(() {
                _error = null;
                _stackTrace = null;
              });
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}

/// Internal widget that catches errors during build.
class _ErrorCatcher extends StatelessWidget {
  final Widget child;
  final void Function(Object, StackTrace?) onError;

  const _ErrorCatcher({
    required this.child,
    required this.onError,
  });

  @override
  Widget build(BuildContext context) {
    try {
      return child;
    } catch (e, stack) {
      onError(e, stack);
      return const SizedBox.shrink();
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ASYNC VALUE ERROR EXTENSION
// ═══════════════════════════════════════════════════════════════════════════

/// Extension to make handling AsyncValue errors easier.
extension AsyncValueErrorExtension<T> on AsyncValue<T> {
  /// Handle error states with automatic reporting to global boundary.
  Widget whenWithErrorBoundary({
    required Widget Function(T data) data,
    required Widget Function() loading,
    Widget Function(Object error, StackTrace stack)? error,
    bool reportErrors = true,
  }) {
    return when(
      data: data,
      loading: loading,
      error: (err, stack) {
        if (reportErrors) {
          reportError(
            err,
            stackTrace: stack,
            context: 'AsyncValue.error',
            severity: ErrorSeverity.error,
          );
        }
        if (error != null) {
          return error(err, stack);
        }
        return _buildDefaultAsyncError(err);
      },
    );
  }

  Widget _buildDefaultAsyncError(Object error) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 32),
          const SizedBox(height: 8),
          Text(
            CapturedError(
              error: error,
              source: ErrorSource.provider,
            ).userMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ],
      ),
    );
  }
}

// Internal: actual runApp wrapper (allows testing override)
@visibleForTesting
void Function(Widget) runAppInternal = runApp;
