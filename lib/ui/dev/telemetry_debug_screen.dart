import 'package:flutter/material.dart';
import '../../services/telemetry_service.dart';

class TelemetryDebugScreen extends StatefulWidget {
  const TelemetryDebugScreen({super.key});
  @override
  State<TelemetryDebugScreen> createState() => _TelemetryDebugScreenState();
}

class _TelemetryDebugScreenState extends State<TelemetryDebugScreen> {
  late TelemetryService _svc;
  Map<String, dynamic> _snapshot = {};
  @override
  void initState() {
    super.initState();
    _svc = TelemetryService.I;
    _snapshot = _svc.snapshot();
    _svc.eventsStream.listen((_) {
      setState(() => _snapshot = _svc.snapshot());
    });
  }
  @override
  Widget build(BuildContext context) {
    final counters = (_snapshot['counters'] as Map?) ?? const {};
    final gauges = (_snapshot['gauges'] as Map?) ?? const {};
    final timers = (_snapshot['timers'] as Map?) ?? const {};
    final events = (_snapshot['events'] as List?) ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Telemetry Debug')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionTitle('Counters'),
          ...counters.entries.map((e) => Text('${e.key}: ${e.value}')),
          const SizedBox(height: 12),
          _sectionTitle('Gauges'),
            ...gauges.entries.map((e) => Text('${e.key}: ${e.value}')),
          const SizedBox(height: 12),
          _sectionTitle('Timers'),
          ...timers.entries.map((e) => Text('${e.key}: ${e.value}')),
          const SizedBox(height: 12),
          _sectionTitle('Recent Events (${events.length})'),
          ...events.take(50).map((e) => Text(e.toString(), style: const TextStyle(fontSize: 10))),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String s) => Text(s, style: const TextStyle(fontWeight: FontWeight.bold));
}