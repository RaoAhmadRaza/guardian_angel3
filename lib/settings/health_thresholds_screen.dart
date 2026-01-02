import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class HealthThresholdsScreen extends StatefulWidget {
  const HealthThresholdsScreen({super.key});

  @override
  State<HealthThresholdsScreen> createState() => _HealthThresholdsScreenState();
}

class _HealthThresholdsScreenState extends State<HealthThresholdsScreen> {
  RangeValues _heartRateRange = const RangeValues(60, 100);
  bool _fallDetection = true;
  bool _inactivityAlert = true;
  double _inactivityHours = 2.0;

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
              'Health Thresholds',
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
                  Text(
                    'HEART RATE ALERTS',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Min: ${_heartRateRange.start.round()} BPM',
                              style: TextStyle(
                                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'Max: ${_heartRateRange.end.round()} BPM',
                              style: TextStyle(
                                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        RangeSlider(
                          values: _heartRateRange,
                          min: 40,
                          max: 160,
                          divisions: 120,
                          activeColor: Colors.red,
                          inactiveColor: Colors.red.withOpacity(0.2),
                          onChanged: (values) {
                            setState(() {
                              _heartRateRange = values;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Alert guardians if heart rate goes outside this range.',
                          style: TextStyle(
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'SAFETY MONITORING',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        _buildSwitchTile(
                          title: 'Fall Detection',
                          subtitle: 'Automatically trigger SOS on impact',
                          value: _fallDetection,
                          onChanged: (val) => setState(() => _fallDetection = val),
                          isDarkMode: isDarkMode,
                          isFirst: true,
                        ),
                        Divider(
                          height: 1,
                          indent: 16,
                          color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                        ),
                        _buildSwitchTile(
                          title: 'Inactivity Alert',
                          subtitle: 'Notify if no movement for ${_inactivityHours.round()} hours',
                          value: _inactivityAlert,
                          onChanged: (val) => setState(() => _inactivityAlert = val),
                          isDarkMode: isDarkMode,
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDarkMode,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDarkMode ? Colors.white : Colors.black,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          fontSize: 13,
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
