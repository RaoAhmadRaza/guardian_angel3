import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:ui';
// Removed legacy notch bottom bar import
// overlay_nav_bar removed
import 'theme/app_theme.dart' as theme;

import 'services/session_service.dart';
// Previous chat implementation preserved in chat_screen_new.dart
import 'screens/patient_chat_screen.dart';
import 'diagnostic_screen.dart';
import 'home automation/navigation/drawer_wrapper.dart';
import 'home automation/main.dart' show HomeAutomationScreen;
import 'main.dart';
import 'settings_screen.dart';
import 'widgets/overlay_nav_bar.dart';

class NextScreen extends StatefulWidget {
  final String? selectedGender;
  final String? patientName;

  const NextScreen({
    super.key,
    this.selectedGender,
    this.patientName,
  });

  @override
  State<NextScreen> createState() => _NextScreenState();
}

class _NextScreenState extends State<NextScreen> {
  int _selectedIndex = 0;

  // Removed nav index state
  // Removed overlay nav controller

  // Live health data variables
  int _heartPressureSystolic = 120;
  int _heartPressureDiastolic = 80;
  int _heartRate = 67;
  Timer? _healthDataTimer;

  @override
  void initState() {
    super.initState();
    _checkSessionPeriodically();
    _startHealthDataAnimation();

    // Removed home automation initialization
  }

  @override
  void dispose() {
    _healthDataTimer?.cancel();
    super.dispose();
  }

  /// Start live health data animation
  void _startHealthDataAnimation() {
    _healthDataTimer =
        Timer.periodic(const Duration(milliseconds: 3000), (timer) {
      if (mounted) {
        setState(() {
          // More realistic hospital-style variations
          // Heart rate: 60-75 bpm with occasional spikes
          final now = DateTime.now().millisecondsSinceEpoch;
          final baseHeartRate = 67;
          final variation = (now % 13) - 6; // -6 to +6 variation
          _heartRate = baseHeartRate + variation;

          // Blood pressure: more realistic medical variations
          final baseSystolic = 120;
          final baseDiastolic = 80;
          _heartPressureSystolic = baseSystolic + ((now % 11) - 5); // 115-125
          _heartPressureDiastolic = baseDiastolic + ((now % 7) - 3); // 77-83
        });
      }
    });
  }

