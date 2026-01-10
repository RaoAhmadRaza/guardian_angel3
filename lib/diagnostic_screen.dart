import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'theme/app_theme.dart' as theme;
import 'providers/theme_provider.dart';
import 'screens/diagnostic/diagnostic_state.dart';
import 'screens/diagnostic/diagnostic_data_provider.dart';

class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen>
    with TickerProviderStateMixin {
  // Screen state from data provider
  DiagnosticState _state = DiagnosticState.initial();
  bool _isLoading = true;

  // Animation controllers (only for UI transitions, NOT data simulation)
  late AnimationController _aiAnalysisController;
  late AnimationController _pulseAnimationController;
  late AnimationController _ecgAnimationController;
  late AnimationController _rhythmPulseController;

  // UI state
  bool _isAIContainerExpanded = false;
  bool _hasExpandedOnce = false;
  
  // Lead selection (UI only)
  final String _selectedLead = 'Lead II';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadDiagnosticData();
  }

  @override
  void dispose() {
    _aiAnalysisController.dispose();
    _pulseAnimationController.dispose();
    _ecgAnimationController.dispose();
    _rhythmPulseController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    // Only UI transition animations - NOT data simulation
    _aiAnalysisController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _ecgAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _rhythmPulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    // Only start animations if we have data
    // Animations will be started when data arrives
  }

  /// Load diagnostic data from local sources
  Future<void> _loadDiagnosticData() async {
    try {
      final state = await DiagnosticDataProvider.instance.loadInitialState();
      if (mounted) {
        setState(() {
          _state = state;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[DiagnosticScreen] Error loading data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // AI Analysis Showcase Container with Expandable Design
  Widget _buildAIShowcaseContainer(bool isDarkMode) {
    // Display values from state
    final rhythmDisplay = _state.heartRhythm ?? 'Not analyzed yet';
    final statusDisplay = _state.aiStatusMessage ?? 'No data available for analysis';
    final confidenceValue = _state.aiConfidence;
    final confidencePercent = confidenceValue != null ? (confidenceValue * 100).toInt() : null;
    final confidenceDisplay = confidencePercent != null ? '$confidencePercent%' : '--%';
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOutCubic,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDarkMode
                    ? [
                        Colors.white.withOpacity(0.05),
                        Colors.white.withOpacity(0.02),
                      ]
                    : [
                        const Color(0xFFF5F5F7).withOpacity(0.8),
                        const Color(0xFFE0E0E2).withOpacity(0.4),
                      ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.1)
                    : const Color(0xFFE0E0E2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDarkMode
                      ? Colors.black.withOpacity(0.3)
                      : const Color(0xFF475569).withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                // Simple AI Header and Status
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.1)
                            : const Color(0xFFF5F5F7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.2)
                              : const Color(0xFFE0E0E2),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.psychology_rounded,
                        size: 24,
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.7)
                            : const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Analysis',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDarkMode
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            rhythmDisplay,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isDarkMode
                                  ? Colors.white.withOpacity(0.7)
                                  : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Toggle Arrow Button (Expand/Collapse)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isAIContainerExpanded = !_isAIContainerExpanded;
                          if (_isAIContainerExpanded && !_hasExpandedOnce) {
                            _hasExpandedOnce = true;
                            _aiAnalysisController.reset();
                            _aiAnalysisController.forward();
                          } else if (!_isAIContainerExpanded) {
                            _aiAnalysisController.reverse(from: 1.0);
                          }
                        });
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.06)
                              : const Color(0xFFF5F5F7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.2)
                                : const Color(0xFFE0E0E2),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          _isAIContainerExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.7)
                              : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Simple confidence display
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.05)
                              : Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.1)
                                : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.verified_user,
                              size: 20,
                              color: isDarkMode
                                  ? Colors.white.withOpacity(_state.hasAIAnalysis ? 0.7 : 0.4)
                                  : const Color(0xFF475569).withOpacity(_state.hasAIAnalysis ? 1.0 : 0.5),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Confidence: $confidenceDisplay',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDarkMode
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    statusDisplay,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDarkMode
                                          ? Colors.white.withOpacity(0.6)
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Expanded Content with Animations
                if (_isAIContainerExpanded) ...[
                  const SizedBox(height: 24),

                  // Detailed AI Analysis with Animations
                  _buildExpandedAIContent(isDarkMode),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedAIContent(bool isDarkMode) {
    // Get confidence breakdown from state or use zeros
    final rhythmConf = _state.confidenceBreakdown?.rhythm ?? 0.0;
    final variabilityConf = _state.confidenceBreakdown?.variability ?? 0.0;
    final patternConf = _state.confidenceBreakdown?.pattern ?? 0.0;
    final statusDisplay = _state.aiStatusMessage ?? 'No data available for analysis';
    
    return AnimatedBuilder(
      animation: _aiAnalysisController,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rhythm Analysis
            Text(
              'Rhythm Analysis',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),

            // Confidence Bars - show 0% if no data
            _buildAnimatedConfidenceBar('Rhythm Detection', rhythmConf, isDarkMode),
            const SizedBox(height: 8),
            _buildAnimatedConfidenceBar('Variability', variabilityConf, isDarkMode),
            const SizedBox(height: 8),
            _buildAnimatedConfidenceBar('Pattern Match', patternConf, isDarkMode),

            const SizedBox(height: 20),

            // AI Status
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.05)
                    : Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: (isDarkMode
                              ? Colors.white.withOpacity(0.7)
                              : const Color(0xFF475569))
                          .withOpacity(_state.hasAIAnalysis ? 1.0 : 0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      statusDisplay,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color:
                            isDarkMode ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Explain Analysis Button
            Center(
              child: GestureDetector(
                onTap: () {
                  // Show info dialog if no data
                  if (!_state.hasAIAnalysis) {
                    _showNoDataDialog();
                  } else {
                    _showAIExplanation();
                  }
                  HapticFeedback.mediumImpact();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDarkMode
                          ? [
                              Colors.white.withOpacity(_state.hasAIAnalysis ? 0.1 : 0.05),
                              Colors.white.withOpacity(_state.hasAIAnalysis ? 0.05 : 0.02)
                            ]
                          : [const Color(0xFFF5F5F7), const Color(0xFFE0E0E2)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: isDarkMode
                            ? Colors.black.withOpacity(0.3)
                            : const Color(0xFF475569).withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    'Detailed Analysis',
                    style: TextStyle(
                      color: _state.hasAIAnalysis 
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Show dialog explaining no data is available
  void _showNoDataDialog() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'No Data Available',
          style: TextStyle(
            color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Connect a heart monitoring device to start receiving diagnostic data and AI analysis.',
          style: TextStyle(
            color: isDarkMode ? Colors.white.withOpacity(0.8) : const Color(0xFF475569),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(
                color: isDarkMode ? Colors.white : const Color(0xFF475569),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedConfidenceBar(
      String label, double confidence, bool isDarkMode) {
    return AnimatedBuilder(
      animation: _aiAnalysisController,
      builder: (context, child) {
        // Use confidence value (will be 0 if no data)
        final animatedConfidence = _hasExpandedOnce &&
                _aiAnalysisController.status == AnimationStatus.forward
            ? confidence * _aiAnalysisController.value
            : confidence;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.8)
                        : const Color(0xFF64748B),
                  ),
                ),
                Text(
                  '${(animatedConfidence * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.1)
                    : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: animatedConfidence.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDarkMode
                          ? [
                              Colors.white.withOpacity(0.7),
                              Colors.white.withOpacity(0.5)
                            ]
                          : [const Color(0xFF475569), const Color(0xFF64748B)],
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAIExplanation() {
    // Don't show if no data
    if (!_state.hasAIAnalysis) {
      _showNoDataDialog();
      return;
    }
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildAIExplanationModal(),
    );
  }

  Widget _buildAIExplanationModal() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final rhythmConf = _state.confidenceBreakdown?.rhythm ?? 0.0;
    final variabilityConf = _state.confidenceBreakdown?.variability ?? 0.0;
    final patternConf = _state.confidenceBreakdown?.pattern ?? 0.0;
    final rhythmDisplay = _state.heartRhythm ?? 'Unknown';

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.3)
                  : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.1)
                        : const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.psychology_rounded,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.7)
                        : const Color(0xFF475569),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Analysis Explanation',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: isDarkMode
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'How we analyzed your heartbeat',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.7)
                              : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildExplanationCard(
                    'Rhythm Analysis',
                    'Examined heart rhythm patterns for regularity and consistency. Your rhythm shows $rhythmDisplay characteristics.',
                    rhythmConf,
                    Icons.favorite,
                    isDarkMode,
                  ),
                  const SizedBox(height: 16),
                  _buildExplanationCard(
                    'R-R Variability',
                    'Analyzed intervals between heartbeats. Healthy variation indicates good autonomic function.',
                    variabilityConf,
                    Icons.show_chart,
                    isDarkMode,
                  ),
                  const SizedBox(height: 16),
                  _buildExplanationCard(
                    'Pattern Recognition',
                    'AI detected ECG patterns and compared with medical standards.',
                    patternConf,
                    Icons.pattern,
                    isDarkMode,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExplanationCard(String title, String description,
      double confidence, IconData icon, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF374151).withOpacity(0.5)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.1)
              : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: _getConfidenceColor(confidence, isDarkMode),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              Text(
                '${(confidence * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _getConfidenceColor(confidence, isDarkMode),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.8)
                  : const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Color _getHealthStatusColor() {
    // For first-time users with no data, return neutral color
    if (!_state.hasAIAnalysis) {
      return const Color(0xFF94A3B8); // Neutral gray
    }
    
    final rhythm = _state.heartRhythm ?? '';
    final isStressDetected = _state.isStressDetected ?? false;
    
    if (rhythm.contains("Arrhythmia") || isStressDetected) {
      return const Color(0xFFFFBE0B); // Warning yellow
    } else if (rhythm.contains("Tachycardia") ||
        rhythm.contains("Bradycardia")) {
      return const Color(0xFFD97706); // Orange for mild concern
    } else {
      return const Color(0xFF059669); // Green for normal
    }
  }

  double _calculateRRVariability() {
    final intervals = _state.rrIntervals;
    if (intervals == null || intervals.length < 2) return 0;

    double sum = 0;
    for (int i = 1; i < intervals.length; i++) {
      sum += (intervals[i] - intervals[i - 1]).abs();
    }
    return sum / (intervals.length - 1);
  }

  // NOTE: ECG data generation removed - should come from real device data
  // Empty ECG data will show "Connect a device" message

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFFDFDFD),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDarkMode
              ? theme.AppTheme.getPrimaryGradient(context)
              : theme.AppTheme.lightPrimaryGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar with back button and theme toggle
              _buildTopBar(isDarkMode),

              // Main content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),

                      // Title
                      Text(
                        'Diagnostic Center',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: isDarkMode
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'Comprehensive health analysis and monitoring',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.7)
                              : const Color(0xFF475569),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Enhanced Heartbeat Card with ECG
                      _buildHeartbeatCard(isDarkMode),

                      const SizedBox(height: 16),

                      // R-R Interval Analysis Card
                      _buildRRIntervalCard(isDarkMode),

                      const SizedBox(height: 16),

                      // AI Analysis Showcase Container
                      _buildAIShowcaseContainer(isDarkMode),

                      const SizedBox(height: 16),

                      // Results Summary Card
                      _buildResultsCard(isDarkMode),

                      // Emergency Actions (shown only when in critical alert state from REAL data)
                      // For first-time users with no data, this will never show
                      if (_state.hasCriticalAlert) ...[
                        const SizedBox(height: 16),
                        _buildEmergencyActionsCard(isDarkMode),
                      ],

                      const SizedBox(height: 24),

                      // Oxygen Saturation - from Apple HealthKit
                      _buildDiagnosticCard(
                        isDarkMode: isDarkMode,
                        icon: CupertinoIcons.drop_fill,
                        title: 'Oxygen Saturation',
                        subtitle: _state.oxygenSaturation != null
                            ? '${_state.oxygenSaturation!.percent}% SpO₂'
                            : 'No reading available',
                        status: _state.oxygenSaturationStatus,
                        statusColor:
                            const Color(0xFF475569),
                      ),

                      const SizedBox(height: 16),

                      // Heart Rhythm - from AI Analysis
                      _buildDiagnosticCard(
                        isDarkMode: isDarkMode,
                        icon: CupertinoIcons.waveform_path_ecg,
                        title: 'Heart Rhythm',
                        subtitle: _state.heartRhythm ?? 'No reading available',
                        status: _state.hasAIAnalysis ? 'Analyzed' : 'No data',
                        statusColor: const Color(0xFF475569),
                      ),

                      const SizedBox(height: 16),

                      _buildDiagnosticCard(
                        isDarkMode: isDarkMode,
                        icon: CupertinoIcons.moon_zzz_fill,
                        title: 'Sleep Quality',
                        subtitle: _state.sleep != null
                            ? '${_state.sleep!.hoursSlept.toStringAsFixed(1)} hours'
                            : 'No data available',
                        status: _state.sleep?.quality ?? 'No data',
                        statusColor: const Color(0xFF475569),
                      ),

                      const SizedBox(height: 32),

                      // Action buttons
                      _buildActionButton(
                        isDarkMode: isDarkMode,
                        title: 'Start Full Diagnostic',
                        subtitle: 'Complete health assessment',
                        icon: CupertinoIcons.play_circle_fill,
                        isPrimary: true,
                      ),

                      const SizedBox(height: 16),

                      _buildActionButton(
                        isDarkMode: isDarkMode,
                        title: 'View History',
                        subtitle: _state.hasDiagnosticHistory 
                            ? 'Previous diagnostic reports'
                            : 'No diagnostic history available',
                        icon: CupertinoIcons.doc_text_fill,
                        isPrimary: false,
                        isEnabled: _state.hasDiagnosticHistory,
                      ),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.1)
                  : const Color(0xFFFDFDFD),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.2)
                    : const Color(0xFFE0E0E2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDarkMode
                      ? Colors.black.withOpacity(0.3)
                      : const Color(0xFF475569).withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
                child: Center(
                  child: Icon(
                    CupertinoIcons.back,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.8)
                        : const Color(0xFF475569),
                    size: 24,
                  ),
                ),
              ),
            ),
          ),

          // Theme toggle button
          _buildThemeToggle(isDarkMode),
        ],
      ),
    );
  }

  Widget _buildThemeToggle(bool isDarkMode) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withOpacity(0.1)
            : const Color(0xFFFDFDFD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.2)
              : const Color(0xFFE0E0E2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : const Color(0xFF475569).withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.lightImpact();
            ThemeProvider.instance.toggleTheme();
          },
          child: Center(
            child: Icon(
              isDarkMode
                  ? CupertinoIcons.sun_max_fill
                  : CupertinoIcons.moon_fill,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.8)
                  : const Color(0xFF475569),
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  // Enhanced Heartbeat Card with ECG visualization
  Widget _buildHeartbeatCard(bool isDarkMode) {
    final hasHeartData = _state.heartRate != null;
    final heartRateDisplay = _state.heartRate?.toString() ?? '--';
    final targetBpmDisplay = _state.targetHeartRate?.toString() ?? '--';
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.06)
              : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : const Color(0xFF475569).withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and menu
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.1)
                      : const Color(0xFFF5F5F7),
                  shape: BoxShape.circle,
                ),
                child: hasHeartData
                    ? AnimatedBuilder(
                        animation: _pulseAnimationController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: 1.0 + (_pulseAnimationController.value * 0.1),
                            child: Icon(
                              CupertinoIcons.heart_fill,
                              color: isDarkMode
                                  ? Colors.white.withOpacity(0.75)
                                  : const Color(0xFF475569),
                              size: 24,
                            ),
                          );
                        },
                      )
                    : Icon(
                        CupertinoIcons.heart,
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.4)
                            : const Color(0xFF94A3B8),
                        size: 24,
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Heartbeat',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color:
                            isDarkMode ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.08)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _selectedLead,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.7)
                              : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.ellipsis,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.5)
                    : const Color(0xFF475569).withOpacity(0.5),
                size: 20,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Large BPM display
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                heartRateDisplay,
                style: TextStyle(
                  fontSize: 58,
                  fontWeight: FontWeight.w800,
                  color: isDarkMode 
                      ? (hasHeartData ? Colors.white : Colors.white.withOpacity(0.4))
                      : (hasHeartData ? const Color(0xFF0F172A) : const Color(0xFF94A3B8)),
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'bpm',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.7)
                        : const Color(0xFF475569),
                  ),
                ),
              ),
              const Spacer(),
              // Target indicator
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.08)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$targetBpmDisplay bpm',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.8)
                        : const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ECG Wave visualization or empty state
          if (hasHeartData && _state.ecgSamples != null && _state.ecgSamples!.isNotEmpty)
            SizedBox(
              height: 120,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: ECGPainter(
                          data: _state.ecgSamples!,
                          animationValue: _ecgAnimationController.value,
                          isDarkMode: isDarkMode,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 2,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFACC15),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.04)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.waveform_path,
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.3)
                          : const Color(0xFF94A3B8),
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Connect a device to view heart activity',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.5)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // R-R Interval Analysis Card
  Widget _buildRRIntervalCard(bool isDarkMode) {
    final hasRRData = _state.rrIntervals != null && _state.rrIntervals!.isNotEmpty;
    final rrDisplay = hasRRData ? '${_state.rrIntervals!.first} ms' : '-- ms';
    final rrProgress = hasRRData ? 0.7 : 0.0; // TODO: replace with real RR normalization
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : const Color(0xFF475569).withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.1)
                      : const Color(0xFFF5F5F7),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.waveform_path_ecg,
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.7)
                      : const Color(0xFF475569),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rrDisplay,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color:
                            isDarkMode ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'R-R interval',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.7)
                            : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.ellipsis,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.5)
                    : const Color(0xFF475569).withOpacity(0.5),
                size: 20,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Progress bar
          Container(
            height: 8,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDarkMode
                  ? const Color(0xFF374151)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: rrProgress,
              child: Container(
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.7)
                      : const Color(0xFF475569),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Interval values
          if (hasRRData)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _state.rrIntervals!.asMap().entries.map((entry) {
                  final isLast = entry.key == _state.rrIntervals!.length - 1;
                  return Padding(
                    padding: EdgeInsets.only(right: isLast ? 0 : 8),
                    child: Text(
                      '${entry.value}ms',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.8)
                            : const Color(0xFF475569),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // Results Summary Card (Simplified)
  Widget _buildResultsCard(bool isDarkMode) {
    final hasAIAnalysis = _state.hasAIAnalysis;
    final rhythmDisplay = _state.heartRhythm ?? 'Not analyzed yet';
    final statusDisplay = hasAIAnalysis 
        ? _state.aiAnalysisStatus ?? 'Analysis complete' 
        : 'No data to analyze';
    final confidenceDisplay = hasAIAnalysis 
        ? '${((_state.aiConfidence ?? 0) * 100).toInt()}%' 
        : '--%';
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : const Color(0xFF475569).withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with info icon
          Row(
            children: [
              Text(
                'AI Analysis of Heartbeat',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.1)
                      : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.info,
                  size: 12,
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.7)
                      : const Color(0xFF475569),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Simplified content
          Row(
            children: [
              // Status dot - only animate when we have data
              if (hasAIAnalysis)
                AnimatedBuilder(
                  animation: _rhythmPulseController,
                  builder: (context, child) {
                    return Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _getHealthStatusColor().withOpacity(
                          0.4 + 0.6 * _rhythmPulseController.value,
                        ),
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                )
              else
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.3)
                        : const Color(0xFF94A3B8),
                    shape: BoxShape.circle,
                  ),
                ),
              const SizedBox(width: 12),

              // Heart rhythm text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rhythmDisplay,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode 
                            ? (hasAIAnalysis ? Colors.white : Colors.white.withOpacity(0.5))
                            : (hasAIAnalysis ? const Color(0xFF0F172A) : const Color(0xFF94A3B8)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusDisplay,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.7)
                            : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),

              // Confidence badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.1)
                      : const Color(0xFFF5F5F7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.2)
                        : const Color(0xFFE0E0E2),
                    width: 1,
                  ),
                ),
                child: Text(
                  confidenceDisplay,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode
                        ? Colors.white.withOpacity(hasAIAnalysis ? 0.8 : 0.4)
                        : (hasAIAnalysis ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Emergency Actions Card
  Widget _buildEmergencyActionsCard(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFFDC2626).withOpacity(0.1)
            : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode
              ? const Color(0xFFDC2626).withOpacity(0.3)
              : const Color(0xFFDC2626).withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Alert header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.warning_rounded,
                  color: Color(0xFFDC2626),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Health Alert',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color:
                            isDarkMode ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Critical values detected - Take action',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.8)
                            : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Emergency action buttons
          Row(
            children: [
              Expanded(
                child: _buildEmergencyButton(
                  'Call Doctor',
                  Icons.local_hospital,
                  const Color(0xFF0EA5E9),
                  () => _callEmergencyContact('doctor'),
                  isDarkMode,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildEmergencyButton(
                  'Call Caregiver',
                  Icons.person,
                  const Color(0xFF059669),
                  () => _callEmergencyContact('caregiver'),
                  isDarkMode,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildEmergencyButton(
                  'Emergency',
                  Icons.emergency,
                  const Color(0xFFDC2626),
                  () => _callEmergencyContact('emergency'),
                  isDarkMode,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyButton(String label, IconData icon, Color color,
      VoidCallback onTap, bool isDarkMode) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: color,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _callEmergencyContact(String type) {
    // Emergency contact functionality
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Calling $type'),
        content: Text('Emergency contact feature would be activated.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Color _getConfidenceColor(double confidence, bool isDarkMode) {
    if (confidence >= 0.9) {
      return isDarkMode
          ? Colors.white.withOpacity(0.8)
          : const Color(0xFF475569);
    } else if (confidence >= 0.8) {
      return isDarkMode
          ? const Color(0xFFFFBE0B)
          : const Color(0xFFD97706); // Keep medical amber for warnings
    } else {
      return isDarkMode
          ? const Color(0xFFFF6B6B)
          : const Color(0xFFDC2626); // Keep medical red for critical
    }
  }

  Widget _buildDiagnosticCard({
    required bool isDarkMode,
    required IconData icon,
    required String title,
    required String subtitle,
    required String status,
    required Color statusColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : const Color(0xFF475569).withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon container
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: statusColor,
              size: 24,
            ),
          ),

          const SizedBox(width: 16),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.7)
                        : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),

          // Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required bool isDarkMode,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isPrimary,
    bool isEnabled = true,
  }) {
    final effectiveOpacity = isEnabled ? 1.0 : 0.5;
    
    return Opacity(
      opacity: effectiveOpacity,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: isPrimary
              ? (isDarkMode
                  ? Colors.white.withOpacity(0.1)
                  : const Color(0xFFF5F5F7))
              : (isDarkMode ? const Color(0xFF2A2A2A) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: isPrimary
              ? Border.all(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.2)
                      : const Color(0xFFE0E0E2),
                  width: 1,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: isDarkMode
                  ? Colors.black.withOpacity(0.3)
                  : const Color(0xFF475569).withOpacity(0.15),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: isEnabled ? () {
              HapticFeedback.lightImpact();
              // Action button logic
            } : null,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isPrimary
                          ? Colors.white.withOpacity(0.1)
                          : (isDarkMode
                              ? Colors.white.withOpacity(0.1)
                              : const Color(0xFFF5F5F7)),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: isPrimary
                          ? (isDarkMode
                              ? Colors.white.withOpacity(0.8)
                              : const Color(0xFF475569))
                          : (isDarkMode
                              ? Colors.white.withOpacity(0.8)
                              : const Color(0xFF475569)),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: isPrimary
                                ? (isDarkMode
                                    ? Colors.white
                                    : const Color(0xFF0F172A))
                                : (isDarkMode
                                    ? Colors.white
                                    : const Color(0xFF0F172A)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: isPrimary
                                ? (isDarkMode
                                    ? Colors.white.withOpacity(0.7)
                                    : const Color(0xFF475569))
                                : (isDarkMode
                                    ? Colors.white.withOpacity(0.7)
                                    : const Color(0xFF475569)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    CupertinoIcons.chevron_right,
                    color: isPrimary
                        ? Colors.white.withOpacity(0.8)
                        : (isDarkMode
                            ? Colors.white.withOpacity(0.5)
                            : const Color(0xFF475569).withOpacity(0.5)),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Custom painter for ECG wave
class ECGPainter extends CustomPainter {
  final List<double> data;
  final double animationValue;
  final bool isDarkMode;

  ECGPainter({
    required this.data,
    required this.animationValue,
    required this.isDarkMode,
  });

  double _hashNoise01(int n) {
    // Deterministic pseudo-random in [0, 1). No state, stable per index.
    n = (n ^ 0xDEADBEEF) * 2654435761;
    n = (n ^ (n >> 16)) * 2246822519;
    n = (n ^ (n >> 13)) * 3266489917;
    n = n ^ (n >> 16);
    return (n & 0x7FFFFFFF) / 0x80000000;
  }

  double _noiseSigned(int n) => (_hashNoise01(n) - 0.5) * 2.0;

  /// Produces a stable, organic-looking ECG trace (visual only).
  /// The goal is to match the reference screenshot: irregular baseline with
  /// occasional sharp spikes and small noisy clusters.
  double _organicSample(int i, int total, double t) {
    final n = _noiseSigned(i);
    final slow = math.sin((i / 22.0) + t * 2.2) * 0.20;
    final wander = math.sin((i / 75.0) + t * 0.9) * 0.12;

    // Base noise floor.
    var value = (slow + wander) * 0.35 + n * 0.10;

    // Place sparse impulses (spikes) at pseudo-random intervals.
    // Use a deterministic spacing so it doesn't look periodic.
    final seed = 9000 + total;
    final spacing = 92 + (_hashNoise01(seed) * 28).round(); // ~92..120
    final phase = (_hashNoise01(seed + 1) * spacing).round();

    final k = (i + phase) % spacing;
    // QRS-like: quick up, immediate down, settle.
    if (k == 0) {
      value += 1.35;
    } else if (k == 1) {
      value -= 0.55;
    } else if (k == 2) {
      value += 0.22;
    }

    // Add occasional noisy bursts to mimic irregular segments.
    final burstEvery = 260 + (_hashNoise01(seed + 2) * 90).round();
    final burstPhase = (_hashNoise01(seed + 3) * burstEvery).round();
    final b = (i + burstPhase) % burstEvery;
    if (b >= 0 && b < 18) {
      final envelope = (1.0 - (b / 18.0));
      value += _noiseSigned(seed + i * 7) * 0.55 * envelope;
    }

    // Clamp to a safe range.
    if (value > 1.6) value = 1.6;
    if (value < -1.2) value = -1.2;
    return value;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color =
          isDarkMode ? Colors.white.withOpacity(0.7) : const Color(0xFF475569)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    final baseY = size.height * 0.5;

    // Draw baseline
    final baselinePaint = Paint()
      ..color =
          (isDarkMode ? Colors.white : const Color(0xFF0F172A)).withOpacity(0.1)
      ..strokeWidth = 1.0;

    canvas.drawLine(
      Offset(0, baseY),
      Offset(size.width, baseY),
      baselinePaint,
    );

    // Draw additional grid lines
    for (int i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        baselinePaint,
      );
    }

    // Draw ECG wave
    if (data.isNotEmpty) {
      final total = data.length;
      final stepX = size.width / (total - 1);
      final amplitudePx = size.height * 0.42;
      final t = animationValue;
      // Larger values => waveform features appear farther apart.
      final spacingFactor = 7.0;

      double pointY(int i) {
        // Render an organic trace (visual), not a strictly periodic pattern.
        final sample = _organicSample((i * spacingFactor).round(), total, t);
        return baseY - (sample * amplitudePx);
      }

      path.moveTo(0, pointY(0));
      for (int i = 1; i < total; i++) {
        final xPrev = (i - 1) * stepX;
        final yPrev = pointY(i - 1);
        final x = i * stepX;
        final y = pointY(i);
        final midX = (xPrev + x) / 2;
        final midY = (yPrev + y) / 2;
        path.quadraticBezierTo(xPrev, yPrev, midX, midY);
        if (i == total - 1) {
          path.quadraticBezierTo(midX, midY, x, y);
        }
      }

      canvas.drawPath(path, paint);

      // Intentionally omit a moving indicator line; the UI overlay provides
      // the centered marker to match the reference design.
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Custom painter for Radial ECG-inspired progress indicator
class RadialECGPainter extends CustomPainter {
  final double progress;
  final List<double> ecgData;
  final bool isDarkMode;
  final double animationValue;

  RadialECGPainter({
    required this.progress,
    required this.ecgData,
    required this.isDarkMode,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // Background circle
    final backgroundPaint = Paint()
      ..color = isDarkMode ? const Color(0xFF374151) : const Color(0xFFF1F5F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;

    canvas.drawCircle(center, radius, backgroundPaint);

    // ECG-inspired progress arc
    final progressPaint = Paint()
      ..color =
          isDarkMode ? Colors.white.withOpacity(0.7) : const Color(0xFF475569)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    // Draw ECG pattern around the circle
    if (ecgData.isNotEmpty) {
      final path = Path();
      final sweepAngle = 2 * math.pi * progress;

      for (int i = 0;
          i < ecgData.length && i < (progress * ecgData.length);
          i++) {
        final angle = (i / ecgData.length) * sweepAngle - math.pi / 2;
        final ecgAmplitude = ecgData[i] * 8; // Scale ECG data
        final currentRadius = radius + ecgAmplitude;

        final x = center.dx + currentRadius * math.cos(angle);
        final y = center.dy + currentRadius * math.sin(angle);

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(path, progressPaint);
    }

    // Animated pulse dot
    final pulsePaint = Paint()
      ..color = (isDarkMode ? const Color(0xFFFFBE0B) : const Color(0xFFD97706))
          .withOpacity(
        0.5 + 0.5 * math.sin(animationValue * 2 * math.pi),
      )
      ..style = PaintingStyle.fill;

    final pulseRadius = 6 + 3 * math.sin(animationValue * 4 * math.pi);
    canvas.drawCircle(center, pulseRadius, pulsePaint);

    // Center confidence text
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${(progress * 100).toInt()}%',
        style: TextStyle(
          color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
