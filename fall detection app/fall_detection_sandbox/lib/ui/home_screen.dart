import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../logic/fall_detection_manager.dart';
import '../services/monitoring_logging_service.dart';
import 'fall_detected_screen.dart';
import 'monitoring_active_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late FallDetectionManager _manager;
  late MonitoringLoggingService _loggingService;
  bool _isMonitoring = false;
  double _currentProbability = 0.0;

  @override
  void initState() {
    super.initState();
    _loggingService = MonitoringLoggingService();
    _manager = FallDetectionManager(onFallDetected: _handleFallDetected);
    _manager.setLoggingService(_loggingService);
    _manager.initialize();
    _manager.addListener(_updateState);
  }

  @override
  void dispose() {
    _manager.removeListener(_updateState);
    _manager.dispose();
    _loggingService.dispose();
    super.dispose();
  }

  void _updateState() {
    if (mounted) {
      setState(() {
        _isMonitoring = _manager.isMonitoring;
        _currentProbability = _manager.lastProbability;
      });
    }
  }

  void _handleFallDetected() {
    if (mounted) {
      Navigator.of(context).push(
        CupertinoPageRoute(builder: (context) => const FallDetectedScreen()),
      );
    }
  }

  void _startMonitoringWithLogs() {
    _manager.startMonitoring();
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => MonitoringActiveScreen(
          manager: _manager,
          loggingService: _loggingService,
        ),
      ),
    );
  }

  void _toggleMonitoring() {
    if (_isMonitoring) {
      _manager.stopMonitoring();
    } else {
      _startMonitoringWithLogs();
    }
  }

  void _simulateFall() {
    _manager.simulateFall();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Guardian Angel'),
      ),
      child: SafeArea(
        child: Padding(
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
              
              // Large Title
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
              
              // Subtext
              Text(
                _isMonitoring 
                    ? 'Model running every 0.5s\nCollecting 400 samples/window'
                    : 'System is currently paused\nTap start to resume',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  color: CupertinoColors.secondaryLabel,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 24),

              // Live Probability Display
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Live Fall Probability',
                      style: TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      (_currentProbability * 100).toStringAsFixed(1) + '%',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: _currentProbability > 0.35 
                            ? CupertinoColors.systemRed 
                            : CupertinoColors.label,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Threshold: 35.0%',
                      style: const TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.tertiaryLabel,
                      ),
                    ),
                  ],
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
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
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
                        '`Simulate Fall`',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
