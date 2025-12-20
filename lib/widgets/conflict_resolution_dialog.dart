/// ConflictResolutionDialog - Minimal Conflict Resolution UI
///
/// Part of FINAL CLIMB: Audit closure items.
///
/// Provides a basic dialog for resolving sync conflicts:
/// "Local version vs Remote version. Choose one."
///
/// USAGE:
/// ```dart
/// final choice = await ConflictResolutionDialog.show(
///   context,
///   entityType: 'Room',
///   entityName: 'Living Room',
///   localData: localRoom.toJson(),
///   remoteData: remoteRoom.toJson(),
/// );
///
/// if (choice == ConflictChoice.local) {
///   // Keep local version
/// } else {
///   // Use remote version
/// }
/// ```
library;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// User's choice for conflict resolution
enum ConflictChoice {
  /// Keep local version
  local,
  /// Use remote version
  remote,
  /// Cancel/dismiss without choosing
  cancel,
}

/// Information about a conflict
class ConflictInfo {
  final String entityType;
  final String entityId;
  final String? entityName;
  final Map<String, dynamic>? localData;
  final Map<String, dynamic>? remoteData;
  final DateTime? localModifiedAt;
  final DateTime? remoteModifiedAt;
  final int? localVersion;
  final int? remoteVersion;

  ConflictInfo({
    required this.entityType,
    required this.entityId,
    this.entityName,
    this.localData,
    this.remoteData,
    this.localModifiedAt,
    this.remoteModifiedAt,
    this.localVersion,
    this.remoteVersion,
  });

  String get displayName => entityName ?? entityId;
}

/// Result of conflict resolution
class ConflictResolutionChoice {
  final ConflictChoice choice;
  final ConflictInfo conflict;
  final DateTime resolvedAt;

  ConflictResolutionChoice({
    required this.choice,
    required this.conflict,
    required this.resolvedAt,
  });

  bool get isLocal => choice == ConflictChoice.local;
  bool get isRemote => choice == ConflictChoice.remote;
  bool get isCancelled => choice == ConflictChoice.cancel;
}

/// Minimal conflict resolution dialog.
///
/// Shows local vs remote data and lets user choose.
class ConflictResolutionDialog extends StatelessWidget {
  final ConflictInfo conflict;

  const ConflictResolutionDialog({
    super.key,
    required this.conflict,
  });

  /// Show the conflict resolution dialog.
  ///
  /// Returns the user's choice, or [ConflictChoice.cancel] if dismissed.
  static Future<ConflictResolutionChoice> show(
    BuildContext context, {
    required String entityType,
    required String entityId,
    String? entityName,
    Map<String, dynamic>? localData,
    Map<String, dynamic>? remoteData,
    DateTime? localModifiedAt,
    DateTime? remoteModifiedAt,
    int? localVersion,
    int? remoteVersion,
  }) async {
    final conflict = ConflictInfo(
      entityType: entityType,
      entityId: entityId,
      entityName: entityName,
      localData: localData,
      remoteData: remoteData,
      localModifiedAt: localModifiedAt,
      remoteModifiedAt: remoteModifiedAt,
      localVersion: localVersion,
      remoteVersion: remoteVersion,
    );

    final choice = await showDialog<ConflictChoice>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ConflictResolutionDialog(conflict: conflict),
    );

