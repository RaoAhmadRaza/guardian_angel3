import 'package:flutter/material.dart';
import 'dart:io';
import 'package:hive/hive.dart';
import '../../persistence/index/pending_index.dart';
import '../../persistence/queue/pending_queue_service.dart';
import '../../persistence/audit/audit_service.dart';
import '../../persistence/backups/backup_service.dart';
import '../../persistence/box_registry.dart';
import '../../services/failed_ops_service.dart';
import '../../models/failed_op_model.dart';
import '../../persistence/hive_service.dart';
import '../guards/admin_auth_guard.dart';

/// Developer-only admin/debug screen. Guard with a dev flag before inclusion.
class AdminDebugScreen extends StatefulWidget {
  const AdminDebugScreen({super.key});

  @override
  State<AdminDebugScreen> createState() => _AdminDebugScreenState();
}

class _AdminDebugScreenState extends State<AdminDebugScreen> {
  String _log = '';

  void _appendLog(String msg) {
    setState(() => _log = '${DateTime.now().toIso8601String()} :: $msg\n$_log');
  }

  Future<void> _rebuildIndex() async {
    final idx = await PendingIndex.create();
    await idx.rebuild();
    _appendLog('Index rebuilt');
  }

  Future<void> _exportBackup() async {
    final audit = await AuditService.create();
    final file = await BackupService.exportPasswordEncryptedBackup(
      boxNames: [BoxRegistry.pendingOpsBox, BoxRegistry.auditLogsBox],
      destinationPath: '${Directory.systemTemp.path}/debug_backup.tar',
      password: 'debug-password',
      schemaVersion: 1,
      audit: audit,
    );
    _appendLog('Password backup exported: ${file.path}');
  }

  Future<void> _previewBackup() async {
    final path = '${Directory.systemTemp.path}/debug_backup.tar.penc';
    try {
      final info = await BackupService.previewPasswordEncryptedBackup(
        encryptedPath: path,
        password: 'debug-password',
      );
      _appendLog('Backup preview: ${info['meta']} counts=${info['recordCounts']}');
    } catch (e) {
      _appendLog('Preview failed: $e');
    }
  }

  Future<void> _restoreBackup() async {
    final authorized = await requireBiometricConfirmation(
      context: context,
      action: 'restore backup (will overwrite existing data)',
    );
    if (!authorized) return _appendLog('Restore cancelled: authentication failed');
    
    final path = '${Directory.systemTemp.path}/debug_backup.tar.penc';
    try {
      final audit = await AuditService.create();
      final restored = await BackupService.restorePasswordEncryptedBackup(
        encryptedPath: path,
        password: 'debug-password',
        expectedSchemaVersion: 1,
        overwriteExisting: true,
        audit: audit,
      );
      _appendLog('Restored boxes: $restored');
    } catch (e) {
      _appendLog('Restore failed: $e');
    }
  }

  Future<void> _processQueueOnce() async {
    final service = await PendingQueueService.create();
    final processed = await service.process(handler: (op) async {
      // Simulate success
      _appendLog('Processed op ${op.id}');
    }, batchSize: 5);
    _appendLog('Processed count: $processed');
  }

  Future<void> _showAuditTail() async {
    final audit = await AuditService.create();
    final tail = audit.tail(10);
    _appendLog('Audit tail: $tail');
  }

  Future<void> _retryFirstFailed() async {
    final authorized = await requireBiometricConfirmation(
      context: context,
      action: 'retry failed operation',
    );
    if (!authorized) return _appendLog('Retry cancelled: authentication failed');
    
    if (!Hive.isBoxOpen(BoxRegistry.failedOpsBox)) return _appendLog('Failed ops box not open');
    final box = Hive.box<FailedOpModel>(BoxRegistry.failedOpsBox);
    if (box.isEmpty) return _appendLog('No failed ops');
    final first = box.values.first;
    final index = await PendingIndex.create();
    final svc = FailedOpsService(registry: BoxRegistry(), index: index);
    await svc.retryOp(first.id);
    _appendLog('Retried failed op ${first.id}');
  }

  Future<void> _rotateKey() async {
    final authorized = await requireBiometricConfirmation(
      context: context,
      action: 'rotate encryption key',
    );
    if (!authorized) return _appendLog('Key rotation cancelled: authentication failed');
    
    try {
      final service = await HiveService.create();
      await service.init();
      await service.rotateEncryptionKey();
      _appendLog('Key rotation completed');
    } catch (e) {
      _appendLog('Key rotation failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Debug')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(spacing: 12, runSpacing: 12, children: [
              ElevatedButton(onPressed: _rebuildIndex, child: const Text('Rebuild Index')),
              ElevatedButton(onPressed: _processQueueOnce, child: const Text('Process Queue')),
              ElevatedButton(onPressed: _exportBackup, child: const Text('Export Backup')),
              ElevatedButton(onPressed: _previewBackup, child: const Text('Preview Backup')),
              ElevatedButton(onPressed: _restoreBackup, child: const Text('Restore Backup')),
              ElevatedButton(onPressed: _showAuditTail, child: const Text('Audit Tail')),
              ElevatedButton(onPressed: _retryFirstFailed, child: const Text('Retry First Failed')),
              ElevatedButton(onPressed: _rotateKey, child: const Text('Rotate Key')),
            ]),
            const SizedBox(height: 24),
            Text('Log:', style: Theme.of(context).textTheme.titleMedium),
            SelectableText(_log, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}