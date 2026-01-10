import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/caregiver_portal_provider.dart';
import 'caregiver_patient_chat_screen.dart';
import 'caregiver_call_screen.dart';

class CaregiverCommunicationScreen extends ConsumerStatefulWidget {
  const CaregiverCommunicationScreen({super.key});

  @override
  ConsumerState<CaregiverCommunicationScreen> createState() => _CaregiverCommunicationScreenState();
}

class _CaregiverCommunicationScreenState extends ConsumerState<CaregiverCommunicationScreen> {
  String _activeTab = 'Messages';

  @override
  Widget build(BuildContext context) {
    final portalState = ref.watch(caregiverPortalProvider);
    final patients = portalState.linkedPatients;
    
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
                Text(
                  'Messages',
                  style: GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Stay connected with your patients',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF8E8E93),
                  ),
                ),
                const SizedBox(height: 24),

                // Custom Segmented Control
                Container(
                  height: 48,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3E3E8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          AnimatedAlign(
                            alignment: _activeTab == 'Messages' ? Alignment.centerLeft : Alignment.centerRight,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                            child: Container(
                              width: (constraints.maxWidth - 12) / 2,
                              height: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _activeTab = 'Messages'),
                                  behavior: HitTestBehavior.opaque,
                                  child: Center(
                                    child: Text(
                                      'Messages',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: _activeTab == 'Messages' ? Colors.black : const Color(0xFF8E8E93),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _activeTab = 'Calls'),
                                  behavior: HitTestBehavior.opaque,
                                  child: Center(
                                    child: Text(
                                      'Calls',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: _activeTab == 'Calls' ? Colors.black : const Color(0xFF8E8E93),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                if (_activeTab == 'Messages') ...[
                  // Show all linked patients as message threads
                  if (patients.isEmpty)
                    _buildEmptyState()
                  else
                    ...patients.map((patientData) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildPatientMessageCard(patientData),
                    )),
                ] else ...[
                  // Calls List - Real call history from patients
                  if (patients.isEmpty)
                    _buildEmptyCallsState()
                  else
                    ...patients.map((patientData) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildPatientCallCard(patientData),
                    )),
                ],
                
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPatientMessageCard(LinkedPatientData patientData) {
    final patient = patientData.patient;
    final recentMessage = patientData.recentMessages.isNotEmpty 
        ? patientData.recentMessages.last 
        : null;
    final canChat = patientData.hasPermission('chat');
    
    if (!canChat) {
      // Chat not permitted
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
            _buildPatientAvatar(patient, showOnlineStatus: false),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patient.name,
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF8E8E93),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(CupertinoIcons.lock_fill, color: Color(0xFFC7C7CC), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Chat permission not granted',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFFC7C7CC),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    
    return GestureDetector(
      onTap: () => Navigator.push(
        context, 
        CupertinoPageRoute(builder: (context) => const CaregiverPatientChatScreen()),
      ),
      child: Container(
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
            _buildPatientAvatar(patient, showOnlineStatus: true),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          patient.name,
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        recentMessage != null 
                            ? _formatMessageTime(recentMessage.createdAt)
                            : '',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF8E8E93),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    recentMessage?.content ?? 'No messages yet',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (patientData.unreadMessageCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  patientData.unreadMessageCount > 99 
                      ? '99+' 
                      : '${patientData.unreadMessageCount}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              )
            else
              const Icon(CupertinoIcons.chevron_right, color: Color(0xFFC7C7CC), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientCallCard(LinkedPatientData patientData) {
    final patient = patientData.patient;
    
    return GestureDetector(
      onTap: () => Navigator.push(
        context, 
        CupertinoPageRoute(
          builder: (context) => CaregiverCallScreen(
            callerName: patient.name,
            callerPhotoUrl: patient.photoUrl,
          ),
        ),
      ),
      child: Container(
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
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF34C759).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                CupertinoIcons.phone_fill,
                color: Color(0xFF34C759),
                size: 24,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patient.name,
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    patient.isOnline ? 'Available now' : 'Last seen ${_formatLastSeen(patient.lastSeen)}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: patient.isOnline 
                          ? const Color(0xFF34C759) 
                          : const Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF34C759),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                CupertinoIcons.phone_fill,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientAvatar(PatientInfo patient, {required bool showOnlineStatus}) {
    return Stack(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F4FD),
            borderRadius: BorderRadius.circular(28),
          ),
          child: patient.photoUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(28),
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
        if (showOnlineStatus && patient.isOnline)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xFF34C759),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
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
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Icon(
              CupertinoIcons.chat_bubble_2,
              color: Color(0xFF8E8E93),
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No Conversations',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Link with a patient to start messaging',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF8E8E93),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCallsState() {
    return Container(
      padding: const EdgeInsets.all(40),
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
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Icon(
              CupertinoIcons.phone,
              color: Color(0xFF8E8E93),
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No Patients Linked',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Link with a patient to make calls',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF8E8E93),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMessageTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inMinutes < 1) return 'Now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) {
      const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      return days[timestamp.weekday % 7];
    }
    return '${timestamp.month}/${timestamp.day}';
  }

  String _formatLastSeen(DateTime? lastSeen) {
    if (lastSeen == null) return 'unknown';
    final diff = DateTime.now().difference(lastSeen);
    if (diff.inMinutes < 5) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
