/// Sync Status Banner Widget
///
/// Part of PHASE 2: Backend is the only source of truth.
/// STEP 2.6: Wire Emergency & Safety State to UI.
/// Updated in PHASE 3 STEP 3.5: Close UI ↔ Backend Loop with Observability.
///
/// Displays sync status to users:
/// - "Offline mode active. Changes will sync later."
/// - "Syncing changes..."
/// - "Sync failed - tap to retry"
/// - Storage warning when quota exceeded
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/domain_providers.dart';
import '../persistence/monitoring/storage_monitor.dart';

/// A banner that shows sync status to the user.
///
/// Place at the top of screens to show offline/sync status:
/// ```dart
/// Column(
///   children: [
///     const SyncStatusBanner(),
///     Expanded(child: yourContent),
///   ],
/// )
/// ```
class SyncStatusBanner extends ConsumerWidget {
  final VoidCallback? onRetry;

  const SyncStatusBanner({
    super.key,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(syncStatusProvider);
    final pendingCount = ref.watch(pendingOpsCountProvider);
    final failedCount = ref.watch(failedOpsCountProvider);

    if (!syncStatus.showBanner) {
      return const SizedBox.shrink();
    }

    return _SyncBannerContent(
      status: syncStatus,
      pendingCount: pendingCount,
      failedCount: failedCount,
      onRetry: onRetry,
    );
  }
}

class _SyncBannerContent extends StatelessWidget {
  final SyncStatus status;
  final int pendingCount;
  final int failedCount;
  final VoidCallback? onRetry;

  const _SyncBannerContent({
    required this.status,
    required this.pendingCount,
    required this.failedCount,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _backgroundColor(isDark),
        border: Border(
          bottom: BorderSide(
            color: _borderColor(isDark),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            _StatusIcon(status: status),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _textColor(isDark),
                    ),
                  ),
                  if (_subtitle.isNotEmpty)
                    Text(
                      _subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: _textColor(isDark).withOpacity(0.7),
                      ),
                    ),
                ],
              ),
            ),
            if (status == SyncStatus.failed && onRetry != null)
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                child: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }

  String get _title {
    switch (status) {
      case SyncStatus.offline:
        return 'Offline Mode';
      case SyncStatus.pending:
        return 'Syncing...';
      case SyncStatus.failed:
        return 'Sync Failed';
      case SyncStatus.synced:
        return 'All Synced';
    }
  }

  String get _subtitle {
    switch (status) {
      case SyncStatus.offline:
        return 'Changes will sync when online';
      case SyncStatus.pending:
        return '$pendingCount change${pendingCount == 1 ? '' : 's'} pending';
      case SyncStatus.failed:
        return '$failedCount change${failedCount == 1 ? '' : 's'} failed';
      case SyncStatus.synced:
        return '';
    }
  }

  Color _backgroundColor(bool isDark) {
    switch (status) {
      case SyncStatus.offline:
        return isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6);
      case SyncStatus.pending:
        return isDark ? const Color(0xFF1E3A5F) : const Color(0xFFDBEAFE);
      case SyncStatus.failed:
        return isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2);
      case SyncStatus.synced:
        return Colors.transparent;
    }
  }

  Color _borderColor(bool isDark) {
    switch (status) {
      case SyncStatus.offline:
        return isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB);
      case SyncStatus.pending:
        return isDark ? const Color(0xFF3B82F6) : const Color(0xFF93C5FD);
      case SyncStatus.failed:
        return isDark ? const Color(0xFFDC2626) : const Color(0xFFFCA5A5);
      case SyncStatus.synced:
        return Colors.transparent;
    }
  }

  Color _textColor(bool isDark) {
    switch (status) {
      case SyncStatus.offline:
        return isDark ? Colors.white : const Color(0xFF374151);
      case SyncStatus.pending:
        return isDark ? Colors.white : const Color(0xFF1E40AF);
      case SyncStatus.failed:
        return isDark ? Colors.white : const Color(0xFF991B1B);
      case SyncStatus.synced:
        return isDark ? Colors.white : Colors.black;
    }
  }
}