  /// Check session validity periodically and logout if expired
  void _checkSessionPeriodically() {
    Timer.periodic(const Duration(hours: 1), (timer) async {
      final hasValidSession = await SessionService.instance.hasValidSession();
      if (!hasValidSession && mounted) {
        // Session expired, restart app to show onboarding
        timer.cancel();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MyApp()),
          (route) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final List<Widget> pages = [
      _buildHomePage(isDarkMode),
      _buildChatPage(isDarkMode),
      _buildBulbPage(isDarkMode),
      _buildSettingsPage(isDarkMode),
    ];

    return Scaffold(
      backgroundColor:
          isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFFDFDFD),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDarkMode
              ? theme.AppTheme.getPrimaryGradient(context)
              : theme.AppTheme.lightPrimaryGradient,
        ),
        child: Stack(
          children: [
            Positioned.fill(child: pages[_selectedIndex]),
            Positioned(
              left: 0,
              right: 0,
              bottom: 49,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 250),
                  child: OverlayNavBar(
                icons: const [
                  CupertinoIcons.house_fill,
                  CupertinoIcons.chat_bubble_text_fill,
                  CupertinoIcons.lightbulb_fill,
                  CupertinoIcons.gear_solid,
                ],
                labels: const ['Home', 'Chat', 'Automation', 'Settings'],
                selectedIndex: _selectedIndex,
                onSelected: (i) => setState(() => _selectedIndex = i),
                iconSize: 24, // Reduced icon size per request
                    contentVerticalPadding: 4, // Reduce bar height
                    // Active/inactive/icon colors per theme
                    // Dark theme: white background, active icons black
                    // Light theme: black background, active icons white
                    activeColor: isDarkMode ? Colors.black : Colors.white,
                    inactiveColor: Colors.grey, // grey inactive both themes
                    // Disable blur/glass effect (commented out functionality)
                    blurSigma: 0,
                    enableBlur: false,
                    showLabels: false
                  , // Enable labels to apply black text color
                respectSafeArea: false,
                extraBottomPadding: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    // Remove gradient border for simple solid background
                    borderGradient: null,
                    // Solid background per theme
                    tintColor: isDarkMode ? Colors.white : Colors.black,
                    // Label colors aligned with icon colors
                    // Force black label text for both themes
                    labelColor: Colors.black,
                    activeLabelColor: Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      extendBody: true,
    );
  }

  /// Build Home Page
  Widget _buildHomePage(bool isDarkMode) {
    final displayGender = (widget.selectedGender ?? 'Male');
    final displayName = (widget.patientName ?? 'Patient');
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.1)
                        : const Color(0xFFF5F5F7),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: isDarkMode
                            ? Colors.black.withOpacity(0.3)
                            : const Color(0xFF475569).withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    image: DecorationImage(
                      image: AssetImage(
                        displayGender.toLowerCase() == 'female'
                            ? 'images/female.jpg'
                            : 'images/male.jpg',
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Greeting
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, ${displayName.toUpperCase()}!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                // Notification icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color:
                        isDarkMode ? Colors.white.withOpacity(0.1) : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: isDarkMode
                            ? Colors.black.withOpacity(0.3)
                            : const Color(0xFF475569).withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    CupertinoIcons.bell,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.7)
                        : const Color(0xFF475569),
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildMainHealthCard(isDarkMode),
            const SizedBox(height: 20),
            _buildHealthMetricsRow(isDarkMode),
            const SizedBox(height: 20),
            _buildSafetyStatusContainer(isDarkMode),
            const SizedBox(height: 20),
            _buildDoctorContactCard(isDarkMode),
            const SizedBox(height: 20),
            _buildAutomationGrid(isDarkMode),
            const SizedBox(height: 20),
            _buildNewspaperContainer(isDarkMode),
            const SizedBox(height: 20),
            _buildMedicationReminderContainer(isDarkMode),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  /// Main health card with heart visualization
  Widget _buildMainHealthCard(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDarkMode 
            ? const Color(0xFF1C1C1E) // Standardized dark theme main container
            : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.white.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.4) // Enhanced shadow for dark theme
                : const Color(0xFF475569).withOpacity(0.15),
            blurRadius: 16, // Standardized blur radius
            offset: const Offset(0, 6), // Standardized offset
          ),
        ],
      ),
      child: Row(
        children: [
          // Left side with health info
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Health icon in circle
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.1)
                        : const Color(0xFFF5F5F7),
                    shape: BoxShape.circle,
                  ),
                  child: TweenAnimationBuilder<double>(
                    duration: Duration(milliseconds: 1200 + (_heartRate * 8)),
                    tween: Tween<double>(begin: 0.98, end: 1.02),
                    builder: (context, scale, child) {
                      return Transform.scale(
                        scale: scale,
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

                const SizedBox(height: 16),

                Text(
                  'Health',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Last diagnosis of heart\n3 days ago',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.7)
                        : const Color(0xFF475569),
                  ),
                ),

                const SizedBox(height: 16),

                // Diagnostic button
                Container(
                  decoration: BoxDecoration(
                    color: isDarkMode 
                        ? const Color(0xFF2C2C2E) // Dark theme: consistent with cards
                        : Colors.white, // Light theme: white background
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.1)
                          : Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDarkMode
                            ? Colors.black.withOpacity(0.3)
                            : Colors.black.withOpacity(0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (context) => const DiagnosticScreen(),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        child: Text(
                          'Diagnostic',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.8)
                                : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Right side with heart illustration placeholder
          Expanded(
            flex: 1,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.05)
                    : const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Image.asset(
                  'images/heart.png',
                  width: 400,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Get heart metrics card decoration for dark theme
  BoxDecoration _getHeartCardDecorationDark() {
    return BoxDecoration(
      color: const Color(0xFF2C2C2E), // Slightly lighter than main container for contrast
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: Colors.white.withOpacity(0.1),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.4),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  /// Get heart metrics card decoration for light theme
  BoxDecoration _getHeartCardDecorationLight() {
    return BoxDecoration(
      color: Colors.white.withOpacity(1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: Colors.white.withOpacity(1),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.15),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  /// Health metrics row (pressure and rhythm)
  Widget _buildHealthMetricsRow(bool isDarkMode) {
    return Row(
      children: [
        // Heart pressure card with enhanced glassmorphism
        Expanded(
          child: Container(
            height: 100, // Fixed height for uniformity like automation cards
            decoration: isDarkMode 
                ? _getHeartCardDecorationDark()
                : _getHeartCardDecorationLight(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(14), // Slightly reduced padding like automation cards
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: Icon + Title aligned horizontally
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Enhanced icon with consistent styling
                          Container(
                            padding: const EdgeInsets.all(4), // Reduced padding for compact layout
                            decoration: BoxDecoration(
                              color: isDarkMode 
                                  ? Colors.white.withOpacity(0.1) 
                                  : Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: TweenAnimationBuilder<double>(
                              duration: Duration(milliseconds: 1000 + (_heartRate * 5)),
                              tween: Tween<double>(begin: 0.95, end: 1.05),
                              builder: (context, scale, child) {
                                return Transform.scale(
                                  scale: scale,
                                  child: Icon(
                                    CupertinoIcons.heart,
                                    color: isDarkMode
                                        ? Colors.white.withOpacity(0.8) // 80% opacity like automation cards
                                        : const Color(0xFF475569).withOpacity(0.8),
                                    size: 18, // Standardized 18px size
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Title aligned with icon
                          Expanded(
                            child: Text(
                              'Heart pressure',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                                letterSpacing: -0.2,
                                height: 1.2, // Improved line height for alignment
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      const Spacer(), // Use spacer to fill available space

                      // Pressure reading at bottom
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.0, 0.1),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOut,
                              )),
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          '$_heartPressureSystolic / $_heartPressureDiastolic',
                          key: ValueKey('$_heartPressureSystolic-$_heartPressureDiastolic'),
                          style: TextStyle(
                            fontSize: 16, // Slightly smaller for card layout
                            fontWeight: FontWeight.w700,
                            color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                            letterSpacing: -0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 16),

        // Heart rhythm card with enhanced glassmorphism
        Expanded(
          child: Container(
            height: 100, // Fixed height for uniformity like automation cards
            decoration: isDarkMode 
                ? _getHeartCardDecorationDark()
                : _getHeartCardDecorationLight(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(14), // Slightly reduced padding like automation cards
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: Icon + Title aligned horizontally
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Enhanced icon with consistent styling
                          Container(
                            padding: const EdgeInsets.all(4), // Reduced padding for compact layout
                            decoration: BoxDecoration(
                              color: isDarkMode 
                                  ? Colors.white.withOpacity(0.1) 
                                  : Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: TweenAnimationBuilder<double>(
                              duration: Duration(milliseconds: 900 + (_heartRate * 6)),
                              tween: Tween<double>(begin: 0.9, end: 1.1),
                              builder: (context, scale, child) {
                                return Transform.scale(
                                  scale: scale,
                                  child: Icon(
                                    CupertinoIcons.waveform,
                                    color: isDarkMode
                                        ? Colors.white.withOpacity(0.8) // 80% opacity like automation cards
                                        : const Color(0xFF475569).withOpacity(0.8),
                                    size: 18, // Standardized 18px size
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Title aligned with icon
                          Expanded(
                            child: Text(
                              'Heart rhythm',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                                letterSpacing: -0.2,
                                height: 1.2, // Improved line height for alignment
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      const Spacer(), // Use spacer to fill available space

                      // Heart rate reading at bottom
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.0, 0.1),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOut,
                              )),
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          '$_heartRate / min',
                          key: ValueKey(_heartRate),
                          style: TextStyle(
                            fontSize: 16, // Slightly smaller for card layout
                            fontWeight: FontWeight.w700,
                            color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                            letterSpacing: -0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Safety Status container
  Widget _buildSafetyStatusContainer(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDarkMode 
            ? const Color(0xFF1C1C1E) // Dark theme: consistent dark background
            : Colors.white, // Light theme: white background
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.white.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'Safety Status',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
            ),
          ),

          const SizedBox(height: 20),

          // All Clear status card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: isDarkMode 
                ? _getAutomationCardDecorationDark()
                : _getAutomationCardDecorationLight(),
            child: Row(
              children: [
                // Safety icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.1)
                        : Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_outline,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.7)
                        : const Color(0xFF475569),
                    size: 24,
                  ),
                ),

                const SizedBox(width: 16),

                // Status text
                Expanded(
                  child: Text(
                    'All Clear',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color:
                          isDarkMode ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Doctor contact card
  Widget _buildDoctorContactCard(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode 
            ? const Color(0xFF1C1C1E) // Standardized dark theme main container
            : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.white.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.4) // Enhanced shadow for dark theme
                : const Color(0xFF475569).withOpacity(0.15),
            blurRadius: 16, // Standardized blur radius
            offset: const Offset(0, 6), // Standardized offset
          ),
        ],
      ),
      child: Row(
        children: [
          // Doctor profile image placeholder
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.1)
                  : const Color(0xFFF5F5F7),
              shape: BoxShape.circle,
            ),
            child: Icon(
              CupertinoIcons.person_fill,
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
                  'Robert Fox',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cardiologist',
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

          // Action buttons
          Row(
            children: [
              // Message button
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.1)
                      : const Color(0xFFF5F5F7),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.chat_bubble_fill,
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.7)
                      : const Color(0xFF475569),
                  size: 20,
                ),
              ),

              const SizedBox(width: 12),

              // Call button
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.1)
                      : const Color(0xFFF5F5F7),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.phone_fill,
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.7)
                      : const Color(0xFF475569),
                  size: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build Chat Page
  Widget _buildChatPage(bool isDarkMode) {
    // Previous implementation: ChatScreenNew() - preserved in chat_screen_new.dart
    return const PatientChatScreen();
  }

  /// Build Home Automation Page (integrated from module)
  Widget _buildBulbPage(bool isDarkMode) {
    // Removed SafeArea to allow full bleed under status bar
    return const DrawerWrapper(
      homeScreen: HomeAutomationScreen(),
    );
  }

  /// Build automation header with user greeting
  // Removed: _buildAutomationHeader moved to HomeAutomationDashboard

  /// Build quick status overview cards
  // Removed: _buildQuickStatusOverview moved to HomeAutomationDashboard

  /// Build room section
  // Removed: _buildRoomSection moved to HomeAutomationDashboard

  /// Build individual room card
  // Removed: _buildRoomCard moved to HomeAutomationDashboard

  /// Build device section
  // Removed: _buildDeviceSection moved to HomeAutomationDashboard

  /// Build individual device item
  // Removed: _buildDeviceItem moved to HomeAutomationDashboard

  /// Build energy usage section
  // Removed: _buildEnergyUsageSection moved to HomeAutomationDashboard

  /// Build Settings Page
  Widget _buildSettingsPage(bool isDarkMode) {
    return const SettingsScreen();
  }

  



  // Removed _buildTopBar (no longer used after automation integration)

  // Removed debug reset and theme toggle helpers (unused)

  /// Build automation cards in vertical column layout with subtle animations
  Widget _buildAutomationGrid(bool isDarkMode) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      tween: Tween<double>(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 8 * (1 - value)), // Slide up effect: translateY(8px) -> translateY(0)
          child: Opacity(
            opacity: value, // Fade in effect: opacity: 0 -> opacity: 1
            child: Container(
              padding: const EdgeInsets.all(24), // Generous internal padding
              decoration: BoxDecoration(
                // Theme-aware background
                color: isDarkMode 
                    ? const Color(0xFF1C1C1E) // Dark theme: proper dark background
                    : Colors.white, // Light theme: white background
                borderRadius: BorderRadius.circular(28), // Increased to 28px for organic Apple-style look
                border: Border.all(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.1)
                      : Colors.white.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDarkMode
                        ? Colors.black.withOpacity(0.2)
                        : Colors.black.withOpacity(0.05), // Soft iOS floating card shadow
                    blurRadius: 24, // Enhanced blur for glassmorphism
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enhanced title with better hierarchy
          Text(
            'Home Automation',
            style: TextStyle(
              fontSize: 24, // Larger for better hierarchy
              fontWeight: FontWeight.w700, // Semibold for stronger presence
              letterSpacing: -0.4, // Tighter letter spacing as requested
              height: 1.2, // Tighter line height for impact
              color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 24), // Slightly more space after title

          // Smart Lighting Card
          _buildAutomationCard(
            title: 'Smart Light 💡',
            subtitle: '12 devices',
            icon: Icons.lightbulb_outline,
            value: '8 Active',
            color: isDarkMode
                ? Colors.white.withOpacity(0.7)
                : const Color(0xFF475569),
            isDarkMode: isDarkMode,
            height: 100, // Reduced height for column layout
          ),

          const SizedBox(height: 16),

          // Security Card
          _buildAutomationCard(
            title: 'Security 🛡️',
            subtitle: 'System Status',
            icon: Icons.security,
            value: 'ON (Armed)',
            color: isDarkMode
                ? Colors.white.withOpacity(0.7)
                : const Color(0xFF475569),
            isDarkMode: isDarkMode,
            height: 100,
          ),

          const SizedBox(height: 16), // Standard spacing between cards

          // Thermostat Card
          _buildAutomationCard(
            title: 'Thermostat',
            subtitle: 'Climate Control',
            icon: Icons.thermostat,
            value: 'AUTO 24°C',
            color: isDarkMode
                ? Colors.white.withOpacity(0.7)
                : const Color(0xFF475569),
            isDarkMode: isDarkMode,
            height: 100,
          ),

          const SizedBox(height: 16),

          // Entertainment Card
          _buildAutomationCard(
            title: 'Entertainment',
            subtitle: 'Living Room',
            icon: Icons.tv,
            value: 'Playing Music',
            color: isDarkMode
                ? Colors.white.withOpacity(0.7)
                : const Color(0xFF475569),
            isDarkMode: isDarkMode,
            height: 100,
          ),
        ],
              ), // Close Column
            ), // Close Container  
          ), // Close Opacity
        ); // Close Transform.translate
      }, // Close builder function
    ); // Close TweenAnimationBuilder
  }



  /// Get automation card decoration for dark theme
  BoxDecoration _getAutomationCardDecorationDark() {
    return BoxDecoration(
      color: const Color(0xFF2C2C2E), // Slightly lighter than main container for contrast
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: Colors.white.withOpacity(0.1),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.4),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  /// Get automation card decoration for light theme
  BoxDecoration _getAutomationCardDecorationLight() {
    return BoxDecoration(
      color: Colors.white.withOpacity(0.7),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: Colors.white.withOpacity(0.3),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.15),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  /// Build individual automation card with enhanced glassmorphism
  Widget _buildAutomationCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
    required Color color,
    required bool isDarkMode,
    required double height,
  }) {
    return Container(
      height: height,
      decoration: isDarkMode 
          ? _getAutomationCardDecorationDark()
          : _getAutomationCardDecorationLight(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(14), // Slightly reduced padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Icon + Title aligned horizontally
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Smaller icon with consistent top-left alignment
                    Container(
                      padding: const EdgeInsets.all(4), // Reduced padding for compact layout
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        icon,
                        color: color.withOpacity(0.8), // Added opacity: 0.8
                        size: 18, // Reduced to 18px as requested
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Title aligned with icon
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: -0.2,
                          height: 1.2, // Improved line height for alignment
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const Spacer(), // Use spacer to fill available space

                // Bottom section: Data and subtext with optimized spacing
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Main data value
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 16, // Optimized size to fit container
                        fontWeight: FontWeight.w700,
                        color: color,
                        letterSpacing: -0.3,
                        height: 1.1, // Tight line height for data
                      ),
                    ),
                    const SizedBox(height: 2), // Reduced spacing for compact layout
                    // Subtitle/description
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11, // Compact size for better fit
                        fontWeight: FontWeight.w400,
                        color: (isDarkMode ? Colors.white : const Color(0xFF475569))
                            .withOpacity(0.7),
                        height: 1.2, // More compact line height
                        letterSpacing: -0.1, // Subtle kerning adjustment
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Premium newspaper reading container
  Widget _buildNewspaperContainer(bool isDarkMode) {
    return Container(
      width: double.infinity,
      height: 160,
      decoration: BoxDecoration(
        color: isDarkMode 
            ? const Color(0xFF1C1C1E) // Standardized dark theme main container
            : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.white.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.4) // Enhanced shadow for dark theme
                : const Color(0xFF475569).withOpacity(0.15),
            blurRadius: 16, // Standardized blur radius
            offset: const Offset(0, 6), // Standardized offset
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Premium background pattern
            Positioned.fill(
              child: CustomPaint(
                painter: NewspaperPatternPainter(isDarkMode),
              ),
            ),

            // Main content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  // Left content
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Premium badge

                        const SizedBox(height: 12),

                        // Main title
                        Text(
                          'Read Newspaper',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: isDarkMode
                                ? Colors.white
                                : const Color(0xFF0F172A),
                            height: 1.1,
                          ),
                        ),

                        const SizedBox(height: 6),

                        // Subtitle
                        Text(
                          'Stay informed with daily news',
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

                  const SizedBox(width: 20),

                  // Right side - Newspaper icon with monochromatic styling
                  Expanded(
                    flex: 2,
                    child: Image.asset(
                      'images/newspaper.png',
                      width: 200,
                      height: 200,
                      fit: BoxFit.cover,
                      colorBlendMode: BlendMode.modulate,
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

  /// Medication reminder container with time slots
  Widget _buildMedicationReminderContainer(bool isDarkMode) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      tween: Tween<double>(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 8 * (1 - value)), // Slide up effect: translateY(8px) -> translateY(0)
          child: Opacity(
            opacity: value, // Fade in effect: opacity: 0 -> opacity: 1
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24), // Generous internal padding
              decoration: BoxDecoration(
                // Theme-aware background
                color: isDarkMode 
                    ? const Color(0xFF1C1C1E) // Dark theme: proper dark background
                    : Colors.white, // Light theme: white background
                borderRadius: BorderRadius.circular(28), // Increased to 28px for organic Apple-style look
                border: Border.all(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.1)
                      : Colors.white.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDarkMode
                        ? Colors.black.withOpacity(0.2) // Soft iOS floating card shadow
                        : Colors.black.withOpacity(0.05), // Very subtle shadow for light mode
                    blurRadius: 24, // Enhanced blur for glassmorphism
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enhanced title with better hierarchy
          Text(
            'Medication Reminder',
            style: TextStyle(
              fontSize: 24, // Larger for better hierarchy
              fontWeight: FontWeight.w700, // Semibold for stronger presence
              letterSpacing: -0.4, // Tighter letter spacing as requested
              height: 1.2, // Tighter line height for impact
              color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
            ),
          ),

          const SizedBox(height: 24), // Slightly more space after title

          // Morning medications (8:30 AM)
          _buildMedicationTimeSlot(
            time: '8:30 AM',
            medications: [
              {
                'name': 'Sergel',
                'dose': '20 mg, Take 1',
                'color': isDarkMode
                    ? Colors.white.withOpacity(0.1)
                    : const Color(0xFFF5F5F7),
                'type': 'capsule'
              },
              {
                'name': 'Dribbble',
                'dose': '150 mg, Take 1',
                'color': isDarkMode
                    ? Colors.white.withOpacity(0.05)
                    : const Color(0xFFE0E0E2),
                'type': 'pill'
              },
            ],
            isDarkMode: isDarkMode,
          ),

          const SizedBox(height: 20),

          // Evening medications (8:30 PM)
          _buildMedicationTimeSlot(
            time: '8:30 PM',
            medications: [
              {
                'name': 'Napa',
                'dose': '150 mg, Take 1',
                'color': isDarkMode
                    ? Colors.white.withOpacity(0.1)
                    : const Color(0xFFF5F5F7),
                'type': 'pill'
              },
              {
                'name': 'Napa',
                'dose': '150 mg, Take 1',
                'color': isDarkMode
                    ? Colors.white.withOpacity(0.05)
                    : const Color(0xFFE0E0E2),
                'type': 'capsule'
              },
            ],
            isDarkMode: isDarkMode,
          ),

          const SizedBox(height: 24),

          // Enhanced See More button with glassmorphism
          Center(
            child: Container(
              decoration: isDarkMode 
                  ? _getMedicationCardDecorationDark()
                  : _getMedicationCardDecorationLight(),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                    ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    // Handle see more action
                    print('See more medications tapped');
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    child: Text(
                      'See More',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.8)
                            : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
                  ),
                ),
              ),
            ),
          ),
          )
        ],
              ), // Close Column
            ), // Close Container  
          ), // Close Opacity
        ); // Close Transform.translate
      }, // Close builder function
    ); // Close TweenAnimationBuilder
  }

  /// Get medication card decoration for dark theme
  BoxDecoration _getMedicationCardDecorationDark() {
    return BoxDecoration(
      color: const Color(0xFF2C2C2E), // Slightly lighter than main container for contrast
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: Colors.white.withOpacity(0.1),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.4),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  /// Get medication card decoration for light theme
  BoxDecoration _getMedicationCardDecorationLight() {
    return BoxDecoration(
      color: Colors.white.withOpacity(0.7),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: Colors.white.withOpacity(0.3),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.15),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  /// Build individual medication time slot
  Widget _buildMedicationTimeSlot({
    required String time,
    required List<Map<String, dynamic>> medications,
    required bool isDarkMode,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Time label
        Text(
          time,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDarkMode
                ? Colors.white.withOpacity(0.7)
                : const Color(0xFF475569),
          ),
        ),

        const SizedBox(height: 12),

        // Medication cards
        Row(
          children: medications
              .map(
                (med) => Expanded(
                  child: Container(
                    margin: EdgeInsets.only(
                      right: medications.indexOf(med) < medications.length - 1
                          ? 12
                          : 0,
                    ),
                    child: _buildMedicationCard(
                      name: med['name'],
                      dose: med['dose'],
                      color: med['color'],
                      type: med['type'],
                      isDarkMode: isDarkMode,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  /// Build individual medication card with enhanced glassmorphism
  Widget _buildMedicationCard({
    required String name,
    required String dose,
    required Color color,
    required String type,
    required bool isDarkMode,
  }) {
    return Container(
      height: 100, // Fixed height for uniformity like automation cards
      decoration: isDarkMode 
          ? _getMedicationCardDecorationDark()
          : _getMedicationCardDecorationLight(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(14), // Slightly reduced padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Icon + Name aligned horizontally
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Smaller icon with consistent styling
                    Container(
                      padding: const EdgeInsets.all(4), // Reduced padding for compact layout
                      decoration: BoxDecoration(
                        color: isDarkMode 
                            ? Colors.white.withOpacity(0.1) 
                            : Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: _buildMedicationIcon(type, isDarkMode),
                    ),
                    const SizedBox(width: 10),
                    // Name aligned with icon
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: -0.2,
                          height: 1.2, // Improved line height for alignment
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const Spacer(), // Use spacer to fill available space

                // Dose information at bottom
                Text(
                  dose,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.7)
                        : const Color(0xFF475569),
                    letterSpacing: -0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build medication icon based on type
  Widget _buildMedicationIcon(String type, bool isDarkMode) {
    if (type == 'capsule') {
      // Capsule icon - standardized 18px size
      return Container(
        width: 18,
        height: 10,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          color: isDarkMode
              ? Colors.white.withOpacity(0.8) // 80% opacity like automation cards
              : const Color(0xFF475569).withOpacity(0.8),
        ),
      );
    } else {
      // Pill icon - standardized 18px size
      return Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDarkMode
              ? Colors.white.withOpacity(0.8) // 80% opacity like automation cards
              : const Color(0xFF475569).withOpacity(0.8),
        ),
      );
    }
  }
}

/// Custom painter for newspaper background pattern
class NewspaperPatternPainter extends CustomPainter {
  final bool isDarkMode;

  NewspaperPatternPainter(this.isDarkMode);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDarkMode
          ? Colors.white.withOpacity(0.02)
          : Colors.black.withOpacity(0.03)
      ..strokeWidth = 1;

    // Draw subtle grid pattern
    for (double x = 0; x < size.width; x += 20) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    for (double y = 0; y < size.height; y += 20) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
