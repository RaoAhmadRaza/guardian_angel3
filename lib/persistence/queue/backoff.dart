/// Queue Backoff Utilities
///
/// Pure, testable functions for computing retry backoff.
/// No side effects, no state.
library;

/// Compute backoff duration for a given attempt count.
///
/// Uses exponential backoff with a 2-second base and 10-minute ceiling.
///
/// Formula: min(2s * 2^attempts, 10 minutes)
///
/// Example progression:
/// - Attempt 0: 2s (first retry)
/// - Attempt 1: 4s
/// - Attempt 2: 8s
/// - Attempt 3: 16s
/// - Attempt 4: 32s
/// - Attempt 5: 64s (~1 min)
/// - Attempt 6: 128s (~2 min)
/// - Attempt 7+: 600s (10 min ceiling)
Duration computeBackoff(int attempts) {
  const base = Duration(seconds: 2);
  const maxBackoff = Duration(minutes: 10);

  // Guard against negative attempts
  if (attempts < 0) return base;

  // Calculate exponential backoff: base * 2^attempts
  // Use bit shift for efficiency: 1 << attempts == 2^attempts
  // Cap at reasonable value to prevent overflow
  final multiplier = attempts >= 20 ? (1 << 20) : (1 << attempts);
  final backoff = base * multiplier;

  return backoff > maxBackoff ? maxBackoff : backoff;
}

/// Compute the next eligible time for an operation.
///
/// Returns `now + backoff(attempts)`.
DateTime computeNextEligibleAt(int attempts) {
  return DateTime.now().toUtc().add(computeBackoff(attempts));
}

/// Check if an operation is eligible for processing.
///
/// An op is eligible if:
/// - nextEligibleAt is null (never failed)
/// - Current time is after nextEligibleAt
bool isOpEligible(DateTime? nextEligibleAt) {
  if (nextEligibleAt == null) return true;
  return DateTime.now().toUtc().isAfter(nextEligibleAt);
}

/// Format backoff duration for logging.
String formatBackoff(Duration d) {
  if (d.inMinutes >= 1) {
    return '${d.inMinutes}m ${d.inSeconds % 60}s';
  }
  return '${d.inSeconds}s';
}
