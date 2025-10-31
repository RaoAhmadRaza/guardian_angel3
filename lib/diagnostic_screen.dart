import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'theme/app_theme.dart' as theme;
import 'providers/theme_provider.dart';

class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen>
    with TickerProviderStateMixin {
  // Heartbeat monitoring data
  int _currentHeartRate = 82;
  List<double> _ecgData = [];
  List<int> _rrIntervals = [851, 841, 871, 881];
  Timer? _heartbeatTimer;

  // Animation controllers
  late AnimationController _ecgAnimationController;
  late AnimationController _pulseAnimationController;
  late AnimationController _aiAnalysisController;
  late AnimationController _rhythmPulseController;

  // Health status and AI analysis
  String _heartRhythm = "Normal Sinus Rhythm";
  String _aiAnalysisStatus = "Analyzing...";
  bool _isStressDetected = false;
  double _aiConfidence = 0.95;
  bool _isAIContainerExpanded = false;
  bool _hasExpandedOnce = false;

  // ECG Lead configuration
  String _selectedLead = "Lead II";

  // AI Confidence breakdown
  Map<String, double> _confidenceBreakdown = {
    'rhythm': 0.92,
    'variability': 0.89,
    'pattern': 0.94,
    'overall': 0.95,
  };

  // Alert system
  bool _showEmergencyActions = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startHeartbeatSimulation();
    _generateECGData();
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _ecgAnimationController.dispose();
    _pulseAnimationController.dispose();
    _aiAnalysisController.dispose();
    _rhythmPulseController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _ecgAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _aiAnalysisController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _rhythmPulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
  }

  void _startHeartbeatSimulation() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() {
          // Simulate realistic heartbeat variations
          _currentHeartRate = 78 + (math.Random().nextInt(10));
          _rrIntervals = [
            845 + math.Random().nextInt(20),
            835 + math.Random().nextInt(15),
            865 + math.Random().nextInt(25),
            875 + math.Random().nextInt(20),
          ];

          // AI Analysis and Rhythm Detection
          _performAIAnalysis();
        });
      }
    });
  }

  void _performAIAnalysis() {
    // Simulate AI analysis based on heart rate and R-R intervals
    final variability = _calculateRRVariability();

    // Reset alert state
    _showEmergencyActions = false;

    if (_currentHeartRate > 100) {
      _heartRhythm = "Sinus Tachycardia";
      _aiAnalysisStatus = "Elevated heart rate detected";
      _isStressDetected = true;
      _aiConfidence = 0.92;

      // Check for critical threshold
      if (_currentHeartRate > 120) {
        _showEmergencyActions = true;
      }
    } else if (_currentHeartRate < 60) {
      _heartRhythm = "Sinus Bradycardia";
      _aiAnalysisStatus = "Low heart rate detected";
      _isStressDetected = false;
      _aiConfidence = 0.88;

      // Check for critical threshold
      if (_currentHeartRate < 50) {
        _showEmergencyActions = true;
      }
    } else if (variability > 50) {
      _heartRhythm = "Possible Arrhythmia";
      _aiAnalysisStatus = "Irregular rhythm pattern";
      _isStressDetected = true;
      _aiConfidence = 0.85;
      _showEmergencyActions = true; // Arrhythmia always triggers alert
    } else {
      _heartRhythm = "Normal Sinus Rhythm";
      _aiAnalysisStatus = "Healthy rhythm pattern";
      _isStressDetected = false;
      _aiConfidence = 0.96;
    }

    // Update confidence breakdown based on analysis
    _confidenceBreakdown = {
      'rhythm': _aiConfidence,
      'variability': math.max(0.75, 1.0 - (variability / 100)),
      'pattern':
          _currentHeartRate >= 60 && _currentHeartRate <= 100 ? 0.95 : 0.80,
      'overall': _aiConfidence,
    };
  }

  // AI Analysis Showcase Container with Expandable Design
  Widget _buildAIShowcaseContainer(bool isDarkMode) {
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
                            _heartRhythm,
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
                            // Start one-time animation for expanded content
                            _aiAnalysisController.reset();
                            _aiAnalysisController.forward();
                          } else if (!_isAIContainerExpanded) {
                            _hasExpandedOnce = false; // Reset for next time
                          }
                        });
                        HapticFeedback.lightImpact();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.1)
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
                                  ? Colors.white.withOpacity(0.7)
                                  : const Color(0xFF475569),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Confidence: ${(_aiConfidence * 100).toInt()}%',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDarkMode
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    _aiAnalysisStatus,
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

            // Confidence Bars with Animation
            _buildAnimatedConfidenceBar('Rhythm Detection',
                _confidenceBreakdown['rhythm']!, isDarkMode),
            const SizedBox(height: 8),
            _buildAnimatedConfidenceBar('Variability',
                _confidenceBreakdown['variability']!, isDarkMode),
            const SizedBox(height: 8),
            _buildAnimatedConfidenceBar(
                'Pattern Match', _confidenceBreakdown['pattern']!, isDarkMode),

            const SizedBox(height: 20),

            // AI Status with Pulse Animation
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
                  AnimatedContainer(
                    duration: Duration(milliseconds: 800),
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: (isDarkMode
                              ? Colors.white.withOpacity(0.7)
                              : const Color(0xFF475569))
                          .withOpacity(_hasExpandedOnce &&
                                  _aiAnalysisController.status ==
                                      AnimationStatus.forward
                              ? 0.5 + 0.5 * _aiAnalysisController.value
                              : 1.0),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (isDarkMode
                                  ? Colors.white.withOpacity(0.3)
                                  : const Color(0xFF475569))
                              .withOpacity(0.3),
                          blurRadius: _hasExpandedOnce &&
                                  _aiAnalysisController.status ==
                                      AnimationStatus.forward
                              ? 8 + 4 * _aiAnalysisController.value
                              : 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _aiAnalysisStatus,
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
                  _showAIExplanation();
                  HapticFeedback.mediumImpact();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDarkMode
                          ? [
                              Colors.white.withOpacity(0.1),
                              Colors.white.withOpacity(0.05)
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
                      color: Colors.white,
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

  Widget _buildAnimatedConfidenceBar(
      String label, double confidence, bool isDarkMode) {
    return AnimatedBuilder(
      animation: _aiAnalysisController,
      builder: (context, child) {
        // Use full confidence value if animation is complete or not expanded
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
                widthFactor: animatedConfidence,
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildAIExplanationModal(),
    );
  }

  Widget _buildAIExplanationModal() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

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
                    'Examined heart rhythm patterns for regularity and consistency. Your rhythm shows $_heartRhythm characteristics.',
                    _confidenceBreakdown['rhythm']!,
                    Icons.favorite,
                    isDarkMode,
                  ),
                  const SizedBox(height: 16),
                  _buildExplanationCard(
                    'R-R Variability',
                    'Analyzed intervals between heartbeats. Healthy variation indicates good autonomic function.',
                    _confidenceBreakdown['variability']!,
                    Icons.show_chart,
                    isDarkMode,
                  ),
                  const SizedBox(height: 16),
                  _buildExplanationCard(
                    'Pattern Recognition',
                    'AI detected ECG patterns and compared with medical standards. All patterns appear within normal ranges.',
                    _confidenceBreakdown['pattern']!,
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
    if (_heartRhythm.contains("Arrhythmia") || _isStressDetected) {
      return const Color(0xFFFFBE0B); // Warning yellow
    } else if (_heartRhythm.contains("Tachycardia") ||
        _heartRhythm.contains("Bradycardia")) {
      return const Color(0xFFD97706); // Orange for mild concern
    } else {
      return const Color(0xFF059669); // Green for normal
    }
  }

  double _calculateRRVariability() {
    if (_rrIntervals.length < 2) return 0;

    double sum = 0;
    for (int i = 1; i < _rrIntervals.length; i++) {
      sum += (_rrIntervals[i] - _rrIntervals[i - 1]).abs();
    }
    return sum / (_rrIntervals.length - 1);
  }

  void _generateECGData() {
    // Generate realistic ECG wave pattern with variability
    _ecgData = List.generate(100, (index) {
      double t = index / 20.0;

      // Add realistic noise and variability
      double baseNoise =
          (math.Random().nextDouble() - 0.5) * 0.03; // ±1.5% noise
      double amplitudeVariability =
          0.85 + (math.Random().nextDouble() * 0.3); // 0.85-1.15x
      double durationVariability =
          1.0 + (math.Random().nextDouble() * 0.15 - 0.075); // ±7.5%

      // Simulate P-QRS-T complex with variability
      if (index % 25 < 5) {
        // P wave with slight variations
        return (0.1 *
                math.sin(t * 2 * math.pi * durationVariability) *
                amplitudeVariability +
            baseNoise);
      } else if (index % 25 < 15) {
        // QRS complex with more pronounced variability
        return (0.8 *
                math.sin(t * 4 * math.pi * durationVariability) *
                amplitudeVariability +
            baseNoise);
      } else {
        // T wave with gentle variations
        return (0.2 *
                math.sin(t * math.pi * durationVariability) *
                amplitudeVariability +
            baseNoise);
      }
    });
  }

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

                      // Emergency Actions (shown only when in alert state)
                      if (_showEmergencyActions) ...[
                        const SizedBox(height: 16),
                        _buildEmergencyActionsCard(isDarkMode),
                      ],

                      const SizedBox(height: 24),

                      // Original diagnostic cards
                      _buildDiagnosticCard(
                        isDarkMode: isDarkMode,
                        icon: CupertinoIcons.waveform,
                        title: 'Blood Pressure',
                        subtitle: 'Systolic and diastolic readings',
                        status: 'Optimal',
                        statusColor:
                            const Color(0xFF475569), // Changed from Colors.blue
                      ),

                      const SizedBox(height: 16),

                      _buildDiagnosticCard(
                        isDarkMode: isDarkMode,
                        icon: CupertinoIcons.thermometer,
                        title: 'Body Temperature',
                        subtitle: 'Core temperature monitoring',
                        status: 'Normal',
                        statusColor: const Color(
                            0xFF475569), // Changed from Colors.green
                      ),

                      const SizedBox(height: 16),

                      _buildDiagnosticCard(
                        isDarkMode: isDarkMode,
                        icon: CupertinoIcons.moon_zzz_fill,
                        title: 'Sleep Quality',
                        subtitle: 'Sleep patterns and quality analysis',
                        status: 'Good',
                        statusColor: const Color(
                            0xFF475569), // Changed from Colors.purple
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
                        subtitle: 'Previous diagnostic reports',
                        icon: CupertinoIcons.doc_text_fill,
                        isPrimary: false,
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
                child: AnimatedBuilder(
                  animation: _pulseAnimationController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1.0 + (_pulseAnimationController.value * 0.1),
                      child: Icon(
                        CupertinoIcons.heart_fill,
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.7)
                            : const Color(0xFF475569),
                        size: 24,
                      ),
                    );
                  },
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
                            ? const Color(0xFF374151).withOpacity(0.7)
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
                '$_currentHeartRate',
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w700,
                  color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
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
                      ? const Color(0xFF374151).withOpacity(0.7)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '80 bpm',
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

          // ECG Wave visualization
          Container(
            height: 120,
            width: double.infinity,
            child: CustomPaint(
              painter: ECGPainter(
                data: _ecgData,
                animationValue: _ecgAnimationController.value,
                isDarkMode: isDarkMode,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // R-R Interval Analysis Card
  Widget _buildRRIntervalCard(bool isDarkMode) {
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
                      '${_rrIntervals.first} ms',
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
              widthFactor: 0.7,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _rrIntervals.map((interval) {
              return Text(
                '${interval}ms',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.8)
                      : const Color(0xFF475569),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Results Summary Card (Simplified)
  Widget _buildResultsCard(bool isDarkMode) {
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
              // Status dot
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
              ),
              const SizedBox(width: 12),

              // Heart rhythm text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _heartRhythm,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color:
                            isDarkMode ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _aiAnalysisStatus,
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
                  '${(_aiConfidence * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.8)
                        : const Color(0xFF475569),
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
  }) {
    return Container(
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
          onTap: () {
            HapticFeedback.lightImpact();
            // Action button logic
          },
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
      final stepX = size.width / data.length;

      for (int i = 0; i < data.length; i++) {
        final x = i * stepX;
        final y = baseY - (data[i] * size.height * 0.3);

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(path, paint);

      // Draw moving indicator line
      final indicatorX = size.width * animationValue;
      final indicatorPaint = Paint()
        ..color = isDarkMode ? const Color(0xFFFFBE0B) : const Color(0xFFD97706)
        ..strokeWidth = 2.0;

      canvas.drawLine(
        Offset(indicatorX, 0),
        Offset(indicatorX, size.height),
        indicatorPaint,
      );
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
