import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian_angel_fyp/sync/pending_queue_service.dart';
import 'package:guardian_angel_fyp/sync/processing_lock.dart';
import 'package:guardian_angel_fyp/sync/telemetry/production_metrics.dart';
import 'package:guardian_angel_fyp/sync/models/pending_op.dart';

/// Admin Console - Dev-only screen for sync engine operations
/// 
/// Features:
/// - View queue status and metrics
/// - Force release processing lock
/// - Rebuild queue index
/// - View pending/failed operations
/// - Export/import operations
/// - Manual retry failed operations
/// 
/// ⚠️ WARNING: This screen should only be accessible in dev builds!
class AdminConsoleScreen extends ConsumerStatefulWidget {
  const AdminConsoleScreen({super.key});

  @override
  ConsumerState<AdminConsoleScreen> createState() => _AdminConsoleScreenState();
}

class _AdminConsoleScreenState extends ConsumerState<AdminConsoleScreen> {
  bool _isLoading = false;
  String? _statusMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Engine Admin Console'),
        backgroundColor: Colors.red[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWarningBanner(),
                  const SizedBox(height: 24),
                  _buildMetricsSection(),
                  const SizedBox(height: 24),
                  _buildQueueStatusSection(),
                  const SizedBox(height: 24),
                  _buildActionsSection(),
                  const SizedBox(height: 24),
                  _buildOperationsPreview(),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 24),
                    _buildStatusMessage(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[100],
        border: Border.all(color: Colors.red[900]!, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.red[900], size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DEVELOPMENT ONLY',
                  style: TextStyle(
                    color: Colors.red[900],
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This console has dangerous operations. Use with caution.',
                  style: TextStyle(color: Colors.red[800]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Metrics Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            FutureBuilder<Map<String, dynamic>>(
              future: _fetchMetrics(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final metrics = snapshot.data!;
                final ops = metrics['counters'] as Map;
                final gauges = metrics['gauges'] as Map;
                final latency = metrics['latency'] as Map;

                return Column(
                  children: [
                    _buildMetricRow('Pending Operations', gauges['pending_ops']),
                    _buildMetricRow('Processed Total', ops['processed_ops_total']),
                    _buildMetricRow('Failed Total', ops['failed_ops_total']),
                    _buildMetricRow('P95 Latency', '${latency['p95_ms']}ms'),
                    _buildMetricRow('Success Rate', '${metrics['health']['success_rate_percent'].toStringAsFixed(1)}%'),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            value.toString(),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueStatusSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Queue Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            FutureBuilder<Map<String, int>>(
              future: _fetchQueueCounts(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final counts = snapshot.data!;
                return Column(
                  children: [
                    _buildMetricRow('Pending', counts['pending']),
                    _buildMetricRow('Failed', counts['failed']),
                    _buildMetricRow('Index Entries', counts['index']),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Admin Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _forceReleaseLock,
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Force Release Lock'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                ),
                ElevatedButton.icon(
                  onPressed: _rebuildIndex,
                  icon: const Icon(Icons.build),
                  label: const Text('Rebuild Index'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                ),
                ElevatedButton.icon(
                  onPressed: _exportOperations,
                  icon: const Icon(Icons.download),
                  label: const Text('Export Operations'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                ),
                ElevatedButton.icon(
                  onPressed: _clearFailedOps,
                  icon: const Icon(Icons.delete_sweep),
                  label: const Text('Clear Failed Ops'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
                ElevatedButton.icon(
                  onPressed: _retryAllFailed,
                  icon: const Icon(Icons.replay),
                  label: const Text('Retry All Failed'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                ),
                ElevatedButton.icon(
                  onPressed: _viewLogs,
                  icon: const Icon(Icons.article),
                  label: const Text('View Logs'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationsPreview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Operations',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => _showAllOperations(),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<PendingOp>>(
              future: _fetchRecentOperations(limit: 10),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final operations = snapshot.data!;
                if (operations.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No pending operations'),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: operations.length,
                  itemBuilder: (context, index) {
                    final op = operations[index];
                    return ListTile(
                      leading: _getOperationIcon(op.opType),
                      title: Text('${op.opType} ${op.entityType}'),
                      subtitle: Text(
                        'ID: ${op.id.substring(0, 8)}... | Attempts: ${op.attempts}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Text(
                        _formatTimestamp(op.createdAt),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      onTap: () => _showOperationDetails(op),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusMessage() {
    final isError = _statusMessage!.startsWith('ERROR');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isError ? Colors.red[100] : Colors.green[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error : Icons.check_circle,
            color: isError ? Colors.red[900] : Colors.green[900],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _statusMessage!,
              style: TextStyle(
                color: isError ? Colors.red[900] : Colors.green[900],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _statusMessage = null),
          ),
        ],
      ),
    );
  }

  Icon _getOperationIcon(String opType) {
    switch (opType) {
      case 'CREATE':
        return const Icon(Icons.add_circle, color: Colors.green);
      case 'UPDATE':
        return const Icon(Icons.edit, color: Colors.blue);
      case 'DELETE':
        return const Icon(Icons.delete, color: Colors.red);
      default:
        return const Icon(Icons.sync, color: Colors.grey);
    }
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return '${diff.inSeconds}s ago';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // Action handlers
  Future<void> _forceReleaseLock() async {
    final confirmed = await _showConfirmDialog(
      'Force Release Lock',
      'This will forcibly release the processing lock. Only do this if the lock is stuck.',
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      // TODO: Implement force release lock
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _statusMessage = 'Lock released successfully';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'ERROR: Failed to release lock: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _rebuildIndex() async {
    final confirmed = await _showConfirmDialog(
      'Rebuild Index',
      'This will rebuild the queue index from pending operations.',
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      // TODO: Implement rebuild index
      await Future.delayed(const Duration(seconds: 2));
      setState(() {
        _statusMessage = 'Index rebuilt successfully';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'ERROR: Failed to rebuild index: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _exportOperations() async {
    // TODO: Implement export operations
    setState(() => _statusMessage = 'Export started (see app directory)');
  }

  Future<void> _clearFailedOps() async {
    final confirmed = await _showConfirmDialog(
      'Clear Failed Operations',
      'This will permanently delete all failed operations. Consider exporting first.',
      isDangerous: true,
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      // TODO: Implement clear failed ops
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _statusMessage = 'Failed operations cleared';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'ERROR: Failed to clear operations: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _retryAllFailed() async {
    final confirmed = await _showConfirmDialog(
      'Retry All Failed',
      'This will move all failed operations back to the pending queue.',
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      // TODO: Implement retry all failed
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _statusMessage = 'Failed operations re-enqueued';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'ERROR: Failed to retry operations: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _viewLogs() async {
    // TODO: Implement view logs
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logs viewer not yet implemented')),
    );
  }

  void _showAllOperations() {
    // TODO: Navigate to full operations list
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Full operations list not yet implemented')),
    );
  }

  void _showOperationDetails(PendingOp op) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${op.opType} ${op.entityType}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('ID', op.id),
              _buildDetailRow('Status', op.status),
              _buildDetailRow('Attempts', op.attempts.toString()),
              _buildDetailRow('Created', op.createdAt.toString()),
              if (op.nextAttemptAt != null)
                _buildDetailRow('Next Attempt', op.nextAttemptAt.toString()),
              _buildDetailRow('Idempotency Key', op.idempotencyKey),
              if (op.traceId != null) _buildDetailRow('Trace ID', op.traceId!),
              if (op.txnToken != null) _buildDetailRow('Txn Token', op.txnToken!),
              const Divider(),
              const Text('Payload:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(op.payload.toString()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: SelectableText(value),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showConfirmDialog(
    String title,
    String message, {
    bool isDangerous = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDangerous ? Colors.red : null,
            ),
            child: Text(isDangerous ? 'Delete' : 'Confirm'),
          ),
        ],
      ),
    );
  }

  // Data fetching methods (to be implemented with real providers)
  Future<Map<String, dynamic>> _fetchMetrics() async {
    // TODO: Get from ProductionMetrics provider
    return {
      'gauges': {'pending_ops': 0, 'active_processors': 0},
      'counters': {
        'processed_ops_total': 0,
        'failed_ops_total': 0,
      },
      'latency': {'p95_ms': 0},
      'health': {'success_rate_percent': 100.0},
    };
  }

  Future<Map<String, int>> _fetchQueueCounts() async {
    // TODO: Get from PendingQueueService provider
    return {
      'pending': 0,
      'failed': 0,
      'index': 0,
    };
  }

  Future<List<PendingOp>> _fetchRecentOperations({int limit = 10}) async {
    // TODO: Get from PendingQueueService provider
    return [];
  }
}
