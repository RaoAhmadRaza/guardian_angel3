import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models/patient_model.dart';
import 'patient_overview_screen.dart';
import 'providers/doctor_patients_provider.dart';
import 'relationships/services/doctor_relationship_service.dart';
import 'chat/screens/patient_doctor_chat_screen.dart';
import 'screens/doctor_patient_vitals_screen.dart';

// Mock Data Models - KEPT FOR FALLBACK/DEMO MODE

final List<Patient> mockPatients = [
  Patient(
    id: '1',
    name: 'Sarah Jenkins',
    age: 72,
    photo: 'https://i.pravatar.cc/150?u=1',
    status: PatientStatus.stable,
    lastUpdate: '2m ago',
    conditions: ['Hypertension', 'Arrhythmia'],
    caregiverName: 'Martha (Daughter)',
  ),
  Patient(
    id: '2',
    name: 'Robert Chen',
    age: 68,
    photo: 'https://i.pravatar.cc/150?u=2',
    status: PatientStatus.critical,
    lastUpdate: 'Just now',
    conditions: ['Post-Op', 'High BP'],
    caregiverName: 'David (Son)',
  ),
  Patient(
    id: '3',
    name: 'Elise Bowen',
    age: 81,
    photo: 'https://i.pravatar.cc/150?u=3',
    status: PatientStatus.stable,
    lastUpdate: '15m ago',
    conditions: ['Dementia', 'Mobility'],
    caregiverName: 'Sarah (Nurse)',
  ),
];

class DoctorMainScreen extends ConsumerStatefulWidget {
  const DoctorMainScreen({super.key});

  @override
  ConsumerState<DoctorMainScreen> createState() => _DoctorMainScreenState();
}

class _DoctorMainScreenState extends ConsumerState<DoctorMainScreen> with TickerProviderStateMixin {
  bool _showConnectModal = false;
  bool _showProfileModal = false;
  final TextEditingController _inviteCodeController = TextEditingController();
  bool _isAcceptingInvite = false;
  String? _inviteError;
  
  // Animation controllers for pulse effects
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(_pulseController);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _acceptInviteCode() async {
    final code = _inviteCodeController.text.trim().replaceAll('-', '');
    if (code.isEmpty || code.length < 6) {
      setState(() => _inviteError = 'Please enter a valid 6-digit code');
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _inviteError = 'Not authenticated');
      return;
    }

    setState(() {
      _isAcceptingInvite = true;
      _inviteError = null;
    });

    final result = await DoctorRelationshipService.instance.acceptDoctorInvite(
      inviteCode: code,
      doctorId: uid,
    );

    if (mounted) {
      setState(() => _isAcceptingInvite = false);

      if (result.success) {
        setState(() => _showConnectModal = false);
        _inviteCodeController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Patient connected successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        // Refresh providers
        ref.invalidate(doctorPatientListProvider);
      } else {
        setState(() => _inviteError = result.errorMessage ?? 'Failed to connect');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate-50
      body: Stack(
        children: [
          // Main Content
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 140, bottom: 40), // Space for header
              child: _buildPatientList(),
            ),
          ),

          // Sticky Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildHeader(),
          ),

