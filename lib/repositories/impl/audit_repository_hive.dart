/// AuditRepositoryHive - Hive implementation of AuditRepository.
///
/// Part of PHASE 2: Backend is the only source of truth.
/// Updated in PHASE 1 BLOCKER FIX: HiveError handling.
///
/// Data Flow:
/// UI → auditLogProvider → AuditRepositoryHive → BoxAccessor.auditLogs() → Hive
library;

import 'package:hive/hive.dart';
import '../../models/audit_log_record.dart';
import '../../persistence/box_registry.dart';
import '../../persistence/errors/errors.dart';
import '../../persistence/wrappers/box_accessor.dart';
import '../audit_repository.dart';

/// Hive-backed implementation of AuditRepository.
class AuditRepositoryHive implements AuditRepository {
  final BoxAccessor _boxAccessor;

  AuditRepositoryHive({BoxAccessor? boxAccessor})
      : _boxAccessor = boxAccessor ?? BoxAccessor();

  Box<AuditLogRecord> get _box => _boxAccessor.auditLogs();

  String _generateKey() =>
      'audit_${DateTime.now().millisecondsSinceEpoch}_${_box.length}';

  @override
  Stream<List<AuditLogRecord>> watchAll() async* {
    // Emit current state immediately
    yield _getSortedLogs();
    // Then emit on every change
    yield* _box.watch().map((_) => _getSortedLogs());
  }

  List<AuditLogRecord> _getSortedLogs() {
    return _box.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  @override
  Stream<List<AuditLogRecord>> watchForActor(String actor) async* {
    List<AuditLogRecord> _filter() => _box.values
        .where((r) => r.actor == actor)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    yield _filter();
    yield* _box.watch().map((_) => _filter());
  }

  @override
  Future<List<AuditLogRecord>> getAll() async {
    return _getSortedLogs();
  }

  @override
  Future<List<AuditLogRecord>> getForActor(String actor) async {
    return _box.values.where((r) => r.actor == actor).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  @override
  Future<List<AuditLogRecord>> getByType(String type) async {
    return _box.values.where((r) => r.type == type).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  @override
  Future<void> log(AuditLogRecord record) async {
    // PHASE 1 BLOCKER FIX: Safe HiveError handling
    final result = await SafeBoxOps.put(
      _box,
      _generateKey(),
      record,
      boxName: BoxRegistry.auditLogsBox,
    );
    if (result.isFailure) throw result.error!;
  }

  @override
  Future<int> deleteOlderThan(DateTime date) async {
    final toDelete = <dynamic>[];
    for (final entry in _box.toMap().entries) {
      if (entry.value.timestamp.isBefore(date)) {
        toDelete.add(entry.key);
      }
    }
    final result = await SafeBoxOps.deleteAll(
      _box,
      toDelete,
      boxName: BoxRegistry.auditLogsBox,
    );
    if (result.isFailure) throw result.error!;
    return toDelete.length;
  }

  @override
  Future<List<AuditLogRecord>> getInDateRange(
    DateTime start,
    DateTime end,
  ) async {
    return _box.values
        .where((r) =>
            r.timestamp.isAfter(start) && r.timestamp.isBefore(end))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  @override
  Future<int> getCount() async {
    return _box.length;
  }

  @override
  Future<void> clearAll() async {
    final result = await SafeBoxOps.clear(
      _box,
      boxName: BoxRegistry.auditLogsBox,
    );
    if (result.isFailure) throw result.error!;
  }
}
