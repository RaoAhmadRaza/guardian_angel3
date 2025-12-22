import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'patient_ai_chat_screen.dart';
import 'patient_sos_screen.dart';
import 'care_team_directory_screen.dart';
import 'caregiver_chat_screen.dart';
import 'doctor_chat_screen.dart';
import 'add_member_screen.dart';
import 'medication_screen.dart';
import 'peace_of_mind_screen.dart';
import 'community_discovery_screen.dart';

// --- MOCK DATA & TYPES ---

enum ViewType { AI_COMPANION, CAREGIVER, DOCTOR, SYSTEM, PEACE_OF_MIND, COMMUNITY }

class ChatSession {
  final String id;
  final ViewType type;
  final String name;
  final String? subtitle;
  final bool isOnline;
  final int unreadCount;
  final String? imageUrl;

  const ChatSession({
    required this.id,
    required this.type,
    required this.name,
    this.subtitle,
    this.isOnline = false,
    this.unreadCount = 0,
    this.imageUrl,
  });
}

final List<ChatSession> INITIAL_SESSIONS = [
  ChatSession(
    id: 'ai-1',
    type: ViewType.AI_COMPANION,
    name: 'Guardian Angel',
    subtitle: 'Monitoring quietly',
  ),
  ChatSession(
    id: 'caregiver-1',
    type: ViewType.CAREGIVER,
    name: 'Sarah',
    subtitle: 'Active earlier',
    isOnline: true,
    unreadCount: 2,
  ),
  ChatSession(
    id: 'doc-1',
    type: ViewType.DOCTOR,
    name: 'Dr. Emily',
    subtitle: 'Cardiologist',
    isOnline: false,
    imageUrl: 'https://images.unsplash.com/photo-1559839734-2b71ea860632?q=80&w=100&auto=format&fit=crop',
  ),
  ChatSession(
    id: 'sys-1',
    type: ViewType.SYSTEM,
    name: 'Medication',
    subtitle: 'On track',
  ),
  ChatSession(
    id: 'peace-1',
    type: ViewType.PEACE_OF_MIND,
    name: 'Daily Peace',
    subtitle: 'Mindfulness',
  ),
];

// --- COMPONENTS ---

class ProgressRing extends StatelessWidget {
  final double progress; // 0 to 100
  final Color color;
  final double size;
  final double stroke;
  final IconData? icon;

  const ProgressRing({
    super.key,
    required this.progress,
    required this.color,
    this.size = 48,
    this.stroke = 4,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Circle
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: stroke,
              color: Colors.grey.withOpacity(0.2), // text-gray-400 with opacity
            ),
          ),
          // Progress Circle
          Transform.rotate(
            angle: -math.pi / 2,
            child: SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: progress / 100,
                strokeWidth: stroke,
                color: color,
                strokeCap: StrokeCap.round,
              ),
            ),
          ),
          if (icon != null)
            Icon(
              icon,
              color: color,
              size: size * 0.4,
            ),
        ],
      ),
    );
  }
}

class PatientChatScreen extends StatefulWidget {
  const PatientChatScreen({super.key});

  @override
  State<PatientChatScreen> createState() => _PatientChatScreenState();
}