          // Modals
          if (_showConnectModal) _buildConnectModal(),
          if (_showProfileModal) _buildProfileModal(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Welcome Doctor',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A), // Slate-900
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Wednesday, Oct 24',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B), // Slate-500
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Notification Bell
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE2E8F0)), // Slate-200
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(Icons.notifications_outlined, color: Color(0xFF64748B), size: 20),
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEF4444), // Rose-500
                                  shape: BoxShape.circle,
                                  border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 1.5)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Profile Image
                      GestureDetector(
                        onTap: () => setState(() => _showProfileModal = true),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF3B82F6), Color(0xFF2563EB)], // Blue-500 to Blue-600
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF3B82F6).withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              'DR',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPatientList() {
    // Watch real patient data from provider
    final patientsAsync = ref.watch(doctorPatientListProvider);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Clinical Summary Header - shows real count
          patientsAsync.when(
            data: (patients) => _buildSummaryHeader(patients.length, patients.where((p) => !p.isStable).length),
            loading: () => _buildSummaryHeader(0, 0),
            error: (_, __) => _buildSummaryHeader(mockPatients.length, 1),
          ),

          const SizedBox(height: 12),

          // Search Bar
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)), // Slate-200
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name, ID, or condition...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF94A3B8), // Slate-400
                ),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ),

          // Connection Glass Widget
          GestureDetector(
            onTap: () => setState(() => _showConnectModal = true),
            child: Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF).withOpacity(0.5), // Blue-50/50
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDBEAFE).withOpacity(0.5)), // Blue-100/50
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB), // Blue-600
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFBFDBFE), // Blue-200
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Connect New Patient',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF1D4ED8), // Blue-700
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'ENTER CODE',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF2563EB), // Blue-600
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Patient Grid - use real data with fallback to mock
          patientsAsync.when(
            data: (patients) {
              if (patients.isEmpty) {
                return _buildEmptyState();
              }
              return Column(
                children: patients.map((patient) => _buildRealPatientCard(patient)).toList(),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, __) => Column(
              children: mockPatients.map((patient) => _buildPatientCard(patient)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(int totalPatients, int attentionRequired) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'ACTIVE MONITORING: $totalPatients',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF94A3B8), // Slate-400
              letterSpacing: 1.5,
            ),
          ),
          if (attentionRequired > 0)
            Row(
              children: [
                FadeTransition(
                  opacity: _pulseAnimation,
                  child: Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF43F5E), // Rose-500
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Text(
                  '$attentionRequired ATTENTION REQUIRED',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFF43F5E), // Rose-500
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.people_outline, color: Color(0xFF3B82F6), size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            'No Patients Yet',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect with patients by entering their invite code above.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  /// Build card for real patient data from DoctorPatientItem.
  Widget _buildRealPatientCard(DoctorPatientItem patient) {
    final statusColor = patient.isStable ? const Color(0xFF10B981) : const Color(0xFFF43F5E);
    final ringColor = patient.isStable ? const Color(0xFF10B981).withOpacity(0.1) : const Color(0xFFF43F5E).withOpacity(0.1);

    return GestureDetector(
      onTap: () {
        // Navigate to patient vitals screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DoctorPatientVitalsScreen(
              patientId: patient.patientId,
              patientName: patient.patientName,
              currentVitals: patient.vitals,
            ),
          ),
        );
      },
      onLongPress: () {
        // Long press to go to chat if available
        if (patient.hasChatPermission && patient.chatThread != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PatientDoctorChatScreen(
                threadId: patient.chatThread!.id,
                otherUserName: patient.patientName,
                otherUserAvatarUrl: patient.photo,
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vital Ring Avatar
            Stack(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: ringColor,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: patient.photo != null
                        ? Image.network(
                            patient.photo!,
                            fit: BoxFit.cover,
                            errorBuilder: (c, o, s) => _buildPatientAvatarFallback(patient.patientName),
                          )
                        : _buildPatientAvatarFallback(patient.patientName),
                  ),
                ),
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
                // Chat badge if unread
                if (patient.unreadMessages > 0)
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Text(
                        '${patient.unreadMessages}',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patient.patientName,
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0F172A),
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            patient.age != null 
                                ? '${patient.age} YRS • GA-${patient.patientId.substring(0, 3).toUpperCase()}'
                                : 'GA-${patient.patientId.substring(0, 6).toUpperCase()}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF94A3B8),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        (patient.lastActivity ?? 'No activity').toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFCBD5E1),
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Conditions pills
                  if (patient.conditions.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: patient.conditions.map((c) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          c.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF64748B),
                            letterSpacing: -0.2,
                          ),
                        ),
                      )).toList(),
                    ),

                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFF8FAFC)),
                  const SizedBox(height: 8),

                  // Bottom Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (patient.caregiverName != null)
                        Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEFF6FF),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.person, size: 10, color: Color(0xFF3B82F6)),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              patient.caregiverName!,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        )
                      else
                        const SizedBox(),
                      
                      // Chat or View button
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: patient.hasChatPermission 
                              ? const Color(0xFFECFDF5) // Green-50
                              : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              patient.hasChatPermission ? Icons.chat_bubble_outline : Icons.visibility,
                              size: 12,
                              color: patient.hasChatPermission 
                                  ? const Color(0xFF059669)
                                  : const Color(0xFF2563EB),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              patient.hasChatPermission ? 'CHAT' : 'VIEW',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: patient.hasChatPermission 
                                    ? const Color(0xFF059669)
                                    : const Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientAvatarFallback(String name) {
    return Container(
      color: const Color(0xFFEFF6FF),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF3B82F6),
          ),
        ),
      ),
    );
  }

  Widget _buildPatientCard(Patient patient) {
    final isStable = patient.status == PatientStatus.stable;
    final statusColor = isStable ? const Color(0xFF10B981) : const Color(0xFFF43F5E); // Emerald-500 : Rose-500
    final ringColor = isStable ? const Color(0xFF10B981).withOpacity(0.1) : const Color(0xFFF43F5E).withOpacity(0.1);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PatientOverviewScreen(patient: patient),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF1F5F9)), // Slate-100
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vital Ring Avatar
            Stack(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: ringColor,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.network(
                      patient.photo,
                      fit: BoxFit.cover,
                      errorBuilder: (c, o, s) => Container(color: Colors.grey[200]),
                    ),
                  ),
                ),
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patient.name,
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0F172A), // Slate-900
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${patient.age} YRS • GA-${patient.id.padLeft(3, '0')}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF94A3B8), // Slate-400
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        patient.lastUpdate.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFCBD5E1), // Slate-300
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Micro-pills
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: patient.conditions.map((c) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC), // Slate-50
                        border: Border.all(color: const Color(0xFFF1F5F9)), // Slate-100
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        c.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF64748B), // Slate-500
                          letterSpacing: -0.2,
                        ),
                      ),
                    )).toList(),
                  ),
                  
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFF8FAFC)),
                  const SizedBox(height: 8),
                  
                  // Bottom Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEFF6FF), // Blue-50
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.person, size: 10, color: Color(0xFF3B82F6)),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            patient.caregiverName,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF94A3B8), // Slate-400
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF), // Blue-50
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'VIEW HUB',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF2563EB), // Blue-600
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right, size: 14, color: Color(0xFFBFDBFE)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectModal() {
    return Stack(
      children: [
        // Backdrop
        GestureDetector(
          onTap: () => setState(() {
            _showConnectModal = false;
            _inviteError = null;
          }),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Container(
              color: Colors.black.withOpacity(0.2),
            ),
          ),
        ),
        // Modal Content
        Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF), // Blue-50
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.link, color: Color(0xFF2563EB), size: 24),
                ),
                const SizedBox(height: 16),
                Text(
                  'Connect New Case',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A), // Slate-900
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the 6-digit pairing code from the patient\'s device.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B), // Slate-500
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _inviteCodeController,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC), // Slate-50
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    hintText: '000-000',
                    hintStyle: GoogleFonts.inter(
                      color: const Color(0xFFCBD5E1), // Slate-300
                    ),
                    errorText: _inviteError,
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 7, // 6 digits + 1 dash
                  onChanged: (value) {
                    // Auto-format with dash
                    if (value.length == 3 && !value.contains('-')) {
                      _inviteCodeController.text = '$value-';
                      _inviteCodeController.selection = TextSelection.fromPosition(
                        TextPosition(offset: _inviteCodeController.text.length),
                      );
                    }
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isAcceptingInvite ? null : _acceptInviteCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB), // Blue-600
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isAcceptingInvite
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : Text(
                            'Verify Connection',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileModal() {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => setState(() => _showProfileModal = false),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Container(
              color: Colors.black.withOpacity(0.2),
            ),
          ),
        ),
        Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3B82F6).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'DR',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 28,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Dr. Sarah Mitchell',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'Cardiology Specialist',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      setState(() => _showProfileModal = false);
                      Navigator.of(context).pop(); // Go back to selection
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFFFEF2F2), // Red-50
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Sign Out',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFEF4444), // Red-500
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
