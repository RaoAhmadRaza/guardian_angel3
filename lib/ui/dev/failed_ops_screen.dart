import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../persistence/box_registry.dart';
import '../../models/failed_op_model.dart';
import '../../services/failed_ops_service.dart';
import '../../persistence/index/pending_index.dart';

class FailedOpsScreen extends StatefulWidget {
  const FailedOpsScreen({super.key});
  @override
  State<FailedOpsScreen> createState() => _FailedOpsScreenState();
}

class _FailedOpsScreenState extends State<FailedOpsScreen> {
  late FailedOpsService service;
  List<FailedOpModel> items = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final index = await PendingIndex.create();
    service = FailedOpsService(registry: BoxRegistry(), index: index);
    _refresh();
  }

  void _refresh() {
    final box = Hive.box<FailedOpModel>(BoxRegistry.failedOpsBox);
    setState(() {
      items = box.values.toList();
      loading = false;
    });
  }

  Future<void> _retry(String id) async {
    await service.retryOp(id);
    _refresh();
  }

  Future<void> _archive(String id) async {
    await service.archiveOp(id);
    _refresh();
  }

  Future<void> _delete(String id) async {
    await service.deleteOp(id);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Failed Operations')),
      body: ListView.builder(
        itemCount: items.length,
        itemBuilder: (c, i) {
          final f = items[i];
          return Card(
            child: ListTile(
              title: Text('${f.opType} (${f.errorCode ?? 'ERR'})'),
              subtitle: Text('Attempts: ${f.attempts}  Archived: ${f.archived}\nIdem: ${f.idempotencyKey ?? 'none'}'),
              trailing: Wrap(spacing: 8, children: [
                IconButton(icon: const Icon(Icons.refresh), onPressed: () => _retry(f.id)),
                IconButton(icon: const Icon(Icons.archive), onPressed: () => _archive(f.id)),
                IconButton(icon: const Icon(Icons.delete), onPressed: () => _delete(f.id)),
              ]),
            ),
          );
        },
      ),
    );
  }
}