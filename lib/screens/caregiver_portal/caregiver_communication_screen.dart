import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/caregiver_portal_provider.dart';
import 'caregiver_ai_chat_screen.dart';
import 'caregiver_patient_chat_screen.dart';
import 'caregiver_doctor_chat_screen.dart';

class CaregiverCommunicationScreen extends ConsumerStatefulWidget {
  const CaregiverCommunicationScreen({super.key});

  @override
  ConsumerState<CaregiverCommunicationScreen> createState() => _CaregiverCommunicationScreenState();
}

class _CaregiverCommunicationScreenState extends ConsumerState<CaregiverCommunicationScreen> {
  String _activeTab = 'Messages';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: SingleChildScrollView(
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
              const SizedBox(height: 32),

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
                // AI Guardian Thread
                _buildMessageCard(
                  onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (context) => const CaregiverAIChatScreen())),
                  icon: CupertinoIcons.shield_fill,
                  iconColor: const Color(0xFF007AFF),
                  iconBgColor: const Color(0xFFE5F1FF),
                  title: 'AI Guardian',
                  time: 'Now',
                  message: "Analysis complete: Your patient's vitals are stable.",
                ),
                const SizedBox(height: 16),

                // Patient Thread - Use real data from provider
                Builder(builder: (context) {
                  final portalState = ref.watch(caregiverPortalProvider);
                  final patient = portalState.linkedPatient;
                  final recentMessage = portalState.recentMessages.isNotEmpty 
                      ? portalState.recentMessages.last 
                      : null;
                  
                  if (!portalState.canChat) {
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
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F2F7),
                              borderRadius: BorderRadius.circular(32),
                            ),
                            child: const Icon(CupertinoIcons.lock_fill, color: Color(0xFF8E8E93), size: 28),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Patient Chat',
                                  style: GoogleFonts.inter(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF8E8E93),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Chat permission not granted',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFFC7C7CC),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  return _buildMessageCard(
                    onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (context) => const CaregiverPatientChatScreen())),
                    image: patient?.photoUrl,
                    title: patient?.name ?? 'No Patient',
                    time: recentMessage != null ? _formatMessageTime(recentMessage.createdAt) : '--',
                    message: recentMessage?.content ?? 'No messages yet',
                    isOnline: patient?.isOnline ?? false,
                    unreadCount: portalState.unreadMessageCount,
                  );
                }),
                const SizedBox(height: 16),

                // Doctor Thread
                _buildMessageCard(
                  onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (context) => const CaregiverDoctorChatScreen())),
                  icon: CupertinoIcons.heart_circle_fill,
                  iconColor: const Color(0xFFFF2D55),
                  iconBgColor: const Color(0xFFFFF0F3),
                  title: 'Dr. Aris Thorne',
                  time: 'Tue',
                  message: "The latest lab results look promising. Let's discuss.",
                ),
              ] else ...[
                // Calls List
                Builder(builder: (context) {
                  final portalState = ref.watch(caregiverPortalProvider);
                  final patient = portalState.linkedPatient;
                  final patientName = patient?.name ?? 'Patient';
                  
                  return Column(
                    children: [
                      _buildCallCard(patientName, 'Outgoing', 'Yesterday', 'Missed', '0:00'),
                      const SizedBox(height: 16),
                      _buildCallCard('Dr. Aris Thorne', 'Incoming', 'Tue', 'Answered', '4:12'),
                      const SizedBox(height: 16),
                      _buildCallCard(patientName, 'FaceTime', 'Monday', 'Answered', '12:05'),
                    ],
                  );
                }),
              ],
              
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageCard({
    required VoidCallback onTap,
    IconData? icon,
    Color? iconColor,
    Color? iconBgColor,
    String? image,
    required String title,
    required String time,
    required String message,
    bool isOnline = false,
    int unreadCount = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
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
            if (image != null)
              Stack(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F4FD),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: const Icon(CupertinoIcons.person_fill, color: Color(0xFF007AFF), size: 28),
                  ),
                  if (isOnline)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: const Color(0xFF34C759),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                      ),
                    ),
                ],
              )
            else
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        time,
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
                    message,
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
            if (unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
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

  Widget _buildCallCard(String name, String type, String time, String status, String duration) {
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
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              type == 'FaceTime' ? CupertinoIcons.videocam_fill : CupertinoIcons.phone_fill,
              color: Colors.black,
              size: 20,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: status == 'Missed' ? const Color(0xFFFF3B30) : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$type • $time',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          ),
          Text(
            duration,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF8E8E93),
            ),
          ),
          const SizedBox(width: 12),
          const Icon(CupertinoIcons.info, color: Color(0xFF007AFF), size: 22),
        ],
      ),
    );
  }
  
  /// Format message timestamp for display
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
}
