import 'dart:math';

/// Exponential backoff policy with jitter
/// 
/// Implements the backoff formula from specs/sync/backoff_policy.md:
/// delay_ms = min(MAX_BACKOFF_MS, BASE_MS * 2^(attempts-1) * jitter)
class BackoffPolicy {
  final int baseMs;
  final int maxBackoffMs;
  final int maxAttempts;
  final Random _random;

  BackoffPolicy({
    this.baseMs = 1000,
    this.maxBackoffMs = 30000,
    this.maxAttempts = 5,
    Random? random,
  }) : _random = random ?? Random();

  /// Compute delay for given attempt number
  /// 
  /// [attempts] - Current retry attempt (1-indexed)
  /// [retryAfter] - Optional server-specified retry delay (overrides backoff)
  Duration computeDelay(int attempts, Duration? retryAfter) {
    if (attempts <= 0) attempts = 1;

    // Honor server-specified Retry-After (RFC 7231)
    if (retryAfter != null) {
      // Add small jitter (0-500ms) to prevent cascade without excessive delay
      final jitterMs = _random.nextDouble() * 500;
      return retryAfter + Duration(milliseconds: jitterMs.toInt());
    }

    // Exponential component: 2^(attempts - 1)
    final exponential = pow(2, attempts - 1).toDouble();

    // Jitter: random value between 0.5 and 1.5
    final jitter = 0.5 + _random.nextDouble();

    // Calculate delay with jitter
    final delayMs = (baseMs * exponential * jitter).toInt();

    // Cap at maximum
    return Duration(milliseconds: min(delayMs, maxBackoffMs));
  }

  /// Check if should retry based on attempt count
  bool shouldRetry(int attempts) {
    return attempts < maxAttempts;
  }

  /// Estimate total time until exhaustion (approximate, assuming average jitter)
  Duration estimateTotalTime() {
    int totalMs = 0;
    for (int i = 1; i <= maxAttempts; i++) {
      final exponential = pow(2, i - 1);
      totalMs += (baseMs * exponential).toInt();
    }
    return Duration(milliseconds: totalMs);
  }
}
