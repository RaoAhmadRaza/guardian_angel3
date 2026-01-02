import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() => _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState extends State<NotificationsSettingsScreen> {
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _smsNotifications = false;
  bool _fallDetectionAlerts = true;
  bool _heartRateAlerts = true;
  bool _medicationReminders = true;
  bool _appointmentReminders = true;
  bool _marketingEmails = false;

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
                      _buildSwitchTile('Push Notifications', _pushNotifications, (v) => setState(() => _pushNotifications = v), isDarkMode),
                      _buildDivider(isDarkMode),
                      _buildSwitchTile('Email Notifications', _emailNotifications, (v) => setState(() => _emailNotifications = v), isDarkMode),
                      _buildDivider(isDarkMode),
                      _buildSwitchTile('SMS Notifications', _smsNotifications, (v) => setState(() => _smsNotifications = v), isDarkMode),
                    ],
                  ),
                  
                  _buildSectionHeader('HEALTH ALERTS', isDarkMode),
                  _buildGroup(
                    isDarkMode,
                    [
                      _buildSwitchTile('Fall Detection', _fallDetectionAlerts, (v) => setState(() => _fallDetectionAlerts = v), isDarkMode),
                      _buildDivider(isDarkMode),
                      _buildSwitchTile('Heart Rate Alerts', _heartRateAlerts, (v) => setState(() => _heartRateAlerts = v), isDarkMode),
                    ],
                  ),

                  _buildSectionHeader('REMINDERS', isDarkMode),
                  _buildGroup(
                    isDarkMode,
                    [
                      _buildSwitchTile('Medication Reminders', _medicationReminders, (v) => setState(() => _medicationReminders = v), isDarkMode),
                      _buildDivider(isDarkMode),
                      _buildSwitchTile('Appointment Reminders', _appointmentReminders, (v) => setState(() => _appointmentReminders = v), isDarkMode),
                    ],
                  ),

                  _buildSectionHeader('OTHER', isDarkMode),
                  _buildGroup(
                    isDarkMode,
                    [
                      _buildSwitchTile('Marketing & Updates', _marketingEmails, (v) => setState(() => _marketingEmails = v), isDarkMode),
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
