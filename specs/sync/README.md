# Sync Engine Specification

**Version:** 1.0.0  
**Last Updated:** November 22, 2025  
**Status:** Phase 1 - Design & Specification

---

## Overview

This directory contains the complete specification for Guardian Angel's production-grade, offline-first Sync Engine. The engine provides reliable, at-least-once delivery of local operations to the backend with idempotency guarantees, exponential backoff, and comprehensive error handling.

---

## Goals & Constraints

### Primary Goals

**Durability**
- All operations must survive app restarts and device reboots
- Persistent queue backed by encrypted Hive storage
- FIFO processing order guaranteed

**Safety**
- No duplicated side-effects via idempotency keys
- Single processor guarantee (persistent lock with heartbeat)
- Transactional operation state changes

**Responsiveness**
- Instant UI feedback via optimistic updates
- Background processing with rollback on failure
- User never blocks on network operations

**Resource Efficiency**
- Bounded memory usage (streaming processing)
- Battery-conscious retry scheduling
- Adaptive backoff reduces network waste

**Security**
- All operations include JWT authentication
- No secrets or PII in logs
- TLS 1.3 for all network traffic
- Secure error reporting with redaction

### Constraints

**Network Reliability**
- Assume intermittent connectivity
- Must handle offline → online transitions
- Graceful degradation during network issues

**Memory Limits**
- Process operations in batches (configurable)
- No unbounded in-memory queues
- Release resources after processing

**Battery Conservation**
- Exponential backoff reduces retry frequency
- Batch processing when possible
- Respect system power state

**Backend Compatibility**
- Standard HTTP/REST semantics
- Idempotency key support required
- Optional WebSocket/MQTT for real-time

---

## Architecture Components

### 1. Queue Processor
- **Location:** `lib/services/sync/queue_processor.dart`
- **Responsibility:** FIFO processing of pending operations
- **Features:**
  - Single active processor via persistent lock
  - Heartbeat mechanism for crash recovery
  - Configurable batch size and concurrency

### 2. API Client
- **Location:** `lib/services/sync/api_client.dart`
- **Responsibility:** HTTP communication with backend
- **Features:**
  - Standard request/response envelopes
  - Automatic auth token injection
  - Retry logic with exponential backoff
  - Error classification and mapping

### 3. Operation Router
- **Location:** `lib/services/sync/op_router.dart`
- **Responsibility:** Route operations to correct API endpoints
- **Features:**
  - Operation type → endpoint mapping
  - Payload transformation (local → wire format)
  - Response parsing and validation

### 4. Backoff Manager
- **Location:** `lib/services/sync/backoff_manager.dart`
- **Responsibility:** Calculate retry delays
- **Features:**
  - Exponential backoff with jitter
  - Respect Retry-After headers
  - Configurable limits and base delays

### 5. Idempotency Service
- **Location:** `lib/services/sync/idempotency_service.dart`
- **Responsibility:** Generate and track idempotency keys
- **Features:**
  - UUID v4 generation per operation
  - Success tracking to prevent re-sends
  - 24-hour deduplication window

### 6. Optimistic Update Manager
- **Location:** `lib/services/sync/optimistic_update_manager.dart`
- **Responsibility:** Handle UI optimistic updates and rollbacks
- **Features:**
  - Transaction token generation
  - Local state change tracking
  - Rollback on permanent failure

---

## Document Structure

### Core Specifications
- **[api_envelope.md](api_envelope.md)** - Request/response format standards
- **[error_mapping.md](error_mapping.md)** - HTTP status → exception mapping
- **[backoff_policy.md](backoff_policy.md)** - Retry delay calculation
- **[idempotency_policy.md](idempotency_policy.md)** - Deduplication strategy
- **[op_router.md](op_router.md)** - Operation routing and endpoints
- **[test_matrix.md](test_matrix.md)** - Comprehensive test plan

### Test Vectors
- **[test_vectors/](test_vectors/)** - JSON fixtures for testing
  - `pending_op_valid.json` - Valid operation
  - `pending_op_retry_after.json` - Operation with Retry-After
  - `pending_op_corrupt.json` - Malformed operation

---

## Key Design Decisions

