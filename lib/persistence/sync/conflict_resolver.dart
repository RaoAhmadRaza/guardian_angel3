/// Conflict Resolution Service
///
/// Provides version-based conflict resolution for sync operations.
/// Part of 10% CLIMB #4 - Final audit closure.
///
/// This service implements a simple, explicit conflict resolution strategy:
/// - If remote.version > local.version: discard local, accept remote
/// - Otherwise: overwrite remote with local
library;

// Shared instance management (avoids circular imports)
ConflictResolver? _sharedConflictResolverInstance;

/// Sets the shared ConflictResolver instance.
void setSharedConflictResolverInstance(ConflictResolver instance) {
  _sharedConflictResolverInstance = instance;
}

/// Gets or creates the shared ConflictResolver instance.
ConflictResolver getSharedConflictResolverInstance() {
  return _sharedConflictResolverInstance ??= ConflictResolver.forTest();
}

/// Represents a versioned entity for conflict detection.
abstract class VersionedEntity {
  int get version;
  DateTime get updatedAt;
  String get id;
}

/// Result of conflict resolution.
enum ConflictResolution {
  /// Local wins - overwrite remote with local data
  localWins,
  
  /// Remote wins - discard local, accept remote data
  remoteWins,
  
  /// Merge required - manual intervention needed
  mergeRequired,
}

/// Details about a conflict resolution decision.
class ConflictResolutionResult {
  final ConflictResolution resolution;
  final String reason;
  final int localVersion;
  final int remoteVersion;
  final DateTime resolvedAt;
  
  ConflictResolutionResult({
    required this.resolution,
    required this.reason,
    required this.localVersion,
    required this.remoteVersion,
  }) : resolvedAt = DateTime.now();
  
  @override
  String toString() => 'ConflictResolutionResult('
      'resolution: $resolution, '
      'reason: $reason, '
      'local: v$localVersion, '
      'remote: v$remoteVersion)';
}

/// Conflict resolver with explicit version-based strategy.
///
/// The resolution strategy is simple and deterministic:
/// ```
/// if (remote.version > local.version) {
///   discardLocal();
/// } else {
///   overwriteRemote();
/// }
/// ```
class ConflictResolver {
  // ═══════════════════════════════════════════════════════════════════════
  // SINGLETON (DEPRECATED - Use ServiceInstances instead)
  // ═══════════════════════════════════════════════════════════════════════
  /// Legacy singleton accessor - routes to shared instance.
  @Deprecated('Use ServiceInstances.conflictResolver instead')
  static ConflictResolver get I => getSharedConflictResolverInstance();
  
  ConflictResolver._();
  
  /// Factory constructor for testing and DI
  factory ConflictResolver.forTest() => ConflictResolver._();
  
  /// Resolves a conflict between local and remote versions.
  ///
  /// Uses explicit version comparison:
  /// - remote.version > local.version → remoteWins (discardLocal)
  /// - otherwise → localWins (overwriteRemote)
  ConflictResolutionResult resolve({
    required int localVersion,
    required int remoteVersion,
    DateTime? localUpdatedAt,
    DateTime? remoteUpdatedAt,
  }) {
    // Primary strategy: version comparison
    if (remoteVersion > localVersion) {
      return ConflictResolutionResult(
        resolution: ConflictResolution.remoteWins,
        reason: 'Remote version ($remoteVersion) > local version ($localVersion)',
        localVersion: localVersion,
        remoteVersion: remoteVersion,
      );
    } else {
      return ConflictResolutionResult(
        resolution: ConflictResolution.localWins,
        reason: 'Local version ($localVersion) >= remote version ($remoteVersion)',
        localVersion: localVersion,
        remoteVersion: remoteVersion,
      );
    }
  }
  
  /// Resolves conflict using versioned entities directly.
  ConflictResolutionResult resolveEntities<T extends VersionedEntity>({
    required T local,
    required T remote,
  }) {
    return resolve(
      localVersion: local.version,
      remoteVersion: remote.version,
      localUpdatedAt: local.updatedAt,
      remoteUpdatedAt: remote.updatedAt,
    );
  }
  
  /// Applies resolution to local and remote data.
  ///
  /// Returns a tuple of (localData, shouldSyncToRemote).
  /// - If remoteWins: returns (remoteData, false) - discard local
  /// - If localWins: returns (localData, true) - overwrite remote
  (Map<String, dynamic>, bool) applyResolution({
    required ConflictResolutionResult result,
    required Map<String, dynamic> localData,
    required Map<String, dynamic> remoteData,
  }) {
    switch (result.resolution) {
      case ConflictResolution.remoteWins:
        // Discard local, accept remote
        return (remoteData, false);
      
      case ConflictResolution.localWins:
        // Keep local, sync to remote
        return (localData, true);
      
      case ConflictResolution.mergeRequired:
        // For now, default to local wins for merge cases
        return (localData, true);
    }
  }
}

/// Extension for easy conflict resolution on maps with version field.
extension ConflictResolutionExtension on Map<String, dynamic> {
  /// Resolves conflict between this (local) and remote data.
  ConflictResolutionResult resolveWith(Map<String, dynamic> remote) {
    final localVersion = (this['version'] as num?)?.toInt() ?? 0;
    final remoteVersion = (remote['version'] as num?)?.toInt() ?? 0;
    
    return ConflictResolver.I.resolve(
      localVersion: localVersion,
      remoteVersion: remoteVersion,
    );
  }
}

/// Mixin for entities that support conflict resolution.
mixin ConflictResolvable {
  int get version;
  DateTime get updatedAt;
  
  /// Check if this entity conflicts with another version.
  bool conflictsWith(int otherVersion) => version != otherVersion;
  
  /// Resolve conflict with remote version.
  ConflictResolutionResult resolveConflict(int remoteVersion) {
    return ConflictResolver.I.resolve(
      localVersion: version,
      remoteVersion: remoteVersion,
    );
  }
}
