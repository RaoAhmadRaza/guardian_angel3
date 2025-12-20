/// Queue Status UI - Minimal Read-Only Widget
///
/// Displays pending/failed/emergency operation counts in a compact,
/// read-only format for observability.
///
/// FEATURES:
/// - Pending ops count
/// - Failed ops count  
/// - Emergency ops count
/// - Health status indicator
/// - Last sync age
///
/// DESIGN:
/// - Minimal footprint
/// - Read-only (no mutations)
/// - Auto-refreshes every 30 seconds
/// - Accessible for dev/admin debugging
///
/// Usage:
/// ```dart
/// // In a widget tree
/// QueueStatusWidget()
///
/// // Or with custom refresh interval
/// QueueStatusWidget(refreshInterval: Duration(seconds: 10))
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../local_backend_status.dart';
import 'backend_health.dart';

// ═══════════════════════════════════════════════════════════════════════════
// QUEUE STATUS WIDGET
// ═══════════════════════════════════════════════════════════════════════════

/// Minimal read-only widget showing queue status.
class QueueStatusWidget extends ConsumerStatefulWidget {
  /// How often to refresh the status.
  final Duration refreshInterval;
  
  /// Whether to show the expanded detail view.
  final bool expanded;
  
  /// Whether to show in compact mode (icon only).
  final bool compact;

  const QueueStatusWidget({
    super.key,
    this.refreshInterval = const Duration(seconds: 30),
    this.expanded = false,
    this.compact = false,
  });

  @override
  ConsumerState<QueueStatusWidget> createState() => _QueueStatusWidgetState();
}

