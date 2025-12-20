/// Failure Classification System
///
/// This file provides comprehensive failure classification for sync operations.
/// It maps various exception types and error conditions to failure categories
/// that inform retry strategy, escalation policy, and user messaging.
///
/// The classification system ensures:
/// 1. Transient failures are retried with appropriate backoff
/// 2. Permanent failures are moved to failed_ops without retry
/// 3. Auth failures trigger re-authentication flow
/// 4. Schema failures prompt app update
///
/// Usage:
/// ```dart
/// try {
///   await syncOperation();
/// } catch (e) {
///   final classification = FailureClassifier.classify(e);
///   if (classification.shouldRetry) {
///     await queue.scheduleRetry(op, classification);
///   } else {
///     await queue.moveToFailed(op, classification);
///   }
/// }
/// ```
library;

import 'dart:async';
import 'dart:io';

import 'sync_consumer.dart';

/// Comprehensive failure classification with metadata.
///
/// Provides rich failure information beyond just the type,
/// including suggested actions and user-facing messages.
class FailureClassification {
  /// The type of failure.
  final FailureType type;

  /// Technical error message for logging.
  final String technicalMessage;

  /// User-friendly message for display.
  final String userMessage;

  /// Original exception (if available).
  final Object? originalError;

  /// Stack trace (if available).
  final StackTrace? stackTrace;

  /// Whether this failure should be retried.
  bool get shouldRetry => type == FailureType.transient;

  /// Whether this failure should be escalated to user.
  bool get shouldEscalate => type != FailureType.transient;

  /// Whether this failure requires re-authentication.
  bool get requiresAuth => type == FailureType.auth;

  /// Whether this failure requires app update.
  bool get requiresUpdate => type == FailureType.schema;

  /// Suggested delay before retry (for transient failures).
  Duration get suggestedDelay {
    switch (type) {
      case FailureType.transient:
        return const Duration(seconds: 2);
      case FailureType.auth:
        return const Duration(seconds: 30); // Wait for re-auth
      case FailureType.permanent:
      case FailureType.schema:
        return Duration.zero; // No retry
    }
  }

  const FailureClassification({
    required this.type,
    required this.technicalMessage,
    required this.userMessage,
    this.originalError,
    this.stackTrace,
  });

