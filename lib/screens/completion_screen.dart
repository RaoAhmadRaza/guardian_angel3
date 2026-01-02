import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class CompletionScreen extends StatelessWidget {
  final VoidCallback onDone;
  final VoidCallback onTryAnother;

  const CompletionScreen({
    super.key,
    required this.onDone,
    required this.onTryAnother,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFAF7), // bg-[#FCFAF7]
      body: Stack(
        children: [
          // Background Calmness
          Positioned(
            top: MediaQuery.of(context).size.height * 0.2,
            left: MediaQuery.of(context).size.width * 0.1,
            child: Container(
              width: 256,
              height: 256,
              decoration: BoxDecoration(
                color: const Color(0xFFE7E5E4).withOpacity(0.2), // bg-stone-200 opacity-20
                shape: BoxShape.circle,
              ),
            ).animate().fadeIn(duration: 1000.ms).blur(begin: const Offset(100, 100), end: const Offset(100, 100)),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.2,
            right: MediaQuery.of(context).size.width * 0.1,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                color: const Color(0xFFE7E5E4).withOpacity(0.2), // bg-stone-200 opacity-20
                shape: BoxShape.circle,
              ),
            ).animate().fadeIn(duration: 1000.ms).blur(begin: const Offset(120, 120), end: const Offset(120, 120)),
          ),

          // Main Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Hero Section: Refined Trophy
                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        color: const Color(0xFF292524), // bg-stone-800
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF44403C), // border-stone-700
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25), // shadow-2xl
                            blurRadius: 25,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.emoji_events_rounded, // Trophy
                        size: 80,
                        color: Color(0xFFE5DACE), // text-[#E5DACE]
                      ),
                    ).animate().scale(duration: 1000.ms, curve: Curves.easeOutBack),

                    const SizedBox(height: 64),

                    // Celebration Text
                    Text(
                      'Wonderful work',
                      style: GoogleFonts.inter(
                        fontSize: 48,
                        fontWeight: FontWeight.w900, // Blocky & Bold
                        color: const Color(0xFF1C1917), // text-stone-900
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'ACTIVITY COMPLETE',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFA8A29E), // text-stone-400
                        letterSpacing: 6.0, // tracking-[0.3em] -> 20 * 0.3 = 6
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 64),

                    // Stats - Simplified & Clear
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 384), // max-w-sm
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              icon: CupertinoIcons.timer,
                              title: 'Relaxed',
                              subtitle: 'PACE',
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildStatCard(
                              icon: CupertinoIcons.scope, // Target
                              title: 'Perfect',
                              subtitle: 'FOCUS',
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 64),

                    // Action Buttons
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 384), // max-w-sm
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: onDone,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              decoration: BoxDecoration(
                                color: const Color(0xFF292524), // bg-stone-800
                                borderRadius: BorderRadius.circular(32),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.25), // shadow-2xl
                                    blurRadius: 25,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Return Home',
                                    style: GoogleFonts.inter(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(
                                    CupertinoIcons.chevron_right,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          GestureDetector(
                            onTap: onTryAnother,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(
                                  color: const Color(0xFFF5F5F4), // border-stone-100
                                  width: 2,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Do another exercise',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF57534E), // text-stone-600
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 48),

                    Text(
                      'GUARDIAN ANGEL',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFD6D3D1), // text-stone-300
                        letterSpacing: 6.0, // tracking-[0.5em]
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: const Color(0xFFF5F5F4), // border-stone-100
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05), // shadow-sm
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 24,
            color: const Color(0xFFA8A29E), // text-stone-400
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w900, // Blocky & Bold
              color: const Color(0xFF292524), // text-stone-800
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFA8A29E), // text-stone-400
              letterSpacing: 1.2, // tracking-widest
            ),
          ),
        ],
      ),
    );
  }
}
