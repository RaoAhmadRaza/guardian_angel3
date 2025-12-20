/// SessionRepositoryHive - Hive implementation of SessionRepository.
///
/// Part of PHASE 2: Backend is the only source of truth.
/// Updated in PHASE 1 BLOCKER FIX: HiveError handling.
///
/// Data Flow:
/// UI → sessionProvider → SessionRepositoryHive → BoxAccessor.sessions() → Hive
library;

import 'package:hive/hive.dart';
import '../../models/session_model.dart';
import '../../persistence/box_registry.dart';
import '../../persistence/errors/errors.dart';
import '../../persistence/wrappers/box_accessor.dart';
import '../session_repository.dart';

/// Hive-backed implementation of SessionRepository.
class SessionRepositoryHive implements SessionRepository {
  static const String _currentSessionKey = 'current_session';
  final BoxAccessor _boxAccessor;

  SessionRepositoryHive({BoxAccessor? boxAccessor})
      : _boxAccessor = boxAccessor ?? BoxAccessor();

  Box get _box => _boxAccessor.sessions();

  @override
  Stream<SessionModel?> watchCurrent() async* {
    // Emit current state immediately
    yield _getCurrentSync();
    // Then emit on every change
    yield* _box.watch(key: _currentSessionKey).map((_) => _getCurrentSync());
  }

  SessionModel? _getCurrentSync() {
    final data = _box.get(_currentSessionKey);
    if (data == null) return null;
    if (data is SessionModel) return data;
    if (data is Map) {
      return SessionModel.fromJson(Map<String, dynamic>.from(data));
    }
    return null;
  }

  @override
  Future<SessionModel?> getCurrent() async {
    return _getCurrentSync();
  }

  @override
  Future<SessionModel?> getById(String id) async {
    final data = _box.get(id);
    if (data == null) return null;
    if (data is SessionModel) return data;
    if (data is Map) {
      return SessionModel.fromJson(Map<String, dynamic>.from(data));
    }
    return null;
  }

  @override
  Future<void> save(SessionModel session) async {
    // Validate before persisting
    session.validate();
    // PHASE 1 BLOCKER FIX: Safe HiveError handling
    final result1 = await SafeBoxOps.put(
      _box,
      session.id,
      session.toJson(),
      boxName: BoxRegistry.sessionsBox,
    );
    if (result1.isFailure) throw result1.error!;
    
    final result2 = await SafeBoxOps.put(
      _box,
      _currentSessionKey,
      session.toJson(),
      boxName: BoxRegistry.sessionsBox,
    );
    if (result2.isFailure) throw result2.error!;
  }

  @override
  Future<void> delete(String id) async {
    final result = await SafeBoxOps.delete(
      _box,
      id,
      boxName: BoxRegistry.sessionsBox,
    );
    if (result.isFailure) throw result.error!;
    
    final current = _getCurrentSync();
    if (current?.id == id) {
      final result2 = await SafeBoxOps.delete(
        _box,
        _currentSessionKey,
        boxName: BoxRegistry.sessionsBox,
      );
      if (result2.isFailure) throw result2.error!;
    }
  }

  @override
  Future<void> clearAll() async {
    final result = await SafeBoxOps.clear(
      _box,
      boxName: BoxRegistry.sessionsBox,
    );
    if (result.isFailure) throw result.error!;
  }

  @override
  Future<bool> hasValidSession() async {
    final session = await getCurrent();
    if (session == null) return false;
    return session.expiresAt.isAfter(DateTime.now());
  }

  @override
  Future<String?> getCurrentUserId() async {
    final session = await getCurrent();
    return session?.userId;
  }
}