class _PatientChatScreenState extends State<PatientChatScreen> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  bool _isScrolled = false;
  bool _isSOSOpen = false;
  String _greeting = "Good Afternoon";

  @override
  void initState() {
    super.initState();
    _updateGreeting();
    _scrollController.addListener(_onScroll);

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _updateGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      setState(() => _greeting = "Good Morning");
    } else if (hour < 18) {
      setState(() => _greeting = "Good Afternoon");
    } else {
      setState(() => _greeting = "Good Evening");
    }
  }

  void _onScroll() {
    if (_scrollController.offset > 40 && !_isScrolled) {
      setState(() => _isScrolled = true);
    } else if (_scrollController.offset <= 40 && _isScrolled) {
      setState(() => _isScrolled = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Background color transition
    return Scaffold(
      backgroundColor: _isSOSOpen ? Colors.grey[200] : const Color(0xFFF2F2F7),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Sticky Header
                SliverAppBar(
                  pinned: true,
                  backgroundColor: _isScrolled 
                      ? const Color(0xFFF2F2F7).withOpacity(0.8) 
                      : Colors.transparent,
                  elevation: 0,
                  toolbarHeight: 50,
                  flexibleSpace: ClipRect(
                    child: BackdropFilter(
                      filter: _isScrolled 
                          ? ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10) 
                          : ui.ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                      child: Container(
                        color: Colors.transparent,
                        alignment: Alignment.center,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 500),
                          opacity: _isScrolled ? 1.0 : 0.0,
                          child: Text(
                            _greeting,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 100), // Bottom padding
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMainHeader(),
                        _buildDynamicIsland(),
                        _buildSOSButton(),
                        _buildCareTeamRail(),
                        _buildBentoGrid(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainHeader() {
    final now = DateTime.now();
    // Format: FRIDAY, DECEMBER 20
    final dateStr = "${_getDayName(now.weekday)}, ${_getMonthName(now.month)} ${now.day}";

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateStr.toUpperCase(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _greeting,
                style: const TextStyle(
                  fontSize: 34,
                  fontFamily: 'Serif', // Uses system serif
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF111827), // gray-900
                  height: 1.1,
                ),
              ),
            ],
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[200]!.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(CupertinoIcons.person_fill, color: Colors.grey, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicIsland() {
    return Center(
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PatientAIChatScreen()),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(top: 8, bottom: 24),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.9),
            borderRadius: BorderRadius.circular(100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pulsing Dot
              FadeTransition(
                opacity: _pulseAnimation,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.greenAccent[400],
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.greenAccent[400]!.withOpacity(0.5),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Guardian Angel',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(CupertinoIcons.sparkles, color: Color(0xFFD8B4FE), size: 12), // purple-300
              const SizedBox(width: 4),
              Icon(CupertinoIcons.chevron_right, color: Colors.white.withOpacity(0.5), size: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSOSButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const PatientSOSScreen()),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 32),
          decoration: BoxDecoration(
            color: _isSOSOpen ? const Color(0xFFDC2626) : Colors.white, // red-600
            borderRadius: BorderRadius.circular(16),
            border: _isSOSOpen ? null : Border.all(color: const Color(0xFFFEE2E2).withOpacity(0.5)), // red-100
            boxShadow: _isSOSOpen 
                ? [BoxShadow(color: const Color(0xFFDC2626).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))]
                : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1))],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _isSOSOpen ? Colors.white : const Color(0xFFFEF2F2), // red-50
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.exclamationmark_triangle_fill,
                  color: _isSOSOpen ? const Color(0xFFDC2626) : const Color(0xFFEF4444), // red-500
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Emergency SOS',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _isSOSOpen ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  Text(
                    'Tap for immediate help',
                    style: TextStyle(
                      fontSize: 13,
                      color: _isSOSOpen ? const Color(0xFFFEE2E2) : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCareTeamRail() {
    final careTeam = INITIAL_SESSIONS.where((s) => s.type == ViewType.CAREGIVER || s.type == ViewType.DOCTOR).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Care Team',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => CareTeamDirectoryScreen(sessions: INITIAL_SESSIONS),
                    ),
                  );
                },
                child: const Text(
                  'See All',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2563EB), // blue-600
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 110, // Height for avatar + name
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: careTeam.length + 1, // +1 for Add button
            separatorBuilder: (c, i) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              if (index == careTeam.length) {
                return _buildAddMemberButton();
              }
              return _buildCareTeamMember(careTeam[index]);
            },
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildCareTeamMember(ChatSession session) {
    final isDoctor = session.type == ViewType.DOCTOR;
    
    return GestureDetector(
      onTap: () {
        if (isDoctor) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => DoctorChatScreen(session: session),
            ),
          );
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => CaregiverChatScreen(session: session),
            ),
          );
        }
      },
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: isDoctor ? const Color(0xFFEFF6FF) : const Color(0xFFF3F4F6), // blue-50 : gray-100
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDoctor ? const Color(0xFFDBEAFE) : Colors.white, // blue-100 : white
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: isDoctor && session.imageUrl != null
                    ? ClipOval(
                        child: Image.network(
                          session.imageUrl!,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Text(session.name[0], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                        ),
                      )
                    : Text(
                        session.name[0],
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDoctor ? const Color(0xFF2563EB) : const Color(0xFF6B7280), // blue-600 : gray-500
                        ),
                      ),
              ),
              if (session.isOnline)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.greenAccent.withOpacity(0.3), width: 3),
                    ),
                  ),
                ),
              if (session.unreadCount > 0)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6), // blue-500
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF2F2F7), width: 2),
                    ),
                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                    alignment: Alignment.center,
                    child: Text(
                      '${session.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            session.name.split(' ')[0],
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF4B5563), // gray-600
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddMemberButton() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            opaque: false,
            pageBuilder: (context, _, __) => const AddMemberScreen(),
          ),
        );
      },
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB).withOpacity(0.5), // gray-200/50
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFD1D5DB), // gray-300
                width: 2,
                style: BorderStyle.solid,
              ),
            ),
            alignment: Alignment.center,
            child: const Text(
              '+',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w300,
                color: Color(0xFF9CA3AF), // gray-400
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF9CA3AF), // gray-400
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBentoGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'Wellness & Community',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(child: _buildMedicationCard()),
              const SizedBox(width: 16),
              Expanded(child: _buildPeaceCard()),
            ],
          ),
          const SizedBox(height: 16),
          _buildCommunityCard(),
        ],
      ),
    );
  }

  Widget _buildMedicationCard() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MedicationScreen(
              session: ChatSession(
                id: 'sys-1',
                type: ViewType.SYSTEM,
                name: 'Medication',
                subtitle: 'On track',
              ),
            ),
          ),
        );
      },
      child: Container(
        height: 160, // Aspect square approx
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF9FAFB), // gray-50
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.capsule_fill, size: 16, color: Color(0xFF6B7280)),
                ),
                const Text(
                  'TODAY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF9CA3AF),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const ProgressRing(
              progress: 80,
              color: Color(0xFF10B981), // emerald-500
              icon: CupertinoIcons.checkmark_circle_fill,
              size: 52,
            ),
            const Column(
              children: [
                Text(
                  'Medication',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                    height: 1.1,
                  ),
                ),
                Text(
                  'On track',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF9CA3AF), // gray-400
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeaceCard() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const PeaceOfMindScreen(),
          ),
        );
      },
      child: Container(
        height: 160,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF0FDFA), // teal-50
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.eco, size: 16, color: Color(0xFF0D9488)), // teal-600
                ),
                const Text(
                  'MIND',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0x990D9488), // teal-600/60
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const ProgressRing(
              progress: 45,
              color: Color(0xFF0D9488), // teal-600
              icon: CupertinoIcons.bolt_fill,
              size: 52,
            ),
            const Column(
              children: [
                Text(
                  'Daily Peace',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                    height: 1.1,
                  ),
                ),
                Text(
                  '2 mins left',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityCard() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const CommunityDiscoveryScreen(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED), // orange-50
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(CupertinoIcons.group_solid, color: Color(0xFFEA580C), size: 24), // orange-600
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Community Groups',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '3 active discussions',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF9CA3AF), // gray-400
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Icon(CupertinoIcons.chevron_right, color: Color(0xFFD1D5DB), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarCircle(double left, Color color) {
    return Positioned(
      left: left,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1),
        ),
      ),
    );
  }

  String _getDayName(int weekday) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekday - 1];
  }

  String _getMonthName(int month) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return months[month - 1];
  }
}
