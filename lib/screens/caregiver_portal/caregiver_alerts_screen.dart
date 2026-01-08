import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/caregiver_portal_provider.dart';

class CaregiverAlertsScreen extends ConsumerWidget {
  const CaregiverAlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portalState = ref.watch(caregiverPortalProvider);
    final alerts = portalState.alerts;
    final activeCount = portalState.activeAlertCount;
    final patient = portalState.linkedPatient;
    final canUseSOS = portalState.canUseSOS;

    // If SOS not permitted, show restricted view
    if (!canUseSOS) {
      return _buildRestrictedView(context, patient?.name ?? 'Patient');
    }

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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Alerts',
                            style: GoogleFonts.inter(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            activeCount > 0 
                                ? 'You have $activeCount active notification${activeCount > 1 ? 's' : ''}'
                                : 'All clear! No active alerts.',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF8E8E93),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(CupertinoIcons.ellipsis, color: Colors.black, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                // Emergency Actions Card
                if (patient != null)
                  _buildEmergencyActionsCard(context, patient.name),
                
                if (patient != null)
                  const SizedBox(height: 24),
                
                // Alerts List
                if (alerts.isNotEmpty)
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: alerts.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final alert = alerts[index];
                      return _CaregiverAlertCard(
                        alert: alert,
                        onResolve: () {
                          ref.read(caregiverPortalProvider.notifier).resolveAlert(alert.id);
                        },
                        onCall: () {
                          // TODO: Implement call functionality
                        },
                      );
                    },
                  ),
                
                // Empty state
                if (alerts.isEmpty)
                  _buildEmptyState(),
                  
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyActionsCard(BuildContext context, String patientName) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF3B30), Color(0xFFFF6B6B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF3B30).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(CupertinoIcons.exclamationmark_shield_fill, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EMERGENCY ACTIONS',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withOpacity(0.8),
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      'Quick response for $patientName',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Call emergency services
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFFF3B30),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(CupertinoIcons.phone_fill, size: 16),
                  label: Text('Call 911', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Call patient
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(CupertinoIcons.person_fill, size: 16),
                  label: Text('Call Patient', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F8ED),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(CupertinoIcons.checkmark_shield_fill, size: 40, color: Color(0xFF34C759)),
            ),
            const SizedBox(height: 16),
            Text(
              'ALL CLEAR',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF34C759),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No alerts at this time',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF8E8E93),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestrictedView(BuildContext context, String patientName) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF2F2F7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.lock_fill, color: Color(0xFF8E8E93), size: 48),
                ),
                const SizedBox(height: 24),
                Text(
                  'SOS Access Required',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Ask $patientName to grant you SOS alert permission to view and respond to emergencies.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: const Color(0xFF8E8E93),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Individual alert card widget
class _CaregiverAlertCard extends StatelessWidget {
  final CaregiverAlert alert;
  final VoidCallback onResolve;
  final VoidCallback onCall;

  const _CaregiverAlertCard({
    required this.alert,
    required this.onResolve,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final isResolved = alert.isResolved;
    
    Color bgColor = Colors.white;
    Color iconBgColor = const Color(0xFFF2F2F7);
    Color iconColor = Colors.black;
    IconData iconData = CupertinoIcons.bell_fill;
    BoxBorder? border;
    List<BoxShadow> shadows = [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 10,
        offset: const Offset(0, 2),
      ),
    ];

    if (isResolved) {
      bgColor = Colors.white.withOpacity(0.6);
      iconBgColor = const Color(0xFFF2F2F7);
      iconColor = const Color(0xFFC7C7CC);
    } else {
      switch (alert.type) {
        case CaregiverAlertType.sos:
          iconBgColor = const Color(0xFFFFF0F3);
          iconColor = const Color(0xFFFF3B30);
          iconData = CupertinoIcons.exclamationmark_shield_fill;
          border = Border.all(color: const Color(0xFFFF3B30), width: 2);
          shadows = [
            BoxShadow(
              color: const Color(0xFFFF3B30).withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ];
          break;
        case CaregiverAlertType.fall:
          iconBgColor = const Color(0xFFFFF7ED);
          iconColor = const Color(0xFFFF9500);
          iconData = CupertinoIcons.waveform_path_ecg;
          border = Border.all(color: const Color(0xFFFF9500), width: 2);
          shadows = [
            BoxShadow(
              color: const Color(0xFFFF9500).withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ];
          break;
        case CaregiverAlertType.geoFence:
          iconBgColor = const Color(0xFFE5F1FF);
          iconColor = const Color(0xFF007AFF);
          iconData = CupertinoIcons.location_solid;
          break;
        case CaregiverAlertType.medication:
          iconBgColor = const Color(0xFFE5F1FF);
          iconColor = const Color(0xFF007AFF);
          iconData = Icons.medication;
          break;
        case CaregiverAlertType.vitals:
          iconBgColor = const Color(0xFFFFF0F3);
          iconColor = const Color(0xFFFF2D55);
          iconData = CupertinoIcons.heart_fill;
          break;
        case CaregiverAlertType.system:
          iconBgColor = const Color(0xFFF2F2F7);
          iconColor = const Color(0xFF8E8E93);
          iconData = CupertinoIcons.gear_alt_fill;
          break;
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: border,
        boxShadow: shadows,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(iconData, color: iconColor, size: 24),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_getTypeLabel(alert.type)} ALERT',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: isResolved ? const Color(0xFFC7C7CC) : Colors.black,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      alert.timeAgo,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF8E8E93),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  alert.title,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isResolved ? const Color(0xFF8E8E93) : Colors.black,
                    height: 1.2,
                  ),
                ),
                if (alert.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    alert.description,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF8E8E93),
                    ),
                  ),
                ],
                if (!isResolved) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onCall,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF007AFF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(CupertinoIcons.phone_fill, size: 14),
                              const SizedBox(width: 8),
                              Text(
                                'Call',
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onResolve,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF2F2F7),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(CupertinoIcons.check_mark, size: 14),
                              const SizedBox(width: 8),
                              Text(
                                'Clear',
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(CupertinoIcons.check_mark, color: Color(0xFF34C759), size: 14),
                      const SizedBox(width: 8),
                      Text(
                        'RESOLVED',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF34C759),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTypeLabel(CaregiverAlertType type) {
    switch (type) {
      case CaregiverAlertType.sos:
        return 'SOS';
      case CaregiverAlertType.fall:
        return 'FALL';
      case CaregiverAlertType.geoFence:
        return 'GEO-FENCE';
      case CaregiverAlertType.medication:
        return 'MEDICATION';
      case CaregiverAlertType.vitals:
        return 'VITALS';
      case CaregiverAlertType.system:
        return 'SYSTEM';
    }
  }
}
