import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../logic/fall_detection_manager.dart';
import '../services/monitoring_logging_service.dart';
import 'live_logs_screen.dart';
import 'fall_detected_screen.dart';

/// Active monitoring screen displayed when the user starts monitoring.
/// 
/// Features:
/// - Real-time fall probability display
/// - Logs button in top-right corner (iOS style)
/// - Pause/Resume controls
/// - Visual feedback for model state
class MonitoringActiveScreen extends StatefulWidget {
  final FallDetectionManager manager;
  final MonitoringLoggingService loggingService;

  const MonitoringActiveScreen({
    super.key,
    required this.manager,
    required this.loggingService,
  });

  @override
  State<MonitoringActiveScreen> createState() => _MonitoringActiveScreenState();
}

class _MonitoringActiveScreenState extends State<MonitoringActiveScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  double _currentProbability = 0.0;
  int _windowsProcessed = 0;
  bool _isMonitoring = true;

  @override
  void initState() {
    super.initState();
    
    // Pulse animation for the status indicator
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // Listen to manager updates
    widget.manager.addListener(_updateState);
    
    // Start logging session
    widget.loggingService.startSession();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    widget.manager.removeListener(_updateState);
    super.dispose();
  }

  void _updateState() {
    if (mounted) {
      setState(() {
        _currentProbability = widget.manager.lastProbability;
        _isMonitoring = widget.manager.isMonitoring;
        _windowsProcessed = widget.loggingService.totalWindowsProcessed;
      });
      
      // Check if fall was detected (manager stopped monitoring)
      if (!widget.manager.isMonitoring && _isMonitoring) {
        // Fall detected - navigate to alert screen
        _handleFallDetected();
      }
    }
  }

  void _handleFallDetected() {
    widget.loggingService.endSession();
    Navigator.of(context).pushReplacement(
      CupertinoPageRoute(builder: (context) => const FallDetectedScreen()),
    );
  }

  void _openLogs() {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => LiveLogsScreen(
          loggingService: widget.loggingService,
        ),
      ),
    );
  }

  void _togglePause() {
    widget.manager.toggleMonitoring();
  }

  void _stopMonitoring() {
    widget.loggingService.endSession();
    widget.manager.stopMonitoring();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final probabilityColor = _getProbabilityColor(_currentProbability);
    
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Monitoring Active'),
        backgroundColor: CupertinoColors.systemBackground.withOpacity(0.9),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _openLogs,
          child: const Icon(
            CupertinoIcons.doc_text,
            size: 24,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Spacer(flex: 1),
              
              // Animated Status Indicator
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _isMonitoring ? _pulseAnimation.value : 1.0,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isMonitoring 
                            ? CupertinoColors.activeGreen.withOpacity(0.1)
                            : CupertinoColors.systemYellow.withOpacity(0.1),
                        border: Border.all(
                          color: _isMonitoring 
                              ? CupertinoColors.activeGreen
                              : CupertinoColors.systemYellow,
                          width: 4,
                        ),
                        boxShadow: _isMonitoring ? [
                          BoxShadow(
                            color: CupertinoColors.activeGreen.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ] : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isMonitoring 
                                ? CupertinoIcons.waveform_path
                                : CupertinoIcons.pause_circle,
                            size: 48,
                            color: _isMonitoring 
                                ? CupertinoColors.activeGreen
                                : CupertinoColors.systemYellow,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isMonitoring ? 'ACTIVE' : 'PAUSED',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _isMonitoring 
                                  ? CupertinoColors.activeGreen
                                  : CupertinoColors.systemYellow,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 32),
              
              // Fall Probability Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: probabilityColor.withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: probabilityColor.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Fall Probability',
                      style: TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.secondaryLabel,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(_currentProbability * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: probabilityColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Probability bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _currentProbability,
                        backgroundColor: CupertinoColors.systemGrey5,
                        valueColor: AlwaysStoppedAnimation(probabilityColor),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Threshold: 35%',
                      style: TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.tertiaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Stats Row
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      icon: CupertinoIcons.graph_square,
                      label: 'Windows',
                      value: '$_windowsProcessed',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      icon: CupertinoIcons.time,
                      label: 'Rate',
                      value: '2/sec',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      icon: CupertinoIcons.layers,
                      label: 'Buffer',
                      value: '400',
                    ),
                  ),
                ],
              ),
              
              const Spacer(flex: 2),
              
              // Control Buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: CupertinoButton(
                        color: _isMonitoring 
                            ? CupertinoColors.systemYellow
                            : CupertinoColors.activeGreen,
                        borderRadius: BorderRadius.circular(16),
                        onPressed: _togglePause,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isMonitoring 
                                  ? CupertinoIcons.pause_fill
                                  : CupertinoIcons.play_fill,
                              color: _isMonitoring 
                                  ? CupertinoColors.black
                                  : CupertinoColors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isMonitoring ? 'Pause' : 'Resume',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: _isMonitoring 
                                    ? CupertinoColors.black
                                    : CupertinoColors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 56,
                    width: 56,
                    child: CupertinoButton(
                      color: CupertinoColors.systemRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      padding: EdgeInsets.zero,
                      onPressed: _stopMonitoring,
                      child: const Icon(
                        CupertinoIcons.stop_fill,
                        color: CupertinoColors.systemRed,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: CupertinoColors.secondaryLabel),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
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
}
