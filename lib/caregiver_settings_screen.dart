import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'main.dart';
import 'welcome.dart';
import 'services/session_service.dart';

class CaregiverSettingsScreen extends StatelessWidget {
  final String? caregiverName;
  final String? email;

  const CaregiverSettingsScreen({super.key, this.caregiverName, this.email});

  String get _displayCaregiverName => caregiverName ?? 'Sarah Thompson';
  String get _displayEmail => email ?? 'sarah.thompson@email.com';

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return SafeArea(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isTablet ? 32.0 : 20.0),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF8C42), Color(0xFFFF6B35)],
              ),
            ),
            child: Column(
              children: [
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
                      Container(
                        width: isTablet ? 64 : 56,
                        height: isTablet ? 64 : 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: const ClipOval(
                          child: Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _displayCaregiverName,
                              style: GoogleFonts.inter(
                                fontSize: isTablet ? 24 : 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _displayEmail,
                              style: GoogleFonts.inter(
                                fontSize: isTablet ? 16 : 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
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
          Expanded(
            child: Container(
              color: isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFFDFDFD),
              child: ListView(
                padding: EdgeInsets.all(isTablet ? 32.0 : 20.0),
                children: [
                  _buildSettingsMenuItem(
                    context: context,
                    isDarkMode: isDarkMode,
                    isTablet: isTablet,
                    icon: Icons.person_outline,
                    title: 'Profile',
                    onTap: () => debugPrint('Navigate to Profile'),
                  ),
                  _buildSettingsMenuItem(
                    context: context,
                    isDarkMode: isDarkMode,
                    isTablet: isTablet,
                    icon: Icons.lock_outline,
                    title: 'Password',
                    onTap: () => debugPrint('Navigate to Password'),
                  ),
                  _buildSettingsMenuItem(
                    context: context,
                    isDarkMode: isDarkMode,
                    isTablet: isTablet,
                    icon: Icons.bookmark_outline,
                    title: 'Saved Messages',
                    onTap: () => debugPrint('Navigate to Saved Messages'),
                  ),
                  _buildSettingsMenuItem(
                    context: context,
                    isDarkMode: isDarkMode,
                    isTablet: isTablet,
                    icon: Icons.phone_outlined,
                    title: 'Contact Us',
                    onTap: () => debugPrint('Navigate to Contact Us'),
                  ),
                  _buildSettingsMenuItem(
                    context: context,
                    isDarkMode: isDarkMode,
                    isTablet: isTablet,
                    icon: Icons.settings_outlined,
                    title: 'App Settings',
                    onTap: () => debugPrint('Navigate to App Settings'),
                  ),
                  _buildSettingsMenuItem(
                    context: context,
                    isDarkMode: isDarkMode,
                    isTablet: isTablet,
                    icon: Icons.delete_outline,
                    title: 'Delete Account',
                    textColor: const Color(0xFFEF4444),
                    onTap: () => debugPrint('Navigate to Delete Account'),
                  ),
                  _buildSettingsMenuItem(
                    context: context,
                    isDarkMode: isDarkMode,
                    isTablet: isTablet,
                    icon: Icons.logout,
                    title: 'Logout',
                    textColor: const Color(0xFFFF8C42),
                    onTap: () => _handleLogout(context),
                  ),
                  if (kDebugMode) ...[
                    const SizedBox(height: 32),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isTablet ? 20 : 16),
                      decoration: BoxDecoration(
                        color: isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFFFFFFF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFEF4444).withOpacity(0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDarkMode ? Colors.black.withOpacity(0.3) : const Color(0xFF475569).withOpacity(0.15),
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
                              color: isDarkMode ? Colors.white.withOpacity(0.7) : const Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                HapticFeedback.mediumImpact();
                                final confirm = await _showConfirmDialog(
                                  context,
                                  title: 'Reset Session',
                                  message:
                                      'This will log you out and return to the welcome screen. Are you sure?',
                                  confirmText: 'Reset Session',
                                  confirmColor: const Color(0xFFEF4444),
                                );
                                if (confirm == true) {
                                  await SessionService.instance.resetSession();
                                  if (context.mounted) {
                                    Navigator.of(context).pushAndRemoveUntil(
                                      MaterialPageRoute(builder: (context) => const MyApp()),
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

  Future<void> _handleLogout(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final bool? confirm = await _showConfirmDialog(
      context,
      title: 'Logout',
      message: 'Are you sure you want to logout?',
      confirmText: 'Logout',
      confirmColor: const Color(0xFFFF8C42),
    );

    if (confirm == true) {
      await SessionService.instance.endSession();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const WelcomePage()),
          (route) => false,
        );
      }
    }
  }

  Future<bool?> _showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFFFFFFF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            title,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          content: Text(
            message,
            style: GoogleFonts.inter(
              color: isDarkMode ? Colors.white.withOpacity(0.7) : const Color(0xFF475569),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: isDarkMode ? Colors.white.withOpacity(0.7) : const Color(0xFF475569),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                confirmText,
                style: GoogleFonts.inter(color: confirmColor, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSettingsMenuItem({
    required BuildContext context,
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
            color: isDarkMode ? Colors.black.withOpacity(0.3) : const Color(0xFF475569).withOpacity(0.15),
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
                    color: isDarkMode ? Colors.white.withOpacity(0.1) : const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: textColor ?? (isDarkMode ? Colors.white.withOpacity(0.7) : const Color(0xFF475569)),
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
                      color: textColor ?? (isDarkMode ? Colors.white : const Color(0xFF0F172A)),
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: isDarkMode ? Colors.white.withOpacity(0.5) : const Color(0xFF475569),
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
