import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import 'peace_of_mind/peace_of_mind_state.dart';
import 'peace_of_mind/peace_of_mind_data_provider.dart';

class PeaceOfMindScreen extends StatefulWidget {
  const PeaceOfMindScreen({super.key});

  @override
  State<PeaceOfMindScreen> createState() => _PeaceOfMindScreenState();
}

class _PeaceOfMindScreenState extends State<PeaceOfMindScreen> with TickerProviderStateMixin {
  // State - loaded from provider
  PeaceOfMindState _state = PeaceOfMindState.initial();
  double _moodValue = 50.0; // Local slider value for smooth interaction
  bool _isLoading = true;
  
  // Card Drag State
  double _dragY = 0.0;
  
  // Animation Controllers
  late AnimationController _blobController;
  late AnimationController _breatheController;
  late AnimationController _liquidController;

  // Data provider
  final _dataProvider = PeaceOfMindDataProvider.instance;

  @override
  void initState() {
    super.initState();
    
    _blobController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _liquidController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    try {
      final loadedState = await _dataProvider.loadInitialState();
      if (mounted) {
        setState(() {
          _state = loadedState;
          _moodValue = loadedState.moodSliderValue;
          _isLoading = false;
        });
      }
    } catch (e) {
      // On error, use initial state
      if (mounted) {
        setState(() {
          _state = PeaceOfMindState.initial();
          _moodValue = 50.0;
          _isLoading = false;
        });
      }
    }
  }

  void _onMoodChanged(double value) {
    setState(() {
      _moodValue = value;
      _state = _state.copyWith(mood: MoodLevel.fromSliderValue(value));
    });
    // Persist mood change
    _dataProvider.saveMood(value);
  }

  void _onReflectStart() {
    setState(() {
      _state = _state.copyWith(isRecordingReflection: true);
    });
  }

  void _onReflectEnd() {
    setState(() {
      _state = _state.copyWith(isRecordingReflection: false);
    });
  }

  @override
  void dispose() {
    _blobController.dispose();
    _breatheController.dispose();
    _liquidController.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragY += details.delta.dy;
      _dragY = _dragY.clamp(0.0, 400.0);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_dragY > 150) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _dragY = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mood Tints
    final warmOpacity = _moodValue / 100;
    final coolOpacity = (100 - _moodValue) / 100;

