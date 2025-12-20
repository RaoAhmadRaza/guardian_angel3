#!/usr/bin/env dart
/// Export pending operations to CSV for operational analysis
/// 
/// Usage:
///   dart run scripts/export_pending_ops.dart --out pending_ops.csv
///   dart run scripts/export_pending_ops.dart --out pending_ops.csv --format json
///   dart run scripts/export_pending_ops.dart --failed-only
/// 
/// Options:
///   --out <file>       Output file path (default: pending_ops_<timestamp>.csv)
///   --format <type>    Output format: csv or json (default: csv)
///   --failed-only      Export only failed operations
///   --include-payload  Include full payload data (may contain PII)
///   --help             Show this help message

import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:guardian_angel_fyp/sync/models/pending_op.dart';
import 'package:guardian_angel_fyp/persistence/adapters/pending_op_adapter.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('out', help: 'Output file path')
    ..addOption('format', defaultsTo: 'csv', help: 'Output format (csv|json)')
    ..addFlag('failed-only', defaultsTo: false, help: 'Export only failed operations')
    ..addFlag('include-payload', defaultsTo: false, help: 'Include full payload data')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help');

  try {
    final args = parser.parse(arguments);

    if (args['help'] as bool) {
      print('Export Pending Operations Tool');
      print('');
      print('Usage: dart run scripts/export_pending_ops.dart [options]');
      print('');
      print(parser.usage);
      exit(0);
    }

    final format = args['format'] as String;
    final failedOnly = args['failed-only'] as bool;
    final includePayload = args['include-payload'] as bool;
    final outputPath = args['out'] as String? ??
        'pending_ops_${DateTime.now().millisecondsSinceEpoch}.$format';

    print('╔═══════════════════════════════════════════════════════════╗');
    print('║        EXPORT PENDING OPERATIONS                          ║');
    print('╚═══════════════════════════════════════════════════════════╝');
    print('');
    print('Configuration:');
    print('  Output file: $outputPath');
    print('  Format: $format');
    print('  Failed only: $failedOnly');
    print('  Include payload: $includePayload');
    print('');

    // Initialize Hive
    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);
    Hive.registerAdapter(PendingOpAdapter());

    // Open boxes
    print('Opening database boxes...');
    final pendingBox = await Hive.openBox<PendingOp>('pending_operations');
    final failedBox = await Hive.openBox<Map>('failed_ops');

    final operations = <ExportedOp>[];

    // Export pending operations
    if (!failedOnly) {
      print('Exporting pending operations...');
      for (var i = 0; i < pendingBox.length; i++) {
        final op = pendingBox.getAt(i);
        if (op != null) {
          operations.add(ExportedOp.fromPendingOp(
            op,
            includePayload: includePayload,
            status: 'pending',
          ));
        }
      }
      print('  Found ${pendingBox.length} pending operations');
    }

    // Export failed operations
    if (failedOnly || failedBox.isNotEmpty) {
      print('Exporting failed operations...');
      for (var key in failedBox.keys) {
        final failedData = failedBox.get(key);
        if (failedData != null) {
          operations.add(ExportedOp.fromFailedOp(
            failedData,
            includePayload: includePayload,
          ));
        }
      }
      print('  Found ${failedBox.length} failed operations');
    }

    // Export to file
    print('');
    print('Writing to $outputPath...');
    
    if (format == 'csv') {
      await _exportToCsv(operations, outputPath);
    } else if (format == 'json') {
      await _exportToJson(operations, outputPath);
    } else {
      print('ERROR: Unknown format: $format');
      exit(1);
    }

    await pendingBox.close();
    await failedBox.close();
    await Hive.close();

    print('');
    print('✅ Export completed successfully!');
    print('   File: $outputPath');
    print('   Records: ${operations.length}');
    print('');
    print('⚠️  WARNING: Exported data may contain sensitive information.');
    print('   Store securely and delete after analysis.');
  } catch (e) {
    print('ERROR: $e');
    exit(1);
  }
}

/// Export operations to CSV
Future<void> _exportToCsv(List<ExportedOp> operations, String path) async {
  final file = File(path);
  final sink = file.openWrite();

  // Write header
  sink.writeln('id,op_type,entity_type,status,attempts,created_at,'
      'next_attempt_at,last_error,idempotency_key,trace_id,txn_token');

  // Write rows
  for (final op in operations) {
    sink.writeln([
      _escapeCsv(op.id),
      _escapeCsv(op.opType),
      _escapeCsv(op.entityType),
      _escapeCsv(op.status),
      op.attempts,
      _escapeCsv(op.createdAt),
      _escapeCsv(op.nextAttemptAt ?? ''),
      _escapeCsv(op.lastError ?? ''),
      _escapeCsv(op.idempotencyKey),
      _escapeCsv(op.traceId ?? ''),
      _escapeCsv(op.txnToken ?? ''),
    ].join(','));
  }

  await sink.close();
}

