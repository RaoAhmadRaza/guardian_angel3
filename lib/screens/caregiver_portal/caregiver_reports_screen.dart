import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/caregiver_portal_provider.dart';

/// Caregiver Reports Screen
/// 
/// Displays health reports, documents, and AI summaries for the patient.
/// Uses real data from health repositories.
class CaregiverReportsScreen extends ConsumerWidget {
  const CaregiverReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portalState = ref.watch(caregiverPortalProvider);
    final patient = portalState.linkedPatient;
    final vitals = portalState.patientVitals;
    final patientName = patient?.name ?? 'Patient';
    final patientFirstName = patientName.split(' ').first;
    final canViewVitals = portalState.canViewVitals;

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
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reports',
                            style: GoogleFonts.inter(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Medical documents & health trends',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF8E8E93),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildHeaderButton(CupertinoIcons.search),
                  ],
                ),
                const SizedBox(height: 32),

                // Health Summary Card (from real vitals)
                if (canViewVitals && vitals != null)
                  _buildHealthSummaryCard(patientFirstName, vitals),
                
                if (canViewVitals && vitals != null)
                  const SizedBox(height: 24),

                // Document Library - Empty State
                _buildSectionHeader('Document Library'),
                _buildEmptyDocumentsState(),
                const SizedBox(height: 24),

                // AI Summary - Based on real vitals
                _buildSectionHeader('Health Overview'),
                _buildHealthOverviewCard(patientFirstName, vitals, canViewVitals),
                
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHealthSummaryCard(String patientName, PatientVitals vitals) {
    final status = vitals.overallStatus;
    final isStable = status == 'Stable';
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isStable 
              ? [const Color(0xFF34C759), const Color(0xFF30D158)]
              : [const Color(0xFFFF9500), const Color(0xFFFF9F0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isStable ? const Color(0xFF34C759) : const Color(0xFFFF9500))
                .withOpacity(0.3),
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
                child: Icon(
                  isStable ? CupertinoIcons.heart_fill : CupertinoIcons.exclamationmark_circle_fill,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Updated ${vitals.lastUpdatedText}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildVitalChip('HR', '${vitals.heartRate ?? "--"} bpm'),
              const SizedBox(width: 12),
              _buildVitalChip('BP', vitals.bloodPressure ?? '--/--'),
              const SizedBox(width: 12),
              _buildVitalChip('O₂', '${vitals.oxygenLevel ?? "--"}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVitalChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDocumentsState() {
    return Container(
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(32),
            ),
            child: const Icon(
              CupertinoIcons.doc_text,
              color: Color(0xFF8E8E93),
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Documents Yet',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Medical reports and documents will appear here when uploaded',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF8E8E93),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F9FA),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                'Request Lab Data',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF007AFF),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthOverviewCard(String patientName, PatientVitals? vitals, bool canViewVitals) {
    if (!canViewVitals || vitals == null) {
      return Container(
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
          children: [
            const Icon(CupertinoIcons.lock_fill, color: Color(0xFF8E8E93), size: 32),
            const SizedBox(height: 12),
            Text(
              'Vitals Access Required',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Request vitals permission to view health insights',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF8E8E93),
              ),
            ),
          ],
        ),
      );
    }

    final hasGoodData = vitals.heartRate != null || vitals.oxygenLevel != null;
    
    return Container(
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
            children: [
              Icon(
                hasGoodData ? Icons.trending_up : CupertinoIcons.chart_bar,
                color: hasGoodData ? const Color(0xFF34C759) : const Color(0xFF8E8E93),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                hasGoodData ? 'HEALTH INSIGHTS' : 'COLLECTING DATA',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: hasGoodData ? const Color(0xFF34C759) : const Color(0xFF8E8E93),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            hasGoodData 
                ? "$patientName's vitals are being monitored"
                : 'Waiting for more health data',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasGoodData
                ? 'Last reading: ${vitals.lastUpdatedText}'
                : 'Health insights will appear as data is collected',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF8E8E93),
            ),
          ),
          const SizedBox(height: 24),
          Divider(height: 1, color: const Color(0xFFF2F2F7)),
          const SizedBox(height: 24),
          
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007AFF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: Text(
              'Export PDF Report',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.black, size: 20),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF8E8E93),
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
