import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

class CaregiverCallScreen extends StatefulWidget {
  final String callerName;
  final String? callerPhotoUrl;

  const CaregiverCallScreen({
    super.key,
    required this.callerName,
    this.callerPhotoUrl,
  });

  @override
  State<CaregiverCallScreen> createState() => _CaregiverCallScreenState();
}

class _CaregiverCallScreenState extends State<CaregiverCallScreen> {
  int _seconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final mins = (seconds / 60).floor();
    final secs = seconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Gradient Background (no network image needed)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F0F23)],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(height: 40),
                
                // Caller Info
                Column(
                  children: [
                    Container(
                      width: 128,
                      height: 128,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF007AFF).withOpacity(0.2),
                        border: Border.all(color: Colors.white.withOpacity(0.2), width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(CupertinoIcons.person_fill, color: Colors.white, size: 60),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      widget.callerName,
                      style: GoogleFonts.inter(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatTime(_seconds),
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.6),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),

                // Controls
                Padding(
                  padding: const EdgeInsets.only(bottom: 40, left: 40, right: 40),
                  child: Column(
                    children: [
                      GridView.count(
                        shrinkWrap: true,
                        crossAxisCount: 3,
                        mainAxisSpacing: 32,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.8,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildControlBtn(CupertinoIcons.mic_off, 'mute'),
                          _buildControlBtn(CupertinoIcons.square_grid_3x2_fill, 'keypad'),
                          _buildControlBtn(CupertinoIcons.volume_up, 'speaker'),
                          _buildControlBtn(CupertinoIcons.person_add_solid, 'add call'),
                          _buildControlBtn(CupertinoIcons.videocam_fill, 'FaceTime'),
                          _buildControlBtn(CupertinoIcons.chat_bubble_2_fill, 'contacts'),
                        ],
                      ),
                      const SizedBox(height: 40),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3B30),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF3B30).withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(CupertinoIcons.phone_down_fill, color: Colors.white, size: 32),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBtn(IconData icon, String label) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.white.withOpacity(0.7),
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}
