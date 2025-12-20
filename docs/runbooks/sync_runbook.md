# Sync Engine Operational Runbook

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Monitoring & Alerts](#monitoring--alerts)
4. [Common Operations](#common-operations)
5. [Troubleshooting](#troubleshooting)
6. [Emergency Procedures](#emergency-procedures)
7. [Maintenance](#maintenance)
8. [Performance Tuning](#performance-tuning)

---

## Overview

The Guardian Angel Sync Engine is a production-grade offline-first synchronization system that processes operations in FIFO order with:
- Automatic retry with exponential backoff
- Circuit breaker protection
- Conflict resolution (409 handling)
- Optimistic UI updates with rollback
- Comprehensive telemetry

**Key Components:**
- `SyncEngine` - Main orchestrator
- `PendingQueueService` - FIFO queue management
- `ProcessingLock` - Single processor guarantee
- `CircuitBreaker` - API protection
- `Reconciler` - Conflict resolution
- `ProductionMetrics` - Telemetry & alerting

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    SyncEngine                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │ Circuit      │  │ Processing   │  │ Optimistic   │ │
│  │ Breaker      │  │ Lock         │  │ Store        │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │ Reconciler   │  │ Batch        │  │ Metrics      │ │
│  │              │  │ Coalescer    │  │              │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────┘
                            │
            ┌───────────────┼───────────────┐
            │               │               │
    ┌───────▼──────┐ ┌──────▼─────┐ ┌──────▼─────┐
    │  API Client  │ │ Real-time  │ │   Hive     │
    │    (HTTP)    │ │ (WebSocket)│ │ (Storage)  │
    └──────────────┘ └────────────┘ └────────────┘
```

**Data Flow:**
1. User action → Operation enqueued
2. SyncEngine picks oldest operation
3. Circuit breaker checks health
4. API call with idempotency key
5. On success: mark processed, commit optimistic
6. On failure: retry with backoff or reconcile
7. Metrics recorded throughout

---

## Monitoring & Alerts

### Key Metrics

**Gauges (current values):**
- `pending_ops_gauge` - Current pending operations
- `active_processors_gauge` - Number of active processors

**Counters (cumulative):**
- `processed_ops_total` - Successfully processed operations
- `failed_ops_total` - Failed operations
- `backoff_events_total` - Backoff delays applied
- `circuit_tripped_total` - Circuit breaker trips
- `retries_total` - Retry attempts
- `conflicts_resolved_total` - 409 conflicts resolved

**Histograms:**
- `avg_processing_time_ms` - Processing latency distribution
  - Buckets: 0-10ms, 10-50ms, 50-100ms, 100-500ms, 500-1000ms, 1000ms+

**Health Metrics:**
- `success_rate_percent` - Overall success rate
- `failure_rate_per_min` - Recent failure rate
- `network_health_score` - Network reliability (0-100)

### Alert Thresholds

| Alert | Threshold | Severity | Action |
|-------|-----------|----------|--------|
| `failed_ops_rate > 10/min` | 10 failures/min | **CRITICAL** | Page on-call |
| `pending_ops_gauge > 1000` for 1h | 1000 ops | **HIGH** | Investigate |
| `circuit_tripped_total > 50/day` | 50 trips/day | **MEDIUM** | Review logs |
| `p95_latency > 5000ms` | 5 seconds | **MEDIUM** | Check network |
| `success_rate < 90%` | 90% | **HIGH** | Page on-call |

### Monitoring Setup

**Prometheus Export:**
```bash
# Metrics are exported in Prometheus format
GET /metrics

# Example output:
# pending_ops_gauge 42
# processed_ops_total 15234
# failed_ops_total 12
```

**Grafana Dashboard:**
Create dashboard with panels for:
1. Operations Rate (processed vs failed)
2. Queue Depth Over Time
3. Processing Latency (P50, P95, P99)
4. Success Rate
5. Circuit Breaker Status
6. Active Alerts

---

## Common Operations

### 1. Check Queue Status

**Via Admin Console:**
```dart
// Navigate to Admin Console screen
Navigator.push(context, MaterialPageRoute(
  builder: (_) => AdminConsoleScreen(),
));
```

**Via CLI:**
```bash
# Export pending operations
dart run scripts/export_pending_ops.dart --out status.csv

# Count operations
wc -l status.csv
```

**Via Metrics API:**
```dart
final metrics = syncEngine.getMetrics();
print('Pending: ${metrics['gauges']['pending_ops']}');
print('Failed: ${metrics['counters']['failed_ops_total']}');
```

### 2. Export Operations for Analysis

**Export to CSV:**
```bash
dart run scripts/export_pending_ops.dart \
  --out pending_ops_$(date +%Y%m%d_%H%M%S).csv \
  --format csv
```

**Export to JSON:**
```bash
dart run scripts/export_pending_ops.dart \
  --out pending_ops_$(date +%Y%m%d_%H%M%S).json \
  --format json
```

**Export failed operations only:**
```bash
dart run scripts/export_pending_ops.dart \
  --failed-only \
  --out failed_ops.csv
```

### 3. Rebuild Queue Index

**When to rebuild:**
- Index corruption detected
- After database migration
- Queue count doesn't match index

**Procedure:**
```dart
// Via Admin Console
// Tap "Rebuild Index" button

// Or via code
final queue = ref.read(pendingQueueProvider);
await queue.rebuildIndex();
print('Index rebuilt successfully');
```

### 4. Force Release Processing Lock

**When to force release:**
- Lock stuck for >10 minutes
- Processor crashed without cleanup
- After forced app termination

**Procedure:**
```dart
// Via Admin Console
// Tap "Force Release Lock" button

// Or via code
final lock = ref.read(processingLockProvider);
await lock.forceRelease();
print('Lock released');
```

**⚠️ WARNING:** Only force release when certain no other processor is running!

### 5. Retry Failed Operations

**Retry all failed:**
```dart
// Via Admin Console
// Tap "Retry All Failed" button

// Or via code
final queue = ref.read(pendingQueueProvider);
final failedBox = await Hive.openBox('failed_ops');

for (var key in failedBox.keys) {
  final failedData = failedBox.get(key);
  final op = PendingOp.fromJson(failedData['operation']);
  await queue.enqueue(op);
}

await failedBox.clear();
print('${failedBox.length} operations re-enqueued');
```

**Retry specific operation:**
```dart
final failedBox = await Hive.openBox('failed_ops');
final failedData = failedBox.get(operationId);
final op = PendingOp.fromJson(failedData['operation']);
await queue.enqueue(op);
await failedBox.delete(operationId);
```

---

## Troubleshooting

### Issue: High Failed Operations Rate

**Symptoms:**
- `failed_ops_rate` alert triggered
- Many operations in failed_ops box
- User complaints about sync failures

**Diagnosis:**
1. Check metrics dashboard for error patterns
2. Export failed operations: `dart run scripts/export_pending_ops.dart --failed-only`
3. Analyze error reasons in export
4. Check server logs for corresponding errors

**Common Causes:**
- Network issues (transient)
- Server downtime/errors (5xx)
- Auth token expired
- Validation errors (4xx)
- Resource conflicts (409)

**Resolution:**
```bash
# 1. Check failure reasons
dart run scripts/export_pending_ops.dart --failed-only --out failed.csv
grep -E "auth|401|403" failed.csv

# 2. If auth issues, refresh tokens
# Let app attempt auto-refresh or manually trigger

# 3. If validation errors, investigate root cause
grep -E "400|422" failed.csv

# 4. If server errors, wait for recovery then retry
dart run scripts/export_pending_ops.dart --failed-only
# Review and manually retry after server fix
```

### Issue: Processing Lock Stuck

**Symptoms:**
- Queue not processing
- `pending_ops_gauge` increasing
- Lock heartbeat timestamp old (>10min)

**Diagnosis:**
```dart
// Check lock status
final lockBox = await Hive.openBox('processing_lock');
final lockData = lockBox.get('processing_lock');
print('Lock owner: ${lockData['runner_id']}');
print('Last heartbeat: ${lockData['last_heartbeat']}');

// Calculate stale duration
final lastHeartbeat = DateTime.parse(lockData['last_heartbeat']);
final staleMinutes = DateTime.now().difference(lastHeartbeat).inMinutes;
print('Stale for: $staleMinutes minutes');
```

**Resolution:**
```dart
// If stale > 10 minutes, force release
if (staleMinutes > 10) {
  await lockBox.put('processing_lock', null);
  print('Lock forcibly released');
  
  // Restart sync engine
  await syncEngine.start();
}
```

### Issue: Circuit Breaker Constantly Tripping

**Symptoms:**
- `circuit_tripped_total` increasing rapidly
- Operations delayed
- Processing paused

**Diagnosis:**
```dart
final breaker = ref.read(circuitBreakerProvider);
print('Is tripped: ${breaker.isTripped()}');
print('Cooldown remaining: ${breaker.getCooldownRemaining()}');
```

**Common Causes:**
- Server experiencing 5xx errors
- Network instability
- DDoS attack on backend
- Backend deployment

**Resolution:**
```bash
# 1. Check server health
curl -v https://api.example.com/health

# 2. Review server logs for 5xx patterns
# Look for spike in errors

# 3. If server is healthy, investigate network
ping api.example.com
traceroute api.example.com

# 4. Wait for circuit breaker cooldown (default: 1 min)
# Operations will resume automatically

# 5. If server is down, coordinate with backend team
# Export pending operations for later retry
dart run scripts/export_pending_ops.dart --out backup.csv
```

### Issue: High Queue Depth

**Symptoms:**
- `pending_ops_gauge > 1000` for extended period
- Slow sync progress
- User actions not syncing

**Diagnosis:**
```bash
# Export operations
dart run scripts/export_pending_ops.dart --out queue.csv

# Analyze operation types
cut -d',' -f2 queue.csv | sort | uniq -c

# Check for duplicates
cut -d',' -f10 queue.csv | sort | uniq -d
```

**Common Causes:**
- Network offline for extended period
- Batch of operations created (e.g., import)
- Circuit breaker tripped repeatedly
- Processing rate < enqueue rate

**Resolution:**
```dart
// 1. Check if coalescing is working
final metrics = syncEngine.getMetrics();
// Compare enqueued vs processed

// 2. Enable batch coalescing if not already
final coalescer = ref.read(batchCoalescerProvider);
// Coalescer should be enabled by default

// 3. If legitimate backlog, be patient
// Monitor processing rate
// Typical rate: 50-100 ops/sec with 50ms API latency

// 4. If stuck, check for deadlock or infinite retry
// Review logs for repeating operation IDs
```

### Issue: Duplicate Operations Processed

**Symptoms:**
- Server side effects duplicated
- Idempotency not working
- User reports duplicate actions

**Diagnosis:**
```bash
# Check for operations with same idempotency key
dart run scripts/export_pending_ops.dart --out ops.csv
cut -d',' -f9 ops.csv | sort | uniq -d

# Check server logs for duplicate requests
# Look for same Idempotency-Key in multiple requests
```

**Common Causes:**
- Idempotency key not sent
- Server not enforcing idempotency
- Race condition in processing lock
- Operation re-enqueued before marking processed

**Resolution:**
```dart
// 1. Verify idempotency keys are generated
final op = PendingOp(...);
assert(op.idempotencyKey.isNotEmpty);

// 2. Check server idempotency implementation
// Verify server stores and checks idempotency keys

// 3. Review processing lock logic
// Ensure only one processor active

// 4. Add server-side deduplication
// Track operation IDs and reject duplicates
```

---

## Emergency Procedures

### Emergency: Mass 5xx Errors

**Impact:** All operations failing, circuit breaker tripping

**Immediate Actions:**
1. **Acknowledge alert** - Page received
2. **Check server status** - Is backend down?
3. **Export pending operations** - Backup before cleanup
4. **Stop sync engine** - Prevent more failures
5. **Coordinate with backend team** - ETA for fix?

**Step-by-Step:**
```bash
# 1. Export all pending operations
dart run scripts/export_pending_ops.dart \
  --out emergency_backup_$(date +%Y%m%d_%H%M%S).csv

# 2. Stop sync engine
# Via admin console or code:
await syncEngine.stop();

# 3. Wait for backend recovery
# Monitor server health endpoint

# 4. Once backend recovered, restart
await syncEngine.start();

# 5. Monitor metrics for recovery
# Watch success_rate and pending_ops_gauge
```

### Emergency: Database Corruption

**Impact:** Queue operations failing, app crashes

**Immediate Actions:**
1. **Export data if possible** - Backup before repair
2. **Close all Hive boxes**
3. **Rebuild index**
4. **If severe, delete and reinit**

**Step-by-Step:**
```dart
// 1. Try export first
try {
  await exportPendingOps();
} catch (e) {
  print('Export failed: $e');
}

// 2. Close boxes
await Hive.close();

// 3. Attempt repair
await Hive.init(appDirectory);
Hive.registerAdapter(PendingOpAdapter());

final pendingBox = await Hive.openBox<PendingOp>('pending_operations');
final indexBox = await Hive.openBox<String>('pending_index');

// 4. Rebuild index
final queue = PendingQueueService(
  pendingBox: pendingBox,
  indexBox: indexBox,
  failedBox: failedBox,
);
await queue.rebuildIndex();

// 5. If still failing, nuclear option
await Hive.deleteBoxFromDisk('pending_operations');
await Hive.deleteBoxFromDisk('pending_index');
await Hive.deleteBoxFromDisk('failed_ops');

// Reinitialize (data lost)
// User will need to retry actions
```

### Emergency: Processing Lock Deadlock

**Impact:** Queue frozen, operations not processing

**Immediate Actions:**
1. **Check lock status** - Who owns it?
2. **Verify process alive** - Is owner running?
3. **Force release if stale** - >10 min no heartbeat
4. **Restart processor**

**Step-by-Step:**
```dart
// 1. Inspect lock
final lockBox = await Hive.openBox('processing_lock');
final lockData = lockBox.get('processing_lock');

if (lockData != null) {
  final lastHeartbeat = DateTime.parse(lockData['last_heartbeat']);
  final staleMinutes = DateTime.now().difference(lastHeartbeat).inMinutes;
  
  print('Lock owner: ${lockData['runner_id']}');
  print('Stale for: $staleMinutes minutes');
  
  // 2. Force release if stale
  if (staleMinutes > 10) {
    await lockBox.clear();
    print('Lock forcibly released');
    
    // Record in metrics
    metrics.recordLockTakeover();
  }
}

// 3. Restart engine
await syncEngine.start();

// 4. Monitor for recovery
await Future.delayed(Duration(seconds: 30));
final queueCount = await queue.count();
print('Queue processing resumed, $queueCount pending');
```

---

## Maintenance

### Routine Maintenance Tasks

#### Daily
- [ ] Review metrics dashboard
- [ ] Check for active alerts
- [ ] Monitor queue depth trends
- [ ] Review error logs

#### Weekly
- [ ] Export and archive failed operations
- [ ] Analyze performance trends
- [ ] Review circuit breaker trip count
- [ ] Update alert thresholds if needed

#### Monthly
- [ ] Full metrics review
- [ ] Performance regression testing
- [ ] Database compaction
- [ ] Security audit

### Database Maintenance

**Compact Hive boxes:**
```dart
// Periodically compact to reclaim space
final pendingBox = await Hive.openBox<PendingOp>('pending_operations');
await pendingBox.compact();

final failedBox = await Hive.openBox('failed_ops');
await failedBox.compact();
```

**Archive old failed operations:**
```bash
# Export failed ops older than 30 days
dart run scripts/export_pending_ops.dart \
  --failed-only \
  --out archive_$(date +%Y%m%d).csv

# Then clear from database (via admin console)
```

### Performance Testing

**Run load tests monthly:**
```bash
# Run full load test suite
flutter run tool/stress/load_test.dart

# Expected results:
# - Enqueue: >1000 ops/sec
# - Processing: >50 ops/sec (with 50ms API latency)
# - Memory: <10 KB per operation
# - P95 latency: <500ms
```

**Stress test under failure:**
```dart
// Simulate 5xx storm
// Verify circuit breaker trips at threshold
// Confirm recovery after cooldown
```

---

## Performance Tuning

### Optimizing Enqueue Throughput

**Enable batch coalescing:**
```dart
final coalescer = BatchCoalescer(pendingBox, indexBox);
await syncEngine.enqueue(op); // Auto-coalesces
```

**Batch operations:**
```dart
// Instead of:
for (var item in items) {
  await queue.enqueue(createOp(item));
}

// Use batch:
final batch = items.map((item) => createOp(item)).toList();
for (var op in batch) {
  queue.enqueue(op); // Remove await for non-critical
}
```

### Optimizing Processing Speed

**Tune backoff policy:**
```dart
final backoff = BackoffPolicy(
  initialDelay: Duration(milliseconds: 500), // Faster initial retry
  maxDelay: Duration(minutes: 5),
  maxAttempts: 10,
);
```

**Adjust circuit breaker:**
```dart
final breaker = CircuitBreaker(
  failureThreshold: 15, // Allow more failures before trip
  window: Duration(seconds: 30),
  cooldown: Duration(seconds: 30), // Shorter cooldown
);
```

### Reducing Memory Usage

**Limit in-memory samples:**
```dart
final metrics = ProductionMetrics(
  maxLatencySamples: 500, // Default: 1000
  maxLogRetention: 50, // Default: 100
);
```

**Compact boxes regularly:**
```dart
Timer.periodic(Duration(hours: 24), (_) async {
  await pendingBox.compact();
  await indexBox.compact();
});
```

### Network Optimization

**Enable HTTP/2:**
```dart
final apiClient = ApiClient(
  baseUrl: 'https://api.example.com',
  httpVersion: HttpVersion.http2, // If backend supports
);
```

**Use WebSocket for real-time:**
```dart
final realtime = RealtimeService(url: 'wss://api.example.com/ws');
// Reduces polling overhead by 90%
```

---

## Security

### PII Redaction

All exports automatically redact:
- Email addresses → `[REDACTED_EMAIL]`
- Phone numbers → `[REDACTED_PHONE]`
- Credit cards → `[REDACTED_CC]`
- Password fields → `[REDACTED]`

**Verify redaction:**
```bash
dart run scripts/export_pending_ops.dart --out test.csv
grep -E "REDACTED" test.csv
```

### Token Management

**Secure token storage:**
```dart
final authService = AuthService(
  secureStorage: FlutterSecureStorage(),
);
// Tokens stored in keychain/keystore
```

**Token refresh:**
```dart
// Automatic refresh on 401
// Manual refresh:
final refreshed = await authService.tryRefresh();
if (!refreshed) {
  // Logout user
}
```

### Certificate Pinning

**Enable for production:**
```dart
final apiClient = ApiClient(
  baseUrl: 'https://api.example.com',
  certificatePinning: true,
  pinnedCertificates: [
    'sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
  ],
);
```

---

## Appendix

### Useful Commands

```bash
# Check queue status
dart run scripts/export_pending_ops.dart --out - | wc -l

# Monitor real-time
watch -n 5 'dart run scripts/export_pending_ops.dart --out - | wc -l'

# Find stuck operations
dart run scripts/export_pending_ops.dart --out ops.csv
awk -F',' '$4 > 10 {print}' ops.csv

# Analyze error patterns
dart run scripts/export_pending_ops.dart --failed-only --out failed.csv
cut -d',' -f8 failed.csv | sort | uniq -c | sort -rn
```

### Contact Information

**On-Call Engineer:** [pager-duty-link]
**Slack Channel:** #sync-engine-alerts
**Runbook Updates:** [git-repo-link]
**Dashboard:** [grafana-link]

---

**Last Updated:** November 22, 2025
**Version:** 4.0.0
**Maintained By:** Platform Team
