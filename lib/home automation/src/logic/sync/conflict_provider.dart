import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConflictRecord {
  final String entityType; // 'room' | 'device'
  final String entityId;
  final String opType; // 'create' | 'update' | 'delete' | 'toggle'
  final Map<String, dynamic> localPayload;
  final Map<String, dynamic> serverEntity;
  final DateTime detectedAt;
  final int attempts;

  ConflictRecord({
    required this.entityType,
    required this.entityId,
    required this.opType,
    required this.localPayload,
    required this.serverEntity,
    required this.attempts,
    DateTime? detectedAt,
  }) : detectedAt = detectedAt ?? DateTime.now();
}

class ConflictList extends StateNotifier<List<ConflictRecord>> {
  ConflictList() : super(const []);

  void add(ConflictRecord record) {
    state = [...state, record];
  }

  void removeFor(String entityType, String entityId) {
    state = state.where((r) => !(r.entityType == entityType && r.entityId == entityId)).toList();
  }

  void clear() => state = const [];
}

final conflictProvider = StateNotifierProvider<ConflictList, List<ConflictRecord>>((ref) => ConflictList());