/// Export operations to JSON
Future<void> _exportToJson(List<ExportedOp> operations, String path) async {
  final file = File(path);
  
  final data = {
    'exported_at': DateTime.now().toIso8601String(),
    'count': operations.length,
    'operations': operations.map((op) => op.toJson()).toList(),
  };

  await file.writeAsString(
    const JsonEncoder.withIndent('  ').convert(data),
  );
}

/// Escape CSV field
String _escapeCsv(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

/// Redact PII from string
String _redactPii(String value) {
  // Redact email addresses
  value = value.replaceAllMapped(
    RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'),
    (match) => '[REDACTED_EMAIL]',
  );

  // Redact phone numbers
  value = value.replaceAllMapped(
    RegExp(r'\b\d{3}[-.]?\d{3}[-.]?\d{4}\b'),
    (match) => '[REDACTED_PHONE]',
  );

  // Redact credit card numbers
  value = value.replaceAllMapped(
    RegExp(r'\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b'),
    (match) => '[REDACTED_CC]',
  );

  return value;
}

/// Exported operation record
class ExportedOp {
  final String id;
  final String opType;
  final String entityType;
  final String status;
  final int attempts;
  final String createdAt;
  final String? nextAttemptAt;
  final String? lastError;
  final String idempotencyKey;
  final String? traceId;
  final String? txnToken;
  final Map<String, dynamic>? payload;

  ExportedOp({
    required this.id,
    required this.opType,
    required this.entityType,
    required this.status,
    required this.attempts,
    required this.createdAt,
    this.nextAttemptAt,
    this.lastError,
    required this.idempotencyKey,
    this.traceId,
    this.txnToken,
    this.payload,
  });

  factory ExportedOp.fromPendingOp(
    PendingOp op, {
    required bool includePayload,
    required String status,
  }) {
    return ExportedOp(
      id: op.id,
      opType: op.opType,
      entityType: op.entityType,
      status: status,
      attempts: op.attempts,
      createdAt: op.createdAt.toIso8601String(),
      nextAttemptAt: op.nextAttemptAt?.toIso8601String(),
      lastError: null,
      idempotencyKey: op.idempotencyKey,
      traceId: op.traceId,
      txnToken: op.txnToken,
      payload: includePayload ? _redactPayload(op.payload) : null,
    );
  }

  factory ExportedOp.fromFailedOp(
    Map<dynamic, dynamic> failedData, {
    required bool includePayload,
  }) {
    final op = failedData['operation'] as Map?;
    final error = failedData['error'] as Map?;

    return ExportedOp(
      id: op?['id'] ?? 'unknown',
      opType: op?['op_type'] ?? 'unknown',
      entityType: op?['entity_type'] ?? 'unknown',
      status: 'failed',
      attempts: failedData['attempts'] ?? 0,
      createdAt: failedData['failed_at'] ?? DateTime.now().toIso8601String(),
      nextAttemptAt: null,
      lastError: error?['reason'] ?? 'unknown',
      idempotencyKey: op?['idempotency_key'] ?? '',
      traceId: op?['trace_id'],
      txnToken: op?['txn_token'],
      payload: includePayload && op?['payload'] != null
          ? _redactPayload(Map<String, dynamic>.from(op!['payload']))
          : null,
    );
  }

  /// Redact sensitive fields from payload
  static Map<String, dynamic> _redactPayload(Map<String, dynamic> payload) {
    final redacted = <String, dynamic>{};
    
    for (var entry in payload.entries) {
      final key = entry.key.toLowerCase();
      final value = entry.value;

      // Redact known sensitive fields
      if (key.contains('password') ||
          key.contains('token') ||
          key.contains('secret') ||
          key.contains('key') ||
          key.contains('auth')) {
        redacted[entry.key] = '[REDACTED]';
      } else if (value is String) {
        redacted[entry.key] = _redactPii(value);
      } else {
        redacted[entry.key] = value;
      }
    }

    return redacted;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'op_type': opType,
      'entity_type': entityType,
      'status': status,
      'attempts': attempts,
      'created_at': createdAt,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (lastError != null) 'last_error': lastError,
      'idempotency_key': idempotencyKey,
      if (traceId != null) 'trace_id': traceId,
      if (txnToken != null) 'txn_token': txnToken,
      if (payload != null) 'payload': payload,
    };
  }
}
