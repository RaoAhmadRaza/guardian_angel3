import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:animated_notch_bottom_bar/animated_notch_bottom_bar/animated_notch_bottom_bar.dart';
import 'theme/app_theme.dart' as theme;
import 'providers/theme_provider.dart';
import 'services/session_service.dart';
import 'services/patient_service.dart';
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
  final NotchBottomBarController _controller =
      NotchBottomBarController(index: 0);

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
  }

  @override
  void dispose() {
    _pageController.dispose();
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
        child: AnimatedNotchBottomBar(
          /// Provide NotchBottomBarController
          notchBottomBarController: _controller,
          color: isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFFDFDFD),
          showLabel: true,
          textOverflow: TextOverflow.visible,
          maxLine: 1,
          shadowElevation: isDarkMode ? 2 : 5,
          kBottomRadius: 28.0,
          notchColor:
              isDarkMode ? const Color(0xFF3A3A3A) : const Color(0xFF475569),
          removeMargins: false,
          bottomBarWidth: 500,
          showShadow: isDarkMode ? false : true,
          durationInMilliSeconds: 300,
          itemLabelStyle: TextStyle(
            fontSize: 10,
            color: isDarkMode
                ? Colors.white.withOpacity(0.7)
                : const Color(0xFF475569),
          ),
          elevation: 8,
          bottomBarItems: [
            BottomBarItem(
              inActiveItem: Icon(
                CupertinoIcons.house,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.5)
                    : const Color(0xFF475569).withOpacity(0.6),
              ),
              activeItem: Icon(
                CupertinoIcons.house_fill,
                color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
              ),
              itemLabel: 'Home',
            ),
            BottomBarItem(
              inActiveItem: Icon(
                CupertinoIcons.chat_bubble,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.5)
                    : const Color(0xFF475569).withOpacity(0.6),
              ),
              activeItem: Icon(
                CupertinoIcons.chat_bubble_fill,
                color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
              ),
              itemLabel: 'Chat',
            ),
            BottomBarItem(
              inActiveItem: Icon(
                CupertinoIcons.lightbulb,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.5)
                    : const Color(0xFF475569).withOpacity(0.6),
              ),
              activeItem: Icon(
                CupertinoIcons.lightbulb_fill,
                color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
              ),
              itemLabel: 'Insights',
            ),
            BottomBarItem(
              inActiveItem: Icon(
                CupertinoIcons.gear,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.5)
                    : const Color(0xFF475569).withOpacity(0.6),
              ),
              activeItem: Icon(
                CupertinoIcons.gear_solid,
                color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
              ),
              itemLabel: 'Settings',
            ),
          ],
          onTap: (index) {
            _pageController.jumpToPage(index);
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

                  const SizedBox(height: 20),

                  // Doctor contact card
                  _buildDoctorContactCard(isDarkMode),

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
            color:
                isDarkMode ? const Color(0xFF475569) : const Color(0xFFF5F5F7),
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
        color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : const Color(0xFF475569).withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
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
                        ? Colors.white.withOpacity(0.1)
                        : const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.2)
                          : const Color(0xFFE0E0E2),
                      width: 1,
                    ),
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
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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

  /// Health metrics row (pressure and rhythm)
  Widget _buildHealthMetricsRow(bool isDarkMode) {
    return Row(
      children: [
        // Heart pressure card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: isDarkMode
                      ? Colors.black.withOpacity(0.3)
                      : const Color(0xFF475569).withOpacity(0.15),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TweenAnimationBuilder<double>(
                  duration: Duration(milliseconds: 1000 + (_heartRate * 5)),
                  tween: Tween<double>(begin: 0.95, end: 1.05),
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: Icon(
                        CupertinoIcons.heart,
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.7)
                            : const Color(0xFF475569),
                        size: 24,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  'Heart pressure',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.7)
                        : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
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
                    key: ValueKey(
                        '$_heartPressureSystolic-$_heartPressureDiastolic'),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color:
                          isDarkMode ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 16),

        // Heart rhythm card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: isDarkMode
                      ? Colors.black.withOpacity(0.3)
                      : const Color(0xFF475569).withOpacity(0.15),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TweenAnimationBuilder<double>(
                  duration: Duration(milliseconds: 900 + (_heartRate * 6)),
                  tween: Tween<double>(begin: 0.9, end: 1.1),
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: Icon(
                        CupertinoIcons.waveform,
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.7)
                            : const Color(0xFF475569),
                        size: 24,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  'Heart rhythm',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.7)
                        : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
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
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color:
                          isDarkMode ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Doctor contact card
  Widget _buildDoctorContactCard(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : const Color(0xFF475569).withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
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
                  ? const Color(0xFF475569)
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
    return SafeArea(
      child: Column(
        children: [
          _buildTopBar(isDarkMode),
          Expanded(
            child: Center(
              child: Text(
                'Chat with Guardian Angel\nAI Assistant',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build Insights/Bulb Page
  Widget _buildBulbPage(bool isDarkMode) {
    return SafeArea(
      child: Column(
        children: [
          _buildTopBar(isDarkMode),
          Expanded(
            child: Center(
              child: Text(
                'Health Insights\n& Analytics',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
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
      child: Column(
        children: [
          _buildTopBar(isDarkMode),
          Expanded(
            child: Center(
              child: Text(
                'Settings & Preferences',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
          ),
        ],
      ),
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
}
