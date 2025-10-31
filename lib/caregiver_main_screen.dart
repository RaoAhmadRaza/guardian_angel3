import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:animated_notch_bottom_bar/animated_notch_bottom_bar/animated_notch_bottom_bar.dart';
import 'colors.dart';
import 'providers/theme_provider.dart';
import 'all_rooms_screen.dart';
import 'chat_screen_new.dart';
import 'services/session_service.dart';
import 'main.dart';
import 'welcome.dart';
import 'services/session_service.dart';

class CaregiverMainScreen extends StatefulWidget {
  final String? caregiverName;
  final String? patientName;
  final String? relationship;
  final String? phone;
  final String? email;

  const CaregiverMainScreen({
    super.key,
    this.caregiverName,
    this.patientName,
    this.relationship,
    this.phone,
    this.email,
  });

  @override
  State<CaregiverMainScreen> createState() => _CaregiverMainScreenState();
}

class _CaregiverMainScreenState extends State<CaregiverMainScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late NotchBottomBarController _controller;
  late PageController _pageController;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Session management
  Timer? _sessionTimer;

  // Caregiver data
  String get displayCaregiverName => widget.caregiverName ?? 'Sarah Thompson';
  String get displayPatientName => widget.patientName ?? 'Jacob';
  String get displayRelationship => widget.relationship ?? 'Mother';
  String get displayPhone => widget.phone ?? '+1 (555) 123-4567';
  String get displayEmail => widget.email ?? 'sarah.thompson@email.com';

  @override
  void initState() {
    super.initState();

    // Initialize controllers
    _controller = NotchBottomBarController(index: 0);
    _pageController = PageController(initialPage: 0);

    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    // Start animations
    _fadeController.forward();
    _slideController.forward();

    // Start session monitoring
    _checkSessionPeriodically();

    // Debug output
    debugPrint(
        '🏥 CaregiverMainScreen - caregiverName: ${widget.caregiverName}');
    debugPrint('🏥 CaregiverMainScreen - patientName: ${widget.patientName}');
    debugPrint(
        '🏥 CaregiverMainScreen - displayCaregiverName: $displayCaregiverName');
    debugPrint(
        '🏥 CaregiverMainScreen - displayPatientName: $displayPatientName');
  }

  /// Periodically check session validity and auto-logout if expired
  void _checkSessionPeriodically() {
    _sessionTimer = Timer.periodic(const Duration(hours: 1), (timer) async {
      if (mounted) {
        final hasValidSession = await SessionService.instance.hasValidSession();

        if (!hasValidSession) {
          timer.cancel();
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const MyApp()),
              (route) => false,
            );
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _fadeController.dispose();
    _slideController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    // Define the pages for navigation
    final bottomBarPages = [
      _buildHomeView(isDarkMode, isTablet),
      _buildChatView(isDarkMode, isTablet),
      _buildCaregiverSettingsView(isDarkMode, isTablet),
    ];

    return Scaffold(
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: isDarkMode
                      ? AppTheme.primaryGradient
                      : AppTheme.lightPrimaryGradient,
                ),
                child: PageView(
                  controller: _pageController,
                  children: List.generate(
                      bottomBarPages.length, (index) => bottomBarPages[index]),
                ),
              ),
            ),
          );
        },
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

  Widget _buildHomeView(bool isDarkMode, bool isTablet) {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.all(isTablet ? 32.0 : 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              _buildCaregiverHeader(isDarkMode, isTablet),
              const SizedBox(height: 32),

              // Patient Status Card
              _buildPatientStatusCard(isDarkMode, isTablet),
              const SizedBox(height: 24),

              // Quick Actions
              _buildQuickActions(isDarkMode, isTablet),
              const SizedBox(height: 24),

              // Home Automation Section
              _buildHomeAutomationSection(isDarkMode, isTablet),
              const SizedBox(height: 24),

              // Recent Alerts
              _buildRecentAlerts(isDarkMode, isTablet),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCaregiverHeader(bool isDarkMode, bool isTablet) {
    return Row(
      children: [
        // Profile Avatar
        Container(
          width: isTablet ? 64 : 56,
          height: isTablet ? 64 : 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: isDarkMode
                  ? [const Color(0xFF475569), const Color(0xFF64748B)]
                  : [const Color(0xFF475569), const Color(0xFF64748B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: isDarkMode
                    ? Colors.black.withOpacity(0.3)
                    : const Color(0xFF475569).withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.person,
            color: Colors.white,
            size: isTablet ? 32 : 28,
          ),
        ),
        const SizedBox(width: 16),

        // Caregiver Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good ${_getTimeOfDay()}, $displayCaregiverName',
                style: GoogleFonts.inter(
                  fontSize: isTablet ? 24 : 20,
                  fontWeight: FontWeight.w700,
                  color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Caring for $displayPatientName • $displayRelationship',
                style: GoogleFonts.inter(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.7)
                      : const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),

        // Theme Toggle
        Container(
          width: isTablet ? 48 : 44,
          height: isTablet ? 48 : 44,
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
                      color: const Color(0xFF475569).withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: IconButton(
            icon: Icon(
              ThemeProvider.instance.themeIcon,
              color: isDarkMode ? Colors.white : const Color(0xFF404040),
              size: isTablet ? 24 : 20,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              ThemeProvider.instance.toggleTheme();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPatientStatusCard(bool isDarkMode, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 24 : 20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.favorite,
                  color: Color(0xFF10B981),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$displayPatientName\'s Status',
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 20 : 18,
                        fontWeight: FontWeight.w700,
                        color:
                            isDarkMode ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Last updated: 2 minutes ago',
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 14 : 12,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.7)
                            : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Stable',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Health Metrics
          Row(
            children: [
              Expanded(
                child: _buildHealthMetric(
                  'Heart Rate',
                  '72 BPM',
                  Icons.favorite,
                  const Color(0xFFEF4444),
                  isDarkMode,
                  isTablet,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildHealthMetric(
                  'Blood Pressure',
                  '120/80',
                  Icons.speed,
                  const Color(0xFF3B82F6),
                  isDarkMode,
                  isTablet,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthMetric(String label, String value, IconData icon,
      Color color, bool isDarkMode, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withOpacity(0.05)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.1)
              : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: isTablet ? 20 : 16,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: isTablet ? 18 : 16,
              fontWeight: FontWeight.w700,
              color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: isTablet ? 12 : 10,
              fontWeight: FontWeight.w500,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.7)
                  : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool isDarkMode, bool isTablet) {
    final actions = [
      {
        'title': 'Call Patient',
        'icon': Icons.phone,
        'color': const Color(0xFF10B981),
        'onTap': () => _callPatient(),
      },
      {
        'title': 'Emergency',
        'icon': Icons.emergency,
        'color': const Color(0xFFEF4444),
        'onTap': () => _handleEmergency(),
      },
      {
        'title': 'Medication',
        'icon': Icons.medication,
        'color': const Color(0xFF8B5CF6),
        'onTap': () => _viewMedication(),
      },
      {
        'title': 'Reports',
        'icon': Icons.analytics,
        'color': const Color(0xFF3B82F6),
        'onTap': () => setState(() => _currentIndex = 2),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.inter(
            fontSize: isTablet ? 20 : 18,
            fontWeight: FontWeight.w700,
            color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: isTablet ? 16 : 12,
            mainAxisSpacing: isTablet ? 16 : 12,
            childAspectRatio: 1,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) {
            final action = actions[index];
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                action['onTap'] as VoidCallback;
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.05)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.1)
                        : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                  boxShadow: isDarkMode
                      ? null
                      : [
                          BoxShadow(
                            color: const Color(0xFF475569).withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (action['color'] as Color).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        action['icon'] as IconData,
                        color: action['color'] as Color,
                        size: isTablet ? 24 : 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      action['title'] as String,
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 12 : 10,
                        fontWeight: FontWeight.w600,
                        color:
                            isDarkMode ? Colors.white : const Color(0xFF0F172A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHomeAutomationSection(bool isDarkMode, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Home Environment',
              style: GoogleFonts.inter(
                fontSize: isTablet ? 20 : 18,
                fontWeight: FontWeight.w700,
                color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AllRoomsScreen(isDarkMode: isDarkMode),
                  ),
                );
              },
              child: Text(
                'See all',
                style: GoogleFonts.inter(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode
                      ? const Color(0xFF475569)
                      : const Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildAutomationGrid(isDarkMode),
      ],
    );
  }

  Widget _buildAutomationGrid(bool isDarkMode) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row - 2 containers with 2:1 ratio
          Row(
            children: [
              // Large container - Smart Lighting
              Expanded(
                flex: 2,
                child: _buildAutomationCard(
                  title: 'Patient Room',
                  subtitle: 'Optimal lighting',
                  icon: Icons.lightbulb_outline,
                  value: 'Comfortable',
                  color: const Color(0xFF475569),
                  isDarkMode: isDarkMode,
                  height: 140,
                ),
              ),
              const SizedBox(width: 16),
              // Small container - Security
              Expanded(
                flex: 1,
                child: _buildAutomationCard(
                  title: 'Security',
                  subtitle: 'Monitoring',
                  icon: Icons.security,
                  value: 'Active',
                  color: const Color(0xFF475569),
                  isDarkMode: isDarkMode,
                  height: 140,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Bottom row - 2 containers with 1:2 ratio
          Row(
            children: [
              // Small container - Climate
              Expanded(
                flex: 1,
                child: _buildAutomationCard(
                  title: 'Temperature',
                  subtitle: '22°C',
                  icon: Icons.thermostat,
                  value: 'Perfect',
                  color: const Color(0xFF475569),
                  isDarkMode: isDarkMode,
                  height: 120,
                ),
              ),
              const SizedBox(width: 16),
              // Large container - Medication Reminder
              Expanded(
                flex: 2,
                child: _buildAutomationCard(
                  title: 'Medication',
                  subtitle: 'Next dose',
                  icon: Icons.medication,
                  value: 'In 30 mins',
                  color: const Color(0xFF475569),
                  isDarkMode: isDarkMode,
                  height: 120,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withOpacity(0.05)
            : const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.2)
              : const Color(0xFFE0E0E2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header with icon and title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // Bottom section with value and subtitle
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Value
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 4),

              // Subtitle
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.7)
                      : const Color(0xFF475569),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAlerts(bool isDarkMode, bool isTablet) {
    final alerts = [
      {
        'title': 'Medication Reminder',
        'subtitle': '$displayPatientName needs to take evening medication',
        'time': '30 minutes ago',
        'icon': Icons.medication,
        'color': const Color(0xFF8B5CF6),
        'isUrgent': false,
      },
      {
        'title': 'Heart Rate Spike',
        'subtitle': 'Brief elevation to 95 BPM, now stable',
        'time': '2 hours ago',
        'icon': Icons.favorite,
        'color': const Color(0xFFEF4444),
        'isUrgent': false,
      },
      {
        'title': 'Sleep Quality',
        'subtitle': 'Good night sleep - 8 hours total',
        'time': '8 hours ago',
        'icon': Icons.bedtime,
        'color': const Color(0xFF10B981),
        'isUrgent': false,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: GoogleFonts.inter(
            fontSize: isTablet ? 20 : 18,
            fontWeight: FontWeight.w700,
            color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: alerts.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final alert = alerts[index];
            return Container(
              padding: EdgeInsets.all(isTablet ? 20 : 16),
              decoration: BoxDecoration(
                color:
                    isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.1)
                      : const Color(0xFFE2E8F0),
                  width: 1,
                ),
                boxShadow: isDarkMode
                    ? null
                    : [
                        BoxShadow(
                          color: const Color(0xFF475569).withOpacity(0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (alert['color'] as Color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      alert['icon'] as IconData,
                      color: alert['color'] as Color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert['title'] as String,
                          style: GoogleFonts.inter(
                            fontSize: isTablet ? 16 : 14,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          alert['subtitle'] as String,
                          style: GoogleFonts.inter(
                            fontSize: isTablet ? 14 : 12,
                            fontWeight: FontWeight.w400,
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.7)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    alert['time'] as String,
                    style: GoogleFonts.inter(
                      fontSize: isTablet ? 12 : 10,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.5)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildChatView(bool isDarkMode, bool isTablet) {
    return SafeArea(
      child: ChatScreenNew(),
    );
  }

  Widget _buildCaregiverSettingsView(bool isDarkMode, bool isTablet) {
    return SafeArea(
      child: Column(
        children: [
          // Header with profile card
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isTablet ? 32.0 : 20.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFFF8C42),
                  const Color(0xFFFF6B35),
                ],
              ),
            ),
            child: Column(
              children: [
                // Profile card with rounded design
                Container(
                  padding: EdgeInsets.all(isTablet ? 24 : 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Profile avatar
                      Container(
                        width: isTablet ? 64 : 56,
                        height: isTablet ? 64 : 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: isDarkMode
                                ? [
                                    const Color(0xFF6366F1),
                                    const Color(0xFF8B5CF6)
                                  ]
                                : [
                                    const Color(0xFF4F46E5),
                                    const Color(0xFF7C3AED)
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: Icon(
                            Icons.person,
                            color: Colors.white,
                            size: isTablet ? 32 : 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Profile info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayCaregiverName,
                              style: GoogleFonts.inter(
                                fontSize: isTablet ? 24 : 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              displayEmail,
                              style: GoogleFonts.inter(
                                fontSize: isTablet ? 16 : 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Verified badge
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.verified,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Settings menu items
          Expanded(
            child: Container(
              color: isDarkMode
                  ? const Color(0xFF1A1A1A)
                  : const Color(0xFFFDFDFD),
              child: ListView(
                padding: EdgeInsets.all(isTablet ? 32.0 : 20.0),
                children: [
                  _buildSettingsMenuItem(
                    isDarkMode: isDarkMode,
                    isTablet: isTablet,
                    icon: Icons.person_outline,
                    title: 'Profile',
                    onTap: () => print('Navigate to Profile'),
                  ),
                  _buildSettingsMenuItem(
                    isDarkMode: isDarkMode,
                    isTablet: isTablet,
                    icon: Icons.lock_outline,
                    title: 'Password',
                    onTap: () => print('Navigate to Password'),
                  ),
                  _buildSettingsMenuItem(
                    isDarkMode: isDarkMode,
                    isTablet: isTablet,
                    icon: Icons.bookmark_outline,
                    title: 'Saved Messages',
                    onTap: () => print('Navigate to Saved Messages'),
                  ),
                  _buildSettingsMenuItem(
                    isDarkMode: isDarkMode,
                    isTablet: isTablet,
                    icon: Icons.phone_outlined,
                    title: 'Contact Us',
                    onTap: () => print('Navigate to Contact Us'),
                  ),
                  _buildSettingsMenuItem(
                    isDarkMode: isDarkMode,
                    isTablet: isTablet,
                    icon: Icons.settings_outlined,
                    title: 'App Settings',
                    onTap: () => print('Navigate to App Settings'),
                  ),
                  _buildSettingsMenuItem(
                    isDarkMode: isDarkMode,
                    isTablet: isTablet,
                    icon: Icons.delete_outline,
                    title: 'Delete Account',
                    textColor: const Color(0xFFEF4444),
                    onTap: () => print('Navigate to Delete Account'),
                  ),
                  _buildSettingsMenuItem(
                    isDarkMode: isDarkMode,
                    isTablet: isTablet,
                    icon: Icons.logout,
                    title: 'Logout',
                    textColor: const Color(0xFFFF8C42),
                    onTap: () => _handleLogout(),
                  ),

                  // Debug mode reset session button (if in debug mode)
                  if (kDebugMode) ...[
                    const SizedBox(height: 32),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isTablet ? 20 : 16),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? const Color(0xFF2A2A2A)
                            : const Color(0xFFFFFFFF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFEF4444).withOpacity(0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDarkMode
                                ? Colors.black.withOpacity(0.3)
                                : const Color(0xFF475569).withOpacity(0.15),
                            blurRadius: isDarkMode ? 15 : 20,
                            offset: Offset(0, isDarkMode ? 5 : 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🔧 Debug Mode',
                            style: GoogleFonts.inter(
                              fontSize: isTablet ? 16 : 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFEF4444),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Reset session and return to welcome screen',
                            style: GoogleFonts.inter(
                              fontSize: isTablet ? 14 : 12,
                              fontWeight: FontWeight.w400,
                              color: isDarkMode
                                  ? Colors.white.withOpacity(0.7)
                                  : const Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                HapticFeedback.mediumImpact();

                                // Show confirmation dialog
                                final bool? confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      backgroundColor: isDarkMode
                                          ? const Color(0xFF2A2A2A)
                                          : Colors.white,
                                      title: Text(
                                        'Reset Session',
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w700,
                                          color: isDarkMode
                                              ? Colors.white
                                              : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      content: Text(
                                        'This will log you out and return to the welcome screen. Are you sure?',
                                        style: GoogleFonts.inter(
                                          color: isDarkMode
                                              ? Colors.white.withOpacity(0.8)
                                              : const Color(0xFF475569),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(false),
                                          child: Text(
                                            'Cancel',
                                            style: GoogleFonts.inter(
                                              color: isDarkMode
                                                  ? Colors.white
                                                      .withOpacity(0.7)
                                                  : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(true),
                                          child: Text(
                                            'Reset Session',
                                            style: GoogleFonts.inter(
                                              color: const Color(0xFFEF4444),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                );

                                if (confirm == true) {
                                  // Reset the session
                                  await SessionService.instance.resetSession();

                                  // Navigate back to welcome screen
                                  if (mounted) {
                                    Navigator.of(context).pushAndRemoveUntil(
                                      MaterialPageRoute(
                                          builder: (context) => const MyApp()),
                                      (route) => false,
                                    );
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEF4444),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: EdgeInsets.symmetric(
                                  vertical: isTablet ? 16 : 12,
                                ),
                                elevation: 2,
                              ),
                              child: Text(
                                'Reset Session (Debug)',
                                style: GoogleFonts.inter(
                                  fontSize: isTablet ? 16 : 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'morning';
    } else if (hour < 17) {
      return 'afternoon';
    } else {
      return 'evening';
    }
  }

  void _callPatient() {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Calling $displayPatientName...'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  void _handleEmergency() {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
          title: Text(
            'Emergency Alert',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          content: Text(
            'Are you sure you want to trigger an emergency alert for $displayPatientName?',
            style: GoogleFonts.inter(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.8)
                  : const Color(0xFF475569),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.7)
                      : const Color(0xFF64748B),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Emergency services notified'),
                    backgroundColor: Color(0xFFEF4444),
                  ),
                );
              },
              child: Text(
                'Emergency',
                style: GoogleFonts.inter(
                  color: const Color(0xFFEF4444),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _viewMedication() {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening medication schedule for $displayPatientName...'),
        backgroundColor: const Color(0xFF8B5CF6),
      ),
    );
  }

  // Helper method to build settings menu items
  Widget _buildSettingsMenuItem({
    required bool isDarkMode,
    required bool isTablet,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : const Color(0xFF475569).withOpacity(0.15),
            blurRadius: isDarkMode ? 15 : 20,
            offset: Offset(0, isDarkMode ? 5 : 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            child: Row(
              children: [
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
                    icon,
                    color: textColor ??
                        (isDarkMode
                            ? Colors.white.withOpacity(0.7)
                            : const Color(0xFF475569)),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.w500,
                      color: textColor ??
                          (isDarkMode ? Colors.white : const Color(0xFF0F172A)),
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.5)
                      : const Color(0xFF475569),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Handle logout functionality
  void _handleLogout() async {
    HapticFeedback.mediumImpact();

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor:
              isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFFFFFFF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Logout',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          content: Text(
            'Are you sure you want to logout?',
            style: GoogleFonts.inter(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.7)
                  : const Color(0xFF475569),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.7)
                      : const Color(0xFF475569),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Logout',
                style: GoogleFonts.inter(
                  color: const Color(0xFFFF8C42),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      // Clear session and navigate to welcome screen
      await SessionService.instance.endSession();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const WelcomePage(),
          ),
          (route) => false,
        );
      }
    }
  }
}
