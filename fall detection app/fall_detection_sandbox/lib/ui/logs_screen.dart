import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Simple screen to display detection logs and debug info
class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Detection Logs'),
        backgroundColor: CupertinoColors.systemBackground,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Icon(CupertinoIcons.back),
        ),
      ),
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header Card
            _buildCard(
              title: 'Detection Summary',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Event Type', 'Fall Detected'),
                  _buildInfoRow('Timestamp', _formatTimestamp(DateTime.now())),
                  _buildInfoRow('Detection Method', 'ML Model + Temporal Voting'),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Model Info Card
            _buildCard(
              title: 'Model Configuration',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Window Size', '400 samples (2 sec)'),
                  _buildInfoRow('Features', '8 channels'),
                  _buildInfoRow('Threshold', '35%'),
                  _buildInfoRow('Voting Rule', '2-of-3 positive'),
                  _buildInfoRow('Refractory Period', '15 seconds'),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Pipeline Info Card
            _buildCard(
              title: 'Processing Pipeline',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPipelineStep(1, 'IMU Data Collection', '~200 Hz sampling'),
                  _buildPipelineStep(2, 'Smoothing', 'Moving average (k=5)'),
                  _buildPipelineStep(3, 'Feature Extraction', 'Accel + Gyro magnitudes'),
                  _buildPipelineStep(4, 'Normalization', 'Z-score (training stats)'),
                  _buildPipelineStep(5, 'TFLite Inference', 'CNN → Sigmoid'),
                  _buildPipelineStep(6, 'Temporal Aggregation', '2-of-3 voting'),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Note Card
            _buildCard(
              title: 'Debug Note',
              child: const Text(
                'For real-time inference logs, check the debug console '
                '(flutter logs) while the app is running. Each inference '
                'prints the probability and buffer state.',
                style: TextStyle(
                  fontSize: 14,
                  color: CupertinoColors.secondaryLabel,
                  height: 1.5,
                ),
              ),
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.label,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: CupertinoColors.label,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineStep(int step, String title, String detail) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: CupertinoColors.activeBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '$step',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: CupertinoColors.label,
                  ),
                ),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
           '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}
