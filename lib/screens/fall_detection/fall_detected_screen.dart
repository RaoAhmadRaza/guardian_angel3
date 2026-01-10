import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../patient_sos_screen.dart';
import '../../services/fall_detection/fall_detection_service.dart';
import '../../services/sos_alert_chat_service.dart';

/// Fall Detected Screen
/// 
/// Shown when the fall detection model detects a potential fall.
/// 
/// Flow:
/// 1. 10-second countdown starts automatically
/// 2. User can tap "I'M OK" to cancel and return to normal
/// 3. If no action for 10 seconds → automatically triggers SOS
/// 4. SOS navigates to PatientSOSScreen which handles the full emergency workflow
class FallDetectedScreen extends StatefulWidget {
  const FallDetectedScreen({super.key});

  @override
  State<FallDetectedScreen> createState() => _FallDetectedScreenState();
}

class _FallDetectedScreenState extends State<FallDetectedScreen> 
    with TickerProviderStateMixin {
  // 10-second countdown as specified
  int _countdown = 10;
  Timer? _timer;
  bool _isTriggered = false;
  
  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _countdownController;

  @override
  void initState() {
    super.initState();
    
    // Pulse animation for the warning icon
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    
    // Countdown animation
    _countdownController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown == 0) {
        _timer?.cancel();
        _triggerSOS();
      } else {
        setState(() {
          _countdown--;
        });
        // Animate countdown number
        _countdownController.forward(from: 0);
      }
    });
  }

  void _triggerSOS() {
    if (_isTriggered) return;
    _isTriggered = true;
    
    // Navigate to the actual SOS screen which handles the full emergency workflow
    // Pass fall detection as the alert reason
    Navigator.of(context).pushReplacement(
      CupertinoPageRoute(
        builder: (context) => const PatientSOSScreen(
          alertReason: SosAlertReason.fallDetection,
        ),
      ),
    );
  }

  void _cancelAlert() {
    _timer?.cancel();
    
    // Resume fall detection monitoring
    FallDetectionService.instance.startMonitoring();
    
    // Return to previous screen
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _countdownController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFF9500), // System Orange (warning color)
      body: SafeArea(
        child: Stack(
          children: [
            // Animated background glow
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.5,
                    colors: [
                      const Color(0xFFFF9500),
                      const Color(0xFFFF6B00).withOpacity(0.8),
                    ],
                  ),
                ),
              ),
            ),
            
            // Main content
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  
                  // Warning Icon with pulse animation
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 1.0 + (_pulseController.value * 0.1),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.3 * _pulseController.value),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: const Icon(
                            CupertinoIcons.exclamationmark_triangle_fill,
                            size: 64,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Main Text
                  Text(
                    'We detected a\npossible fall.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Text(
                    'Are you okay?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Countdown Display
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Emergency SOS in',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$_countdown',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 56,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ).animate(
                          onComplete: (controller) => controller.reset(),
                        ).scale(
                          begin: const Offset(1.2, 1.2),
                          end: const Offset(1.0, 1.0),
                          duration: 300.ms,
                        ),
                        Text(
                          'seconds',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // I'M OK Button - Large and prominent
                  SizedBox(
                    width: double.infinity,
                    height: 80,
                    child: CupertinoButton(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      onPressed: _cancelAlert,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            CupertinoIcons.checkmark_circle_fill,
                            color: Color(0xFFFF9500),
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "I'M OK",
                            style: GoogleFonts.inter(
                              color: const Color(0xFFFF9500),
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Helper text
                  Text(
                    "Tap 'I'm OK' to cancel the emergency alert",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Emergency SOS button (for immediate SOS)
                  TextButton(
                    onPressed: _triggerSOS,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.phone_fill,
                          color: Colors.white.withOpacity(0.9),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "I need help now",
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
