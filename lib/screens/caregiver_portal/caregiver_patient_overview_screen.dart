import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/caregiver_portal_provider.dart';
import 'caregiver_call_screen.dart';
import 'caregiver_patient_chat_screen.dart';

class CaregiverPatientOverviewScreen extends ConsumerWidget {
  const CaregiverPatientOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portalState = ref.watch(caregiverPortalProvider);
    final patient = portalState.linkedPatient;
    final vitals = portalState.patientVitals;
    final canChat = portalState.canChat;
    final canViewVitals = portalState.canViewVitals;
    final canViewLocation = portalState.canViewLocation;

    if (patient == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF2F2F7),
        body: Center(child: Text('No patient linked')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.chevron_left, color: Color(0xFF007AFF)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(caregiverPortalProvider.notifier).refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Premium Profile Header
                Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 128,
                          height: 128,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(40),
                            color: const Color(0xFFE8F4FD),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: patient.photoUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(40),
                                  child: Image.network(
                                    patient.photoUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Center(
                                      child: Text(
                                        patient.initials,
                                        style: GoogleFonts.inter(
                                          fontSize: 40,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF007AFF),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    patient.initials,
                                    style: GoogleFonts.inter(
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF007AFF),
                                    ),
                                  ),
                                ),
                        ),
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: patient.isOnline 
                                  ? const Color(0xFF34C759) 
                                  : const Color(0xFF8E8E93),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      patient.name,
                      style: GoogleFonts.inter(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _buildSubtitle(patient),
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF8E8E93),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildStatusTag(
                          vitals?.overallStatus ?? 'Unknown', 
                          _getStatusColor(vitals?.overallStatus),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusTag(
                          patient.isOnline ? 'Online' : 'Offline', 
                          patient.isOnline ? const Color(0xFF34C759) : const Color(0xFF8E8E93),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context, rootNavigator: true).push(
                                PageRouteBuilder(
                                  pageBuilder: (context, animation, secondaryAnimation) => CaregiverCallScreen(callerName: patient.name),
                                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                    const begin = Offset(0.0, 1.0);
                                    const end = Offset.zero;
                                    const curve = Curves.ease;
                                    var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                    return SlideTransition(position: animation.drive(tween), child: child);
                                  },
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF007AFF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 4,
                              shadowColor: const Color(0xFF007AFF).withOpacity(0.4),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(CupertinoIcons.phone_fill, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Call',
                                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: canChat ? () {
                              Navigator.push(context, CupertinoPageRoute(builder: (context) => const CaregiverPatientChatScreen()));
                            } : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              disabledBackgroundColor: const Color(0xFFF2F2F7),
                              disabledForegroundColor: const Color(0xFFC7C7CC),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: Colors.black.withOpacity(0.05)),
                              ),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  canChat ? CupertinoIcons.chat_bubble_2_fill : CupertinoIcons.lock_fill, 
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Chat',
                                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Health Insights - Only show if permitted
                if (canViewVitals) ...[
                  _buildSectionHeader('Health Insights'),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildInsightRow(
                          'Heart Rate',
                          vitals?.lastUpdatedText ?? 'No data',
                          vitals?.heartRate != null ? '${vitals!.heartRate} bpm' : '--',
                          CupertinoIcons.heart_fill,
                          const Color(0xFFFF2D55),
                          const Color(0xFFFFF0F3),
                        ),
                        const Divider(height: 1, color: Color(0xFFF2F2F7), indent: 20, endIndent: 20),
                        _buildInsightRow(
                          'Oxygen Level',
                          'SpO2',
                          vitals?.oxygenLevel != null ? '${vitals!.oxygenLevel}%' : '--',
                          CupertinoIcons.wind,
                          const Color(0xFF007AFF),
                          const Color(0xFFE5F1FF),
                        ),
                        if (vitals?.bloodPressure != null) ...[
                          const Divider(height: 1, color: Color(0xFFF2F2F7), indent: 20, endIndent: 20),
                          _buildInsightRow(
                            'Blood Pressure',
                            'Systolic/Diastolic',
                            vitals!.bloodPressure!,
                            Icons.favorite_outline,
                            const Color(0xFFFF9500),
                            const Color(0xFFFFF7ED),
                          ),
                        ],
                        if (vitals?.sleepHours != null) ...[
                          const Divider(height: 1, color: Color(0xFFF2F2F7), indent: 20, endIndent: 20),
                          _buildInsightRow(
                            'Sleep',
                            'Last night',
                            '${vitals!.sleepHours!.toStringAsFixed(1)} hrs',
                            CupertinoIcons.moon_fill,
                            const Color(0xFF5856D6),
                            const Color(0xFFEFEBFF),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

                // No vitals permission message
                if (!canViewVitals) ...[
                  _buildSectionHeader('Health Insights'),
                  _buildPermissionRequiredCard(
                    'Vitals Access Required',
                    'Ask ${patient.name} to grant vitals permission to view health data.',
                    CupertinoIcons.heart_fill,
                  ),
                  const SizedBox(height: 32),
                ],

                // Location & Mobility - Only show if permitted
                if (canViewLocation) ...[
                  _buildSectionHeader('Location & Mobility'),
                  _buildLocationCard(patient),
                ] else ...[
                  _buildSectionHeader('Location'),
                  _buildPermissionRequiredCard(
                    'Location Access Required',
                    'Ask ${patient.name} to grant location permission to see their whereabouts.',
                    CupertinoIcons.location_solid,
                  ),
                ],
                
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _buildSubtitle(PatientInfo patient) {
    final parts = <String>[];
    if (patient.age != null) parts.add('${patient.age} Years Old');
    if (patient.patientId != null) parts.add('Patient #${patient.patientId}');
    return parts.isNotEmpty ? parts.join(' • ') : 'Patient';
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Stable':
        return const Color(0xFF34C759);
      case 'Needs Attention':
        return const Color(0xFFFF9500);
      case 'No Data':
        return const Color(0xFF8E8E93);
      default:
        return const Color(0xFF8E8E93);
    }
  }

  Widget _buildLocationCard(PatientInfo patient) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFFE8F4FD),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black12)],
                    ),
                    child: const Icon(CupertinoIcons.location_solid, color: Color(0xFF007AFF), size: 32),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${patient.name.split(' ').first} is at ${patient.currentLocation ?? "Home"}',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  if (patient.lastSeen != null)
                    Text(
                      'Last update: ${_formatLastSeen(patient.lastSeen!)}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF8E8E93),
                      ),
                    ),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              // TODO: Open maps
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              minimumSize: const Size(double.infinity, 50),
            ),
            child: Text(
              'Open in Maps',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF007AFF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionRequiredCard(String title, String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: const Color(0xFF8E8E93), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastSeen(DateTime lastSeen) {
    final diff = DateTime.now().difference(lastSeen);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _buildStatusTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF8E8E93),
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildInsightRow(String title, String subtitle, String value, IconData icon, Color color, Color bgColor) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(CupertinoIcons.chevron_right, color: Color(0xFFC7C7CC), size: 16),
            ],
          ),
        ],
      ),
    );
  }
}