### 1. Idempotency Strategy
**Decision:** Client-side UUID generation with backend deduplication

**Rationale:**
- Eliminates race conditions on client
- Simple server implementation (cache lookup)
- No distributed consensus needed

**Trade-offs:**
- Requires 24h server-side cache
- Duplicate detection is eventually consistent

### 2. Backoff Algorithm
**Decision:** Exponential with jitter (2^attempts * base * jitter)

**Rationale:**
- Reduces server load during outages
- Jitter prevents thundering herd
- Industry standard approach

**Trade-offs:**
- May delay operations longer than necessary
- Requires tuning for specific use cases

### 3. FIFO Processing
**Decision:** Strict FIFO order with single processor

**Rationale:**
- Predictable operation ordering
- Simple reasoning about state changes
- No reordering bugs

**Trade-offs:**
- Head-of-line blocking on stuck operations
- Cannot parallelize processing

**Mitigation:** Move permanently failed ops to failed_ops queue

### 4. Optimistic Updates
**Decision:** Transaction tokens with explicit rollback

**Rationale:**
- Instant UI feedback
- Clear rollback semantics
- Works with any UI framework

**Trade-offs:**
- Requires careful state management
- Rollback complexity in UI layer

### 5. Error Classification
**Decision:** Three-tier classification (transient, permanent, ambiguous)

**Rationale:**
- Clear retry vs. fail semantics
- Special handling for conflicts
- User-visible error messages

**Trade-offs:**
- Some errors difficult to classify
- May require server standardization

---

## Failure Modes & Recovery

### Scenario 1: Network Timeout
**Symptom:** HTTP request times out  
**Classification:** Transient  
**Action:** Retry with exponential backoff  
**User Impact:** None (transparent retry)

### Scenario 2: Server 500 Error
**Symptom:** Internal server error  
**Classification:** Transient  
**Action:** Retry with backoff (max 5 attempts)  
**User Impact:** None initially, failed_ops if exhausted

### Scenario 3: Invalid Payload (400)
**Symptom:** Bad request from server  
**Classification:** Permanent  
**Action:** Move to failed_ops, notify user  
**User Impact:** Error message, manual intervention

### Scenario 4: Auth Token Expired (401)
**Symptom:** Unauthorized response  
**Classification:** Special (refresh attempt)  
**Action:** Attempt token refresh, retry once  
**User Impact:** May require re-login

### Scenario 5: Rate Limit (429)
**Symptom:** Too many requests  
**Classification:** Transient  
**Action:** Respect Retry-After, then exponential backoff  
**User Impact:** Delayed processing

### Scenario 6: Conflict (409)
**Symptom:** Resource state conflict  
**Classification:** Ambiguous  
**Action:** Trigger reconciliation flow  
**User Impact:** Conflict resolution UI

### Scenario 7: App Crash Mid-Processing
**Symptom:** Operation in-flight when app crashes  
**Classification:** Recovery scenario  
**Action:** Stale lock takeover, idempotent retry  
**User Impact:** None (operation completes after restart)

### Scenario 8: Device Offline
**Symptom:** No network connectivity  
**Classification:** Environmental  
**Action:** Queue operations, process when online  
**User Impact:** Optimistic UI, sync when online

---

## Monitoring & Observability

### Metrics to Collect

**Queue Metrics**
- `sync.pending_ops.count` - Current queue depth
- `sync.pending_ops.age_p50` - Median operation age
- `sync.pending_ops.age_p99` - 99th percentile age

**Processing Metrics**
- `sync.processed.count` - Total operations processed
- `sync.processed.success` - Successful operations
- `sync.processed.failed` - Failed operations
- `sync.process_time.avg` - Average processing time
- `sync.process_time.p99` - 99th percentile

**Retry Metrics**
- `sync.retries.count` - Total retry attempts
- `sync.backoff.duration.avg` - Average backoff delay
- `sync.retry_after.count` - Retry-After header respect

**Error Metrics**
- `sync.errors.transient` - Transient error count
- `sync.errors.permanent` - Permanent error count
- `sync.errors.ambiguous` - Conflict error count
- `sync.errors.network` - Network error count

