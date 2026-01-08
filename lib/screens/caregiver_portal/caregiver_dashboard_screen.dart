import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/caregiver_portal_provider.dart';
import 'caregiver_patient_overview_screen.dart';
import 'caregiver_alerts_screen.dart';

class CaregiverDashboardScreen extends ConsumerWidget {
  const CaregiverDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portalState = ref.watch(caregiverPortalProvider);
    final patient = portalState.linkedPatient;
    final vitals = portalState.patientVitals;
    final alertCount = portalState.activeAlertCount;

    // Generate status message based on real data
    final statusMessage = _getStatusMessage(portalState);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(caregiverPortalProvider.notifier).refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Today's Overview",
                            style: GoogleFonts.inter(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            statusMessage,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF8E8E93),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Alert badge if there are active alerts
                    if (alertCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3B30),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              CupertinoIcons.bell_fill,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$alertCount',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),

                // Patient Card - Shows real patient data
                GestureDetector(
                  onTap: () {
                    if (patient != null) {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) =>
                              const CaregiverPatientOverviewScreen(),
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: patient != null
                        ? Row(
                            children: [
                              // Patient avatar with initials or photo
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F4FD),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: patient.photoUrl != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(24),
                                        child: Image.network(
                                          patient.photoUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Center(
                                            child: Text(
                                              patient.initials,
                                              style: GoogleFonts.inter(
                                                fontSize: 18,
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
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF007AFF),
                                          ),
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      patient.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: patient.isOnline
                                                ? const Color(0xFF34C759)
                                                : const Color(0xFF8E8E93),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          patient.isOnline
                                              ? 'ONLINE'
                                              : 'OFFLINE',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: patient.isOnline
                                                ? const Color(0xFF34C759)
                                                : const Color(0xFF8E8E93),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        if (!patient.isOnline &&
                                            patient.lastSeen != null) ...[
                                          const SizedBox(width: 6),
                                          Text(
                                            '• ${_getLastSeenText(patient.lastSeen!)}',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: const Color(0xFF8E8E93),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                CupertinoIcons.chevron_right,
                                color: Color(0xFFC7C7CC),
                                size: 20,
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF2F2F7),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: const Icon(
                                  CupertinoIcons.person_fill,
                                  color: Color(0xFFC7C7CC),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'No Patient Linked',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF8E8E93),
                                      ),
                                    ),
                                    Text(
                                      'Add a patient to get started',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFFC7C7CC),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                CupertinoIcons.plus_circle_fill,
                                color: Color(0xFF007AFF),
                                size: 24,
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // Main Stats Cluster
                // Safety Hero - Location Status
                if (portalState.canViewLocation)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'SAFETY STATUS',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF8E8E93),
                                letterSpacing: 1.2,
                              ),
                            ),
                            Icon(
                              CupertinoIcons.exclamationmark_shield,
                              size: 40,
                              color: const Color(0xFF007AFF).withOpacity(0.1),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF007AFF).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                CupertinoIcons.location_solid,
                                color: Color(0xFF007AFF),
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    patient?.currentLocation ??
                                        'Safe Zone: Home',
                                    style: GoogleFonts.inter(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  Text(
                                    patient?.lastSeen != null
                                        ? 'Updated ${_getLastSeenText(patient!.lastSeen!)}'
                                        : 'Location not available',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF8E8E93),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(child: _buildActionButton('View History')),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildActionButton('Zone Settings'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                if (portalState.canViewLocation) const SizedBox(height: 24),

                // SOS Quick Block - Only show if permitted
                if (portalState.canUseSOS)
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => const CaregiverAlertsScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: alertCount > 0
                            ? const Color(0xFFFFF0F0)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: alertCount > 0
                            ? Border.all(
                                color: const Color(0xFFFF3B30).withOpacity(0.3),
                                width: 1,
                              )
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFFF3B30,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  CupertinoIcons.exclamationmark_shield_fill,
                                  color: Color(0xFFFF3B30),
                                  size: 32,
                                ),
                              ),
                              if (alertCount > 0) ...[
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF3B30),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$alertCount Active',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            alertCount > 0 ? 'Active Alerts' : 'SOS Alert',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          Text(
                            alertCount > 0
                                ? 'Tap to view and respond'
                                : 'Ready for emergency',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF8E8E93),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Text(
                                alertCount > 0 ? 'View Alerts' : 'Check Status',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFFF3B30),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                CupertinoIcons.arrow_right,
                                size: 16,
                                color: Color(0xFFFF3B30),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                if (portalState.canUseSOS) const SizedBox(height: 32),