class _StatusIcon extends StatelessWidget {
  final SyncStatus status;

  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case SyncStatus.offline:
        return const Icon(Icons.cloud_off, size: 20, color: Color(0xFF6B7280));
      case SyncStatus.pending:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
          ),
        );
      case SyncStatus.failed:
        return const Icon(Icons.error_outline, size: 20, color: Color(0xFFDC2626));
      case SyncStatus.synced:
        return const Icon(Icons.cloud_done, size: 20, color: Color(0xFF10B981));
    }
  }
}

/// Compact sync indicator for app bars.
class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(syncStatusProvider);
    final pendingCount = ref.watch(pendingOpsCountProvider);

    if (syncStatus == SyncStatus.synced) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _indicatorColor(syncStatus).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIcon(syncStatus),
          if (pendingCount > 0) ...[
            const SizedBox(width: 4),
            Text(
              '$pendingCount',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _indicatorColor(syncStatus),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.offline:
        return Icon(Icons.cloud_off, size: 16, color: _indicatorColor(status));
      case SyncStatus.pending:
        return SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(_indicatorColor(status)),
          ),
        );
      case SyncStatus.failed:
        return Icon(Icons.error_outline, size: 16, color: _indicatorColor(status));
      case SyncStatus.synced:
        return const SizedBox.shrink();
    }
  }

  Color _indicatorColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.offline:
        return const Color(0xFF6B7280);
      case SyncStatus.pending:
        return const Color(0xFF3B82F6);
      case SyncStatus.failed:
        return const Color(0xFFDC2626);
      case SyncStatus.synced:
        return const Color(0xFF10B981);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PHASE 3 STEP 3.5: STORAGE WARNING WIDGET
// ═══════════════════════════════════════════════════════════════════════════

/// Provider for storage pressure state.
final storagePressureProvider = FutureProvider<StoragePressure>((ref) async {
  final monitor = ref.watch(storageMonitorProvider);
  final result = await monitor.checkQuota();
  return result.pressure;
});

/// Storage warning banner - shows when storage quota is exceeded.
///
/// PHASE 3 STEP 3.5: Surface storage warnings to users.
class StorageWarningBanner extends ConsumerWidget {
  final VoidCallback? onAction;

  const StorageWarningBanner({
    super.key,
    this.onAction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pressureAsync = ref.watch(storagePressureProvider);

    return pressureAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (pressure) {
        if (pressure == StoragePressure.normal) {
          return const SizedBox.shrink();
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final isCritical = pressure == StoragePressure.critical;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isCritical
                ? (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2))
                : (isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7)),
            border: Border(
              bottom: BorderSide(
                color: isCritical
                    ? (isDark ? const Color(0xFFDC2626) : const Color(0xFFFCA5A5))
                    : (isDark ? const Color(0xFFF59E0B) : const Color(0xFFFCD34D)),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                Icon(
                  isCritical ? Icons.storage : Icons.warning_amber,
                  size: 20,
                  color: isCritical
                      ? const Color(0xFFDC2626)
                      : const Color(0xFFF59E0B),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isCritical ? 'Storage Critical' : 'Storage Warning',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        isCritical
                            ? 'Storage is almost full. Some features may not work.'
                            : 'Storage is running low. Consider clearing old data.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onAction != null)
                  TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? Colors.white : Colors.black87,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    child: const Text('Manage'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Combined health banner that shows both sync and storage status.
///
/// PHASE 3 STEP 3.5: Complete observability of backend health.
class BackendHealthBanner extends ConsumerWidget {
  final VoidCallback? onSyncRetry;
  final VoidCallback? onStorageAction;

  const BackendHealthBanner({
    super.key,
    this.onSyncRetry,
    this.onStorageAction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SyncStatusBanner(onRetry: onSyncRetry),
        StorageWarningBanner(onAction: onStorageAction),
      ],
    );
  }
}