**System Metrics**
- `sync.processor.active` - Processor running flag
- `sync.lock.takeover.count` - Stale lock takeovers
- `sync.memory.usage` - Memory footprint

### Logging Guidelines

**What to Log**
- Operation lifecycle (enqueue, process, complete, fail)
- Error details (code, message, classification)
- Backoff calculations (attempts, delay)
- Lock acquisition and release
- Performance measurements

**What NOT to Log**
- User PII (emails, names, addresses)
- Passwords or tokens
- Full operation payloads (may contain sensitive data)
- Stack traces in production (use error reporting service)

**Log Levels**
- `ERROR` - Permanent failures, system errors
- `WARN` - Transient failures, retry events
- `INFO` - Operation lifecycle, lock events
- `DEBUG` - Detailed flow, payload summaries (dev only)

### Tracing

**Trace ID Propagation**
- Generate UUID v4 per operation
- Include in `Trace-Id` header
- Propagate through all backend calls
- Link to frontend logs

**Distributed Tracing**
- Support OpenTelemetry spans
- Track end-to-end operation latency
- Identify bottlenecks and slow paths

---

## Security Considerations

### Authentication
- JWT tokens stored in secure storage
- Automatic token refresh before expiry
- Graceful handling of auth failures

### Authorization
- Operation-level permission checks on backend
- No client-side authorization logic
- Clear error messages for insufficient permissions

### Data Protection
- All network traffic over TLS 1.3
- Sensitive data encrypted at rest (Hive)
- PII redaction in logs and telemetry

### Attack Surface
- Rate limiting on client side (prevent abuse)
- Input validation before serialization
- No SQL injection vectors (Hive is NoSQL)
- CSRF protection via idempotency keys

---

## Performance Targets

### Latency
- **Enqueue operation:** < 50ms (p99)
- **Process operation (success):** < 2s (p95)
- **Process operation (retry):** < 5s including backoff (p95)

### Throughput
- **Operations per second:** 10+ (single processor)
- **Queue depth:** Handle 10,000+ pending ops
- **Concurrent operations:** 1 (FIFO), expandable to 3-5

### Resource Usage
- **Memory:** < 50MB for queue processing
- **Battery:** < 2% per hour of active syncing
- **Storage:** < 10MB for queue metadata

### Reliability
- **Success rate:** 99.9% (excluding permanent failures)
- **Data durability:** 100% (no operation loss)
- **Recovery time:** < 5s after crash

---

## Implementation Phases

### Phase 1: Design & Specification (Current)
- ✅ Define API contracts and error mapping
- ✅ Document backoff and idempotency policies
- ✅ Create test matrix and vectors
- ✅ Establish monitoring strategy

### Phase 2: Core Implementation
- Implement API client with error handling
- Build queue processor with FIFO semantics
- Create backoff manager with jitter
- Implement persistent lock mechanism

### Phase 3: Advanced Features
- Add optimistic update manager
- Implement operation router
- Build reconciliation flow for conflicts
- Add telemetry and logging

### Phase 4: Testing & Validation
- Unit tests for all components
- Integration tests with mock backend
- Fault injection tests
- Performance benchmarking

### Phase 5: Production Hardening
- Load testing with 10k+ operations
- Crash recovery validation
- Security audit
- Documentation and runbook

---

## References

### External Standards
- [RFC 7231](https://tools.ietf.org/html/rfc7231) - HTTP/1.1 Semantics
- [RFC 4122](https://tools.ietf.org/html/rfc4122) - UUID Specification
- [RFC 6585](https://tools.ietf.org/html/rfc6585) - HTTP Status Code 429

### Internal Documents
- [Phase 1 Completion Status](../../docs/PHASE_1_COMPLETION_STATUS.md)
- [Persistence Layer Documentation](../../docs/persistence.md)
- [Data Models Reference](../../docs/models.md)

### Related Systems
- Hive Persistence Layer
- Authentication Service
- Telemetry Service
- Audit Log Service

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-11-22 | Initial specification for Phase 1 |

---

## Approval

**Author:** Guardian Angel Team  
**Reviewers:** TBD  
**Status:** Draft (Phase 1)
