import 'dart:io';
import 'dart:developer' as dev;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/monitoring_report.dart';
import '../models/log_entry.dart';

/// Service for generating and exporting monitoring reports.
/// 
/// Supports:
/// - PDF export (preferred for clinical review)
/// - Plain text export (fallback, universal compatibility)
/// - Local file storage
class ReportExportService {
  
  /// Export a report as PDF.
  /// Returns the file path of the exported PDF.
  Future<String> exportToPdf({
    required MonitoringReport report,
    required List<InferenceLogEntry> recentLogs,
    required String appName,
    required String appVersion,
    required String deviceModel,
    required String osVersion,
  }) async {
    final pdf = pw.Document();
    
    // Title style
    final titleStyle = pw.TextStyle(
      fontSize: 24,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.blue900,
    );
    
    final headerStyle = pw.TextStyle(
      fontSize: 14,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.grey800,
    );
    
    final smallStyle = pw.TextStyle(
      fontSize: 8,
      color: PdfColors.grey600,
    );
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => pw.Container(
          alignment: pw.Alignment.centerLeft,
          margin: const pw.EdgeInsets.only(bottom: 20),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Guardian Angel', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.Text('Fall Detection Report', style: smallStyle),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: smallStyle,
          ),
        ),
        build: (context) => [
          // Title
          pw.Center(
            child: pw.Text('FALL DETECTION\nMONITORING REPORT', style: titleStyle, textAlign: pw.TextAlign.center),
          ),
          pw.SizedBox(height: 20),
          
          // Report Info Section
          _buildPdfSection('REPORT INFORMATION', [
            _buildPdfRow('Report ID', report.id),
            _buildPdfRow('Generated', _formatDateTime(report.generatedAt)),
            _buildPdfRow('Period Start', _formatDateTime(report.periodStart)),
            _buildPdfRow('Period End', _formatDateTime(report.periodEnd)),
            _buildPdfRow('Duration', _formatDuration(report.periodDuration)),
          ]),
          pw.SizedBox(height: 16),
          
          // Device & App Info Section
          _buildPdfSection('APPLICATION & DEVICE', [
            _buildPdfRow('Application', '$appName v$appVersion'),
            _buildPdfRow('Device Model', deviceModel),
            _buildPdfRow('Operating System', osVersion),
            _buildPdfRow('ML Model', report.modelVersion),
            _buildPdfRow('Detection Threshold', '${(report.thresholdUsed * 100).toStringAsFixed(1)}%'),
          ]),
          pw.SizedBox(height: 16),
          
          // Processing Statistics Section
          _buildPdfSection('PROCESSING STATISTICS', [
            _buildPdfRow('Total Windows Processed', '${report.totalWindowsProcessed}'),
            _buildPdfRow('Average Fall Probability', '${(report.averageFallProbability * 100).toStringAsFixed(2)}%'),
            _buildPdfRow('Maximum Fall Probability', '${(report.maxFallProbability * 100).toStringAsFixed(2)}%'),
            _buildPdfRow('Minimum Fall Probability', '${(report.minFallProbability * 100).toStringAsFixed(2)}%'),
            _buildPdfRow('Threshold Crossings', '${report.thresholdCrossings}'),
            _buildPdfRow('Alerts Triggered', '${report.alertsTriggered}'),
            _buildPdfRow('Alerts Suppressed', '${report.alertsSuppressed}'),
          ]),
          pw.SizedBox(height: 16),
          
          // Sensor Statistics Section
          _buildPdfSection('SENSOR STATISTICS', [
            pw.Text('Accelerometer Magnitude (m/s²)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            _buildPdfRow('  Min', report.sensorSummary.accelMagnitudeMin.toStringAsFixed(3)),
            _buildPdfRow('  Max', report.sensorSummary.accelMagnitudeMax.toStringAsFixed(3)),
            _buildPdfRow('  Mean', report.sensorSummary.accelMagnitudeMean.toStringAsFixed(3)),
            pw.SizedBox(height: 8),
            pw.Text('Gyroscope Magnitude (rad/s)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            _buildPdfRow('  Min', report.sensorSummary.gyroMagnitudeMin.toStringAsFixed(3)),
            _buildPdfRow('  Max', report.sensorSummary.gyroMagnitudeMax.toStringAsFixed(3)),
            _buildPdfRow('  Mean', report.sensorSummary.gyroMagnitudeMean.toStringAsFixed(3)),
          ]),
          pw.SizedBox(height: 20),
          
          // Recent Inference Log (last 20 entries)
          pw.Text('RECENT INFERENCE LOG', style: headerStyle),
          pw.Divider(thickness: 1, color: PdfColors.grey400),
          pw.SizedBox(height: 8),
          
          // Log entries table
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(1),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(1.5),
            },
            children: [
              // Header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildTableCell('#', isHeader: true),
                  _buildTableCell('Timestamp', isHeader: true),
                  _buildTableCell('Probability', isHeader: true),
                  _buildTableCell('Aggregation', isHeader: true),
                  _buildTableCell('Decision', isHeader: true),
                ],
              ),
              // Data rows (last 20 entries)
              ...recentLogs.take(20).map((log) => pw.TableRow(
                children: [
                  _buildTableCell('${log.sequenceNumber}'),
                  _buildTableCell(_formatTime(log.timestamp)),
                  _buildTableCell('${(log.inferenceResult.fallProbability * 100).toStringAsFixed(1)}%'),
                  _buildTableCell(log.inferenceResult.temporalAggregationState),
                  _buildTableCell(log.inferenceResult.finalDecision.name),
                ],
              )),
            ],
          ),
        ],
      ),
    );
    
    // Save file
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/fall_detection_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());
    
    dev.log('ReportExportService: PDF exported to $filePath');
    return filePath;
  }
  
  /// Export a report as plain text.
  /// Returns the file path of the exported text file.
  Future<String> exportToText({
    required MonitoringReport report,
    required List<InferenceLogEntry> recentLogs,
    required String appName,
    required String appVersion,
    required String deviceModel,
    required String osVersion,
  }) async {
    final buffer = StringBuffer();
    
    // Generate text report
    buffer.write(report.toTextReport(
      appName: appName,
      appVersion: appVersion,
      deviceModel: deviceModel,
      osVersion: osVersion,
    ));
    
    // Add recent logs section
    buffer.writeln();
    buffer.writeln('┌─────────────────────────────────────────────────────────┐');
    buffer.writeln('│ RECENT INFERENCE LOG (Last 20 entries)                  │');
    buffer.writeln('├─────────────────────────────────────────────────────────┤');
    buffer.writeln('│ #    │ Time     │ Prob   │ Aggregation │ Decision      │');
    buffer.writeln('├──────┼──────────┼────────┼─────────────┼───────────────┤');
    
    for (final log in recentLogs.take(20)) {
      final seq = log.sequenceNumber.toString().padLeft(4);
      final time = _formatTime(log.timestamp);
      final prob = '${(log.inferenceResult.fallProbability * 100).toStringAsFixed(1)}%'.padLeft(6);
      final agg = log.inferenceResult.temporalAggregationState.padRight(11);
      final decision = log.inferenceResult.finalDecision.name.padRight(13);
      buffer.writeln('│ $seq │ $time │ $prob │ $agg │ $decision │');
    }
    
    buffer.writeln('└──────┴──────────┴────────┴─────────────┴───────────────┘');
    
    // Save file
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/fall_detection_report_${DateTime.now().millisecondsSinceEpoch}.txt';
    final file = File(filePath);
    await file.writeAsString(buffer.toString());
    
    dev.log('ReportExportService: Text exported to $filePath');
    return filePath;
  }
  
  /// Get list of saved reports.
  Future<List<FileSystemEntity>> getSavedReports() async {
    final directory = await getApplicationDocumentsDirectory();
    final files = directory.listSync().where((file) {
      final name = file.path.split('/').last;
      return name.startsWith('fall_detection_report_') && 
             (name.endsWith('.pdf') || name.endsWith('.txt'));
    }).toList();
    
    files.sort((a, b) => b.path.compareTo(a.path)); // Most recent first
    return files;
  }
  
  /// Delete a saved report.
  Future<void> deleteReport(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
      dev.log('ReportExportService: Deleted report $filePath');
    }
  }
  
  // Helper methods for PDF generation
  pw.Widget _buildPdfSection(String title, List<pw.Widget> children) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      padding: const pw.EdgeInsets.all(12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
          pw.Divider(thickness: 0.5, color: PdfColors.grey300),
          pw.SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
  
  pw.Widget _buildPdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 160,
            child: pw.Text(label, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          ),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }
  
  pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
  
  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
           '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
  
  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
  
  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }
}
