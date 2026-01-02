import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'colors.dart';
import 'providers/theme_provider.dart';
import 'theme/motion.dart';
import 'onboarding/services/onboarding_local_service.dart';

// New Patient Details Screen import
import 'patient_details_screen.dart';

class PatientAgeSelectionScreen extends StatefulWidget {
  const PatientAgeSelectionScreen({super.key});

  @override
  State<PatientAgeSelectionScreen> createState() =>
      _PatientAgeSelectionScreenState();
}

class _PatientAgeSelectionScreenState extends State<PatientAgeSelectionScreen> {
  int selectedValue = 25;
  final int minValue = 1;
  final int maxValue = 120;

  late FixedExtentScrollController scrollController;

  @override
  void initState() {
    super.initState();
    scrollController =
        FixedExtentScrollController(initialItem: selectedValue - minValue);
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  void increment() {
    if (selectedValue < maxValue) {
      setState(() => selectedValue++);
      scrollController.animateToItem(
        selectedValue - minValue,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void decrement() {
    if (selectedValue > minValue) {
      setState(() => selectedValue--);
      scrollController.animateToItem(
        selectedValue - minValue,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// Handles age selection with validation and navigation
  void _handleAgeSelection() {
    // Provide immediate haptic feedback
    HapticFeedback.selectionClick();

    debugPrint('Selected age: $selectedValue');

    // Age validation - under 60 shows ineligible message
    if (selectedValue < 60) {
      _showIneligibleSnackbar();
    } else {
      // Navigate to patient details screen for eligible users
      _navigateToPatientDetails();
    }
  }

  /// Shows modern snackbar for ineligible users (age < 60)
  void _showIneligibleSnackbar() {
    // Provide error haptic feedback
    HapticFeedback.lightImpact();

    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'You are not an eligible patient/user',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.orange.shade600,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: 'Dismiss',
        textColor: Colors.white,
        onPressed: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        },
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  /// Navigates to patient details screen with smooth transition.
  /// STEP 4B: Updates Patient User with validated age (OFFLINE-FIRST).
  Future<void> _navigateToPatientDetails() async {
    // Get current user ID - try Firebase Auth first, fallback to local storage
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    
    // Fallback for simulator mode: get UID from local storage
    if (uid == null || uid.isEmpty) {
      uid = OnboardingLocalService.instance.getLastSavedUid();
      debugPrint('[PatientAgeSelectionScreen] Using fallback UID from local storage: $uid');
    }
    
    if (uid == null || uid.isEmpty) {
      debugPrint('[PatientAgeSelectionScreen] ERROR: No authenticated user');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authentication error. Please sign in again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // STEP 4B: Update Patient User with validated age (min 60 already validated)
    try {
      await OnboardingLocalService.instance.savePatientRole(
        uid: uid,
        age: selectedValue,
      );
      debugPrint('[PatientAgeSelectionScreen] Step 4B: Patient age ($selectedValue) saved locally');
    } catch (e) {
      debugPrint('[PatientAgeSelectionScreen] Step 4B FAILED: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save age. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      AppMotion.slideTransition(
        page: PatientDetailsScreen(patientAge: selectedValue),
        begin: const Offset(1.0, 0.0),
        duration: AppMotion.pageTransition,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: isDarkMode
              ? AppTheme.primaryGradient
              : AppTheme.lightPrimaryGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with theme toggle - Following color scheme
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Action Button (Theme Toggle) - Following color scheme
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.2)
                            : Colors.white.withOpacity(0.9),
                        border: isDarkMode
                            ? null
                            : Border.all(
                                color: const Color(0xFFE0E0E0),
                                width: 1,
                              ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isDarkMode
                            ? null
                            : [
                                BoxShadow(
                                  color:
                                      const Color(0xFF475569).withOpacity(0.06),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
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
                          await ThemeProvider.instance.toggleTheme();
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Title Section - Using theme-appropriate colors
              Column(
                children: [
                  Text(
                    'Select Your Age',
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode
                          ? AppTheme.primaryText
                          : AppTheme.lightPrimaryText,
                    ),
                  ).animate().fadeIn(duration: 800.ms).slideY(begin: -0.3),
                  const SizedBox(height: 8),
                  Text(
                    'This helps us provide better care',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: isDarkMode
                          ? AppTheme.secondaryText
                          : AppTheme.lightSecondaryText,
                    ),
                  ).animate().fadeIn(duration: 800.ms, delay: 200.ms),
                  const SizedBox(height: 16),
                  // Monochromatic accent line - following user selection screen
                  Container(
                    width: 120,
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
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
                  ).animate().scaleX(duration: 800.ms, delay: 400.ms),
                ],
              ),

              const SizedBox(height: 60),

              // Age Picker Section
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Age Display - Using theme-appropriate colors
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.2)
                              : Colors.white.withOpacity(0.9),
                          border: isDarkMode
                              ? null
                              : Border.all(
                                  color: const Color(0xFFE0E0E0),
                                  width: 1,
                                ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: isDarkMode
                              ? null
                              : [
                                  BoxShadow(
                                    color: const Color(0xFF475569)
                                        .withOpacity(0.06),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: Text(
                          '$selectedValue years old',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode
                                ? Colors.white
                                : const Color(0xFF404040),
                          ),
                        ),
                      ).animate().fadeIn(duration: 600.ms, delay: 600.ms),

                      const SizedBox(height: 40),

                      // Picker Container - Using phone input container style
                      Container(
                        height: 280,
                        width: 160,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surface
                              .withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: isDarkMode
                                ? AppTheme.borderColor
                                : AppTheme.lightBorderColor,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context)
                                  .shadowColor
                                  .withValues(alpha: 0.1),
                              blurRadius: isDarkMode ? 20 : 16,
                              offset: Offset(0, isDarkMode ? 10 : 8),
                            ),
                            if (!isDarkMode)
                              BoxShadow(
                                color:
                                    const Color(0xFF475569).withOpacity(0.04),
                                blurRadius: 32,
                                offset: const Offset(0, 8),
                              ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 16),
                            // Increment Button - Following action button style
                            Container(
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? Colors.white.withOpacity(0.2)
                                    : Colors.white.withOpacity(0.9),
                                border: isDarkMode
                                    ? null
                                    : Border.all(
                                        color: const Color(0xFFE0E0E0),
                                        width: 1,
                                      ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: isDarkMode
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: const Color(0xFF475569)
                                              .withOpacity(0.06),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                              ),
                              child: IconButton(
                                onPressed: increment,
                                icon: Icon(
                                  CupertinoIcons.chevron_up,
                                  color: isDarkMode
                                      ? Colors.white
                                      : const Color(0xFF404040),
                                  size: 24,
                                ),
                              ),
                            ),

                            // Picker
                            Expanded(
                              child: CupertinoPicker(
                                scrollController: scrollController,
                                itemExtent: 50,
                                backgroundColor: Colors.transparent,
                                diameterRatio: 1.5,
                                useMagnifier: true,
                                magnification: 1.2,
                                onSelectedItemChanged: (int index) {
                                  setState(() {
                                    selectedValue = index + minValue;
                                  });
                                },
                                children: List.generate(maxValue - minValue + 1,
                                    (index) {
                                  final actualValue = index + minValue;
                                  final isSelected =
                                      actualValue == selectedValue;
                                  return Center(
                                    child: Text(
                                      '$actualValue',
                                      style: GoogleFonts.inter(
                                        fontSize: isSelected ? 28 : 20,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? (isDarkMode
                                                ? AppTheme.primaryText
                                                : AppTheme.lightPrimaryText)
                                            : (isDarkMode
                                                ? AppTheme.tertiaryText
                                                : AppTheme.lightTertiaryText),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),

                            // Decrement Button - Following action button style
                            Container(
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? Colors.white.withOpacity(0.2)
                                    : Colors.white.withOpacity(0.9),
                                border: isDarkMode
                                    ? null
                                    : Border.all(
                                        color: const Color(0xFFE0E0E0),
                                        width: 1,
                                      ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: isDarkMode
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: const Color(0xFF475569)
                                              .withOpacity(0.06),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                              ),
                              child: IconButton(
                                onPressed: decrement,
                                icon: Icon(
                                  CupertinoIcons.chevron_down,
                                  color: isDarkMode
                                      ? Colors.white
                                      : const Color(0xFF404040),
                                  size: 24,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      )
                          .animate()
                          .slideY(begin: 0.3, duration: 800.ms, delay: 800.ms),
                    ],
                  ),
                ),
              ),

              // Continue Button - GradientButton style following color scheme
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: isDarkMode
                        ? AppTheme
                            .primaryGradient // Uses default theme gradient for dark
                        : const LinearGradient(
                            // Custom gradient for light theme
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFFDFDFD), // off-white
                              Color(0xFFF5F5F7), // light cloud grey
                              Color(0xFFE0E0E2), // gentle cool grey
                            ],
                          ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.1)
                            : const Color(0xFF64748B).withOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextButton(
                    onPressed: () {
                      _handleAgeSelection();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: isDarkMode
                          ? Colors.white // Default for dark theme
                          : const Color(0xFF0F172A), // Custom for light theme
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Continue',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward,
                          size: 20,
                          color: isDarkMode
                              ? Colors.white // Default for dark theme
                              : const Color(
                                  0xFF404040), // Custom for light theme
                        ),
                      ],
                    ),
                  ),
                ),
              ).animate().slideY(begin: 0.5, duration: 800.ms, delay: 1000.ms),
            ],
          ),
        ),
      ),
    );
  }
}