    return Scaffold(
      backgroundColor: const Color(0xFFE8E6D9),
      body: Stack(
        children: [
          // 1. Atmospheric Background
          _buildBackground(warmOpacity, coolOpacity),

          // 2. Main Layout (Column)
          Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Center(
                  child: _buildZenCard(),
                ),
              ),
              _buildFooter(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackground(double warmOpacity, double coolOpacity) {
    return Stack(
      children: [
        // Moving Gradient Orbs
        AnimatedBuilder(
          animation: _blobController,
          builder: (context, child) {
            final t = _blobController.value;
            // Simple orbital movement simulation
            final offset1 = Offset(math.sin(t * 2 * math.pi) * 30, math.cos(t * 2 * math.pi) * -50);
            final offset2 = Offset(math.cos(t * 2 * math.pi) * -20, math.sin(t * 2 * math.pi) * 20);
            
            return Stack(
              children: [
                // Orb 1
                Positioned(
                  top: -100 + offset1.dy,
                  left: -50 + offset1.dx,
                  width: MediaQuery.of(context).size.width * 0.8,
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4E0D6).withOpacity(0.7),
                      shape: BoxShape.circle,
                    ),
                  ).animate().blur(begin: const Offset(80, 80), end: const Offset(80, 80)),
                ),
                // Orb 2
                Positioned(
                  top: 150 + offset2.dy,
                  right: -100 + offset2.dx,
                  width: MediaQuery.of(context).size.width * 0.7,
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCE6E9).withOpacity(0.7),
                      shape: BoxShape.circle,
                    ),
                  ).animate().blur(begin: const Offset(80, 80), end: const Offset(80, 80)),
                ),
                // Orb 3
                Positioned(
                  bottom: -50,
                  left: 50,
                  width: MediaQuery.of(context).size.width * 0.8,
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6D4D4).withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                  ).animate().blur(begin: const Offset(80, 80), end: const Offset(80, 80)),
                ),
              ],
            );
          },
        ),

        // Mood Tints
        Container(color: Colors.blue.withOpacity(coolOpacity * 0.15)), // Reduced opacity for blend
        Container(color: Colors.amber.withOpacity(warmOpacity * 0.15)),

        // Noise Overlay (Simulated with a pattern or just skipped if no asset)
        // Using a very subtle grain if possible, otherwise just the colors.
        // Since we can't add assets, we'll skip the SVG noise but the colors match.
      ],
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Back Button
            Positioned(
              left: 0,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Icon(CupertinoIcons.chevron_left, size: 32, color: Colors.grey.shade700.withOpacity(0.4)),
              ),
            ),

            // Soundscape Pill
            GestureDetector(
              onTap: _state.hasSoundscape ? () {
                // Toggle play state only if soundscape is selected
                // Note: Actual audio playback would be implemented here
              } : null,
              child: Container(
                padding: const EdgeInsets.only(left: 6, right: 16, top: 6, bottom: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _state.isPlayingSound ? CupertinoIcons.cloud_rain : CupertinoIcons.play_fill,
                        size: 14,
                        color: Colors.teal.shade800,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "SOUNDSCAPE",
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          _state.soundscapeDisplayName,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                    if (_state.isPlayingSound) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 12,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildAudioBar(0),
                            const SizedBox(width: 2),
                            _buildAudioBar(1),
                            const SizedBox(width: 2),
                            _buildAudioBar(2),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioBar(int index) {
    return Container(
      width: 2,
      height: 12,
      decoration: BoxDecoration(
        color: Colors.teal.shade700.withOpacity(0.6),
        borderRadius: BorderRadius.circular(100),
      ),
    ).animate(
      onPlay: (c) => c.repeat(reverse: true),
      delay: (index * 150).ms,
    ).scaleY(
      begin: 0.3, 
      end: 1.0, 
      duration: 600.ms, 
      alignment: Alignment.bottomCenter,
      curve: Curves.easeInOut,
    );
  }

  Widget _buildZenCard() {
    return GestureDetector(
      onVerticalDragUpdate: _handleDragUpdate,
      onVerticalDragEnd: _handleDragEnd,
      child: Transform(
        transform: Matrix4.identity()
          ..translate(0.0, _dragY)
          ..rotateX(_dragY * 0.001) // Slight rotation
          ..scale(1.0 - (_dragY * 0.0005)),
        alignment: Alignment.center,
        child: Opacity(
          opacity: (1.0 - (_dragY / 400)).clamp(0.0, 1.0),
          child: OverflowBox(
            minHeight: 0,
            maxHeight: double.infinity,
            alignment: Alignment.center,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: Colors.white.withOpacity(0.4)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 60,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: ClipRRect( // For backdrop blur
                borderRadius: BorderRadius.circular(40),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "DAILY REFLECTION",
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade500,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _state.reflectionDisplayText,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.playfairDisplay( // Serif font
                            fontSize: _state.hasPrompt ? 30 : 24,
                            height: 1.2,
                            color: _state.hasPrompt 
                                ? Colors.grey.shade800 
                                : Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 28),
                        // Handle
                        Container(
                          width: 32,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade400.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Pull down to close",
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade400.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mood Slider
            SizedBox(
              width: 256,
              height: 60,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Labels
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: Text(
                      "CLOUDY",
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade400,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Text(
                      "SUNNY",
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade400,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  // Track
                  Container(
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16), // Move up slightly
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(100),
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue.shade300.withOpacity(0.5),
                          Colors.grey.shade300.withOpacity(0.5),
                          Colors.amber.shade300.withOpacity(0.5),
                        ],
                      ),
                    ),
                  ),
                  // Slider
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    bottom: 16, // Match track margin
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 4,
                        activeTrackColor: Colors.transparent,
                        inactiveTrackColor: Colors.transparent,
                        thumbShape: _SunThumbShape(),
                        overlayShape: SliderComponentShape.noOverlay,
                      ),
                      child: Slider(
                        value: _moodValue,
                        min: 0,
                        max: 100,
                        onChanged: _onMoodChanged,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Mic Button with Aura
            Stack(
              alignment: Alignment.center,
              children: [
                // Breathing Aura
                AnimatedBuilder(
                  animation: _breatheController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1.0 + (_breatheController.value * 0.6), // 1.0 to 1.6
                      child: Opacity(
                        opacity: 0.1 + (_breatheController.value * 0.2), // 0.1 to 0.3
                        child: Container(
                          width: 128,
                          height: 128,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // Liquid Blob (Active State)
                if (_state.isRecordingReflection)
                  AnimatedBuilder(
                    animation: _liquidController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _liquidController.value * 2 * math.pi,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomLeft,
                              end: Alignment.topRight,
                              colors: [
                                Colors.amber.shade200,
                                Colors.white,
                                Colors.teal.shade100,
                              ],
                            ),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(40),
                              topRight: const Radius.circular(60),
                              bottomLeft: const Radius.circular(70),
                              bottomRight: const Radius.circular(30),
                            ),
                          ),
                        ).animate().scale(duration: 500.ms, curve: Curves.easeOut),
                      );
                    },
                  ),

                // Physical Button
                GestureDetector(
                  onTapDown: (_) => _onReflectStart(),
                  onTapUp: (_) => _onReflectEnd(),
                  onTapCancel: () => _onReflectEnd(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _state.isRecordingReflection 
                          ? Colors.white.withOpacity(0.2) 
                          : const Color(0xFFF2F2F2).withOpacity(0.8),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _state.isRecordingReflection ? Colors.white.withOpacity(0.5) : Colors.white.withOpacity(0.2),
                      ),
                      boxShadow: [
                        if (!_state.isRecordingReflection)
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        CupertinoIcons.mic,
                        size: 32,
                        color: _state.isRecordingReflection ? Colors.grey.shade800 : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 500),
              opacity: _state.isRecordingReflection ? 0.0 : 1.0,
              child: Text(
                "Hold to reflect",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SunThumbShape extends SliderComponentShape {
  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return const Size(32, 32);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(center + const Offset(0, 1), 16, shadowPaint);

    // Background
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, 16, bgPaint);

    // Border
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, 16, borderPaint);

    // Icon (Sun)
    final iconColor = value > 0.6 
        ? Colors.amber.shade500 
        : value < 0.4 
            ? Colors.blue.shade400 
            : Colors.grey.shade400;

    final iconPaint = Paint()
      ..color = iconColor
      ..style = PaintingStyle.fill;

    // Draw a simple sun/circle
    canvas.drawCircle(center, 4, iconPaint);
    
    // Rays
    if (value > 0.6) {
      for (int i = 0; i < 8; i++) {
        final angle = (i * 45) * math.pi / 180;
        final p1 = center + Offset(math.cos(angle) * 6, math.sin(angle) * 6);
        final p2 = center + Offset(math.cos(angle) * 8, math.sin(angle) * 8);
        canvas.drawLine(p1, p2, iconPaint..strokeWidth = 1.5);
      }
    }
  }
}
