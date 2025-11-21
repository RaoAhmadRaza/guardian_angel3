import 'package:flutter/material.dart';
import '../models/sync_failure.dart';
import '../services/sync_failure_service.dart';
import 'sync_notifications.dart';

/// Screen showing inbox of sync failures with actionable items
class SyncFailureInboxScreen extends StatefulWidget {
  const SyncFailureInboxScreen({super.key});

  @override
  State<SyncFailureInboxScreen> createState() => _SyncFailureInboxScreenState();
}

class _SyncFailureInboxScreenState extends State<SyncFailureInboxScreen> {
  final _service = SyncFailureService.I;
  bool _loading = false;
  String _filter = 'pending'; // pending, all, critical

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Issues'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() => _filter = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'pending', child: Text('Pending')),
              const PopupMenuItem(value: 'critical', child: Text('Critical Only')),
              const PopupMenuItem(value: 'all', child: Text('All')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _retryAll,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final failures = _getFilteredFailures();

    if (failures.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: failures.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildFailureCard(failures[index]),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: Colors.green[300],
          ),
          const SizedBox(height: 16),
          Text(
            'All synced!',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'No sync issues at the moment',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailureCard(SyncFailure failure) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                _buildSeverityIcon(failure.severity),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        failure.operation,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${failure.entityType} • ${failure.ageDescription}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(failure.status),
              ],
            ),
            const SizedBox(height: 12),
            // Reason
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reason:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    failure.reason,
                    style: const TextStyle(fontSize: 14),
                  ),
                  if (failure.errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ExpansionTile(
                      title: const Text(
                        'Error details',
                        style: TextStyle(fontSize: 13),
                      ),
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(top: 8),
                      children: [
                        Text(
                          failure.errorMessage,
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Retry count
            if (failure.retryCount > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.refresh, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Attempted ${failure.retryCount} time${failure.retryCount > 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const Spacer(),
                  Text(
                    'Last: ${_formatTime(failure.lastAttemptAt)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
            // Suggested action
            if (failure.suggestedAction != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, size: 20, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        failure.suggestedAction!,
                        style: TextStyle(fontSize: 13, color: Colors.blue[900]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Actions
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _retry(failure),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue[700],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: failure.requiresUserAction
                        ? () => _showAssistance(failure)
                        : () => _dismiss(failure),
                    icon: Icon(
                      failure.requiresUserAction ? Icons.help_outline : Icons.close,
                      size: 18,
                    ),
                    label: Text(failure.requiresUserAction ? 'Get Help' : 'Dismiss'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          failure.requiresUserAction ? Colors.orange[700] : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeverityIcon(SyncFailureSeverity severity) {
    final IconData icon;
    final Color color;

    switch (severity) {
      case SyncFailureSeverity.low:
        icon = Icons.info_outline;
        color = Colors.blue;
        break;
      case SyncFailureSeverity.medium:
        icon = Icons.warning_amber_outlined;
        color = Colors.orange;
        break;
      case SyncFailureSeverity.high:
        icon = Icons.error_outline;
        color = Colors.deepOrange;
        break;
      case SyncFailureSeverity.critical:
        icon = Icons.dangerous_outlined;
        color = Colors.red;
        break;
    }

    return CircleAvatar(
      radius: 20,
      backgroundColor: color.withOpacity(0.2),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildStatusBadge(SyncFailureStatus status) {
    final String label;
    final Color color;

    switch (status) {
      case SyncFailureStatus.pending:
        label = 'Pending';
        color = Colors.orange;
        break;
      case SyncFailureStatus.retrying:
        label = 'Retrying';
        color = Colors.blue;
        break;
      case SyncFailureStatus.failed:
        label = 'Failed';
        color = Colors.red;
        break;
      case SyncFailureStatus.resolved:
        label = 'Resolved';
        color = Colors.green;
        break;
      case SyncFailureStatus.dismissed:
        label = 'Dismissed';
        color = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color.lerp(color, Colors.black, 0.2)!,
        ),
      ),
    );
  }

  List<SyncFailure> _getFilteredFailures() {
    switch (_filter) {
      case 'pending':
        return _service.getPendingFailures();
      case 'critical':
        return _service.getFailuresBySeverity(SyncFailureSeverity.critical);
      case 'all':
        return _service.getAllFailures();
      default:
        return _service.getPendingFailures();
    }
  }

  Future<void> _retry(SyncFailure failure) async {
    setState(() => _loading = true);

    try {
      // Show a loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Retrying...'),
            ],
          ),
        ),
      );

      // Simulate retry operation
      // In a real implementation, this would call the actual retry logic
      await Future.delayed(const Duration(seconds: 2));

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Mark as resolved for demo
      await _service.markResolved(failure.id, resolutionNote: 'Manual retry');

      if (mounted) {
        SyncNotifications.showSuccessSnackbar(
          context,
          'Sync successful!',
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Retry failed: ${e.toString()}'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _dismiss(SyncFailure failure) async {
    await _service.dismiss(failure.id);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dismissed')),
      );
    }
  }

  Future<void> _showAssistance(SyncFailure failure) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assistance Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Issue: ${failure.operation}'),
            const SizedBox(height: 8),
            Text('Reason: ${failure.reason}'),
            const SizedBox(height: 16),
            if (failure.suggestedAction != null) ...[
              const Text(
                'Suggested Action:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(failure.suggestedAction!),
              const SizedBox(height: 16),
            ],
            const Text(
              'For additional help, please contact support with the following information:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            SelectableText(
              'Failure ID: ${failure.id}\nEntity: ${failure.entityType}/${failure.entityId}\nFirst occurred: ${failure.firstFailedAt}',
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Navigate to support or open email client
            },
            child: const Text('Contact Support'),
          ),
        ],
      ),
    );
  }

  Future<void> _retryAll() async {
    setState(() => _loading = true);

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Retrying all...'),
            ],
          ),
        ),
      );

      // Simulate retry all
      await Future.delayed(const Duration(seconds: 3));

      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        SyncNotifications.showSuccessSnackbar(
          context,
          'Retry complete',
        );
        setState(() {});
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
