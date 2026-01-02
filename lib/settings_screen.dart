import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'providers/theme_provider.dart';
import 'services/demo_mode_service.dart';
import 'services/session_service.dart';
import 'services/patient_service.dart';
import 'main.dart';
import 'settings/about_screen.dart';
import 'settings/device_settings_screen.dart';
import 'settings/emergency_contacts_screen.dart';
import 'settings/guardians_screen.dart';
import 'settings/health_thresholds_screen.dart';
import 'settings/help_support_screen.dart';
import 'settings/notifications_settings_screen.dart';
import 'settings/profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDemoMode = false;
  String _patientName = 'User';
  int _patientAge = 0;
  String _patientGender = 'male';

  @override
  void initState() {
    super.initState();
    _loadDemoModeState();
    _loadPatientData();
  }

  Future<void> _loadPatientData() async {
    final patientData = await PatientService.instance.getPatientData();
    if (mounted) {
      setState(() {
        _patientName = patientData['fullName'] ?? 'User';
        _patientAge = patientData['age'] ?? 0;
        _patientGender = patientData['gender'] ?? 'male';
      });
    }
  }

  Future<void> _loadDemoModeState() async {
    await DemoModeService.instance.initialize();
    if (mounted) {
      setState(() {
        _isDemoMode = DemoModeService.instance.isEnabled;
      });
    }
  }

  Future<void> _toggleDemoMode() async {
    await DemoModeService.instance.toggleDemoMode();
    if (mounted) {
      setState(() {
        _isDemoMode = DemoModeService.instance.isEnabled;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSettingsHeader(context, isDarkMode),
              const SizedBox(height: 24),
              _buildUserProfileCard(isDarkMode),
              const SizedBox(height: 32),
              _buildOtherSettingsSection(context, isDarkMode),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsHeader(BuildContext context, bool isDarkMode) {
    return Center(
      child: Text(
        'Settings',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
        ),
      ),
    );
  }

  Widget _buildUserProfileCard(bool isDarkMode) {
    final ageText = _patientAge > 0 ? 'Age: $_patientAge' : 'Age: --';
    final avatarPath = _patientGender.toLowerCase() == 'female' 
        ? 'images/female.jpg' 
        : 'images/male.jpg';

    return Column(
      children: [
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: Container(
              width: 100,
              height: 100,
              color: Colors.grey.withOpacity(0.08),
              child: Image.asset(
                avatarPath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: const Color(0xFF3B82F6).withOpacity(0.15),
                  child: const Icon(
                    Icons.person,
                    color: Color(0xFF3B82F6),
                    size: 50,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _patientName,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          ageText,
          style: TextStyle(
            fontSize: 16,
            color: isDarkMode ? Colors.white.withOpacity(0.6) : const Color(0xFF475569),
          ),
        ),
      ],
    );
  }

  Widget _buildOtherSettingsSection(BuildContext context, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDarkMode ? Colors.black.withOpacity(0.4) : const Color(0xFF475569).withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
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
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                },
              ),
              _buildSettingsDivider(isDarkMode),
              _buildSettingsItem(
                icon: Icons.security,
                title: 'My Guardians',
                isDarkMode: isDarkMode,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const GuardiansScreen()));
                },
              ),
              _buildSettingsDivider(isDarkMode),
              _buildSettingsItem(
                icon: Icons.contact_phone_outlined,
                title: 'Emergency Contacts',
                isDarkMode: isDarkMode,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyContactsScreen()));
                },
              ),
              _buildSettingsDivider(isDarkMode),
              _buildSettingsItem(
                icon: Icons.monitor_heart_outlined,
                title: 'Health Thresholds',
                isDarkMode: isDarkMode,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const HealthThresholdsScreen()));
                },
              ),
              _buildSettingsDivider(isDarkMode),
              _buildSettingsItem(
                icon: Icons.watch_outlined,
                title: 'My Device',
                isDarkMode: isDarkMode,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DeviceSettingsScreen()));
                },
              ),
              _buildSettingsDivider(isDarkMode),
              _buildSettingsItem(
                icon: Icons.lock_outline,
                title: 'Password',
                isDarkMode: isDarkMode,
                onTap: () {
                  HapticFeedback.lightImpact();
                },
              ),
              _buildSettingsDivider(isDarkMode),
              _buildSettingsItem(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                isDarkMode: isDarkMode,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsSettingsScreen()));
                },
              ),
              _buildSettingsDivider(isDarkMode),
              _buildDarkModeToggleItem(isDarkMode),
              _buildSettingsDivider(isDarkMode),
              _buildDemoModeToggleItem(isDarkMode),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDarkMode ? Colors.black.withOpacity(0.2) : const Color(0xFF475569).withOpacity(0.06),
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
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()));
                },
              ),
              _buildSettingsDivider(isDarkMode),
              _buildSettingsItem(
                icon: Icons.help_outline,
                title: 'Help/FAQ',
                isDarkMode: isDarkMode,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen()));
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
                  _showDeactivateAccountDialog(context, isDarkMode);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        if (kDebugMode) _buildDebugSection(context),
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
                color: isDestructive ? Colors.red : (isDarkMode ? Colors.white : const Color(0xFF2A2A2A)),
                size: 20,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDestructive ? Colors.red : (isDarkMode ? Colors.white : const Color(0xFF0F172A)),
                  ),
                ),
              ),
              trailing ?? Icon(
                Icons.chevron_right,
                color: isDarkMode ? Colors.white.withOpacity(0.4) : const Color(0xFF475569).withOpacity(0.4),
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
                color: isDarkMode ? const Color(0xFF3B82F6) : const Color(0xFF475569).withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 300),
                alignment: isDarkMode ? Alignment.centerRight : Alignment.centerLeft,
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

  Widget _buildDemoModeToggleItem(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            Icons.science_outlined,
            color: _isDemoMode ? const Color(0xFFF59E0B) : (isDarkMode ? Colors.white : const Color(0xFF2A2A2A)),
            size: 20,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Demo Mode',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isDemoMode ? 'Showing sample data' : 'Show real data only',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white.withOpacity(0.5) : const Color(0xFF475569).withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              HapticFeedback.lightImpact();
              await _toggleDemoMode();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 52,
              height: 28,
              decoration: BoxDecoration(
                color: _isDemoMode ? const Color(0xFFF59E0B) : const Color(0xFF475569).withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 300),
                alignment: _isDemoMode ? Alignment.centerRight : Alignment.centerLeft,
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
      color: isDarkMode ? Colors.white.withOpacity(0.1) : const Color(0xFF475569).withOpacity(0.1),
    );
  }

  Widget _buildDebugSection(BuildContext context) {
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
            children: const [
              Icon(
                Icons.bug_report,
                color: Colors.red,
                size: 20,
              ),
              SizedBox(width: 8),
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
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                  children: const [
                    Icon(
                      Icons.refresh,
                      color: Colors.red,
                      size: 16,
                    ),
                    SizedBox(width: 8),
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

  void _showDeactivateAccountDialog(BuildContext context, bool isDarkMode) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.3),
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
              color: isDarkMode ? Colors.white.withOpacity(0.8) : const Color(0xFF475569),
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
                  color: isDarkMode ? Colors.white.withOpacity(0.8) : const Color(0xFF475569),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Handle account deactivation
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
}
