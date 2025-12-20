import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_angel_fyp/persistence/queue/backoff.dart';

void main() {
  group('computeBackoff', () {
    test('attempt 0 returns 2 seconds', () {
      expect(computeBackoff(0), const Duration(seconds: 2));
    });

    test('attempt 1 returns 4 seconds', () {
      expect(computeBackoff(1), const Duration(seconds: 4));
    });

    test('attempt 2 returns 8 seconds', () {
      expect(computeBackoff(2), const Duration(seconds: 8));
    });

    test('attempt 3 returns 16 seconds', () {
      expect(computeBackoff(3), const Duration(seconds: 16));
    });

    test('attempt 4 returns 32 seconds', () {
      expect(computeBackoff(4), const Duration(seconds: 32));
    });

    test('attempt 5 returns 64 seconds', () {
      expect(computeBackoff(5), const Duration(seconds: 64));
    });

    test('attempt 6 returns 128 seconds', () {
      expect(computeBackoff(6), const Duration(seconds: 128));
    });

    test('attempt 7 returns 256 seconds', () {
      expect(computeBackoff(7), const Duration(seconds: 256));
    });

    test('attempt 8 returns 512 seconds', () {
      expect(computeBackoff(8), const Duration(seconds: 512));
    });

    test('high attempts (9+) cap at 10 minutes', () {
      // 2 * 2^9 = 1024s = 17+ minutes > 10 minute cap
      expect(computeBackoff(9), const Duration(minutes: 10));
      expect(computeBackoff(10), const Duration(minutes: 10));
      expect(computeBackoff(20), const Duration(minutes: 10));
      expect(computeBackoff(100), const Duration(minutes: 10));
    });

    test('negative attempts return base backoff', () {
      expect(computeBackoff(-1), const Duration(seconds: 2));
      expect(computeBackoff(-100), const Duration(seconds: 2));
    });
  });

  group('computeNextEligibleAt', () {
    test('returns future time', () {
      final now = DateTime.now().toUtc();
      final nextEligible = computeNextEligibleAt(0);
      expect(nextEligible.isAfter(now), isTrue);
    });

    test('higher attempts means further in future', () {
      final eligible0 = computeNextEligibleAt(0);
      final eligible5 = computeNextEligibleAt(5);
      expect(eligible5.isAfter(eligible0), isTrue);
    });
  });

  group('isOpEligible', () {
    test('null nextEligibleAt is eligible', () {
      expect(isOpEligible(null), isTrue);
    });

    test('past time is eligible', () {
      final past = DateTime.now().subtract(const Duration(hours: 1));
      expect(isOpEligible(past), isTrue);
    });

    test('future time is not eligible', () {
      final future = DateTime.now().add(const Duration(hours: 1));
      expect(isOpEligible(future), isFalse);
    });
  });

  group('formatBackoff', () {
    test('formats seconds correctly', () {
      expect(formatBackoff(const Duration(seconds: 30)), '30s');
    });

    test('formats minutes and seconds', () {
      expect(formatBackoff(const Duration(minutes: 2, seconds: 30)), '2m 30s');
    });

    test('formats 10 minute ceiling', () {
      expect(formatBackoff(const Duration(minutes: 10)), '10m 0s');
    });
  });
}
