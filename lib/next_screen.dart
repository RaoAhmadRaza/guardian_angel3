import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:ui';
import 'package:animated_notch_bottom_bar/animated_notch_bottom_bar/animated_notch_bottom_bar.dart';
import 'theme/app_theme.dart' as theme;

import 'providers/theme_provider.dart';
import 'services/session_service.dart';
import 'chat_screen_new.dart';
import 'controllers/home_automation_controller.dart';
import 'room_details_screen.dart';
import 'all_rooms_screen.dart';
import 'diagnostic_screen.dart';
import 'main.dart';

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
  /// Controller to handle PageView and also handles initial page
  final _pageController = PageController(initialPage: 0);

  /// Controller to handle bottom nav bar and also handles initial page
  late NotchBottomBarController _controller;
  int _currentIndex = 0;
  Brightness? _lastBrightness;

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

    // Initialize home automation controller
    HomeAutomationController.instance.initialize();

    // Initialize bottom bar controller
    _controller = NotchBottomBarController(index: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _healthDataTimer?.cancel();
    // Dispose bottom bar controller to prevent callbacks after widget is disposed
    _controller.dispose();
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
    final brightness = Theme.of(context).brightness;
    final isDarkMode = brightness == Brightness.dark;

    // If theme brightness changed (e.g., light <-> dark), recreate controller to avoid
    // stale listeners inside AnimatedNotchBottomBar referencing disposed animations.
    if (_lastBrightness != brightness) {
      _lastBrightness = brightness;
      // Replace controller with a fresh one while preserving index
      final old = _controller;
      _controller = NotchBottomBarController(index: _currentIndex);
      // Dispose the old one to drop any listeners
      old.dispose();
    }

    /// widget list for bottom bar pages
    final List<Widget> bottomBarPages = [
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
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: List.generate(
              bottomBarPages.length, (index) => bottomBarPages[index]),
        ),
      ),
      extendBody: true,
      bottomNavigationBar: Container(
        margin: const EdgeInsets.only(bottom: 30), // Move nav bar 30px higher
        decoration: isDarkMode
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: const Color(0xFF3C3C3E), // Subtle border for better definition
                  width: 0.5,
                ),
              )
            : null,
        child: AnimatedNotchBottomBar(
          /// Provide NotchBottomBarController
          notchBottomBarController: _controller,
          color: isDarkMode 
              ? const Color(0xFF2C2C2E) // Distinct darker gray for better contrast against dark background
              : const Color(0xFFFDFDFD),
          showLabel: true,
          textOverflow: TextOverflow.visible,
          maxLine: 1,
          shadowElevation: isDarkMode ? 8 : 5, // Add shadow elevation for better separation in dark mode
          kBottomRadius: 28.0,
          notchColor:
              isDarkMode 
                  ? const Color(0xFF3C3C3E) // Lighter notch color for better visibility
                  : const Color(0xFF475569),
          removeMargins: false,
          bottomBarWidth: 500,
          showShadow: isDarkMode ? true : true, // Enable shadow in dark mode for better separation
          // Snappier indicator movement for better perceived responsiveness
          durationInMilliSeconds: 220,
          itemLabelStyle: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500, // Slightly bolder text for better readability
            color: isDarkMode
                ? const Color(0xFF8E8E93) // More subtle iOS-style gray for labels
                : const Color(0xFF475569),
          ),
          elevation: isDarkMode ? 12 : 8, // Increase elevation in dark mode for better separation from background
          bottomBarItems: [
            BottomBarItem(
              inActiveItem: Icon(
                CupertinoIcons.house,
                color: isDarkMode
                    ? const Color(0xFF8E8E93) // More subtle iOS-style gray for inactive icons
                    : const Color(0xFF475569).withOpacity(0.6),
              ),
              activeItem: Icon(
                CupertinoIcons.house_fill,
                color: isDarkMode ? const Color(0xFFFFFFFF) : const Color(0xFF0F172A), // Pure white for better contrast when active
              ),
              itemLabel: 'Home',
            ),
            BottomBarItem(
              inActiveItem: Icon(
                CupertinoIcons.chat_bubble,
                color: isDarkMode
                    ? const Color(0xFF8E8E93) // More subtle iOS-style gray for inactive icons
                    : const Color(0xFF475569).withOpacity(0.6),
              ),
              activeItem: Icon(
                CupertinoIcons.chat_bubble_fill,
                color: isDarkMode ? const Color(0xFFFFFFFF) : const Color(0xFF0F172A), // Pure white for better contrast when active
              ),
              itemLabel: 'Chat',
            ),
            BottomBarItem(
              inActiveItem: Icon(
                CupertinoIcons.lightbulb,
                color: isDarkMode
                    ? const Color(0xFF8E8E93) // More subtle iOS-style gray for inactive icons
                    : const Color(0xFF475569).withOpacity(0.6),
              ),
              activeItem: Icon(
                CupertinoIcons.lightbulb_fill,
                color: isDarkMode ? const Color(0xFFFFFFFF) : const Color(0xFF0F172A), // Pure white for better contrast when active
              ),
              itemLabel: 'Automation',
            ),
            BottomBarItem(
              inActiveItem: Icon(
                CupertinoIcons.gear,
                color: isDarkMode
                    ? const Color(0xFF8E8E93) // More subtle iOS-style gray for inactive icons
                    : const Color(0xFF475569).withOpacity(0.6),
              ),
              activeItem: Icon(
                CupertinoIcons.gear_solid,
                color: isDarkMode ? const Color(0xFFFFFFFF) : const Color(0xFF0F172A), // Pure white for better contrast when active
              ),
              itemLabel: 'Settings',
            ),
          ],
          onTap: (index) {
            // Move the notch indicator immediately
            _controller.jumpTo(index);
            _currentIndex = index;
            // Animate page to stay in sync with the indicator motion
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
            );
          },
          kIconSize: 24.0,
        ),
      ),
    );
  }

  /// Build Home Page
  Widget _buildHomePage(bool isDarkMode) {
    return SafeArea(
      child: Column(
        children: [
          // Top bar with debug reset and theme toggle
          _buildTopBar(isDarkMode),
          // Home content
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header section with greeting
                  _buildHeaderSection(isDarkMode),

                  const SizedBox(height: 24),

                  // Heart Health title
                  Text(
                    'Heart Health',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color:
                          isDarkMode ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Main health card with heart diagram
                  _buildMainHealthCard(isDarkMode),

                  const SizedBox(height: 20),

                  // Health metrics row
                  _buildHealthMetricsRow(isDarkMode),

                  const SizedBox(height: 24),

                  // Safety Status section
                  _buildSafetyStatusContainer(isDarkMode),

                  const SizedBox(height: 20),

                  // Home Automation section (direct automation grid without outer container)
                  _buildAutomationGrid(isDarkMode),

                  const SizedBox(height: 20),

                  // Doctor contact card
                  _buildDoctorContactCard(isDarkMode),

                  const SizedBox(height: 20),

                  // Newspaper reading container
                  _buildNewspaperContainer(isDarkMode),

                  const SizedBox(height: 20),

                  // Medication reminder container
                  _buildMedicationReminderContainer(isDarkMode),

                  const SizedBox(height: 80), // Extra space for bottom nav
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Header section with profile and greeting
  Widget _buildHeaderSection(bool isDarkMode) {
    // Use passed patient name first, then fallback to SharedPreferences, then default
    final displayName = widget.patientName?.split(' ').first ?? 'Jacob';
    final displayGender = widget.selectedGender ?? 'male';

    // Debug prints to check what data is being received
    print('NextScreen - patientName: ${widget.patientName}');
    print('NextScreen - selectedGender: ${widget.selectedGender}');
    print('NextScreen - displayName: $displayName');
    print('NextScreen - displayGender: $displayGender');

    return Row(
      children: [
        // Profile image placeholder
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

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, ${displayName.toUpperCase()}!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
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
            color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.white,
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
    return ChatScreenNew();
  }

  /// Build Home Automation Dashboard
  Widget _buildBulbPage(bool isDarkMode) {
    return SafeArea(
      child: Column(
        children: [
          _buildTopBar(isDarkMode),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // Header Section
                  _buildAutomationHeader(isDarkMode),

                  const SizedBox(height: 24),

                  // Quick Status Overview
                  _buildQuickStatusOverview(isDarkMode),

                  const SizedBox(height: 28),

                  // Room Section
                  _buildRoomSection(isDarkMode),

                  const SizedBox(height: 28),

                  // Device Section
                  _buildDeviceSection(isDarkMode),

                  const SizedBox(height: 28),

                  // Energy Usage Section
                  _buildEnergyUsageSection(isDarkMode),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build automation header with user greeting
  Widget _buildAutomationHeader(bool isDarkMode) {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: isDarkMode 
                ? const Color(0xFF2C2C2E) // Standardized dark theme card
                : Colors.white,
            borderRadius: BorderRadius.circular(25),
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
                    : const Color(0xFF475569).withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: Image.asset(
              'images/male.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  CupertinoIcons.person_fill,
                  color: isDarkMode ? Colors.white : const Color(0xFF475569),
                  size: 24,
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Alex',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Text(
                'Good Morning!',
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
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.white.withOpacity(0.1)
                : const Color(0xFFF5F5F7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            CupertinoIcons.bell,
            color: isDarkMode ? Colors.white : const Color(0xFF475569),
            size: 20,
          ),
        ),
      ],
    );
  }

  /// Build quick status overview cards
  Widget _buildQuickStatusOverview(bool isDarkMode) {
    final statusItems = [
      {
        'icon': CupertinoIcons.thermometer,
        'label': 'Temperature',
        'value': '72°F',
        'color': const Color(0xFF3B82F6),
      },
      {
        'icon': CupertinoIcons.lightbulb,
        'label': 'Light',
        'value': '4 On',
        'color': const Color(0xFFEAB308),
      },
      {
        'icon': CupertinoIcons.bolt,
        'label': 'Energy',
        'value': 'Low',
        'color': const Color(0xFF10B981),
      },
      {
        'icon': CupertinoIcons.shield,
        'label': 'Security',
        'value': 'Alarmed',
        'color': const Color(0xFF8B5CF6),
      },
    ];

    return Row(
      children: statusItems.map((item) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode 
                  ? const Color(0xFF2C2C2E) // Standardized dark theme card
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
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
                      : const Color(0xFF475569).withOpacity(0.08),
                  blurRadius: 16, // Standardized blur radius
                  offset: const Offset(0, 6), // Standardized offset
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: (item['color'] as Color).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item['icon'] as IconData,
                    color: item['color'] as Color,
                    size: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item['label'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.7)
                        : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item['value'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Build room section
  Widget _buildRoomSection(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Room',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        AllRoomsScreen(isDarkMode: isDarkMode),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                      const begin = Offset(1.0, 0.0);
                      const end = Offset.zero;
                      const curve = Curves.easeInOutCubic;

                      var tween = Tween(begin: begin, end: end).chain(
                        CurveTween(curve: curve),
                      );

                      return SlideTransition(
                        position: animation.drive(tween),
                        child: child,
                      );
                    },
                    transitionDuration: const Duration(milliseconds: 300),
                  ),
                );
                print('Navigate to all rooms');
              },
              child: Text(
                'See all',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF3B82F6),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildRoomCard(
              isDarkMode: isDarkMode,
              icon: CupertinoIcons.house,
              label: 'Living Room',
              devices: '5 Devices',
              color: const Color(0xFF3B82F6),
            ),
            const SizedBox(width: 12),
            _buildRoomCard(
              isDarkMode: isDarkMode,
              icon: CupertinoIcons.scissors,
              label: 'Kitchen',
              devices: '3 Devices',
              color: const Color(0xFFEAB308),
            ),
            const SizedBox(width: 12),
            _buildRoomCard(
              isDarkMode: isDarkMode,
              icon: CupertinoIcons.bed_double,
              label: 'Bed Room',
              devices: '3 Devices',
              color: const Color(0xFF8B5CF6),
            ),
          ],
        ),
      ],
    );
  }

  /// Build individual room card
  Widget _buildRoomCard({
    required bool isDarkMode,
    required IconData icon,
    required String label,
    required String devices,
    required Color color,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          // Navigate to room detail screen
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  RoomDetailsScreen(
                roomName: label,
                roomIcon: icon,
                roomColor: color,
                isDarkMode: isDarkMode,
              ),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                const begin = Offset(1.0, 0.0);
                const end = Offset.zero;
                const curve = Curves.easeInOutCubic;

                var tween = Tween(begin: begin, end: end).chain(
                  CurveTween(curve: curve),
                );

                return SlideTransition(
                  position: animation.drive(tween),
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 300),
            ),
          );
          print('Navigate to room: $label');
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode 
                ? const Color(0xFF2C2C2E) // Standardized dark theme card
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
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
                    : const Color(0xFF475569).withOpacity(0.08),
                blurRadius: 16, // Standardized blur radius
                offset: const Offset(0, 6), // Standardized offset
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                devices,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.7)
                      : const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build device section
  Widget _buildDeviceSection(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Device',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            Text(
              'Manage',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF3B82F6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildDeviceItem(
          isDarkMode: isDarkMode,
          icon: CupertinoIcons.lightbulb,
          name: 'Living Room Light',
          status: 'On • 50% Brightness',
          isOn: true,
          color: const Color(0xFFEAB308),
        ),
        const SizedBox(height: 12),
        _buildDeviceItem(
          isDarkMode: isDarkMode,
          icon: CupertinoIcons.thermometer,
          name: 'Thermostat',
          status: 'Cooling • Auto Mode',
          isOn: true,
          color: const Color(0xFF3B82F6),
          showTemperature: true,
          temperature: '72°F',
        ),
        const SizedBox(height: 12),
        _buildDeviceItem(
          isDarkMode: isDarkMode,
          icon: CupertinoIcons.wind,
          name: 'Fan',
          status: 'On • 60% Speed',
          isOn: true,
          color: const Color(0xFF10B981),
        ),
      ],
    );
  }

  /// Build individual device item
  Widget _buildDeviceItem({
    required bool isDarkMode,
    required IconData icon,
    required String name,
    required String status,
    required bool isOn,
    required Color color,
    bool showTemperature = false,
    String? temperature,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode 
            ? const Color(0xFF2C2C2E) // Standardized dark theme card
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
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
                : const Color(0xFF475569).withOpacity(0.08),
            blurRadius: 16, // Standardized blur radius
            offset: const Offset(0, 6), // Standardized offset
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.7)
                        : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
          if (showTemperature && temperature != null) ...[
            Text(
              temperature,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(width: 16),
          ],
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              // TODO: Toggle device
              print('Toggle device: $name');
            },
            child: Container(
              width: 50,
              height: 30,
              decoration: BoxDecoration(
                color: isOn
                    ? const Color(0xFF3B82F6)
                    : isDarkMode
                        ? Colors.white.withOpacity(0.2)
                        : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(15),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 26,
                  height: 26,
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build energy usage section
  Widget _buildEnergyUsageSection(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode 
            ? const Color(0xFF1C1C1E) // Standardized dark theme main container
            : Colors.white,
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
                ? Colors.black.withOpacity(0.4) // Enhanced shadow for dark theme
                : const Color(0xFF475569).withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Energy Usage',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Text(
                'Details',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF3B82F6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Today's Usage",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.7)
                          : const Color(0xFF475569),
                    ),
                  ),
                  Text(
                    'Apr 22, 2025',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.5)
                          : const Color(0xFF475569).withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '12.4 kWh',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color:
                          isDarkMode ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    '-5% vs yesterday',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.1)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              widthFactor: 0.6,
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build Settings Page
  Widget _buildSettingsPage(bool isDarkMode) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSettingsHeader(isDarkMode),
              const SizedBox(height: 24),
              _buildUserProfileCard(isDarkMode),
              const SizedBox(height: 32),
              _buildOtherSettingsSection(isDarkMode),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsHeader(bool isDarkMode) {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            // Back navigation if needed
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.1)
                  : const Color(0xFF2A2A2A).withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              color: isDarkMode ? Colors.white : const Color(0xFF2A2A2A),
              size: 18,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          'Settings',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildUserProfileCard(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode 
            ? const Color(0xFF2C2C2E) // Standardized dark theme card
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
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
                : const Color(0xFF475569).withOpacity(0.06),
            blurRadius: 16, // Standardized blur radius
            offset: const Offset(0, 6), // Standardized offset
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.person,
              color: Color(0xFF3B82F6),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alfred Daniel',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Product UI Designer',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.6)
                        : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: isDarkMode
                ? Colors.white.withOpacity(0.4)
                : const Color(0xFF475569).withOpacity(0.4),
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildOtherSettingsSection(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Other settings',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDarkMode
                ? Colors.white.withOpacity(0.8)
                : const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: isDarkMode 
                ? const Color(0xFF2C2C2E) // Standardized dark theme card
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
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
                    : const Color(0xFF475569).withOpacity(0.06),
                blurRadius: 16, // Standardized blur radius
                offset: const Offset(0, 6), // Standardized offset
              ),
            ],
          ),
          child: Column(
            children: [
              _buildSettingsItem(
                icon: Icons.person_outline,
                title: 'Profile details',
                isDarkMode: isDarkMode,
                onTap: () {
                  HapticFeedback.lightImpact();
                  print('Navigate to profile details');
                },
              ),
              _buildSettingsDivider(isDarkMode),
              _buildSettingsItem(
                icon: Icons.lock_outline,
                title: 'Password',
                isDarkMode: isDarkMode,
                onTap: () {
                  HapticFeedback.lightImpact();
                  print('Navigate to password settings');
                },
              ),
              _buildSettingsDivider(isDarkMode),
              _buildSettingsItem(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                isDarkMode: isDarkMode,
                onTap: () {
                  HapticFeedback.lightImpact();
                  print('Navigate to notification settings');
                },
              ),
              _buildSettingsDivider(isDarkMode),
              _buildDarkModeToggleItem(isDarkMode),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            color: isDarkMode 
                ? const Color(0xFF2C2C2E) // Standardized dark theme card
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
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
                    : const Color(0xFF475569).withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildSettingsItem(
                icon: Icons.info_outline,
                title: 'About application',
                isDarkMode: isDarkMode,
                onTap: () {
                  HapticFeedback.lightImpact();
                  print('Navigate to about application');
                },
              ),
              _buildSettingsDivider(isDarkMode),
              _buildSettingsItem(
                icon: Icons.help_outline,
                title: 'Help/FAQ',
                isDarkMode: isDarkMode,
                onTap: () {
                  HapticFeedback.lightImpact();
                  print('Navigate to help/FAQ');
                },
              ),
              _buildSettingsDivider(isDarkMode),
              _buildSettingsItem(
                icon: Icons.logout,
                title: 'Deactivate my account',
                isDarkMode: isDarkMode,
                isDestructive: true,
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showDeactivateAccountDialog(isDarkMode);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        if (kDebugMode) _buildDebugSection(isDarkMode),
      ],
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required bool isDarkMode,
    required VoidCallback onTap,
    bool isDestructive = false,
    Widget? trailing,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                icon,
                color: isDestructive
                    ? Colors.red
                    : (isDarkMode ? Colors.white : const Color(0xFF2A2A2A)),
                size: 20,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDestructive
                        ? Colors.red
                        : (isDarkMode ? Colors.white : const Color(0xFF0F172A)),
                  ),
                ),
              ),
              trailing ??
                  Icon(
                    Icons.chevron_right,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.4)
                        : const Color(0xFF475569).withOpacity(0.4),
                    size: 20,
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDarkModeToggleItem(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            Icons.dark_mode_outlined,
            color: isDarkMode ? Colors.white : const Color(0xFF2A2A2A),
            size: 20,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Dark mode',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
          GestureDetector(
            onTap: () async {
              HapticFeedback.lightImpact();
              await ThemeProvider.instance.toggleTheme();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 52,
              height: 28,
              decoration: BoxDecoration(
                color: isDarkMode
                    ? const Color(0xFF3B82F6)
                    : const Color(0xFF475569).withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 300),
                alignment:
                    isDarkMode ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsDivider(bool isDarkMode) {
    return Container(
      height: 1,
      margin: const EdgeInsets.only(left: 52),
      color: isDarkMode
          ? Colors.white.withOpacity(0.1)
          : const Color(0xFF475569).withOpacity(0.1),
    );
  }

  Widget _buildDebugSection(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.red.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bug_report,
                color: Colors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Debug Mode',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                HapticFeedback.lightImpact();
                await SessionService.instance.resetSession();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const MyApp()),
                  (route) => false,
                );
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.refresh,
                      color: Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Reset Session',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.red,
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

  void _showDeactivateAccountDialog(bool isDarkMode) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDarkMode 
              ? const Color(0xFF2C2C2E) // Standardized dark theme card
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.1)
                  : Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          title: Text(
            'Deactivate Account',
            style: TextStyle(
              color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Are you sure you want to deactivate your account? This action cannot be undone.',
            style: TextStyle(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.8)
                  : const Color(0xFF475569),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.8)
                      : const Color(0xFF475569),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Handle account deactivation
                print('Account deactivation requested');
              },
              child: const Text(
                'Deactivate',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }



  Widget _buildTopBar(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Debug reset button (only in debug mode)
          if (kDebugMode)
            _buildDebugResetButton(isDarkMode)
          else
            const SizedBox(width: 56), // Spacer when not in debug mode

          // Theme toggle button
          _buildThemeToggle(isDarkMode),
        ],
      ),
    );
  }

  Widget _buildDebugResetButton(bool isDarkMode) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.red.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? Colors.red.withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            HapticFeedback.lightImpact();
            // Reset session and restart app
            await SessionService.instance.resetSession();
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const MyApp()),
              (route) => false,
            );
          },
          child: const Center(
            child: Icon(
              Icons.refresh,
              color: Colors.red,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeToggle(bool isDarkMode) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withOpacity(0.1)
            : const Color(0xFFFDFDFD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.1)
              : const Color(0xFFE0E0E2),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            HapticFeedback.lightImpact();
            await ThemeProvider.instance.toggleTheme();
          },
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                isDarkMode ? Icons.light_mode : Icons.dark_mode,
                key: ValueKey(isDarkMode),
                color: isDarkMode
                    ? Colors.white.withOpacity(0.8)
                    : const Color(0xFF475569),
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }

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