  /// Creates a transient failure classification.
  factory FailureClassification.transient(
    String technicalMessage, {
    String? userMessage,
    Object? error,
    StackTrace? stackTrace,
  }) {
    return FailureClassification(
      type: FailureType.transient,
      technicalMessage: technicalMessage,
      userMessage: userMessage ?? 'Connection issue. Will retry automatically.',
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  /// Creates a permanent failure classification.
  factory FailureClassification.permanent(
    String technicalMessage, {
    String? userMessage,
    Object? error,
    StackTrace? stackTrace,
  }) {
    return FailureClassification(
      type: FailureType.permanent,
      technicalMessage: technicalMessage,
      userMessage: userMessage ?? 'This operation could not be completed.',
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  /// Creates an auth failure classification.
  factory FailureClassification.auth(
    String technicalMessage, {
    String? userMessage,
    Object? error,
    StackTrace? stackTrace,
  }) {
    return FailureClassification(
      type: FailureType.auth,
      technicalMessage: technicalMessage,
      userMessage: userMessage ?? 'Please sign in again to continue.',
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  /// Creates a schema failure classification.
  factory FailureClassification.schema(
    String technicalMessage, {
    String? userMessage,
    Object? error,
    StackTrace? stackTrace,
  }) {
    return FailureClassification(
      type: FailureType.schema,
      technicalMessage: technicalMessage,
      userMessage: userMessage ?? 'Please update the app to continue.',
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  @override
  String toString() {
    return 'FailureClassification(${type.name}: $technicalMessage)';
  }

  /// Converts to a map for logging/telemetry.
  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'technicalMessage': technicalMessage,
      'userMessage': userMessage,
      'shouldRetry': shouldRetry,
      'errorType': originalError?.runtimeType.toString(),
    };
  }
}

/// Classifier for mapping exceptions and errors to failure types.
///
/// This class provides static methods to classify various error conditions.
/// It serves as the central point for failure classification logic.
class FailureClassifier {
  /// Classifies any error/exception to a FailureClassification.
  ///
  /// This is the main entry point for classification. It handles:
  /// - Dart standard exceptions
  /// - IO exceptions (socket, file)
  /// - HTTP status codes
  /// - Custom exceptions
  static FailureClassification classify(
    Object error, [
    StackTrace? stackTrace,
  ]) {
    // Handle SocketException (network issues)
    if (error is SocketException) {
      return FailureClassification.transient(
        'Socket error: ${error.message}',
        userMessage: 'Network connection failed. Will retry.',
        error: error,
        stackTrace: stackTrace,
      );
    }

    // Handle HttpException
    if (error is HttpException) {
      return FailureClassification.transient(
        'HTTP error: ${error.message}',
        userMessage: 'Server communication failed. Will retry.',
        error: error,
        stackTrace: stackTrace,
      );
    }

    // Handle timeout exceptions
    if (error is TimeoutException) {
      return FailureClassification.transient(
        'Timeout: ${error.message}',
        userMessage: 'Request timed out. Will retry.',
        error: error,
        stackTrace: stackTrace,
      );
    }

    // Handle format exceptions (usually permanent)
    if (error is FormatException) {
      return FailureClassification.schema(
        'Format error: ${error.message}',
        userMessage: 'Data format error. Please update the app.',
        error: error,
        stackTrace: stackTrace,
      );
    }

    // Handle generic exceptions
    if (error is Exception) {
      return _classifyException(error, stackTrace);
    }

    // Handle Error types
    if (error is Error) {
      return _classifyError(error, stackTrace);
    }

    // Unknown error type - treat as permanent
    return FailureClassification.permanent(
      'Unknown error: $error',
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Classifies an HTTP response by status code.
  static FailureClassification classifyHttpStatus(
    int statusCode,
    String? responseBody,
  ) {
    final failureType = statusCode.toFailureType();

    if (failureType == null) {
      // Success - shouldn't reach here, but handle gracefully
      return FailureClassification.permanent(
        'Unexpected success status: $statusCode',
      );
    }

    switch (failureType) {
      case FailureType.transient:
        return FailureClassification.transient(
          'HTTP $statusCode: $responseBody',
          userMessage: _transientUserMessage(statusCode),
        );

      case FailureType.permanent:
        return FailureClassification.permanent(
          'HTTP $statusCode: $responseBody',
          userMessage: _permanentUserMessage(statusCode, responseBody),
        );

      case FailureType.auth:
        return FailureClassification.auth(
          'HTTP $statusCode: $responseBody',
          userMessage: statusCode == 401
              ? 'Your session has expired. Please sign in again.'
              : 'You don\'t have permission to perform this action.',
        );

      case FailureType.schema:
        return FailureClassification.schema(
          'HTTP $statusCode: $responseBody',
        );
    }
  }

  /// Returns user message for transient HTTP errors.
  static String _transientUserMessage(int statusCode) {
    switch (statusCode) {
      case 408:
        return 'Request timed out. Will retry.';
      case 429:
        return 'Too many requests. Will retry shortly.';
      case 500:
      case 502:
      case 503:
      case 504:
        return 'Server is temporarily unavailable. Will retry.';
      default:
        return 'Temporary issue. Will retry automatically.';
    }
  }

  /// Returns user message for permanent HTTP errors.
  static String _permanentUserMessage(int statusCode, String? body) {
    switch (statusCode) {
      case 400:
        return 'Invalid request. Please try again.';
      case 404:
        return 'The requested item was not found.';
      case 409:
        return 'Conflict with existing data.';
      case 410:
        return 'This item is no longer available.';
      case 413:
        return 'The data is too large to process.';
      case 422:
        return 'The data could not be processed.';
      default:
        return 'This operation could not be completed.';
    }
  }

  /// Classifies a generic Exception.
  static FailureClassification _classifyException(
    Exception error,
    StackTrace? stackTrace,
  ) {
    final typeName = error.runtimeType.toString().toLowerCase();
    final message = error.toString();

    // Network-related exceptions
    if (typeName.contains('socket') ||
        typeName.contains('connection') ||
        typeName.contains('network') ||
        typeName.contains('timeout')) {
      return FailureClassification.transient(
        message,
        error: error,
        stackTrace: stackTrace,
      );
    }

    // Auth-related exceptions
    if (typeName.contains('auth') ||
        typeName.contains('permission') ||
        typeName.contains('unauthorized') ||
        typeName.contains('forbidden') ||
        message.contains('401') ||
        message.contains('403')) {
      return FailureClassification.auth(
        message,
        error: error,
        stackTrace: stackTrace,
      );
    }

    // Schema/format exceptions
    if (typeName.contains('format') ||
        typeName.contains('parse') ||
        typeName.contains('schema') ||
        typeName.contains('serializ')) {
      return FailureClassification.schema(
        message,
        error: error,
        stackTrace: stackTrace,
      );
    }

    // Default to permanent
    return FailureClassification.permanent(
      message,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Classifies a Dart Error.
  static FailureClassification _classifyError(
    Error error,
    StackTrace? stackTrace,
  ) {
    // Type errors and assertion errors are schema issues
    if (error is TypeError || error is AssertionError) {
      return FailureClassification.schema(
        error.toString(),
        userMessage: 'Data format error. Please update the app.',
        error: error,
        stackTrace: stackTrace,
      );
    }

    // State errors are usually permanent
    if (error is StateError) {
      return FailureClassification.permanent(
        error.toString(),
        error: error,
        stackTrace: stackTrace,
      );
    }

    // Range and argument errors are schema issues
    if (error is RangeError || error is ArgumentError) {
      return FailureClassification.schema(
        error.toString(),
        error: error,
        stackTrace: stackTrace,
      );
    }

    // Default to permanent for unknown errors
    return FailureClassification.permanent(
      error.toString(),
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Classifies a failure with context from the operation.
  ///
  /// Use this when you have additional context about what was being attempted.
  static FailureClassification classifyWithContext(
    Object error,
    String operation,
    Map<String, dynamic>? context, [
    StackTrace? stackTrace,
  ]) {
    final base = classify(error, stackTrace);
    return FailureClassification(
      type: base.type,
      technicalMessage: '[$operation] ${base.technicalMessage}',
      userMessage: base.userMessage,
      originalError: error,
      stackTrace: stackTrace,
    );
  }
}

/// Exception thrown when an operation fails after max retries.
///
/// This is thrown by the queue processor when an operation has exhausted
/// all retry attempts and is being moved to failed_ops.
class MaxRetriesExceededException implements Exception {
  final String operationId;
  final int attempts;
  final FailureClassification lastFailure;

  const MaxRetriesExceededException({
    required this.operationId,
    required this.attempts,
    required this.lastFailure,
  });

  @override
  String toString() {
    return 'MaxRetriesExceededException: Operation $operationId failed '
        'after $attempts attempts. Last error: ${lastFailure.technicalMessage}';
  }
}

/// Exception thrown when a permanent failure is detected.
///
/// This is thrown immediately (no retries) when a permanent failure is detected.
class PermanentFailureException implements Exception {
  final String operationId;
  final FailureClassification failure;

  const PermanentFailureException({
    required this.operationId,
    required this.failure,
  });

  @override
  String toString() {
    return 'PermanentFailureException: Operation $operationId failed '
        'permanently: ${failure.technicalMessage}';
  }
}

/// Exception thrown when auth is required before continuing.
///
/// The queue should pause when this is thrown and wait for re-auth.
class AuthRequiredException implements Exception {
  final FailureClassification failure;

  const AuthRequiredException(this.failure);

  @override
  String toString() {
    return 'AuthRequiredException: ${failure.technicalMessage}';
  }
}
