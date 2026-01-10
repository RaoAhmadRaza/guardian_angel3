import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() => _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState extends State<NotificationsSettingsScreen> {
  // Critical Issue #9: Persist notification settings with SharedPreferences
  static const String _keyPushNotifications = 'notif_push';
  static const String _keyEmailNotifications = 'notif_email';
  static const String _keySmsNotifications = 'notif_sms';
  static const String _keyFallDetectionAlerts = 'notif_fall_detection';
  static const String _keyHeartRateAlerts = 'notif_heart_rate';
  static const String _keyMedicationReminders = 'notif_medication';
  static const String _keyAppointmentReminders = 'notif_appointments';
  static const String _keyMarketingEmails = 'notif_marketing';
  
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _smsNotifications = false;
  bool _fallDetectionAlerts = true;
  bool _heartRateAlerts = true;
  bool _medicationReminders = true;
  bool _appointmentReminders = true;
  bool _marketingEmails = false;
  
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  /// Load notification settings from SharedPreferences (Critical Issue #9)
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (mounted) {
        setState(() {
          _pushNotifications = prefs.getBool(_keyPushNotifications) ?? true;
          _emailNotifications = prefs.getBool(_keyEmailNotifications) ?? true;
          _smsNotifications = prefs.getBool(_keySmsNotifications) ?? false;
          _fallDetectionAlerts = prefs.getBool(_keyFallDetectionAlerts) ?? true;
          _heartRateAlerts = prefs.getBool(_keyHeartRateAlerts) ?? true;
          _medicationReminders = prefs.getBool(_keyMedicationReminders) ?? true;
          _appointmentReminders = prefs.getBool(_keyAppointmentReminders) ?? true;
          _marketingEmails = prefs.getBool(_keyMarketingEmails) ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[NotificationsSettings] Error loading settings: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  /// Save a single setting to SharedPreferences (Critical Issue #9)
  Future<void> _saveSetting(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
      debugPrint('[NotificationsSettings] Saved $key = $value');
    } catch (e) {
      debugPrint('[NotificationsSettings] Error saving $key: $e');
    }
  }
  
  /// Update a setting and persist it
  void _updateSetting(String key, bool newValue, void Function(bool) setter) {
    setter(newValue);
    _saveSetting(key, newValue);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : const Color(0xFFF2F2F7),
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            backgroundColor: isDarkMode ? Colors.black : const Color(0xFFF2F2F7),
            title: Text(
              'Notifications',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: isDarkMode ? Colors.white : Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('GENERAL', isDarkMode),
                  _buildGroup(
                    isDarkMode,
                    [
                      _buildSwitchTile('Push Notifications', _pushNotifications, (v) {
                        setState(() => _pushNotifications = v);
                        _saveSetting(_keyPushNotifications, v);
                      }, isDarkMode),
                      _buildDivider(isDarkMode),
                      _buildSwitchTile('Email Notifications', _emailNotifications, (v) {
                        setState(() => _emailNotifications = v);
                        _saveSetting(_keyEmailNotifications, v);
                      }, isDarkMode),
                      _buildDivider(isDarkMode),
                      _buildSwitchTile('SMS Notifications', _smsNotifications, (v) {
                        setState(() => _smsNotifications = v);
                        _saveSetting(_keySmsNotifications, v);
                      }, isDarkMode),
                    ],
                  ),
                  
                  _buildSectionHeader('HEALTH ALERTS', isDarkMode),
                  _buildGroup(
                    isDarkMode,
                    [
                      _buildSwitchTile('Fall Detection', _fallDetectionAlerts, (v) {
                        setState(() => _fallDetectionAlerts = v);
                        _saveSetting(_keyFallDetectionAlerts, v);
                      }, isDarkMode),
                      _buildDivider(isDarkMode),
                      _buildSwitchTile('Heart Rate Alerts', _heartRateAlerts, (v) {
                        setState(() => _heartRateAlerts = v);
                        _saveSetting(_keyHeartRateAlerts, v);
                      }, isDarkMode),
                    ],
                  ),

                  _buildSectionHeader('REMINDERS', isDarkMode),
                  _buildGroup(
                    isDarkMode,
                    [
                      _buildSwitchTile('Medication Reminders', _medicationReminders, (v) {
                        setState(() => _medicationReminders = v);
                        _saveSetting(_keyMedicationReminders, v);
                      }, isDarkMode),
                      _buildDivider(isDarkMode),
                      _buildSwitchTile('Appointment Reminders', _appointmentReminders, (v) {
                        setState(() => _appointmentReminders = v);
                        _saveSetting(_keyAppointmentReminders, v);
                      }, isDarkMode),
                    ],
                  ),

                  _buildSectionHeader('OTHER', isDarkMode),
                  _buildGroup(
                    isDarkMode,
                    [
                      _buildSwitchTile('Marketing & Updates', _marketingEmails, (v) {
                        setState(() => _marketingEmails = v);
                        _saveSetting(_keyMarketingEmails, v);
                      }, isDarkMode),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildGroup(bool isDarkMode, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider(bool isDarkMode) {
    return Divider(
      height: 1,
      indent: 16,
      color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
    );
  }

  Widget _buildSwitchTile(String title, bool value, ValueChanged<bool> onChanged, bool isDarkMode) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: isDarkMode ? Colors.white : Colors.black,
        ),
      ),
      trailing: CupertinoSwitch(
        value: value,
        activeColor: const Color(0xFF007AFF),
        onChanged: onChanged,
      ),
    );
  }
}
