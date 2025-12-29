import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import 'patient_sos/patient_sos_state.dart';
import 'patient_sos/patient_sos_data_provider.dart';

class PatientSOSScreen extends StatefulWidget {
  const PatientSOSScreen({super.key});

  @override
  State<PatientSOSScreen> createState() => _PatientSOSScreenState();
}

class _PatientSOSScreenState extends State<PatientSOSScreen> with TickerProviderStateMixin {
  // Data provider for SOS state
  late final PatientSosDataProvider _dataProvider;
  
  // Local UI state (cancel confirmation popup, slider)
  bool _showCancelConfirmation = false;
  
  // Slider State
  double _sliderValue = 0.0;
  bool _isDragging = false;
  final double _thumbSize = 52.0;
  
  // Stream subscription
  StreamSubscription<PatientSosState>? _stateSubscription;

  @override
  void initState() {
    super.initState();
    _dataProvider = PatientSosDataProvider.instance;
    
    // Listen to state changes
    _stateSubscription = _dataProvider.stateStream.listen((_) {
      if (mounted) setState(() {});
    });
    
    // Start the SOS session
    _dataProvider.startSosSession();
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    super.dispose();
  }

  /// Get current SOS state from provider
  PatientSosState get _state => _dataProvider.state;

  void _handleDragUpdate(DragUpdateDetails details, double maxWidth) {
    if (_showCancelConfirmation) return;
    setState(() {
      _isDragging = true;
      _sliderValue += details.delta.dx;
      _sliderValue = _sliderValue.clamp(0.0, maxWidth - _thumbSize - 12); // 12 is padding
    });

    // Cancel Threshold (90%)
    if (_sliderValue >= (maxWidth - _thumbSize - 12) * 0.9) {
      setState(() {
        _isDragging = false;
        _showCancelConfirmation = true;
      });
    }
  }

