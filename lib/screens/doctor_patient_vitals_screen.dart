/// Doctor Patient Vitals Screen - Displays real patient vitals from Firestore.
///
/// Allows doctors to view their patient's health data including:
/// - Heart rate history
/// - Blood oxygen levels
/// - Sleep patterns
/// - Health alerts
library;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../providers/doctor_patients_provider.dart';

/// Screen for doctors to view a patient's vitals history.
class DoctorPatientVitalsScreen extends StatefulWidget {
  final String patientId;
  final String patientName;
  final PatientVitalsData? currentVitals;

  const DoctorPatientVitalsScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    this.currentVitals,
  });

  @override
  State<DoctorPatientVitalsScreen> createState() => _DoctorPatientVitalsScreenState();
}

class _DoctorPatientVitalsScreenState extends State<DoctorPatientVitalsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _heartRateReadings = [];
  List<Map<String, dynamic>> _oxygenReadings = [];
  List<Map<String, dynamic>> _sleepReadings = [];
  List<Map<String, dynamic>> _healthAlerts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadVitalsHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadVitalsHistory() async {
    setState(() => _isLoading = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final healthReadingsRef = firestore
          .collection('patients')
          .doc(widget.patientId)
          .collection('health_readings');
      
      final alertsRef = firestore
          .collection('patients')
          .doc(widget.patientId)
          .collection('health_alerts');

      // Load last 7 days of data
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final sevenDaysAgoStr = sevenDaysAgo.toUtc().toIso8601String();

      // Fetch heart rate readings
      final hrSnapshot = await healthReadingsRef
          .where('reading_type', isEqualTo: 'heart_rate')
          .where('recorded_at', isGreaterThanOrEqualTo: sevenDaysAgoStr)
          .orderBy('recorded_at', descending: true)
          .limit(100)
          .get();
      _heartRateReadings = hrSnapshot.docs.map((d) => d.data()).toList();

      // Fetch blood oxygen readings
      final o2Snapshot = await healthReadingsRef
          .where('reading_type', isEqualTo: 'blood_oxygen')
          .where('recorded_at', isGreaterThanOrEqualTo: sevenDaysAgoStr)
          .orderBy('recorded_at', descending: true)
          .limit(100)
          .get();
      _oxygenReadings = o2Snapshot.docs.map((d) => d.data()).toList();

      // Fetch sleep readings
      final sleepSnapshot = await healthReadingsRef
          .where('reading_type', isEqualTo: 'sleep_session')
          .where('recorded_at', isGreaterThanOrEqualTo: sevenDaysAgoStr)
          .orderBy('recorded_at', descending: true)
          .limit(30)
          .get();
      _sleepReadings = sleepSnapshot.docs.map((d) => d.data()).toList();

      // Fetch health alerts
      final alertsSnapshot = await alertsRef
          .orderBy('created_at', descending: true)
          .limit(20)
          .get();
      _healthAlerts = alertsSnapshot.docs.map((d) => d.data()).toList();

    } catch (e) {
      debugPrint('[DoctorPatientVitals] Failed to load vitals: $e');
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.patientName,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              'Health Vitals',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF3B82F6)),
            onPressed: _loadVitalsHistory,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF3B82F6),
          unselectedLabelColor: const Color(0xFF94A3B8),
          indicatorColor: const Color(0xFF3B82F6),
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
          tabs: const [
            Tab(text: 'OVERVIEW'),
            Tab(text: 'HEART'),
            Tab(text: 'OXYGEN'),
            Tab(text: 'ALERTS'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildHeartRateTab(),
                _buildOxygenTab(),
                _buildAlertsTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    final vitals = widget.currentVitals;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Status Card
          _buildStatusCard(vitals),
          const SizedBox(height: 20),
          
          // Quick Stats
          Text(
            'CURRENT READINGS',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF94A3B8),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: _buildVitalCard(
                  icon: Icons.favorite,
                  iconColor: const Color(0xFFF43F5E),
                  label: 'Heart Rate',
                  value: vitals?.heartRate != null ? '${vitals!.heartRate}' : '--',
                  unit: 'BPM',
                  isNormal: vitals?.heartRate == null || 
                           (vitals!.heartRate! >= 50 && vitals.heartRate! <= 120),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildVitalCard(
                  icon: Icons.water_drop,
                  iconColor: const Color(0xFF3B82F6),
                  label: 'Blood Oxygen',
                  value: vitals?.bloodOxygen != null ? '${vitals!.bloodOxygen}' : '--',
                  unit: '%',
                  isNormal: vitals?.bloodOxygen == null || vitals!.bloodOxygen! >= 90,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildVitalCard(
                  icon: Icons.bedtime,
                  iconColor: const Color(0xFF8B5CF6),
                  label: 'Last Sleep',
                  value: vitals?.sleepHours != null 
                      ? vitals!.sleepHours!.toStringAsFixed(1) 
                      : '--',
                  unit: 'hrs',
                  isNormal: vitals?.sleepHours == null || vitals!.sleepHours! >= 6,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildVitalCard(
                  icon: Icons.access_time,
                  iconColor: const Color(0xFF10B981),
                  label: 'Last Update',
                  value: vitals?.lastUpdated != null 
                      ? _formatTimeAgo(vitals!.lastUpdated!) 
                      : '--',
                  unit: '',
                  isNormal: vitals?.hasRecentData ?? false,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Data Summary
          Text(
            'DATA SUMMARY (7 DAYS)',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF94A3B8),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          
          _buildSummaryRow(
            'Heart Rate Readings',
            '${_heartRateReadings.length}',
            Icons.favorite,
          ),
          _buildSummaryRow(
            'Blood Oxygen Readings',
            '${_oxygenReadings.length}',
            Icons.water_drop,
          ),
          _buildSummaryRow(
            'Sleep Sessions',
            '${_sleepReadings.length}',
            Icons.bedtime,
          ),
          _buildSummaryRow(
            'Active Alerts',
            '${_healthAlerts.where((a) => a['acknowledged'] != true).length}',
            Icons.warning,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(PatientVitalsData? vitals) {
    final isStable = vitals?.isStable ?? true;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isStable
              ? [const Color(0xFF10B981), const Color(0xFF059669)]
              : [const Color(0xFFF43F5E), const Color(0xFFE11D48)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isStable ? const Color(0xFF10B981) : const Color(0xFFF43F5E))
                .withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isStable ? Icons.check_circle : Icons.warning,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isStable ? 'Patient Stable' : 'Needs Attention',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isStable
                      ? 'All vitals are within normal range'
                      : 'Some readings are outside normal range',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String unit,
    required bool isNormal,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNormal ? const Color(0xFFF1F5F9) : const Color(0xFFFECACA),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const Spacer(),
              if (!isNormal)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '!',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFF43F5E),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    unit,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF94A3B8), size: 18),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeartRateTab() {
    if (_heartRateReadings.isEmpty) {
      return _buildEmptyState('No heart rate data', 'Patient has no recorded heart rate readings');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _heartRateReadings.length,
      itemBuilder: (context, index) {
        final reading = _heartRateReadings[index];
        final value = reading['value'] as int? ?? 0;
        final recordedAt = _parseDateTime(reading['recorded_at']);
        final isNormal = value >= 50 && value <= 120;

        return _buildReadingCard(
          icon: Icons.favorite,
          iconColor: const Color(0xFFF43F5E),
          value: '$value BPM',
          time: recordedAt,
          isNormal: isNormal,
          normalRange: '50-120 BPM',
        );
      },
    );
  }

  Widget _buildOxygenTab() {
    if (_oxygenReadings.isEmpty) {
      return _buildEmptyState('No oxygen data', 'Patient has no recorded blood oxygen readings');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _oxygenReadings.length,
      itemBuilder: (context, index) {
        final reading = _oxygenReadings[index];
        final value = reading['value'] as int? ?? 0;
        final recordedAt = _parseDateTime(reading['recorded_at']);
        final isNormal = value >= 90;

        return _buildReadingCard(
          icon: Icons.water_drop,
          iconColor: const Color(0xFF3B82F6),
          value: '$value%',
          time: recordedAt,
          isNormal: isNormal,
          normalRange: '≥90%',
        );
      },
    );
  }

  Widget _buildAlertsTab() {
    if (_healthAlerts.isEmpty) {
      return _buildEmptyState('No alerts', 'Patient has no health alerts');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _healthAlerts.length,
      itemBuilder: (context, index) {
        final alert = _healthAlerts[index];
        return _buildAlertCard(alert);
      },
    );
  }

  Widget _buildReadingCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required DateTime? time,
    required bool isNormal,
    required String normalRange,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isNormal ? const Color(0xFFF1F5F9) : const Color(0xFFFECACA),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isNormal ? const Color(0xFF0F172A) : const Color(0xFFF43F5E),
                  ),
                ),
                Text(
                  'Normal: $normalRange',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isNormal)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'ABNORMAL',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFF43F5E),
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                time != null ? DateFormat('MMM d, HH:mm').format(time) : '--',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final type = alert['type'] as String? ?? 'unknown';
    final riskLevel = alert['risk_level'] as String? ?? 'unknown';
    final recommendation = alert['recommendation'] as String? ?? '';
    final acknowledged = alert['acknowledged'] as bool? ?? false;
    final createdAt = _parseDateTime(alert['created_at']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: acknowledged ? const Color(0xFFF1F5F9) : const Color(0xFFFECACA),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: acknowledged 
                      ? const Color(0xFFDCFCE7) 
                      : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  type.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: acknowledged 
                        ? const Color(0xFF10B981) 
                        : const Color(0xFFF43F5E),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  riskLevel.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                acknowledged ? Icons.check_circle : Icons.error,
                color: acknowledged 
                    ? const Color(0xFF10B981) 
                    : const Color(0xFFF43F5E),
                size: 20,
              ),
            ],
          ),
          if (recommendation.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              recommendation,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            createdAt != null 
                ? DateFormat('MMM d, yyyy • HH:mm').format(createdAt) 
                : 'Unknown time',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: const Color(0xFFCBD5E1),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}