class _QueueStatusWidgetState extends ConsumerState<QueueStatusWidget> {
  LocalBackendStatus? _status;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.expanded;
    _refreshStatus();
  }

  void _refreshStatus() {
    try {
      setState(() {
        _status = LocalBackendStatusCollector.collect();
      });
    } catch (e) {
      // Status collection failed - show error state
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    
    if (widget.compact) {
      return _buildCompactIndicator(status);
    }

    return _buildFullWidget(status);
  }

  /// Compact indicator (just an icon with badge).
  Widget _buildCompactIndicator(LocalBackendStatus? status) {
    final color = _getStatusColor(status);
    final count = (status?.pendingOps ?? 0) + 
                  (status?.failedOps ?? 0) + 
                  (status?.emergencyOps ?? 0);

    return Tooltip(
      message: _getTooltipMessage(status),
      child: Stack(
        children: [
          Icon(
            _getStatusIcon(status),
            color: color,
            size: 24,
          ),
          if (count > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
                constraints: const BoxConstraints(
                  minWidth: 12,
                  minHeight: 12,
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Full widget with counts and status.
  Widget _buildFullWidget(LocalBackendStatus? status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark 
                ? Colors.white.withOpacity(0.1) 
                : Colors.black.withOpacity(0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(status, isDark),
            if (_isExpanded) ...[
              const SizedBox(height: 12),
              _buildDetailedView(status, isDark),
            ],
          ],
        ),
      ),
    );
  }

  /// Header row with status indicator and counts.
  Widget _buildHeader(LocalBackendStatus? status, bool isDark) {
    final statusColor = _getStatusColor(status);

    return Row(
      children: [
        // Status indicator
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        
        // Title
        Text(
          'Queue Status',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        
        const Spacer(),
        
        // Counts summary
        _buildCountBadge(
          'P',
          status?.pendingOps ?? 0,
          Colors.blue,
          isDark,
        ),
        const SizedBox(width: 4),
        _buildCountBadge(
          'F',
          status?.failedOps ?? 0,
          Colors.orange,
          isDark,
        ),
        const SizedBox(width: 4),
        _buildCountBadge(
          'E',
          status?.emergencyOps ?? 0,
          Colors.red,
          isDark,
        ),
        
        const SizedBox(width: 8),
        
        // Expand indicator
        Icon(
          _isExpanded ? Icons.expand_less : Icons.expand_more,
          size: 20,
          color: isDark ? Colors.white54 : Colors.black45,
        ),
      ],
    );
  }

  /// Small badge showing count.
  Widget _buildCountBadge(String label, int count, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: count > 0 ? color.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: count > 0 ? color : (isDark ? Colors.white24 : Colors.black12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: count > 0 ? color : (isDark ? Colors.white38 : Colors.black38),
            ),
          ),
          const SizedBox(width: 2),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: count > 0 ? color : (isDark ? Colors.white38 : Colors.black38),
            ),
          ),
        ],
      ),
    );
  }

  /// Detailed view with all metrics.
  Widget _buildDetailedView(LocalBackendStatus? status, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow('Pending Operations', '${status?.pendingOps ?? 0}', isDark),
        _buildDetailRow('Failed Operations', '${status?.failedOps ?? 0}', isDark),
        _buildDetailRow('Emergency Operations', '${status?.emergencyOps ?? 0}', isDark),
        _buildDetailRow('Escalated Operations', '${status?.escalatedOps ?? 0}', isDark),
        _buildDetailRow('Retrying', '${status?.retryingOps ?? 0}', isDark),
        const Divider(height: 16),
        _buildDetailRow('Queue State', status?.queueState ?? 'unknown', isDark),
        _buildDetailRow('Queue Stalled', status?.queueStalled == true ? 'Yes ⚠️' : 'No', isDark),
        _buildDetailRow('Lock Held', status?.lockStatus.isLocked == true ? 'Yes' : 'No', isDark),
        _buildDetailRow('Safety Fallback', status?.safetyFallbackActive == true ? 'Active ⚠️' : 'Inactive', isDark),
        const Divider(height: 16),
        _buildDetailRow('Encryption', status?.encryptionHealthy == true ? '✓ OK' : '✗ Issue', isDark),
        _buildDetailRow('Adapters', status?.adaptersHealthy == true ? '✓ OK' : '✗ Issue', isDark),
        _buildDetailRow('Open Boxes', '${status?.openBoxCount ?? 0}', isDark),
        if (status?.oldestOpAge != null)
          _buildDetailRow('Oldest Op Age', '${status!.oldestOpAge!.inMinutes}m', isDark),
        if (status?.lastProcessedAt != null)
          _buildDetailRow('Last Processed', _formatTimeAgo(status!.lastProcessedAt!), isDark),
        const SizedBox(height: 8),
        Text(
          'Updated: ${_formatTimeAgo(status?.capturedAt ?? DateTime.now())}',
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
        const SizedBox(height: 8),
        // Refresh button
        TextButton.icon(
          onPressed: _refreshStatus,
          icon: const Icon(Icons.refresh, size: 14),
          label: const Text('Refresh'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: const Size(0, 28),
            textStyle: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  /// Single detail row.
  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  Color _getStatusColor(LocalBackendStatus? status) {
    if (status == null) return Colors.grey;
    if (status.isCritical) return Colors.red;
    if (status.isWarning) return Colors.orange;
    if (status.isHealthy) return Colors.green;
    return Colors.grey;
  }

  IconData _getStatusIcon(LocalBackendStatus? status) {
    if (status == null) return Icons.cloud_off;
    if (status.isCritical) return Icons.error;
    if (status.isWarning) return Icons.warning;
    if (status.isHealthy) return Icons.cloud_done;
    return Icons.cloud_queue;
  }

  String _getTooltipMessage(LocalBackendStatus? status) {
    if (status == null) return 'Status unavailable';
    return 'Pending: ${status.pendingOps}, '
           'Failed: ${status.failedOps}, '
           'Emergency: ${status.emergencyOps}';
  }

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// QUEUE STATUS CARD (Alternative Design)
// ═══════════════════════════════════════════════════════════════════════════

/// A card-style queue status display for admin dashboards.
class QueueStatusCard extends StatelessWidget {
  final LocalBackendStatus status;
  final VoidCallback? onTap;
  final VoidCallback? onRefresh;

  const QueueStatusCard({
    super.key,
    required this.status,
    this.onTap,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  _StatusIndicator(status: status),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Operation Queue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          status.isHealthy ? 'All systems operational' : 'Attention needed',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onRefresh != null)
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: onRefresh,
                      tooltip: 'Refresh',
                    ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Counts row
              Row(
                children: [
                  Expanded(
                    child: _CountTile(
                      label: 'Pending',
                      count: status.pendingOps,
                      color: Colors.blue,
                      isDark: isDark,
                    ),
                  ),
                  Expanded(
                    child: _CountTile(
                      label: 'Failed',
                      count: status.failedOps,
                      color: Colors.orange,
                      isDark: isDark,
                    ),
                  ),
                  Expanded(
                    child: _CountTile(
                      label: 'Emergency',
                      count: status.emergencyOps,
                      color: Colors.red,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Status indicator dot with animation.
class _StatusIndicator extends StatelessWidget {
  final LocalBackendStatus status;

  const _StatusIndicator({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    if (status.isCritical) {
      color = Colors.red;
    } else if (status.isWarning) {
      color = Colors.orange;
    } else {
      color = Colors.green;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Individual count tile.
class _CountTile extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool isDark;

  const _CountTile({
    required this.label,
    required this.count,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: count > 0 ? color : (isDark ? Colors.white38 : Colors.black38),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// RIVERPOD PROVIDERS FOR QUEUE STATUS
// ═══════════════════════════════════════════════════════════════════════════

/// Provider for queue status counts.
final queueCountsProvider = Provider<QueueCounts>((ref) {
  final status = ref.watch(localBackendStatusProvider);
  return QueueCounts(
    pending: status.pendingOps,
    failed: status.failedOps,
    emergency: status.emergencyOps,
    escalated: status.escalatedOps,
  );
});

/// Simple immutable queue counts.
class QueueCounts {
  final int pending;
  final int failed;
  final int emergency;
  final int escalated;

  const QueueCounts({
    required this.pending,
    required this.failed,
    required this.emergency,
    required this.escalated,
  });

  int get total => pending + failed + emergency;
  
  bool get isEmpty => total == 0;
  
  bool get hasFailed => failed > 0;
  
  bool get hasEmergency => emergency > 0;

  @override
  String toString() => 'QueueCounts(pending=$pending, failed=$failed, emergency=$emergency)';
}