                // Vitals Section - Only show if permitted
                if (portalState.canViewVitals) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Vitals',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      Row(
                        children: [
                          if (vitals?.lastUpdated != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Text(
                                'Updated ${vitals!.lastUpdatedText}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF8E8E93),
                                ),
                              ),
                            ),
                          Text(
                            'View Trends',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF007AFF),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.1,
                    children: [
                      _buildVitalCard(
                        'Heart Rate',
                        vitals?.heartRate?.toString() ?? '--',
                        'bpm',
                        CupertinoIcons.heart_fill,
                        const Color(0xFFFF2D55),
                        const Color(0xFFFFF0F3),
                        vitals?.heartRate != null,
                      ),
                      _buildVitalCard(
                        'Oxygen',
                        vitals?.oxygenLevel?.toString() ?? '--',
                        '%',
                        CupertinoIcons.wind,
                        const Color(0xFF007AFF),
                        const Color(0xFFE5F1FF),
                        vitals?.oxygenLevel != null,
                      ),
                      _buildVitalCard(
                        'Sleep',
                        vitals?.sleepHours?.toStringAsFixed(1) ?? '--',
                        'hrs',
                        CupertinoIcons.moon_fill,
                        const Color(0xFF5856D6),
                        const Color(0xFFEFEBFF),
                        vitals?.sleepHours != null,
                      ),
                      _buildVitalCard(
                        'Steps',
                        vitals?.steps != null
                            ? _formatSteps(vitals!.steps!)
                            : '--',
                        'steps',
                        CupertinoIcons.waveform_path_ecg,
                        const Color(0xFF34C759),
                        const Color(0xFFE8F8ED),
                        vitals?.steps != null,
                      ),
                    ],
                  ),
                ],

                // No vitals permission message
                if (!portalState.canViewVitals && patient != null)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
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
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F2F7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            CupertinoIcons.lock_fill,
                            color: Color(0xFF8E8E93),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Vitals Not Available',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                              Text(
                                'Ask ${patient.name} to grant vitals access',
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
                  ),
                const SizedBox(height: 100), // Bottom padding
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Generate status message based on patient and vitals state
  String _getStatusMessage(CaregiverPortalState state) {
    if (!state.hasActiveRelationship || state.linkedPatient == null) {
      return 'No patient linked. Add a patient to get started.';
    }

    final patient = state.linkedPatient!;
    final vitals = state.patientVitals;

    if (state.activeAlertCount > 0) {
      return '⚠️ ${state.activeAlertCount} active alert${state.activeAlertCount > 1 ? 's' : ''} require attention.';
    }

    if (vitals != null && vitals.overallStatus == 'Needs Attention') {
      return 'Some vitals need attention. Tap to view details.';
    }

    final locationPart = patient.currentLocation ?? 'home';
    final statusPart = patient.isOnline ? 'online' : 'offline';
    return 'Everything is stable. ${patient.name.split(' ').first} is $statusPart at $locationPart.';
  }

  /// Format last seen time
  String _getLastSeenText(DateTime lastSeen) {
    final diff = DateTime.now().difference(lastSeen);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  /// Format steps count (e.g., 3200 -> "3.2k")
  String _formatSteps(int steps) {
    if (steps >= 1000) {
      return '${(steps / 1000).toStringAsFixed(1)}k';
    }
    return steps.toString();
  }

  Widget _buildActionButton(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildVitalCard(
    String label,
    String value,
    String unit,
    IconData icon,
    Color color,
    Color bgColor, [
    bool hasData = true,
  ]) {
    return Container(
      padding: const EdgeInsets.all(20),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: hasData ? bgColor : const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: hasData ? color : const Color(0xFFC7C7CC),
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF8E8E93),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: hasData ? Colors.black : const Color(0xFFC7C7CC),
                ),
              ),
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF8E8E93),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
