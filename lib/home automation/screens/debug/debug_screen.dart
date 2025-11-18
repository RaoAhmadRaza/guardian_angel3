import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../src/automation/automation_observability.dart';
import '../../src/automation/automation_providers.dart';
import '../../src/automation/adapters/mqtt_driver.dart';
import '../../src/data/hive_adapters/pending_op_hive.dart';
import '../../src/data/local_hive_service.dart';
import 'package:hive/hive.dart';

class DebugScreen extends ConsumerWidget {
  const DebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(automationStatusProvider);
    final events = ref.watch(deviceEventLogProvider);
    final driver = ref.watch(automationDriverProvider);
    final isMqtt = driver is MqttDriver;
  final topics = isMqtt ? (driver).subscribedTopics : const <String>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Debug & Observability')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _Section(
            title: 'Automation Status',
            child: Row(
              children: [
                _statusDot(status),
                const SizedBox(width: 8),
                Text(status.name),
              ],
            ),
          ),
          if (isMqtt)
            _Section(
              title: 'MQTT Subscriptions',
              child: topics.isEmpty
                  ? const Text('None')
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: topics.map((t) => Chip(label: Text(t))).toList(),
                    ),
            ),
          _Section(
            title: 'Pending Ops',
            child: _PendingOpsList(),
          ),
          _Section(
            title: 'Last 50 Device Events',
            child: events.isEmpty
                ? const Text('No events yet')
                : Column(
                    children: events
                        .map((e) => ListTile(
                              dense: true,
                              title: Text(e.deviceId),
                              subtitle: Text(jsonEncode(e.state.raw ?? {'isOn': e.state.isOn, 'level': e.state.level})),
                              trailing: Text(
                                _ago(e.timestamp),
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statusDot(AutomationConnection s) {
    Color c;
    switch (s) {
      case AutomationConnection.connected:
        c = Colors.green;
        break;
      case AutomationConnection.connecting:
        c = Colors.orange;
        break;
      case AutomationConnection.disconnected:
        c = Colors.red;
        break;
    }
    return Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle));
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return '${d.inSeconds}s ago';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _PendingOpsList extends StatefulWidget {
  @override
  State<_PendingOpsList> createState() => _PendingOpsListState();
}

class _PendingOpsListState extends State<_PendingOpsList> {
  late final Box<PendingOp> _box;
  @override
  void initState() {
    super.initState();
    _box = LocalHiveService.pendingOpsBox();
  }

  @override
  Widget build(BuildContext context) {
    final list = _box.values.toList()
      ..sort((a, b) => (b.lastAttemptAt ?? b.queuedAt).compareTo(a.lastAttemptAt ?? a.queuedAt));
    if (list.isEmpty) return const Text('None');
    return Column(
      children: list
          .map((op) => ListTile(
                dense: true,
                title: Text('${op.entityType}/${op.entityId} — ${op.opType}'),
                subtitle: Text('attempts: ${op.attempts}\n${jsonEncode(op.payload)}'),
              ))
          .toList(),
    );
  }
}