    return ConflictResolutionChoice(
      choice: choice ?? ConflictChoice.cancel,
      conflict: conflict,
      resolvedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Sync Conflict',
              style: theme.textTheme.titleLarge,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Conflict description
              Text(
                'There is a conflict for ${conflict.entityType}: "${conflict.displayName}"',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              
              Text(
                'Choose which version to keep:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Local version card
              _VersionCard(
                title: 'Local Version',
                icon: Icons.phone_android,
                color: Colors.blue,
                version: conflict.localVersion,
                modifiedAt: conflict.localModifiedAt,
                data: conflict.localData,
                isDark: isDark,
              ),
              
              const SizedBox(height: 12),
              
              // VS divider
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'VS',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 12),

              // Remote version card
              _VersionCard(
                title: 'Remote Version',
                icon: Icons.cloud,
                color: Colors.green,
                version: conflict.remoteVersion,
                modifiedAt: conflict.remoteModifiedAt,
                data: conflict.remoteData,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
      actions: [
        // Cancel button
        TextButton(
          onPressed: () => Navigator.of(context).pop(ConflictChoice.cancel),
          child: const Text('Cancel'),
        ),
        
        // Keep Local button
        ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop(ConflictChoice.local),
          icon: const Icon(Icons.phone_android, size: 18),
          label: const Text('Keep Local'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
        
        // Use Remote button
        ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop(ConflictChoice.remote),
          icon: const Icon(Icons.cloud, size: 18),
          label: const Text('Use Remote'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ],
      actionsAlignment: MainAxisAlignment.spaceBetween,
    );
  }
}

/// Card showing one version's data
class _VersionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final int? version;
  final DateTime? modifiedAt;
  final Map<String, dynamic>? data;
  final bool isDark;

  const _VersionCard({
    required this.title,
    required this.icon,
    required this.color,
    this.version,
    this.modifiedAt,
    this.data,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (version != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'v$version',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),

          // Modified time
          if (modifiedAt != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: theme.hintColor),
                const SizedBox(width: 4),
                Text(
                  _formatDateTime(modifiedAt!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
          ],

          // Data preview
          if (data != null && data!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 100),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              child: SingleChildScrollView(
                child: Text(
                  _formatJson(data!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatJson(Map<String, dynamic> json) {
    try {
      return const JsonEncoder.withIndent('  ').convert(json);
    } catch (_) {
      return json.toString();
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CONFLICT RESOLUTION SERVICE
// ═══════════════════════════════════════════════════════════════════════════

/// Provider for conflict resolution service
final conflictResolutionServiceProvider = Provider<ConflictResolutionService>((ref) {
  return ConflictResolutionService();
});

/// Service for managing conflict resolution.
class ConflictResolutionService {
  final List<ConflictResolutionChoice> _resolvedConflicts = [];

  /// Get history of resolved conflicts.
  List<ConflictResolutionChoice> get resolvedConflicts => 
      List.unmodifiable(_resolvedConflicts);

  /// Record a resolved conflict.
  void recordResolution(ConflictResolutionChoice resolution) {
    _resolvedConflicts.add(resolution);
  }

  /// Clear resolution history.
  void clearHistory() {
    _resolvedConflicts.clear();
  }

  /// Get count of conflicts resolved as local wins.
  int get localWinsCount => 
      _resolvedConflicts.where((r) => r.isLocal).length;

  /// Get count of conflicts resolved as remote wins.
  int get remoteWinsCount => 
      _resolvedConflicts.where((r) => r.isRemote).length;

  /// Resolve a conflict using the dialog.
  ///
  /// Shows the dialog and records the resolution.
  Future<ConflictResolutionChoice> resolveWithDialog(
    BuildContext context, {
    required String entityType,
    required String entityId,
    String? entityName,
    Map<String, dynamic>? localData,
    Map<String, dynamic>? remoteData,
    DateTime? localModifiedAt,
    DateTime? remoteModifiedAt,
    int? localVersion,
    int? remoteVersion,
  }) async {
    final resolution = await ConflictResolutionDialog.show(
      context,
      entityType: entityType,
      entityId: entityId,
      entityName: entityName,
      localData: localData,
      remoteData: remoteData,
      localModifiedAt: localModifiedAt,
      remoteModifiedAt: remoteModifiedAt,
      localVersion: localVersion,
      remoteVersion: remoteVersion,
    );

    if (!resolution.isCancelled) {
      recordResolution(resolution);
    }

    return resolution;
  }
}