  void _handleDragEnd() {
    setState(() {
      _isDragging = false;
      if (!_showCancelConfirmation) {
        _sliderValue = 0.0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: Stack(
        children: [
          // 1. Ambient Glow Background
          Positioned.fill(
            child: Stack(
              children: [
                // Main Red Pulse
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.25 - 250,
                  left: MediaQuery.of(context).size.width * 0.5 - 250,
                  child: Container(
                    width: 500,
                    height: 500,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red.shade600.withOpacity(0.2),
                    ),
                  ).animate(onPlay: (c) => c.repeat(reverse: true))
                   .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 4.seconds)
                   .blur(begin: const Offset(120, 120), end: const Offset(140, 140)),
                ),
                // Secondary darker accent
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.red.shade900.withOpacity(0.1),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header Info (Top Bar)
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Row(
                          children: [
                            const Icon(CupertinoIcons.shield_fill, color: Color(0xFF4ADE80), size: 16),
                            const SizedBox(width: 8),
                            Text(
                              "Active Monitoring",
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade200,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Text(
                              _state.elapsedDisplay,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12,
                                color: Colors.grey.shade400,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(duration: 500.ms),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Live Status Tracker (Center)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // THE SONAR PULSE
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Expanding Rings
                            _buildSonarRing(0),
                            _buildSonarRing(600),
                            _buildSonarRing(1200),
                            
                            // Main Icon
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.red.shade500, Colors.red.shade700],
                                ),
                                border: Border.all(color: const Color(0xFF1C1C1E), width: 4),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.shade500.withOpacity(0.5),
                                    blurRadius: 50,
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(CupertinoIcons.phone_fill, color: Colors.white, size: 32),
                              ),
                            ).animate(onPlay: (c) => c.repeat(reverse: true))
                             .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 1.seconds),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Status Text
                      Text(
                        _state.mainStatusText,
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _state.progressStep < 2 ? CupertinoIcons.waveform_path_ecg : Icons.medical_services_outlined,
                            color: Colors.red.shade400,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _state.subStatusText,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(duration: 1.seconds),

                      // Horizontal Step Tracker
                      const SizedBox(height: 24),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [0, 1, 2].map((step) {
                          final isActive = _state.progressStep >= step;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 700),
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            width: isActive ? 32 : 8,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isActive ? Colors.white : Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(100),
                              boxShadow: isActive ? [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.5),
                                  blurRadius: 10,
                                )
                              ] : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),

                // 3. Glass Bento Grids (Data)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Heart Rate Glass Card
                          Expanded(
                            child: Container(
                              height: 110,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: Stack(
                                children: [
                                  Row(
                                    children: [
                                      Icon(CupertinoIcons.heart_fill, color: Colors.red.shade400, size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        "HEART RATE",
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade400,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Positioned(
                                    top: 40,
                                    left: 0,
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(left: 70.0,),
                                          child: Text(
                                            _state.heartRateDisplay,
                                            style: GoogleFonts.inter(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              height: 1,
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 1, left: 4),
                                          child: Text(
                                            "BPM",
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.red.shade300,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Heart waveform - only show when we have real heart rate data
                                  if (_state.showHeartWaveform)
                                    Positioned(
              
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      height: 20,
                                      child: CustomPaint(
                                        painter: HeartbeatPainter(),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          
                          // 3D Perspective Map
                          Expanded(
                            child: Container(
                              height: 110,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2C2C2E),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              clipBehavior: Clip.hardEdge,
                              child: Stack(
                                children: [
                                  // 3D Tilted Map Layer
                                  Positioned.fill(
                                    child: Transform(
                                      transform: Matrix4.identity()
                                        ..setEntry(3, 2, 0.002) // Perspective
                                        ..rotateX(0.7) // 40 degrees
                                        ..scale(1.4),
                                      alignment: Alignment.bottomCenter,
                                      child: Container(
                                        color: const Color(0xFF1A1A1A),
                                        child: Stack(
                                          children: [
                                            Positioned(left: 40, top: 0, bottom: 0, width: 16, child: Container(color: const Color(0xFF333333))),
                                            Positioned(right: 50, top: 0, bottom: 0, width: 24, child: Container(color: const Color(0xFF333333))),
                                            Positioned(top: 40, left: 0, right: 0, height: 16, child: Container(color: const Color(0xFF333333))),
                                            Positioned(bottom: 30, left: 0, right: 0, height: 12, child: Container(color: const Color(0xFF333333))),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                  // 3D Floating Pin
                                  Positioned(
                                    top: 40,
                                    left: 0,
                                    right: 0,
                                    child: Center(
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          // Pin Stalk
                                          Container(
                                            width: 2,
                                            height: 16,
                                            margin: const EdgeInsets.only(top: 16),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withOpacity(0.5),
                                              boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.5), blurRadius: 1)],
                                            ),
                                          ),
                                          // Ping
                                          Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: Colors.red.withOpacity(0.3),
                                              shape: BoxShape.circle,
                                            ),
                                          ).animate(onPlay: (c) => c.repeat()).scale(duration: 1.seconds).fadeOut(duration: 1.seconds),
                                          // Dot
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(color: Colors.red, blurRadius: 15, spreadRadius: 2),
                                              ],
                                            ),
                                          ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2)),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Overlay Text
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [
                                            Colors.black.withOpacity(0.9),
                                            Colors.black.withOpacity(0.5),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(CupertinoIcons.map_pin_ellipse, color: Colors.grey, size: 12),
                                              const SizedBox(width: 4),
                                              Text(
                                                "LOCATION",
                                                style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey.shade300,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _state.locationDisplay,
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Waveform Transcript
                      Container(
                        height: 70,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(CupertinoIcons.mic_fill, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 16),
                            // Waveform Bars - only animate if recording
                            if (_state.showMicWaveform)
                              SizedBox(
                                height: 24,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: List.generate(12, (index) {
                                    return Container(
                                      width: 4,
                                      margin: const EdgeInsets.symmetric(horizontal: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade400,
                                        borderRadius: BorderRadius.circular(100),
                                      ),
                                    ).animate(
                                      onPlay: (c) => c.repeat(reverse: true),
                                      delay: (index * 50).ms,
                                    ).scaleY(
                                      begin: 0.2, 
                                      end: 1.0, 
                                      duration: (500 + math.Random().nextInt(500)).ms,
                                    ).fade(begin: 0.6, end: 1.0);
                                  }),
                                ),
                              ),
                            if (!_state.showMicWaveform)
                              SizedBox(
                                height: 24,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: List.generate(12, (index) {
                                    return Container(
                                      width: 4,
                                      height: 6,
                                      margin: const EdgeInsets.symmetric(horizontal: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade400.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(100),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                _state.transcriptDisplay,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withOpacity(0.7),
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.right,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ).animate(key: ValueKey(_state.transcript.length)).fadeIn(),
                            ),
                          ],
                        ),
                      ),
                      
                      // Medical ID Badge - only show when actually shared
                      if (_state.medicalIdShared)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.amber.shade500.withOpacity(0.2),
                                  Colors.yellow.shade600.withOpacity(0.2),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.amber.shade500.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade500,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.amber.shade900.withOpacity(0.5),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                      child: Icon(CupertinoIcons.creditcard_fill, color: Colors.amber.shade900, size: 16),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "MEDICAL ID",
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber.shade100,
                                          ),
                                        ),
                                        Text(
                                          "Allergies & Blood Type Shared",
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Icon(CupertinoIcons.shield_fill, color: Colors.amber.shade400, size: 20),
                              ],
                            ),
                          ).animate().slideY(begin: 0.5, end: 0, duration: 500.ms).fadeIn(),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 4. Frosted Track Slider (Footer)
                Padding(
                  padding: const EdgeInsets.only(left: 24, right: 24, bottom: 20),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxWidth = constraints.maxWidth;
                      return Container(
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            // Shimmer Text
                            Center(
                              child: AnimatedOpacity(
                                opacity: _isDragging ? 0.0 : 1.0,
                                duration: const Duration(milliseconds: 300),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "SLIDE TO CANCEL",
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withOpacity(0.3),
                                        letterSpacing: 2,
                                      ),
                                    ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.5.seconds, color: Colors.white),
                                    const SizedBox(width: 4),
                                    Icon(CupertinoIcons.chevron_right, color: Colors.white.withOpacity(0.3), size: 16),
                                  ],
                                ),
                              ),
                            ),
                            
                            // Thumb
                            Positioned(
                              left: 6 + _sliderValue,
                              child: GestureDetector(
                                onHorizontalDragUpdate: (details) => _handleDragUpdate(details, maxWidth),
                                onHorizontalDragEnd: (_) => _handleDragEnd(),
                                child: Container(
                                  width: _thumbSize,
                                  height: _thumbSize,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withOpacity(0.4),
                                        blurRadius: 15,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.close, color: Color(0xFF1C1C1E), size: 24),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  ),
                ),
              ],
            ),
          ),

          // Confirmation Popup
          if (_showCancelConfirmation)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.6),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Center(
                    child: Container(
                      width: 300,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2E),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 40,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Colors.red, size: 32),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Cancel Emergency?",
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Caregivers have already been notified. Are you sure you want to cancel?",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.grey.shade400,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _showCancelConfirmation = false;
                                      _sliderValue = 0;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        "No, Keep On",
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    // Cancel the SOS session through the provider
                                    _dataProvider.cancelSosSession();
                                    Navigator.of(context).pop();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        "Yes, Cancel",
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ).animate().scale(duration: 200.ms, curve: Curves.easeOutBack),
                  ),
                ),
              ).animate().fadeIn(duration: 200.ms),
            ),
        ],
      ),
    );
  }

  Widget _buildSonarRing(int delayMs) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.red.withOpacity(0.5), width: 2),
      ),
    ).animate(onPlay: (c) => c.repeat())
     .scale(begin: const Offset(1, 1), end: const Offset(3, 3), duration: 2.seconds, delay: delayMs.ms)
     .fadeOut(duration: 2.seconds, delay: delayMs.ms);
  }
}

class HeartbeatPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.shade500
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path();
    path.moveTo(0, size.height / 2);
    
    // Simple ECG pattern
    path.lineTo(10, size.height / 2);
    path.lineTo(15, size.height / 2 - 10);
    path.lineTo(20, size.height / 2 + 10);
    path.lineTo(25, size.height / 2);
    path.lineTo(35, size.height / 2);
    path.lineTo(40, size.height / 2 - 35); // Peak
    path.lineTo(45, size.height / 2 + 15);
    path.lineTo(50, size.height / 2);
    path.lineTo(60, size.height / 2);
    path.lineTo(65, size.height / 2 - 5);
    path.lineTo(70, size.height / 2 + 5);
    path.lineTo(75, size.height / 2);
    path.lineTo(size.width, size.height / 2);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
