import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'colors.dart';
import 'providers/theme_provider.dart';
import 'theme/motion.dart';
import 'services/battery_stream.dart';
import 'services/session_service.dart';
import 'next_screen.dart';

/// Connection states for the watch pairing process
enum WatchConnectionState {
  scanning,
  found,
  pairing,
  connected,
}

/// Premium watch connection screen with iOS-level polish and elegance
///
/// Features 3D watch visualization, smart pairing animations, and seamless transitions
/// with sophisticated micro-animations and physics-based interactions.
class WatchConnectionScreen extends StatefulWidget {
  final String selectedGender;
  final String patientName;

  const WatchConnectionScreen({
    super.key,
    required this.selectedGender,
    required this.patientName,
  });

  @override
  State<WatchConnectionScreen> createState() => _WatchConnectionScreenState();
}

class _WatchConnectionScreenState extends State<WatchConnectionScreen>
    with TickerProviderStateMixin {
  // Battery monitoring
  final BatteryStream _battery = BatteryStream();
  int _batteryLevel = 100;
  late StreamSubscription<int> _batteryLevelSubscription;

  // Connection states
  WatchConnectionState _connectionState = WatchConnectionState.scanning;
  String _detectedWatchName = 'Apple Watch Series 9';
  String _pairingCode = '';
  double _connectionProgress = 0.0;

  // Animation controllers
  late AnimationController _breathingController;
  late AnimationController _waveController;
  late AnimationController _progressController;
  late AnimationController _successController;
  late AnimationController _pulseController;

  // Animations
  late Animation<double> _breathingAnimation;
  late Animation<double> _waveAnimation;
  late Animation<double> _progressAnimation;
  late Animation<double> _successAnimation;
  late Animation<double> _pulseAnimation;

  Timer? _connectionTimer;

  // Scroll-to-connect variables
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToConnect = false;
  bool _canConnect = false;
  bool _animationsFrozen = false; // New flag to freeze all animations
  double _scrollThreshold = 200.0; // pixels to scroll down for connection

  @override
  void initState() {
    super.initState();

    // Debug prints to check received data
    print('WatchConnectionScreen - selectedGender: ${widget.selectedGender}');
    print('WatchConnectionScreen - patientName: ${widget.patientName}');

    _initBatteryMonitoring();
    _initAnimations();
    _generatePairingCode();
    _setupScrollListener();
    // Remove auto-start of connection sequence
    // _startConnectionSequence();
  }

  void _setupScrollListener() {
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_connectionState == WatchConnectionState.scanning &&
        !_hasScrolledToConnect &&
        _scrollController.offset > _scrollThreshold) {
      _hasScrolledToConnect = true;
      _canConnect = true;
      _startConnectionSequence();

      // Stop pulse animation since we're transitioning away from scanning
      _pulseController.stop();

      // Freeze animations for smoother transition
      setState(() {
        _animationsFrozen = true;
      });

      // Stop specific animations (but keep breathing + wave alive)
      _freezeAllAnimations();

      // Remove this listener after triggering connection
      _scrollController.removeListener(_scrollListener);
    }
  }

  void _freezeAllAnimations() {
    // Only stop pulse animation - keep breathing + wave alive for premium feel
    _pulseController.stop();
    // breathing + wave keep looping for that "alive" premium interface
  }

  void _initAnimations() {
    // Breathing effect for watch
    _breathingController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _breathingAnimation = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(
      parent: _breathingController,
      curve: Curves.easeInOut,
    ));

    // Connection waves
    _waveController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: Curves.easeOut,
    ));

    // Progress indicator
    _progressController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));

    // Success animation
    _successController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _successAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    ));

    // Pulse effect
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Start essential animations that should always loop
    _breathingController.repeat(reverse: true); // Always alive for premium feel
    _waveController.repeat(); // Always alive for premium feel

    // Start pulse conditionally based on connection state
    if (_connectionState == WatchConnectionState.scanning) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
    }
  }

  void _generatePairingCode() {
    final random = math.Random();
    _pairingCode = List.generate(6, (index) => random.nextInt(10)).join();
  }

  void _startConnectionSequence() {
    // Only start if user has scrolled to connect
    if (!_canConnect) return;

    // Simulate realistic connection timing with staggered animations
    _connectionTimer =
        Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        switch (_connectionState) {
          case WatchConnectionState.scanning:
            _connectionState = WatchConnectionState.found;
            // Stop pulse animation with delay for smooth transition
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted) _pulseController.stop();
            });
            break;
          case WatchConnectionState.found:
            _connectionState = WatchConnectionState.pairing;
            // Start progress animation with smooth entrance
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) _progressController.forward();
            });
            break;
          case WatchConnectionState.pairing:
            _connectionProgress += 0.15;
            if (_connectionProgress >= 1.0) {
              _connectionState = WatchConnectionState.connected;
              // Staggered success sequence
              Future.delayed(const Duration(milliseconds: 200), () {
                if (mounted) _successController.forward();
              });
              HapticFeedback.mediumImpact();
              timer.cancel();
            }
            break;
          case WatchConnectionState.connected:
            timer.cancel();
            break;
        }
      });
    });
  }

  void _initBatteryMonitoring() {
    // Get initial battery level
    _batteryLevel = _battery.batteryLevel;

    // Listen to real-time battery level stream with 10-second updates
    _batteryLevelSubscription = _battery
        .batteryLevelStreamWithStateChanges(
            interval: const Duration(seconds: 10))
        .listen(
      (level) {
        if (mounted && level != _batteryLevel) {
          setState(() {
            _batteryLevel = level;
          });
        }
      },
      onError: (error) {
        debugPrint('Battery stream error: $error');
        // Keep current level on error
      },
    );
  }

  @override
  void dispose() {
    _batteryLevelSubscription.cancel();
    _connectionTimer?.cancel();
    _scrollController.dispose();
    _breathingController.dispose();
    _waveController.dispose();
    _progressController.dispose();
    _successController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  /// Connection states for the pairing process
  String get _connectionStatusText {
    switch (_connectionState) {
      case WatchConnectionState.scanning:
        return _hasScrolledToConnect
            ? 'Connecting to your watch...'
            : 'Ready to connect your watch';
      case WatchConnectionState.found:
        return 'Watch found! Ready to pair';
      case WatchConnectionState.pairing:
        return 'Establishing secure connection';
      case WatchConnectionState.connected:
        return 'Successfully connected!';
    }
  }

  /// Get connection status color
  Color _getStatusColor(bool isDarkMode) {
    switch (_connectionState) {
      case WatchConnectionState.scanning:
        return isDarkMode
            ? Colors.white.withOpacity(0.7)
            : const Color(0xFF475569); // Signup secondary text color
      case WatchConnectionState.found:
        return isDarkMode
            ? const Color(0xFF59C2B8)
            : const Color(0xFF06B6D4); // Signup accent color (cyan)
      case WatchConnectionState.pairing:
        return isDarkMode
            ? const Color(0xFF667EEA)
            : const Color(0xFF4F46E5); // Signup primary color (indigo)
      case WatchConnectionState.connected:
        return isDarkMode
            ? const Color(0xFF30D158)
            : const Color(0xFF10B981); // Professional green
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ThemeProvider.instance.isDarkMode;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: isDarkMode
              ? AppTheme.primaryGradient
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFBFBFB), // Very light off-white at top
                    Color(0xFFF8F9FA), // Neutral light gray
                    Color(0xFFF1F3F4), // Subtle medium gray
                    Color(0xFFE8EAED), // Gentle border-like gray at bottom
                  ],
                  stops: [0.0, 0.3, 0.7, 1.0],
                ),
        ),
        child: Stack(
          children: [
            // Premium background effects
            _buildBackgroundEffects(isDarkMode),
            SafeArea(
              child: Column(
                children: [
                  _buildMinimalHeader(isDarkMode),
                  const SizedBox(height: 32),
                  _buildHeroTitle(isDarkMode),
                  const SizedBox(height: 32),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          _buildPremiumWatchVisualization(isDarkMode),
                          const SizedBox(height: 28),
                          _buildConnectionStatus(isDarkMode),
                          const SizedBox(height: 24),
                          if (_connectionState == WatchConnectionState.pairing)
                            _buildPairingCodeSection(isDarkMode),
                          if (_connectionState == WatchConnectionState.pairing)
                            const SizedBox(height: 24),
                          _buildPremiumActionButton(isDarkMode),
                          const SizedBox(height: 16),
                          _buildTroubleshootLink(isDarkMode),

                          // Add scroll instruction for scanning state
                          if (_connectionState ==
                                  WatchConnectionState.scanning &&
                              !_hasScrolledToConnect)
                            _buildScrollInstruction(isDarkMode),

                          const SizedBox(
                              height: 300), // Extra space for scrolling
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Premium background effects with subtle depth
  Widget _buildBackgroundEffects(bool isDarkMode) {
    // Return static background when animations are frozen
    if (_animationsFrozen) {
      return Stack(
        children: [
          // Static floating shapes - no animation
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (isDarkMode
                            ? const Color(0xFF667EEA)
                            : const Color(0xFF0A84FF))
                        .withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (isDarkMode
                            ? const Color(0xFF764BA2)
                            : const Color(0xFF59C2B8))
                        .withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Static geometric element
          Positioned(
            top: 200,
            left: 50,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.1),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Original animated background when animations are active
    return Stack(
      children: [
        // Animated floating shapes
        Positioned(
          top: -100,
          right: -50,
          child: AnimatedBuilder(
            animation: _breathingAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _breathingAnimation.value,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        (isDarkMode
                                ? const Color(0xFF667EEA)
                                : const Color(0xFF0A84FF))
                            .withOpacity(0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          bottom: -150,
          left: -100,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        (isDarkMode
                                ? const Color(0xFF764BA2)
                                : const Color(0xFF59C2B8))
                            .withOpacity(0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Floating geometric elements
        Positioned(
          top: 200,
          left: 50,
          child: AnimatedBuilder(
            animation: _waveAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _waveAnimation.value * 2 * math.pi,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.1),
                        Colors.white.withOpacity(0.05),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Minimal, elegant header with just the theme toggle
  Widget _buildMinimalHeader(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.15)
                  : Colors.white.withOpacity(0.9),
              border: isDarkMode
                  ? null
                  : Border.all(
                      color: const Color(0xFFE0E0E0),
                      width: 1,
                    ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: isDarkMode
                      ? Colors.black.withOpacity(0.2)
                      : const Color(0xFF475569).withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(
                ThemeProvider.instance.themeIcon,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.9)
                    : const Color(0xFF404040),
                size: 18,
              ),
              onPressed: () async {
                HapticFeedback.lightImpact();
                await ThemeProvider.instance.toggleTheme();
              },
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms);
  }

  /// Large, impactful hero title with premium typography
  Widget _buildHeroTitle(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Text(
            'Connect Your\nApple Watch',
            style: GoogleFonts.inter(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
              height: 1.1,
              letterSpacing: -1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Experience seamless health monitoring\nwith premium connectivity',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w400,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.7)
                  : const Color(0xFF475569),
              height: 1.4,
              letterSpacing: -0.2,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 1000.ms, delay: 200.ms).slideY(begin: 0.3);
  }

  /// Premium 3D watch visualization with smooth state transitions
  Widget _buildPremiumWatchVisualization(bool isDarkMode) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      switchInCurve: Curves.easeInOutCubic,
      switchOutCurve: Curves.easeInOutCubic,
      transitionBuilder: (child, animation) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: _connectionState == WatchConnectionState.connected
                ? Curves.easeOutBack // Bounce when checkmark appears
                : Curves.easeInOutCubic,
          ),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      child: _buildStateSpecificVisualization(isDarkMode),
    );
  }

  /// Build visualization based on current connection state
  Widget _buildStateSpecificVisualization(bool isDarkMode) {
    // Use state as key to trigger AnimatedSwitcher transition
    return Container(
      key: ValueKey(_connectionState),
      child: _buildWatchWithEffects(isDarkMode),
    );
  }

  /// Watch visualization with state-based effects
  Widget _buildWatchWithEffects(bool isDarkMode) {
    // Static version when animations are frozen
    if (_animationsFrozen) {
      return _buildStaticWatchContainer(isDarkMode);
    }

    // Animated version with state-based effects
    return AnimatedBuilder(
      animation: Listenable.merge(
          [_breathingAnimation, _waveAnimation, _successAnimation]),
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Connection waves - only show during found/pairing states
            if (_connectionState != WatchConnectionState.scanning &&
                _connectionState != WatchConnectionState.connected)
              ...List.generate(3, (index) {
                final delay = index * 0.3;
                final opacity =
                    (1.0 - (_waveAnimation.value + delay).clamp(0.0, 1.0)) *
                        0.3;
                final scale = 1.0 + (_waveAnimation.value + delay) * 2;

                return AnimatedScale(
                  scale: scale,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _getStatusColor(isDarkMode).withOpacity(opacity),
                        width: 2,
                      ),
                    ),
                  ),
                );
              }),

            // Watch container with premium breathing effect
            AnimatedScale(
              scale: _breathingAnimation.value *
                  (_connectionState == WatchConnectionState.connected
                      ? _successAnimation.value * 1.1 + 0.9
                      : 1.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: isDarkMode
                        ? [
                            Colors.white.withOpacity(0.25),
                            Colors.white.withOpacity(0.05),
                          ]
                        : [
                            const Color(0xFFFFFFFF),
                            const Color(0xFFF8F9FA),
                          ],
                  ),
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.2)
                        : const Color(0xFFE0E0E0),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDarkMode
                          ? Colors.black.withOpacity(0.3)
                          : const Color(0xFF475569).withOpacity(0.1),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                      spreadRadius: 5,
                    ),
                    BoxShadow(
                      color: Colors.white.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Center(
                  child: _build3DWatch(isDarkMode),
                ),
              ),
            ),

            // Success checkmark with premium entrance animation
            if (_connectionState == WatchConnectionState.connected)
              AnimatedScale(
                scale: _successAnimation.value,
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutBack,
                child: AnimatedOpacity(
                  opacity: _successAnimation.value,
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOut,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFF30D158),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF30D158).withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Static watch container for frozen state
  Widget _buildStaticWatchContainer(bool isDarkMode) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Static watch container
        Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: isDarkMode
                  ? [
                      Colors.white.withOpacity(0.25),
                      Colors.white.withOpacity(0.05),
                    ]
                  : [
                      const Color(0xFFFFFFFF),
                      const Color(0xFFF8F9FA),
                    ],
            ),
            border: Border.all(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.2)
                  : const Color(0xFFE0E0E0),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDarkMode
                    ? Colors.black.withOpacity(0.3)
                    : const Color(0xFF475569).withOpacity(0.1),
                blurRadius: 30,
                offset: const Offset(0, 10),
                spreadRadius: 5,
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Center(
            child: _build3DWatch(isDarkMode),
          ),
        ),

        // Static success checkmark if connected
        if (_connectionState == WatchConnectionState.connected)
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF30D158),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF30D158).withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
      ],
    );
  }

  /// Realistic 3D watch render with subtle details
  Widget _build3DWatch(bool isDarkMode) {
    return Container(
      width: 100,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Watch body shadow
          Positioned(
            bottom: 0,
            child: Container(
              width: 80,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Watch body
          Container(
            width: 70,
            height: 85,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF2C2C2E),
                  const Color(0xFF1C1C1E),
                  const Color(0xFF000000),
                ],
              ),
              border: Border.all(
                color: const Color(0xFF3A3A3C),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.1),
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Watch screen
                Center(
                  child: Container(
                    width: 55,
                    height: 68,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF000000),
                          const Color(0xFF1C1C1E),
                        ],
                      ),
                      border: Border.all(
                        color: const Color(0xFF2C2C2E),
                        width: 1,
                      ),
                    ),
                    child: _connectionState == WatchConnectionState.connected
                        ? const Icon(
                            Icons.favorite,
                            color: Color(0xFFFF453A),
                            size: 20,
                          )
                        : Container(
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color:
                                  _getStatusColor(isDarkMode).withOpacity(0.3),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.watch,
                                color: _getStatusColor(isDarkMode),
                                size: 16,
                              ),
                            ),
                          ),
                  ),
                ),

                // Digital crown
                Positioned(
                  right: -1,
                  top: 20,
                  child: Container(
                    width: 6,
                    height: 15,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF3A3A3C),
                          Color(0xFF2C2C2E),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Watch bands
          Positioned(
            top: -10,
            child: Container(
              width: 20,
              height: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF2C2C2E),
                    Color(0xFF1C1C1E),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -10,
            child: Container(
              width: 20,
              height: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF1C1C1E),
                    Color(0xFF2C2C2E),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Connection status display with smooth state transitions
  Widget _buildConnectionStatus(bool isDarkMode) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.fastLinearToSlowEaseIn,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.3),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      child: Container(
        key: ValueKey('${_connectionState}_${_hasScrolledToConnect}'),
        child: Column(
          children: [
            AnimatedBuilder(
              animation: _progressAnimation,
              builder: (context, child) {
                return Container(
                  width: 280,
                  child: Column(
                    children: [
                      // Status text with color transition
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(isDarkMode),
                          letterSpacing: -0.2,
                        ),
                        child: Text(
                          _connectionStatusText,
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Progress indicator with smooth appearance
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeInOutCubic,
                        height: _connectionState == WatchConnectionState.pairing
                            ? 6
                            : 0,
                        child: _connectionState == WatchConnectionState.pairing
                            ? Container(
                                width: 200,
                                height: 6,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(3),
                                  color: isDarkMode
                                      ? Colors.white.withOpacity(0.1)
                                      : const Color(0xFFE0E0E0),
                                ),
                                child: Stack(
                                  children: [
                                    AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      width: 200 * _progressAnimation.value,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(3),
                                        gradient: LinearGradient(
                                          colors: isDarkMode
                                              ? [
                                                  const Color(
                                                      0xFF64748B), // Slate gray
                                                  const Color(
                                                      0xFF475569), // Darker slate
                                                ]
                                              : [
                                                  const Color(
                                                      0xFF475569), // Dark slate
                                                  const Color(
                                                      0xFF334155), // Darker slate
                                                ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),

                      // Detected watch info with slide-in animation
                      if (_connectionState !=
                          WatchConnectionState.scanning) ...[
                        const SizedBox(height: 24),
                        AnimatedSlide(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutCubic,
                          offset:
                              _connectionState != WatchConnectionState.scanning
                                  ? Offset.zero
                                  : const Offset(0, 0.5),
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 400),
                            opacity: _connectionState !=
                                    WatchConnectionState.scanning
                                ? 1.0
                                : 0.0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: isDarkMode
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.white.withOpacity(0.9),
                                border: Border.all(
                                  color: isDarkMode
                                      ? Colors.white.withOpacity(0.1)
                                      : const Color(0xFFE0E0E0),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDarkMode
                                        ? Colors.transparent
                                        : const Color(0xFF475569)
                                            .withOpacity(0.06),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Status indicator with pulse animation
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(isDarkMode),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 300),
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: isDarkMode
                                          ? Colors.white.withOpacity(0.9)
                                          : const Color(0xFF0F172A),
                                    ),
                                    child: Text(_detectedWatchName),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ).animate().fadeIn(
        duration: _animationsFrozen ? 0.ms : 800.ms,
        delay: _animationsFrozen ? 0.ms : 600.ms);
  }

  /// Security pairing code section
  Widget _buildPairingCodeSection(bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: isDarkMode
            ? LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.08),
                  Colors.white.withOpacity(0.04),
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.95),
                  Colors.white.withOpacity(0.85),
                ],
              ),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.1)
              : const Color(0xFFE0E0E0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.2)
                : const Color(0xFF475569).withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Security Code',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.9)
                  : const Color(0xFF0F172A),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Verify this code matches your watch',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.6)
                  : const Color(0xFF475569),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Pairing code display
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _pairingCode.split('').map((digit) {
              return Container(
                width: 40,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.1)
                      : Colors.white.withOpacity(0.9),
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.2)
                        : const Color(0xFFE0E0E0),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDarkMode
                          ? Colors.transparent
                          : const Color(0xFF475569).withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    digit,
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color:
                          isDarkMode ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    ).animate().slideY(begin: 0.3, duration: 800.ms, delay: 400.ms);
  }

  /// Premium action button with dynamic states
  Widget _buildPremiumActionButton(bool isDarkMode) {
    String buttonText;
    bool isEnabled;
    VoidCallback? onPressed;

    switch (_connectionState) {
      case WatchConnectionState.scanning:
        buttonText = 'Searching...';
        isEnabled = false;
        onPressed = null;
        break;
      case WatchConnectionState.found:
        buttonText = 'Start Pairing';
        isEnabled = true;
        onPressed = () {
          HapticFeedback.mediumImpact();
          // Start pairing process
        };
        break;
      case WatchConnectionState.pairing:
        buttonText = 'Connecting...';
        isEnabled = false;
        onPressed = null;
        break;
      case WatchConnectionState.connected:
        buttonText = 'Continue';
        isEnabled = true;
        onPressed = () async {
          HapticFeedback.lightImpact();
          // Start user session when they complete watch connection
          // Get the current user's UID
          final uid = FirebaseAuth.instance.currentUser?.uid ?? 
                      await SessionService.instance.getCurrentUid();
          await SessionService.instance.startSession(userType: 'patient', uid: uid);

          // Debug prints to check what data is being passed to NextScreen
          print(
              'WatchConnectionScreen - passing to NextScreen selectedGender: ${widget.selectedGender}');
          print(
              'WatchConnectionScreen - passing to NextScreen patientName: ${widget.patientName}');

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => NextScreen(
                selectedGender: widget.selectedGender,
                patientName: widget.patientName,
              ),
            ),
            (route) => false, // Remove all previous routes
          );
        };
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: isEnabled
              ? (isDarkMode
                  ? AppTheme.primaryGradient
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFDFDFD), // off-white (signup button colors)
                        Color(0xFFF5F5F7), // light cloud grey
                        Color(0xFFE0E0E2), // gentle cool grey
                      ],
                    ))
              : LinearGradient(
                  colors: [
                    Colors.grey.withOpacity(0.3),
                    Colors.grey.withOpacity(0.2),
                  ],
                ),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: isDarkMode
                        ? const Color(0xFF475569).withOpacity(0.2)
                        : const Color(0xFF475569).withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: onPressed,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_connectionState == WatchConnectionState.pairing)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDarkMode ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  if (_connectionState == WatchConnectionState.pairing)
                    const SizedBox(width: 12),
                  Text(
                    buttonText,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color:
                          isDarkMode ? Colors.white : const Color(0xFF0F172A),
                      letterSpacing: 0.3,
                    ),
                  ),
                  if (_connectionState == WatchConnectionState.connected) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward,
                      color:
                          isDarkMode ? Colors.white : const Color(0xFF0F172A),
                      size: 20,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().slideY(begin: 0.5, duration: 800.ms, delay: 800.ms);
  }

  /// Helper method to conditionally apply flutter_animate effects
  Widget _conditionalAnimate(Widget child, List<Effect> effects) {
    if (_animationsFrozen) {
      return child; // Return widget without animations when frozen
    }
    return child.animate().addEffects(effects);
  }

  /// Minimal troubleshoot link
  Widget _buildTroubleshootLink(bool isDarkMode) {
    return TextButton(
      onPressed: () {
        HapticFeedback.lightImpact();
        // Show troubleshoot options
      },
      child: Text(
        'Having trouble? Switch watch type',
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDarkMode
              ? Colors.white.withOpacity(0.6)
              : const Color(0xFF404040), // Signup link color
          decoration: TextDecoration.underline,
        ),
      ),
    ).animate().fadeIn(
        duration: _animationsFrozen ? 0.ms : 800.ms,
        delay: _animationsFrozen ? 0.ms : 1000.ms);
  }

  /// Subtle scroll instruction with premium entrance animation
  Widget _buildScrollInstruction(bool isDarkMode) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      margin: EdgeInsets.only(
        top: _connectionState == WatchConnectionState.scanning &&
                !_hasScrolledToConnect
            ? 60
            : 0,
        bottom: _connectionState == WatchConnectionState.scanning &&
                !_hasScrolledToConnect
            ? 40
            : 0,
      ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 500),
        opacity: _connectionState == WatchConnectionState.scanning &&
                !_hasScrolledToConnect
            ? 1.0
            : 0.0,
        child: Column(
          children: [
            // Animated scroll indicator with premium pulse
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return AnimatedScale(
                  scale: _pulseAnimation.value,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.3)
                            : const Color(0xFF404040).withOpacity(0.4),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.6)
                          : const Color(0xFF404040),
                      size: 24,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Instruction text with staggered entrance
            AnimatedSlide(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              offset: _connectionState == WatchConnectionState.scanning &&
                      !_hasScrolledToConnect
                  ? Offset.zero
                  : const Offset(0, 0.3),
              child: Text(
                'Scroll down to connect',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.6)
                      : const Color(0xFF475569), // Signup secondary text color
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Subtle hint with delayed entrance
            AnimatedSlide(
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              offset: _connectionState == WatchConnectionState.scanning &&
                      !_hasScrolledToConnect
                  ? Offset.zero
                  : const Offset(0, 0.5),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 500),
                opacity: _connectionState == WatchConnectionState.scanning &&
                        !_hasScrolledToConnect
                    ? 0.8
                    : 0.0,
                child: Text(
                  'Pull gently to start pairing',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.4)
                        : const Color(0xFF64748B).withOpacity(0.8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 1000.ms, delay: 1200.ms);
  }

  /// Battery color helper methods
  Color _getBatteryColor() {
    if (_batteryLevel >= 80) {
      return const Color(0xFF30D158); // Green - full battery
    } else if (_batteryLevel >= 60) {
      return const Color(0xFF59C2B8); // Teal - good battery
    } else if (_batteryLevel >= 40) {
      return const Color(0xFFFF9500); // Amber - medium battery
    } else if (_batteryLevel >= 20) {
      return const Color(0xFFFF9800); // Orange - low battery
    } else {
      return const Color(0xFFFF453A); // Red - critical battery
    }
  }

  Color _getBatteryBackgroundColor() {
    if (_batteryLevel >= 80) {
      return const Color(0xFF30D158).withOpacity(0.15);
    } else if (_batteryLevel >= 60) {
      return const Color(0xFF59C2B8).withOpacity(0.15);
    } else if (_batteryLevel >= 40) {
      return const Color(0xFFFF9500).withOpacity(0.15);
    } else if (_batteryLevel >= 20) {
      return const Color(0xFFFF9800).withOpacity(0.15);
    } else {
      return const Color(0xFFFF453A).withOpacity(0.15);
    }
  }

  IconData _getBatteryIcon() {
    if (_batteryLevel >= 90) {
      return Icons.battery_full;
    } else if (_batteryLevel >= 60) {
      return Icons.battery_6_bar;
    } else if (_batteryLevel >= 40) {
      return Icons.battery_4_bar;
    } else if (_batteryLevel >= 20) {
      return Icons.battery_2_bar;
    } else {
      return Icons.battery_alert;
    }
  }

  /// Builds the centered title section - iOS style
  Widget _buildCenteredTitle() {
    final isDarkMode = ThemeProvider.instance.isDarkMode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text(
            'Ready to sync your watch?',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
              height: 1.2,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Let\'s get you connected! 🚀',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.8)
                  : const Color(0xFF475569),
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          // Decorative line matching User Selection screen
          Container(
            width: 80,
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(1.5),
              gradient: LinearGradient(
                colors: isDarkMode
                    ? [
                        Colors.white.withOpacity(0.6),
                        Colors.white.withOpacity(0.3),
                      ]
                    : [
                        Colors.black.withOpacity(0.3),
                        Colors.black.withOpacity(0.1),
                      ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms).slideY(begin: -0.3);
  }

  /// Builds the greeting section with avatar and patient name - iOS style
  Widget _buildGreetingSection() {
    final isDarkMode = ThemeProvider.instance.isDarkMode;

    return Row(
      children: [
        Hero(
          tag: 'patient_avatar',
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.3),
                  Colors.white.withOpacity(0.1),
                ],
              ),
              border: Border.all(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.4)
                    : Colors.white.withOpacity(0.6),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDarkMode
                      ? Colors.black.withOpacity(0.2)
                      : const Color(0xFF475569).withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'images/${widget.selectedGender}.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.white.withOpacity(0.2),
                    child: Icon(
                      widget.selectedGender == 'male'
                          ? Icons.person
                          : Icons.person_outline,
                      color:
                          isDarkMode ? Colors.white : const Color(0xFF475569),
                      size: 30,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            'Hello, ${widget.patientName}!'.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
              letterSpacing: 0.5,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ).animate().slideX(begin: 0.3, duration: AppMotion.medium);
  }

  /// Builds the battery monitoring card with iOS-like design matching User Selection screen
  Widget _buildTrackingCard() {
    final isDarkMode = ThemeProvider.instance.isDarkMode;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: isDarkMode
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF374151).withOpacity(0.7),
                  const Color(0xFF4B5563).withOpacity(0.6),
                  const Color(0xFF6B7280).withOpacity(0.5),
                ],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFDFDFD), // off-white
                  Color(0xFFF5F5F7), // light cloud grey
                  Color(0xFFE0E0E2), // gentle cool grey
                ],
              ),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.2)
              : const Color(0xFFE0E0E0).withOpacity(0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.2)
                : const Color(0xFF475569).withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          if (!isDarkMode)
            BoxShadow(
              color: const Color(0xFF475569).withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, -2),
              spreadRadius: 0,
            ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withOpacity(0.05),
              Colors.transparent,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Device Battery Status',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                  height: 1.2,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Battery Container with enhanced iOS styling
              Container(
                width: 200,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _getBatteryBackgroundColor(),
                      _getBatteryBackgroundColor().withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _getBatteryColor().withOpacity(0.4),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _getBatteryColor().withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.white.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Battery icon with background
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            _getBatteryColor().withOpacity(0.3),
                            _getBatteryColor().withOpacity(0.1),
                          ],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _getBatteryColor().withOpacity(0.4),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        _getBatteryIcon(),
                        color: _getBatteryColor(),
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '$_batteryLevel%',
                      style: GoogleFonts.inter(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: _getBatteryColor(),
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Battery Level',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _getBatteryColor().withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // iOS-style battery level indicator bars
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final isActive = (index + 1) * 20 <= _batteryLevel;
                        return Container(
                          margin: const EdgeInsets.only(right: 3),
                          width: 6,
                          height: 16,
                          decoration: BoxDecoration(
                            gradient: isActive
                                ? LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      _getBatteryColor(),
                                      _getBatteryColor().withOpacity(0.8),
                                    ],
                                  )
                                : null,
                            color: isActive
                                ? null
                                : _getBatteryColor().withOpacity(0.3),
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color:
                                          _getBatteryColor().withOpacity(0.4),
                                      blurRadius: 3,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().slideY(begin: 0.3, duration: AppMotion.slow);
  }

  /// Builds the slide to connect component with iOS-like design matching User Selection screen
  Widget _buildConnectSlider() {
    final isDarkMode = ThemeProvider.instance.isDarkMode;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        children: [
          // Gradient background matching User Selection screen
          Container(
            height: 64,
            decoration: BoxDecoration(
              gradient: isDarkMode
                  ? AppTheme.primaryGradient
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFDFDFD), // off-white
                        Color(0xFFF5F5F7), // light cloud grey
                        Color(0xFFE0E0E2), // gentle cool grey
                      ],
                    ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.3)
                    : const Color(0xFFE0E0E0).withOpacity(0.5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDarkMode
                      ? Colors.black.withOpacity(0.2)
                      : const Color(0xFF475569).withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                  spreadRadius: 0,
                ),
                if (!isDarkMode)
                  BoxShadow(
                    color: const Color(0xFF475569).withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, -2),
                    spreadRadius: 0,
                  ),
              ],
            ),
          ),
          // Legacy slide action removed - using new premium button instead
          Container(
            height: 64,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              color: Colors.grey.withOpacity(0.1),
            ),
            child: Center(
              child: Text(
                'Premium connection interface active',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().slideY(begin: 0.5, duration: AppMotion.slow, delay: 400.ms);
  }
}
