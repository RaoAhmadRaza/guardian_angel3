import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import '../models/log_entry.dart';
import '../models/monitoring_report.dart';
import '../services/monitoring_logging_service.dart';
import '../services/report_export_service.dart';

/// Live logs screen showing real-time inference data.
/// 
/// Features:
/// - Rolling log display (last 2 minutes)
/// - Auto-scroll with live updates
/// - Grouped log entries by inference window
/// - Export capabilities (PDF/TXT)
class LiveLogsScreen extends StatefulWidget {
  final MonitoringLoggingService loggingService;

  const LiveLogsScreen({
    super.key,
    required this.loggingService,
  });

  @override
  State<LiveLogsScreen> createState() => _LiveLogsScreenState();
}

class _LiveLogsScreenState extends State<LiveLogsScreen> {
  final ScrollController _scrollController = ScrollController();
  final ReportExportService _exportService = ReportExportService();
  
  List<InferenceLogEntry> _logs = [];
  List<MonitoringReport> _reports = [];
  bool _autoScroll = true;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _logs = widget.loggingService.logs;
    _reports = widget.loggingService.reports;
    
    // Listen for new logs
    widget.loggingService.addLogListener(_onNewLog);
    widget.loggingService.addReportListener(_onNewReport);
    widget.loggingService.addListener(_refreshLogs);
  }

  @override
  void dispose() {
    widget.loggingService.removeLogListener(_onNewLog);
    widget.loggingService.removeReportListener(_onNewReport);
    widget.loggingService.removeListener(_refreshLogs);
    _scrollController.dispose();
    super.dispose();
  }

  void _onNewLog(InferenceLogEntry log) {
    if (mounted) {
      setState(() {
        _logs = widget.loggingService.logs;
      });
      
      // Auto-scroll to bottom
      if (_autoScroll) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
  }

  void _onNewReport(MonitoringReport report) {
    if (mounted) {
      setState(() {
        _reports = widget.loggingService.reports;
      });
      
      // Show notification
      _showReportNotification(report);
    }
  }

  void _refreshLogs() {
    if (mounted) {
      setState(() {
        _logs = widget.loggingService.logs;
        _reports = widget.loggingService.reports;
      });
    }
  }

  void _showReportNotification(MonitoringReport report) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Report Generated'),
        content: Text(
          'A new monitoring report has been generated.\n'
          'Windows processed: ${report.totalWindowsProcessed}\n'
          'Avg probability: ${(report.averageFallProbability * 100).toStringAsFixed(1)}%',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            child: const Text('Export'),
            onPressed: () {
              Navigator.pop(context);
              _exportReport(report);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _exportReport(MonitoringReport report) async {
    setState(() => _isExporting = true);
    
    try {
      final deviceInfo = DeviceInfoPlugin();
      String deviceModel = 'Unknown';
      String osVersion = 'Unknown';
      
      if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceModel = iosInfo.model;
        osVersion = 'iOS ${iosInfo.systemVersion}';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceModel = '${androidInfo.brand} ${androidInfo.model}';
        osVersion = 'Android ${androidInfo.version.release}';
      }
      
      // Show format selection
      final format = await showCupertinoModalPopup<String>(
        context: context,
        builder: (context) => CupertinoActionSheet(
          title: const Text('Export Format'),
          message: const Text('Choose the export format for your report'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, 'pdf'),
              child: const Text('PDF (Recommended)'),
            ),
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, 'txt'),
              child: const Text('Plain Text'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ),
      );
      
      if (format == null) {
        setState(() => _isExporting = false);
        return;
      }
      
      String filePath;
      if (format == 'pdf') {
        filePath = await _exportService.exportToPdf(
          report: report,
          recentLogs: _logs,
          appName: 'Guardian Angel',
          appVersion: '1.0.0',
          deviceModel: deviceModel,
          osVersion: osVersion,
        );
      } else {
        filePath = await _exportService.exportToText(
          report: report,
          recentLogs: _logs,
          appName: 'Guardian Angel',
          appVersion: '1.0.0',
          deviceModel: deviceModel,
          osVersion: osVersion,
        );
      }
      
      // Share the file
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Fall Detection Report',
      );
      
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Export Failed'),
            content: Text('Error: $e'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _generateAndExportReport() async {
    final report = widget.loggingService.generateReportNow();
    if (report != null) {
      await _exportReport(report);
    } else {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('No Data'),
          content: const Text('No log data available to generate a report.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Live Logs'),
        backgroundColor: CupertinoColors.systemBackground.withOpacity(0.9),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _isExporting ? null : _generateAndExportReport,
              child: _isExporting
                  ? const CupertinoActivityIndicator()
                  : const Icon(CupertinoIcons.share, size: 22),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                setState(() => _autoScroll = !_autoScroll);
              },
              child: Icon(
                _autoScroll 
                    ? CupertinoIcons.arrow_down_circle_fill
                    : CupertinoIcons.arrow_down_circle,
                size: 22,
                color: _autoScroll ? CupertinoColors.activeBlue : null,
              ),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Stats Header
            Container(
              padding: const EdgeInsets.all(12),
              color: CupertinoColors.systemGrey6,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatBadge('Entries', '${_logs.length}'),
                  _buildStatBadge('Reports', '${_reports.length}'),
                  _buildStatBadge(
                    'Auto-scroll',
                    _autoScroll ? 'ON' : 'OFF',
                    color: _autoScroll ? CupertinoColors.activeGreen : CupertinoColors.systemGrey,
                  ),
                ],
              ),
            ),
            
            // Logs List
            Expanded(
              child: _logs.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        return _buildLogCard(_logs[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(String label, String value, {Color? color}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color ?? CupertinoColors.label,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: CupertinoColors.secondaryLabel,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.doc_text,
            size: 64,
            color: CupertinoColors.systemGrey3,
          ),
          const SizedBox(height: 16),
          const Text(
            'No logs yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Logs will appear here as\ninference windows are processed',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: CupertinoColors.tertiaryLabel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(InferenceLogEntry log) {
    final inference = log.inferenceResult;
    final sensor = log.sensorStats;
    final system = log.systemState;
    
    final probabilityColor = _getProbabilityColor(inference.fallProbability);
    final isFallDetected = inference.finalDecision == FallDecision.fall;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFallDetected 
              ? CupertinoColors.systemRed.withOpacity(0.5)
              : CupertinoColors.systemGrey5,
          width: isFallDetected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: probabilityColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: probabilityColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '#${log.sequenceNumber}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formatTime(log.timestamp),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  '${(inference.fallProbability * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: probabilityColor,
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Model Inference Section
                _buildSectionHeader('🤖 Model Inference'),
                const SizedBox(height: 6),
                _buildDataRow('Window', '${_formatTime(inference.windowStartTime)} → ${_formatTime(inference.windowEndTime)}'),
                _buildDataRow('Window Size', '${inference.windowSize} samples'),
                _buildDataRow('Threshold', '${(inference.thresholdUsed * 100).toStringAsFixed(1)}%'),
                _buildDataRow('Aggregation', inference.temporalAggregationState),
                _buildDataRow('Decision', inference.finalDecision.name.toUpperCase(),
                    valueColor: isFallDetected ? CupertinoColors.systemRed : null),
                _buildDataRow('Latency', '${inference.inferenceLatency.inMilliseconds}ms'),
                
                const SizedBox(height: 12),
                
                // Sensor Data Section
                _buildSectionHeader('🧠 Sensor Data'),
                const SizedBox(height: 6),
                _buildDataRow('Accel Mean', 'X:${sensor.accelXMean.toStringAsFixed(2)} Y:${sensor.accelYMean.toStringAsFixed(2)} Z:${sensor.accelZMean.toStringAsFixed(2)}'),
                _buildDataRow('Accel Peak', 'X:${sensor.accelXPeak.toStringAsFixed(2)} Y:${sensor.accelYPeak.toStringAsFixed(2)} Z:${sensor.accelZPeak.toStringAsFixed(2)}'),
                _buildDataRow('Accel Mag', '${sensor.accelMagnitude.toStringAsFixed(3)} (peak: ${sensor.accelMagnitudePeak.toStringAsFixed(3)})'),
                _buildDataRow('Gyro Mean', 'X:${sensor.gyroXMean.toStringAsFixed(2)} Y:${sensor.gyroYMean.toStringAsFixed(2)} Z:${sensor.gyroZMean.toStringAsFixed(2)}'),
                _buildDataRow('Gyro Peak', 'X:${sensor.gyroXPeak.toStringAsFixed(2)} Y:${sensor.gyroYPeak.toStringAsFixed(2)} Z:${sensor.gyroZPeak.toStringAsFixed(2)}'),
                _buildDataRow('Gyro Mag', '${sensor.gyroMagnitude.toStringAsFixed(3)} (peak: ${sensor.gyroMagnitudePeak.toStringAsFixed(3)})'),
                
                const SizedBox(height: 12),
                
                // System State Section
                _buildSectionHeader('🛑 System State'),
                const SizedBox(height: 6),
                _buildDataRow('Monitoring', system.monitoringState.name),
                _buildDataRow('Refractory', system.refractoryState.name),
                _buildDataRow('Alert', system.alertState.name),
                _buildDataRow('Buffer Fill', '${system.bufferFillLevel}%'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: CupertinoColors.secondaryLabel,
      ),
    );
  }

  Widget _buildDataRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: CupertinoColors.tertiaryLabel,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: valueColor ?? CupertinoColors.label,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getProbabilityColor(double probability) {
    if (probability >= 0.35) {
      return CupertinoColors.systemRed;
    } else if (probability >= 0.2) {
      return CupertinoColors.systemOrange;
    } else {
      return CupertinoColors.activeGreen;
    }
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
           '${dt.minute.toString().padLeft(2, '0')}:'
           '${dt.second.toString().padLeft(2, '0')}.'
           '${dt.millisecond.toString().padLeft(3, '0')}';
  }
}
