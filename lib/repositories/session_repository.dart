/// SessionRepository - Abstract interface for session data access.
///
/// Part of PHASE 2: Backend is the only source of truth.
///
/// Data Flow:
/// UI → sessionProvider → SessionRepository → BoxAccessor.sessions() → Hive
library;

import '../../../models/session_model.dart';

/// Abstract repository for session operations.
///
/// All session access MUST go through this interface.
abstract class SessionRepository {
  /// Watch the current session as a reactive stream.
  Stream<SessionModel?> watchCurrent();

  /// Get the current session (one-time read).
  Future<SessionModel?> getCurrent();

  /// Get a session by ID.
  Future<SessionModel?> getById(String id);

  /// Save a session.
  Future<void> save(SessionModel session);

  /// Delete a session.
  Future<void> delete(String id);

  /// Clear all sessions (logout).
  Future<void> clearAll();

  /// Check if a valid session exists.
  Future<bool> hasValidSession();

  /// Get the current user ID from session.
  Future<String?> getCurrentUserId();
}
