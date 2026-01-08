import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

class SafeZoneInfoScreen extends StatelessWidget {
  const SafeZoneInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFDFD),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0), // Reduced padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Close Button
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(12), // Reduced padding
                    decoration: const BoxDecoration(
                      color: Color(0xFFF5F5F7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.xmark,
                      size: 24, // Reduced size
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24), // Reduced spacing

              // Shield Icon
              Container(
                width: 80, // Reduced size
                height: 80, // Reduced size
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F7),
                  borderRadius: BorderRadius.circular(32), // Reduced radius
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    CupertinoIcons.shield_fill,
                    size: 40, // Reduced size
                    color: Color(0xFF059669),
                  ),
                ),
              ),

              const SizedBox(height: 24), // Reduced spacing

              // Text Content
              Text(
                'Private & Secure.',
                style: GoogleFonts.inter(
                  fontSize: 32, // Reduced font size
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                  height: 1.1,
                  letterSpacing: -1.0,
                ),
              ),

              const SizedBox(height: 16), // Reduced spacing

              Text(
                'Guardian Angel only checks your position for alerts. Your private history is never saved.',
                style: GoogleFonts.inter(
                  fontSize: 16, // Reduced font size
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF475569),
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 24), // Reduced spacing

              // List Items
              Container(
                padding: const EdgeInsets.only(top: 24), // Reduced padding
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 16, // Reduced size
                          height: 16, // Reduced size
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16), // Reduced spacing
                        Expanded(
                          child: Text(
                            'Trusted by your family.',
                            style: GoogleFonts.inter(
                              fontSize: 16, // Reduced font size
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16), // Reduced spacing
                    Row(
                      children: [
                        Container(
                          width: 16, // Reduced size
                          height: 16, // Reduced size
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16), // Reduced spacing
                        Expanded(
                          child: Text(
                            'Privacy Guaranteed.',
                            style: GoogleFonts.inter(
                              fontSize: 16, // Reduced font size
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Bottom Button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16), // Reduced padding
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(20), // Reduced radius
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'I Am Ready',
                      style: GoogleFonts.inter(
                        fontSize: 16, // Reduced font size
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
