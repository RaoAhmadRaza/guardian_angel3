/// Queue Processing State Machine
///
/// Defines the explicit states of the pending queue processor.
/// Prevents double-processing, re-entrancy bugs, and hidden deadlocks.
library;

/// State of the queue processor.
enum QueueState {
  /// Processor is not running. Ready to start.
  idle,

  /// Processor is actively processing operations.
  processing,

  /// Processor is blocked (e.g., lock held by another runner).
  blocked,

  /// Processor is paused (e.g., app backgrounded, network offline).
  paused,

  /// Processor encountered an error and stopped.
  error,
}

/// Extension methods for QueueState.
extension QueueStateExtension on QueueState {
  /// Whether the queue can start processing.
  bool get canStartProcessing => this == QueueState.idle;

  /// Whether the queue is currently active.
  bool get isActive => this == QueueState.processing;

  /// Whether the queue is temporarily unavailable.
  bool get isUnavailable => this == QueueState.blocked || this == QueueState.paused;

  /// Human-readable name for logging.
  String get displayName {
    switch (this) {
      case QueueState.idle:
        return 'Idle';
      case QueueState.processing:
        return 'Processing';
      case QueueState.blocked:
        return 'Blocked';
      case QueueState.paused:
        return 'Paused';
      case QueueState.error:
        return 'Error';
    }
  }
}
