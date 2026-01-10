import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/health_threshold_service.dart';
import '../models/health_threshold_model.dart';

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
  bool _isLoading = true;
  HealthThresholdModel? _thresholds;
  String? _rangeError;
  
  // Issue #16: Minimum separation between min and max heart rate
  static const int _minimumHeartRateSeparation = 20;

  @override
  void initState() {
    super.initState();
    _loadThresholds();
  }

  Future<void> _loadThresholds() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }
    
    final thresholds = await HealthThresholdService.instance.getThresholds(uid);
    setState(() {
      _thresholds = thresholds;
      _heartRateRange = RangeValues(
        thresholds.heartRateMin.toDouble(),
        thresholds.heartRateMax.toDouble(),
      );
      _fallDetection = thresholds.fallDetectionEnabled;
      _inactivityAlert = thresholds.inactivityAlertEnabled;
      _inactivityHours = thresholds.inactivityHours;
      _isLoading = false;
    });
  }

  Future<void> _saveThresholds() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    final thresholds = _thresholds?.copyWith(
      heartRateMin: _heartRateRange.start.round(),
      heartRateMax: _heartRateRange.end.round(),
      fallDetectionEnabled: _fallDetection,
      inactivityAlertEnabled: _inactivityAlert,
      inactivityHours: _inactivityHours,
    ) ?? HealthThresholdModel.defaults(uid).copyWith(
      heartRateMin: _heartRateRange.start.round(),
      heartRateMax: _heartRateRange.end.round(),
      fallDetectionEnabled: _fallDetection,
      inactivityAlertEnabled: _inactivityAlert,
      inactivityHours: _inactivityHours,
    );
    
    await HealthThresholdService.instance.saveThresholds(thresholds);
    setState(() => _thresholds = thresholds);
  }
  
  /// Issue #16: Validate heart rate range has minimum separation
  String? _validateHeartRateRange(RangeValues values) {
    final separation = values.end - values.start;
    if (separation < _minimumHeartRateSeparation) {
      return 'Min and max must be at least $_minimumHeartRateSeparation BPM apart';
    }
    return null;
  }
  
  /// Issue #26: Reset thresholds to defaults
  Future<void> _resetToDefaults() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Reset to Defaults'),
        content: const Text(
          'This will reset all health thresholds to their default values. Are you sure?',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    final defaults = HealthThresholdModel.defaults(uid);
    await HealthThresholdService.instance.saveThresholds(defaults);
    
    setState(() {
      _thresholds = defaults;
      _heartRateRange = RangeValues(
        defaults.heartRateMin.toDouble(),
        defaults.heartRateMax.toDouble(),
      );
      _fallDetection = defaults.fallDetectionEnabled;
      _inactivityAlert = defaults.inactivityAlertEnabled;
      _inactivityHours = defaults.inactivityHours;
      _rangeError = null;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thresholds reset to defaults')),
      );
    }
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
            // Issue #26: Reset to defaults button
            actions: [
              TextButton(
                onPressed: _resetToDefaults,
                child: const Text(
                  'Reset',
                  style: TextStyle(color: Color(0xFF007AFF)),
                ),
              ),
            ],
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
                          activeColor: _rangeError != null ? Colors.orange : Colors.red,
                          inactiveColor: Colors.red.withOpacity(0.2),
                          onChanged: (values) {
                            setState(() {
                              _heartRateRange = values;
                              // Issue #16: Validate range separation
                              _rangeError = _validateHeartRateRange(values);
                            });
                          },
                          onChangeEnd: (values) {
                            // Issue #16: Only save if valid range
                            if (_validateHeartRateRange(values) == null) {
                              _saveThresholds();
                            }
                          },
                        ),
                        if (_rangeError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _rangeError!,
                              style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
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
                          onChanged: (val) {
                            setState(() => _fallDetection = val);
                            _saveThresholds();
                          },
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
                          onChanged: (val) {
                            setState(() => _inactivityAlert = val);
                            _saveThresholds();
                          },
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
