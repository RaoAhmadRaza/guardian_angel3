import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'theme/app_theme.dart' as theme;
import 'providers/theme_provider.dart';

class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFFDFDFD),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDarkMode
              ? theme.AppTheme.getPrimaryGradient(context)
              : theme.AppTheme.lightPrimaryGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar with back button and theme toggle
              _buildTopBar(isDarkMode),

              // Main content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),

                      // Title
                      Text(
                        'Diagnostic Center',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: isDarkMode
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'Comprehensive health analysis and monitoring',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.7)
                              : const Color(0xFF475569),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Diagnostic cards
                      _buildDiagnosticCard(
                        isDarkMode: isDarkMode,
                        icon: CupertinoIcons.heart_fill,
                        title: 'Heart Analysis',
                        subtitle: 'ECG monitoring and rhythm analysis',
                        status: 'Normal',
                        statusColor: Colors.green,
                      ),

                      const SizedBox(height: 16),

                      _buildDiagnosticCard(
                        isDarkMode: isDarkMode,
                        icon: CupertinoIcons.waveform,
                        title: 'Blood Pressure',
                        subtitle: 'Systolic and diastolic readings',
                        status: 'Optimal',
                        statusColor: Colors.blue,
                      ),

                      const SizedBox(height: 16),

                      _buildDiagnosticCard(
                        isDarkMode: isDarkMode,
                        icon: CupertinoIcons.thermometer,
                        title: 'Body Temperature',
                        subtitle: 'Core temperature monitoring',
                        status: 'Normal',
                        statusColor: Colors.green,
                      ),

                      const SizedBox(height: 16),

                      _buildDiagnosticCard(
                        isDarkMode: isDarkMode,
                        icon: CupertinoIcons.moon_zzz_fill,
                        title: 'Sleep Quality',
                        subtitle: 'Sleep patterns and quality analysis',
                        status: 'Good',
                        statusColor: Colors.purple,
                      ),

                      const SizedBox(height: 32),

                      // Action buttons
                      _buildActionButton(
                        isDarkMode: isDarkMode,
                        title: 'Start Full Diagnostic',
                        subtitle: 'Complete health assessment',
                        icon: CupertinoIcons.play_circle_fill,
                        isPrimary: true,
                      ),

                      const SizedBox(height: 16),

                      _buildActionButton(
                        isDarkMode: isDarkMode,
                        title: 'View History',
                        subtitle: 'Previous diagnostic reports',
                        icon: CupertinoIcons.doc_text_fill,
                        isPrimary: false,
                      ),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.1)
                  : const Color(0xFFFDFDFD),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.2)
                    : const Color(0xFFE0E0E2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDarkMode
                      ? Colors.black.withOpacity(0.3)
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
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
                child: Center(
                  child: Icon(
                    CupertinoIcons.back,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.8)
                        : const Color(0xFF475569),
                    size: 24,
                  ),
                ),
              ),
            ),
          ),

          // Theme toggle button
          _buildThemeToggle(isDarkMode),
        ],
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
              ? Colors.white.withOpacity(0.2)
              : const Color(0xFFE0E0E2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
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
          onTap: () {
            HapticFeedback.lightImpact();
            // Toggle theme
            final themeProvider = Theme.of(context).extension<ThemeProvider>();
            if (themeProvider != null) {
              // Theme toggle logic would go here
            }
          },
          child: Center(
            child: Icon(
              isDarkMode
                  ? CupertinoIcons.sun_max_fill
                  : CupertinoIcons.moon_fill,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.8)
                  : const Color(0xFF475569),
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiagnosticCard({
    required bool isDarkMode,
    required IconData icon,
    required String title,
    required String subtitle,
    required String status,
    required Color statusColor,
  }) {
    return Container(
      width: double.infinity,
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
      child: Row(
        children: [
          // Icon container
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: statusColor,
              size: 24,
            ),
          ),

          const SizedBox(width: 16),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
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

          // Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required bool isDarkMode,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isPrimary,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isPrimary
            ? (isDarkMode ? const Color(0xFF475569) : const Color(0xFF0F172A))
            : (isDarkMode ? const Color(0xFF2A2A2A) : Colors.white),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.lightImpact();
            // Action button logic
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isPrimary
                        ? Colors.white.withOpacity(0.1)
                        : (isDarkMode
                            ? Colors.white.withOpacity(0.1)
                            : const Color(0xFFF5F5F7)),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: isPrimary
                        ? Colors.white
                        : (isDarkMode
                            ? Colors.white.withOpacity(0.8)
                            : const Color(0xFF475569)),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isPrimary
                              ? Colors.white
                              : (isDarkMode
                                  ? Colors.white
                                  : const Color(0xFF0F172A)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: isPrimary
                              ? Colors.white.withOpacity(0.8)
                              : (isDarkMode
                                  ? Colors.white.withOpacity(0.7)
                                  : const Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  CupertinoIcons.chevron_right,
                  color: isPrimary
                      ? Colors.white.withOpacity(0.8)
                      : (isDarkMode
                          ? Colors.white.withOpacity(0.5)
                          : const Color(0xFF475569).withOpacity(0.5)),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
