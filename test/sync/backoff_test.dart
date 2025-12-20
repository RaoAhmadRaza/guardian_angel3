import 'package:flutter_test/flutter_test.dart';
import 'dart:math';

import 'package:guardian_angel_fyp/sync/backoff_policy.dart';

void main() {
  group('BackoffPolicy', () {
    late BackoffPolicy policy;

    setUp(() {
      policy = BackoffPolicy();
    });

    group('computeDelay', () {
      test('Follows exponential formula: BASE * 2^(attempts-1) * jitter', () {
        // Test multiple attempts with deterministic random
        final random = Random(12345);
        final policyWithSeed = BackoffPolicy(random: random);

        // Attempt 1: 1000 * 2^0 * jitter = 1000 * jitter
        final delay1 = policyWithSeed.computeDelay(1, null);
        expect(delay1.inMilliseconds, greaterThanOrEqualTo(500));
        expect(delay1.inMilliseconds, lessThanOrEqualTo(1500));

        // Attempt 2: 1000 * 2^1 * jitter = 2000 * jitter
        final delay2 = policyWithSeed.computeDelay(2, null);
        expect(delay2.inMilliseconds, greaterThanOrEqualTo(1000));
        expect(delay2.inMilliseconds, lessThanOrEqualTo(3000));

        // Attempt 3: 1000 * 2^2 * jitter = 4000 * jitter
        final delay3 = policyWithSeed.computeDelay(3, null);
        expect(delay3.inMilliseconds, greaterThanOrEqualTo(2000));
        expect(delay3.inMilliseconds, lessThanOrEqualTo(6000));

        // Attempt 4: 1000 * 2^3 * jitter = 8000 * jitter
        final delay4 = policyWithSeed.computeDelay(4, null);
        expect(delay4.inMilliseconds, greaterThanOrEqualTo(4000));
        expect(delay4.inMilliseconds, lessThanOrEqualTo(12000));

        // Attempt 5: 1000 * 2^4 * jitter = 16000 * jitter
        final delay5 = policyWithSeed.computeDelay(5, null);
        expect(delay5.inMilliseconds, greaterThanOrEqualTo(8000));
        expect(delay5.inMilliseconds, lessThanOrEqualTo(24000));
      });

      test('Respects maxBackoffMs cap', () {
        final policyWithCap = BackoffPolicy(
          baseMs: 1000,
          maxBackoffMs: 5000,
        );

        // Attempt 10: 1000 * 2^9 = 512000ms, should cap at 5000ms
        final delay = policyWithCap.computeDelay(10, null);
        expect(delay.inMilliseconds, lessThanOrEqualTo(7500)); // 5000 * 1.5 jitter
      });

      test('Jitter distribution is uniform 0.5-1.5', () {
        final random = Random(42);
        final policyWithSeed = BackoffPolicy(
          baseMs: 1000,
          maxBackoffMs: 100000,
          random: random,
        );

        final delays = List.generate(100, (_) => policyWithSeed.computeDelay(1, null));
        final minDelay = delays.map((d) => d.inMilliseconds).reduce(min);
        final maxDelay = delays.map((d) => d.inMilliseconds).reduce(max);

        expect(minDelay, greaterThanOrEqualTo(500)); // 1000 * 0.5
        expect(maxDelay, lessThanOrEqualTo(1500)); // 1000 * 1.5
      });

      test('Retry-After header overrides exponential delay', () {
        final retryAfter = const Duration(seconds: 120);
        final delay = policy.computeDelay(1, retryAfter);

        // Should use Retry-After instead of exponential
        expect(delay, retryAfter);
      });

      test('Retry-After respects maxBackoffMs cap', () {
        final policyWithCap = BackoffPolicy(
          baseMs: 1000,
          maxBackoffMs: 10000,
        );

        final retryAfter = const Duration(seconds: 300); // 300s = 300000ms
        final delay = policyWithCap.computeDelay(1, retryAfter);

        // Should cap at maxBackoffMs
        expect(delay.inMilliseconds, 10000);
      });

      test('Zero attempts returns base delay with jitter', () {
        final random = Random(99);
        final policyWithSeed = BackoffPolicy(random: random);

        final delay = policyWithSeed.computeDelay(0, null);
        expect(delay.inMilliseconds, greaterThanOrEqualTo(500));
        expect(delay.inMilliseconds, lessThanOrEqualTo(1500));
      });
    });

    group('shouldRetry', () {
      test('Returns true when attempts < maxAttempts', () {
        expect(policy.shouldRetry(1), true);
        expect(policy.shouldRetry(2), true);
        expect(policy.shouldRetry(3), true);
        expect(policy.shouldRetry(4), true);
      });

      test('Returns false when attempts >= maxAttempts', () {
        expect(policy.shouldRetry(5), false);
        expect(policy.shouldRetry(6), false);
        expect(policy.shouldRetry(100), false);
      });

      test('Custom maxAttempts configuration', () {
        final customPolicy = BackoffPolicy(maxAttempts: 3);

        expect(customPolicy.shouldRetry(1), true);
        expect(customPolicy.shouldRetry(2), true);
        expect(customPolicy.shouldRetry(3), false);
        expect(customPolicy.shouldRetry(4), false);
      });
    });

    group('Edge Cases', () {
      test('Handles very high attempts without overflow', () {
        final delay = policy.computeDelay(100, null);
        expect(delay.inMilliseconds, policy.maxBackoffMs);
      });

      test('Handles negative attempts gracefully', () {
        final delay = policy.computeDelay(-1, null);
        expect(delay.inMilliseconds, greaterThanOrEqualTo(0));
      });

      test('Handles zero base delay', () {
        final zeroPolicy = BackoffPolicy(baseMs: 0);
        final delay = zeroPolicy.computeDelay(3, null);
        expect(delay.inMilliseconds, 0);
      });

      test('Handles Retry-After of zero', () {
        final delay = policy.computeDelay(1, Duration.zero);
        expect(delay.inSeconds, lessThanOrEqualTo(5));
      });
    });

    group('Deterministic Testing', () {
      test('Same seed produces same delays', () {
        final policy1 = BackoffPolicy(random: Random(555));
        final policy2 = BackoffPolicy(random: Random(555));

        final delay1 = policy1.computeDelay(3, null);
        final delay2 = policy2.computeDelay(3, null);

        expect(delay1, delay2);
      });

      test('Different seeds produce different delays', () {
        final policy1 = BackoffPolicy(random: Random(111));
        final policy2 = BackoffPolicy(random: Random(222));

        final delays1 = List.generate(10, (_) => policy1.computeDelay(2, null));
        final delays2 = List.generate(10, (_) => policy2.computeDelay(2, null));

        expect(delays1, isNot(delays2));
      });
    });

    group('Real-World Scenarios', () {
      test('Rate limit with Retry-After: 60s', () {
        final delay = policy.computeDelay(1, const Duration(seconds: 60));
        expect(delay.inSeconds, 60);
      });

      test('First network failure: ~1s delay', () {
        final random = Random(777);
        final policyWithSeed = BackoffPolicy(random: random);

        final delay = policyWithSeed.computeDelay(1, null);
        expect(delay.inMilliseconds, greaterThanOrEqualTo(500));
        expect(delay.inMilliseconds, lessThanOrEqualTo(1500));
      });

      test('Second network failure: ~2s delay', () {
        final random = Random(888);
        final policyWithSeed = BackoffPolicy(random: random);

        final delay = policyWithSeed.computeDelay(2, null);
        expect(delay.inMilliseconds, greaterThanOrEqualTo(1000));
        expect(delay.inMilliseconds, lessThanOrEqualTo(3000));
      });

      test('Third network failure: ~4s delay', () {
        final random = Random(999);
        final policyWithSeed = BackoffPolicy(random: random);

        final delay = policyWithSeed.computeDelay(3, null);
        expect(delay.inMilliseconds, greaterThanOrEqualTo(2000));
        expect(delay.inMilliseconds, lessThanOrEqualTo(6000));
      });

      test('Server error (5xx) with max backoff reached', () {
        final policyWithCap = BackoffPolicy(
          baseMs: 1000,
          maxBackoffMs: 30000,
        );

        final delay = policyWithCap.computeDelay(10, null);
        expect(delay.inMilliseconds, lessThanOrEqualTo(45000)); // 30000 * 1.5
      });
    });
  });
}
