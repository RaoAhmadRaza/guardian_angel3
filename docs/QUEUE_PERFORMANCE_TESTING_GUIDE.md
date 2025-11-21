# Queue Performance Testing - Quick Reference

## Running Performance Tests

```bash
# Run full performance test suite
flutter test test/performance/queue_performance_test.dart --timeout=120s

# Run with verbose output
flutter test test/performance/queue_performance_test.dart --timeout=120s -r expanded
```

## Test Coverage

### 14 Comprehensive Tests

1. **Baseline: 1,000 operations** - Validates basic performance
2. **Medium load: 5,000 operations** - Tests typical workload
3. **Heavy load: 10,000 operations** - Tests high-volume scenarios
4. **Stress test: 25,000 operations** - Identifies breaking points
5. **Extreme load: 50,000 operations** - Maximum capacity testing
6. **Enqueue pattern comparison** - Batched vs individual operations
7. **Query scaling** - getOldestPendingOp(N) with various N
8. **Integrity check performance** - Validation time at scale
9. **Memory usage tracking** - Approximate memory consumption
10. **Sorting/Rebuild performance** - Index rebuild timing
11. **Concurrent access stress test** - Multi-writer safety
12. **Delete pattern performance** - Bulk vs individual deletes
13. **Mixed workload simulation** - Realistic usage patterns
14. **Performance report generation** - Comprehensive analysis

## Key Performance Metrics

### Baseline Results (10K Operations)

| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| Enqueue Time | < 500ms | 90ms | ✅ 5.5x better |
| Sort/Rebuild | < 500ms | 3ms | ✅ 166x better |
| Query (10 oldest) | < 10ms | 2ms | ✅ 5x better |
| Throughput | > 10K ops/sec | 111K ops/sec | ✅ 11x better |

### Scalability

- **1K → 10K:** 7.64x time increase (near-linear)
- **10K → 50K:** Performance remains excellent
- **Batching benefit:** 22x faster for bulk operations

## Quick Analysis Guide

### Interpreting Results

#### ✅ Good Performance Indicators

- Enqueue time < 1 second for 10K operations
- Sort time < 500ms for 10K operations
- Query time < 100ms regardless of result size
- Near-linear scaling (8-12x for 10x data)

#### ⚠️ Warning Signs

- Enqueue time > 5 seconds for 10K operations
- Sort time > 2 seconds for 10K operations
- Query time > 500ms for any result size
- Sub-linear scaling (> 20x for 10x data)

#### 🔴 Critical Issues

- Enqueue time > 30 seconds for 10K operations
- Any operation timing out (> 120 seconds)
- Data corruption (integrity check failures)
- Memory leaks (RSS growth without bound)

## Optimization Recommendations

### Current Status: ✅ Optimal

Based on performance testing, **no optimizations needed**.

### If Performance Degrades

#### Queue Size > 50K Operations

```dart
// Consider chunked storage by time range
final hourBox = getBoxForHour(DateTime.now());
await hourBox.put(op.opId, op);
```

#### Query Time > 100ms

```dart
// Maintain separate sorted index
class OpIndex {
  final DateTime timestamp;
  final String opId;
}
```

#### Processing Rate < Required Throughput

```dart
// Use batched operations exclusively
final batch = <String, PendingOp>{
  for (final op in operations) op.opId: op,
};
await box.putAll(batch);
```

## Monitoring in Production

### Key Metrics to Track

```dart
// Queue size
telemetryService.gauge('queue.pending_ops.size', pendingBox.length);

// Processing rate
telemetryService.counter('queue.operations_processed');

// Query performance
final start = DateTime.now();
final oldest = await getOldestOps(10);
final timeMs = DateTime.now().difference(start).inMilliseconds;
telemetryService.histogram('queue.query_time_ms', timeMs);
```

### Alert Thresholds

- **Queue size > 10,000:** Investigate processing bottleneck
- **Average query time > 100ms:** Check for data issues
- **Failed ops > 1,000:** Backend/network problems

## Test Suite Architecture

### Test Structure

```dart
group('Queue Performance Tests', () {
  // Baseline tests (1K - 50K operations)
  // Pattern comparison tests
  // Scaling analysis tests
  // Stress tests
});

group('Performance Recommendations', () {
  // Comprehensive report generation
  // Analysis and recommendations
});
```

### Helper Functions

- `_runPerformanceTest()` - Execute full test with all metrics
- `_bulkEnqueue()` - Efficiently enqueue N operations
- `_generatePendingOp()` - Create realistic test data
- `_getOldestPendingOps()` - Query N oldest operations
- `_rebuildIndex()` - Sort all operations
- `_verifyIntegrity()` - Check for duplicates and invalid data
- `_printMetrics()` - Format and display results

## Extending the Test Suite

### Adding New Test Scenarios

```dart
test('Custom workload test', () async {
  // Your test logic here
  final metrics = await _runPerformanceTest(pendingBox, operationCount: 15000);
  _printMetrics('Custom Test', metrics);
  
  // Add assertions
  expect(metrics.enqueueTimeMs, lessThan(300));
});
```

### Adding New Metrics

```dart
class PerformanceMetrics {
  // Add your metric
  final int customMetricMs;
  
  PerformanceMetrics({
    // ... existing fields
    required this.customMetricMs,
  });
}
```

## Benchmarking Other Operations

### Template for Custom Benchmarks

```dart
test('Custom operation benchmark', () async {
  await _bulkEnqueue(pendingBox, 10000);
  
  final start = DateTime.now();
  // Your operation here
  final timeMs = DateTime.now().difference(start).inMilliseconds;
  
  print('Custom operation: ${timeMs}ms');
  expect(timeMs, lessThan(yourThreshold));
});
```

## Troubleshooting

### Test Timeouts

If tests timeout (> 120 seconds):

```bash
# Increase timeout
flutter test test/performance/queue_performance_test.dart --timeout=300s

# Or reduce operation count in test
```

### Memory Issues

If tests crash with OOM:

```bash
# Run tests individually
flutter test test/performance/queue_performance_test.dart --name "Baseline"
```

### Inconsistent Results

Run tests multiple times to establish baseline:

```bash
for i in {1..5}; do
  echo "Run $i"
  flutter test test/performance/queue_performance_test.dart --timeout=120s
done
```

## CI/CD Integration

### Running in CI Pipeline

```yaml
# .github/workflows/performance.yml
name: Performance Tests

on:
  push:
    branches: [main]
  schedule:
    - cron: '0 0 * * 0'  # Weekly

jobs:
  performance:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: subosito/flutter-action@v2
      - run: flutter test test/performance/queue_performance_test.dart --timeout=120s
```

### Performance Regression Detection

```bash
# Store baseline results
flutter test test/performance/queue_performance_test.dart > baseline.txt

# Compare against baseline in CI
flutter test test/performance/queue_performance_test.dart > current.txt
# Add script to compare metrics and fail if regression > 20%
```

## Related Documentation

- [Full Performance Analysis Report](./QUEUE_PERFORMANCE_ANALYSIS.md)
- [Lock Protocol Documentation](./LOCK_PROTOCOL.md)
- [Transaction Protocol Documentation](./TRANSACTION_PROTOCOL.md)

---

**Last Updated:** January 18, 2024  
**Test Version:** 1.0  
**Maintained By:** Guardian Angel Development Team
