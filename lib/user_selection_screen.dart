import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'colors.dart';
import 'providers/theme_provider.dart';
import 'patient_age_selection_screen.dart';
import 'guardian_details_screen.dart';

enum UserRole { patient, guardian, developer }

class UserSelectionScreen extends StatefulWidget {
  const UserSelectionScreen({super.key});

  @override
  State<UserSelectionScreen> createState() => _UserSelectionScreenState();
}

class _UserSelectionScreenState extends State<UserSelectionScreen> {
  UserRole? _selectedRole;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Define role cards data with icons
    final roleCards = [
      {
        'role': UserRole.patient,
        'label': 'Patient',
        'subtitle': 'Health monitoring & care',
        'image': 'images/paitient.png',
        'icon': Icons.health_and_safety,
      },
      {
        'role': UserRole.guardian,
        'label': 'Guardian/Caregiver',
        'subtitle': 'Family member or caregiver',
        'image': 'images/caregiver.png',
        'icon': Icons.people_alt,
      }
    ];

    Widget buildRoleCard({
      required UserRole role,
      required String label,
      required String subtitle,
      required String image,
      required IconData icon,
    }) {
      final bool isActive = _selectedRole == role;

      return GestureDetector(
        onTap: () {
          setState(() => _selectedRole = role);
          HapticFeedback.mediumImpact();
        },
        child: AnimatedScale(
          scale: isActive ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: double.infinity,
            height: 230, // Increased from 210 to give more space for text
            margin: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8), // Reduced vertical margin to save space
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: isActive
                  ? AppTheme
                      .primaryGradient // Use same gradient as login/signup
                  : (isDarkMode
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF374151)
                                .withOpacity(0.7), // Lighter gray
                            const Color(0xFF4B5563)
                                .withOpacity(0.6), // Medium gray
                            const Color(0xFF6B7280)
                                .withOpacity(0.5), // Light gray
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
                        )),
              border: isActive
                  ? Border.all(
                      color:
                          Colors.white.withOpacity(0.3), // Match login/signup
                      width: 2,
                    )
                  : Border.all(
                      color: isDarkMode
                          ? Colors.white.withOpacity(
                              0.2) // Increased opacity for better visibility
                          : const Color(0xFFE0E0E0).withOpacity(0.5),
                      width: 1,
                    ),
              boxShadow: [
                BoxShadow(
                  color: isActive
                      ? (isDarkMode
                          ? Colors.black.withOpacity(0.2)
                          : const Color(0xFF475569).withOpacity(0.08))
                      : (isDarkMode
                          ? Colors.black.withOpacity(0.2)
                          : const Color(0xFF475569).withOpacity(0.06)),
                  blurRadius: isActive ? 25 : 15,
                  offset: const Offset(0, 8),
                  spreadRadius: isActive ? 2 : 0,
                ),
                if (isActive && !isDarkMode)
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
                padding:
                    const EdgeInsets.all(16), // Reduced from 18 to save space
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Profile image with enhanced styling
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Background glow effect
                        if (isActive)
                          Container(
                            width:
                                120, // Reduced from 130 to match smaller image
                            height:
                                120, // Reduced from 130 to match smaller image
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                  60), // Adjusted for new size
                              gradient: RadialGradient(
                                colors: [
                                  Colors.white.withOpacity(0.2),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        // Main image container
                        Container(
                          width: 100, // Reduced from 110 to save space
                          height: 100, // Reduced from 110 to save space
                          decoration: BoxDecoration(
                            gradient: isActive
                                ? LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white.withOpacity(0.3),
                                      Colors.white.withOpacity(0.1),
                                    ],
                                  )
                                : LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      const Color(0xFFBDBDBD).withOpacity(0.3),
                                      const Color(0xFFE0E0E0).withOpacity(0.2),
                                    ],
                                  ),
                            borderRadius: BorderRadius.circular(
                                50), // Adjusted for new size
                            border: Border.all(
                              color: isActive
                                  ? Colors.white.withOpacity(0.4)
                                  : Colors.white.withOpacity(0.2),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                                50), // Adjusted for new size
                            child: Image.asset(
                              image,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        // Role icon overlay
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width:
                                32, // Reduced from 34 to proportionally match smaller image
                            height: 32, // Reduced from 34
                            decoration: BoxDecoration(
                              gradient: isActive
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFFFF6B9D),
                                        Color(0xFFFFA726)
                                      ],
                                    )
                                  : LinearGradient(
                                      colors: [
                                        Colors.grey.withOpacity(0.8),
                                        Colors.grey.withOpacity(0.6),
                                      ],
                                    ),
                              borderRadius: BorderRadius.circular(
                                  16), // Adjusted for new size
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              icon,
                              color: Colors.white,
                              size:
                                  16, // Reduced from 18 to fit smaller container
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14), // Increased spacing for text

                    // Role label with improved typography
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 18, // Reduced from 20 to prevent overflow
                        fontWeight: FontWeight.bold,
                        color: isActive
                            ? Colors.white
                            : (isDarkMode
                                ? Colors.white.withOpacity(0.9)
                                : const Color(0xFF0F172A)),
                        letterSpacing: 0.3, // Reduced letter spacing
                        height: 1.2, // Added line height for better spacing
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2, // Allow text to wrap if needed
                      overflow:
                          TextOverflow.ellipsis, // Handle overflow gracefully
                    ),

                    const SizedBox(height: 6), // Consistent spacing

                    // Subtitle
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12, // Reduced from 14 to prevent overflow
                        fontWeight: FontWeight.w400,
                        color: isActive
                            ? Colors.white.withOpacity(0.9)
                            : (isDarkMode
                                ? Colors.white.withOpacity(0.7)
                                : const Color(0xFF475569)),
                        letterSpacing: 0.1, // Reduced letter spacing
                        height: 1.3, // Added line height for better spacing
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2, // Allow text to wrap if needed
                      overflow:
                          TextOverflow.ellipsis, // Handle overflow gracefully
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      )
          .animate()
          .fadeIn(
            duration: 600.ms,
            delay:
                (roleCards.indexWhere((card) => card['role'] == role) * 150).ms,
          )
          .slideX(
            begin: 0.3,
            duration: 600.ms,
            delay:
                (roleCards.indexWhere((card) => card['role'] == role) * 150).ms,
          )
          .scale(
            begin: const Offset(0.8, 0.8),
            duration: 600.ms,
            delay:
                (roleCards.indexWhere((card) => card['role'] == role) * 150).ms,
          );
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: isDarkMode
              ? AppTheme
                  .primaryGradient // Use exact same gradient as login/signup
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
            // Abstract background patterns
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withOpacity(0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              left: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF667EEA).withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Floating geometric shapes
            Positioned(
              top: 150,
              left: 30,
              child: Transform.rotate(
                angle: 0.5,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              )
                  .animate(onPlay: (controller) => controller.repeat())
                  .rotate(duration: 10.seconds),
            ),
            Positioned(
              top: 200,
              right: 50,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF6B9D).withOpacity(0.3),
                ),
              )
                  .animate(onPlay: (controller) => controller.repeat())
                  .scale(duration: 3.seconds, curve: Curves.easeInOut),
            ),

            // Main content with frosted glass effect
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.05),
                    Colors.transparent,
                    Colors.black.withOpacity(0.05),
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Header with theme toggle
                    Padding(
                      padding: const EdgeInsets.all(16.0), // Reduced from 20.0
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.white.withOpacity(0.2)
                                  : Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(12),
                              border: isDarkMode
                                  ? null
                                  : Border.all(
                                      color: const Color(0xFFE0E0E0),
                                      width: 1,
                                    ),
                              boxShadow: isDarkMode
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: const Color(0xFF475569)
                                            .withOpacity(0.06),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                        spreadRadius: 0,
                                      ),
                                    ],
                            ),
                            child: IconButton(
                              icon: Icon(
                                ThemeProvider.instance.themeIcon,
                                color: isDarkMode
                                    ? Colors.white
                                    : const Color(0xFF404040),
                                size: 20,
                              ),
                              onPressed: () async {
                                HapticFeedback.lightImpact();
                                await ThemeProvider.instance.toggleTheme();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 5), // Reduced from 10

                    // Enhanced Title Section
                    Column(
                      children: [
                        Text(
                          'Select User Type',
                          style: GoogleFonts.inter(
                            fontSize: 28, // Reduced from 32
                            fontWeight: FontWeight.bold,
                            color: isDarkMode
                                ? Colors.white
                                : const Color(0xFF0F172A),
                            letterSpacing: -0.5,
                            height: 1.1,
                          ),
                        )
                            .animate()
                            .fadeIn(duration: 800.ms)
                            .slideY(begin: -0.3),
                        const SizedBox(height: 8), // Reduced from 12
                        Text(
                          'Choose your role to continue',
                          style: GoogleFonts.inter(
                            fontSize: 14, // Reduced from 16
                            fontWeight: FontWeight.w400,
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.9)
                                : const Color(0xFF475569),
                            letterSpacing: 0.2,
                          ),
                        ).animate().fadeIn(duration: 800.ms, delay: 200.ms),
                        const SizedBox(height: 12), // Reduced from 16
                        Container(
                          width: 120, // Reduced from 140
                          height: 4, // Reduced from 5
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            gradient: isDarkMode
                                ? LinearGradient(
                                    colors: [
                                      Colors.white.withOpacity(0.8),
                                      Colors.white.withOpacity(0.4),
                                      Colors.white.withOpacity(0.2),
                                    ],
                                  )
                                : LinearGradient(
                                    colors: [
                                      const Color(0xFF0F172A).withOpacity(0.8),
                                      const Color(0xFF475569).withOpacity(0.6),
                                      const Color(0xFF64748B).withOpacity(0.4),
                                    ],
                                  ),
                            boxShadow: [
                              BoxShadow(
                                color: isDarkMode
                                    ? Colors.white.withOpacity(0.2)
                                    : const Color(0xFF475569).withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ).animate().scaleX(duration: 800.ms, delay: 400.ms),
                      ],
                    ),

                    const SizedBox(height: 20), // Reduced from 30

                    // Role Cards in Column
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: roleCards.map((card) {
                            return buildRoleCard(
                              role: card['role'] as UserRole,
                              label: card['label'] as String,
                              subtitle: card['subtitle'] as String,
                              image: card['image'] as String,
                              icon: card['icon'] as IconData,
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                    // Enhanced Bottom Navigation Button
                    Padding(
                      padding: const EdgeInsets.all(16.0), // Reduced from 20.0
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: _selectedRole != null
                              ? 180
                              : 70, // Increased from 160 to 180 for more space
                          height: 50, // Reduced from 60
                          decoration: BoxDecoration(
                            gradient: _selectedRole != null
                                ? (isDarkMode
                                    ? AppTheme
                                        .primaryGradient // Use default dark theme gradient
                                    : const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFFFDFDFD), // off-white
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
                            borderRadius: BorderRadius.circular(
                                25), // Adjusted for new height
                            border: Border.all(
                              color: _selectedRole != null
                                  ? (isDarkMode
                                      ? Colors.white.withOpacity(0.3)
                                      : const Color(0xFFE0E0E0))
                                  : Colors.white.withOpacity(0.1),
                              width: 1,
                            ),
                            boxShadow: _selectedRole != null
                                ? (isDarkMode
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : [
                                        BoxShadow(
                                          color: const Color(0xFF475569)
                                              .withOpacity(0.08),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                          spreadRadius: 2,
                                        ),
                                        BoxShadow(
                                          color: const Color(0xFF475569)
                                              .withOpacity(0.04),
                                          blurRadius: 6,
                                          offset: const Offset(0, -2),
                                        ),
                                      ])
                                : [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(
                                  25), // Adjusted for new height
                              onTap: _selectedRole != null
                                  ? () {
                                      HapticFeedback.mediumImpact();
                                      if (_selectedRole == UserRole.patient) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const PatientAgeSelectionScreen(),
                                          ),
                                        );
                                      } else if (_selectedRole ==
                                          UserRole.guardian) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const GuardianDetailsScreen(),
                                          ),
                                        );
                                      }
                                      debugPrint(
                                          'Selected role: $_selectedRole');
                                    }
                                  : null,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12), // Reduced from 16
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_selectedRole != null) ...[
                                      Flexible(
                                        child: Text(
                                          'Continue',
                                          style: GoogleFonts.inter(
                                            fontSize: 14, // Reduced from 16
                                            fontWeight: FontWeight.w600,
                                            color: isDarkMode
                                                ? Colors.white
                                                : const Color(0xFF0F172A),
                                            letterSpacing: 0.5,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(
                                          width: 6), // Reduced from 8
                                    ],
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      color: isDarkMode
                                          ? Colors.white
                                          : const Color(0xFF404040),
                                      size: _selectedRole != null
                                          ? 20
                                          : 24, // Reduced sizes
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                        .animate()
                        .slideY(begin: 0.5, duration: 800.ms, delay: 600.ms)
                        .fadeIn(duration: 600.ms, delay: 600.ms),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
