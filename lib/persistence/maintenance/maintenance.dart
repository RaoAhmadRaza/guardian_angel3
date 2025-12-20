/// Persistence Maintenance Module
///
/// Contains scheduled maintenance tasks for long-term data health:
/// - Automatic compaction with battery awareness
/// - TTL-based cleanup
library;

export 'auto_compaction_scheduler.dart';
