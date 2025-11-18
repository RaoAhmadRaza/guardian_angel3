enum SyncStatus { idle, syncing, failed }

class SyncState {
  final SyncStatus status;
  final int pending;
  final String? lastError;
  final DateTime? lastSuccessAt;

  const SyncState({
    this.status = SyncStatus.idle,
    this.pending = 0,
    this.lastError,
    this.lastSuccessAt,
  });

  SyncState copyWith({
    SyncStatus? status,
    int? pending,
    String? lastError,
    DateTime? lastSuccessAt,
  }) => SyncState(
        status: status ?? this.status,
        pending: pending ?? this.pending,
        lastError: lastError,
        lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
      );
}
