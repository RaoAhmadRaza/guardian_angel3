import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_angel_fyp/services/telemetry_service.dart';

void main() {
  test('counters and gauges update', () {
    final t = TelemetryService.I;
    t.increment('processed_ops.count');
    t.increment('processed_ops.count', 2);
    t.gauge('pending_ops.count', 5);
    final snap = t.snapshot();
    expect(snap['counters']['processed_ops.count'], 3);
    expect(snap['gauges']['pending_ops.count'], 5);
  });

  test('timer records summary stats', () async {
    final t = TelemetryService.I;
    await t.timeAsync('migration.duration_ms', () async {
      await Future.delayed(const Duration(milliseconds: 20));
      return true;
    });
    final snap = t.snapshot();
    final timers = snap['timers'] as Map;
    expect(timers.containsKey('migration.duration_ms'), isTrue);
    final summary = timers['migration.duration_ms'] as Map;
    expect(summary['count'] > 0, isTrue);
    expect(summary['max_ms'] >= summary['min_ms'], isTrue);
  });
}