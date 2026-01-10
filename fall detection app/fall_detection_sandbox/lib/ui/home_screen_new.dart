import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../logic/fall_detection_manager.dart';
import 'fall_detected_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late FallDetectionManager _manager;
  bool _isMonitoring = false;
  final List<String> _logs = [];
  bool _showLogs = false;

  @override
  void initState() {
    super.initState();
    _manager = FallDetectionManager(onFallDetected: _handleFallDetected);
    _initializeManager();
    _manager.addListener(_updateState);
  }

  Future<void> _initializeManager() async {
    _addLog('Initializing fall detection...');
    await _manager.initialize();
    _addLog('Model loaded. Ready to monitor.');
  }

  @override
  void dispose() {
    _manager.removeListener(_updateState);
    _manager.dispose();
    super.dispose();
  }

  void _addLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    setState(() {
      _logs.add('[$timestamp] $message');
      if (_logs.length > 50) _logs.removeAt(0);
    });
  }

  void _updateState() {
    if (mounted) {
      setState(() {
        _isMonitoring = _manager.isMonitoring;
      });
      if (_isMonitoring) {
        _addLog('Monitoring started');
      } else {
        _addLog('Monitoring stopped');
      }
      if (_manager.lastProbability > 0) {
        _addLog('Prob: ${_manager.lastProbability.toStringAsFixed(3)}');
      }
    }
  }

  void _handleFallDetected() {
    _addLog('FALL DETECTED!');
    if (mounted) {
      Navigator.of(context).push(
        CupertinoPageRoute(builder: (context) => const FallDetectedScreen()),
      );
    }
  }

  void _toggleMonitoring() {
    _manager.toggleMonitoring();
  }

  void _simulateFall() {
    _addLog('Simulating fall...');
    _manager.simulateFall();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Guardian Angel'),
      ),
      child: SafeArea(
        child: _showLogs ? _buildLogsView() : _buildMainView(),
      ),
    );
  }

  Widget _buildMainView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          
          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _isMonitoring 
                  ? CupertinoColors.activeGreen.withOpacity(0.1)
                  : CupertinoColors.systemYellow.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isMonitoring 
                    ? CupertinoColors.activeGreen 
                    : CupertinoColors.systemYellow,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isMonitoring ? CupertinoIcons.waveform_path : CupertinoIcons.pause_circle,
                  color: _isMonitoring ? CupertinoColors.activeGreen : CupertinoColors.systemYellow,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  _isMonitoring ? 'MONITORING' : 'PAUSED',
                  style: TextStyle(
                    color: _isMonitoring ? CupertinoColors.activeGreen : CupertinoColors.systemYellow,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          const Text(
            'Fall Detection\nTest Active',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              height: 1.1,
            ),
          ),
          
          const SizedBox(height: 16),
          
          Text(
            _isMonitoring 
                ? 'Probability: ${_manager.lastProbability.toStringAsFixed(3)}'
                : 'Tap Start to begin monitoring',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              color: CupertinoColors.secondaryLabel,
              height: 1.4,
            ),
          ),
          
          const Spacer(),
          
          // Start/Stop Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: CupertinoButton.filled(
              onPressed: _toggleMonitoring,
              borderRadius: BorderRadius.circular(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_isMonitoring ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill),
                  const SizedBox(width: 8),
                  Text(
                    _isMonitoring ? 'Pause Monitoring' : 'Start Monitoring',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Simulate Fall Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: CupertinoButton(
              color: CupertinoColors.systemOrange,
              borderRadius: BorderRadius.circular(16),
              onPressed: _simulateFall,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.exclamationmark_triangle_fill, color: CupertinoColors.white),
                  SizedBox(width: 8),
                  Text(
                    'Simulate Fall',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: CupertinoColors.white),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // View Logs Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: CupertinoButton(
              color: CupertinoColors.systemGrey5,
              borderRadius: BorderRadius.circular(16),
              onPressed: () => setState(() => _showLogs = true),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(CupertinoIcons.doc_text, color: CupertinoColors.label),
                  const SizedBox(width: 8),
                  Text(
                    'View Logs (${_logs.length})',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: CupertinoColors.label),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLogsView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => setState(() => _showLogs = false),
                child: const Row(
                  children: [Icon(CupertinoIcons.back), SizedBox(width: 4), Text('Back')],
                ),
              ),
              const Spacer(),
              const Text('Logs', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Spacer(),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => setState(() => _logs.clear()),
                child: const Text('Clear'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _logs.isEmpty
              ? const Center(child: Text('No logs yet', style: TextStyle(color: CupertinoColors.secondaryLabel)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[_logs.length - 1 - index];
                    final isAlert = log.contains('FALL');
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isAlert ? CupertinoColors.systemRed.withOpacity(0.1) : CupertinoColors.systemGrey6,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(log, style: TextStyle(fontFamily: 'Menlo', fontSize: 12, color: isAlert ? CupertinoColors.systemRed : CupertinoColors.label)),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
