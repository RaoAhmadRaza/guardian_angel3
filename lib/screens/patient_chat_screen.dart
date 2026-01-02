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
import 'patient_chat/patient_chat_state.dart';
import 'patient_chat/patient_chat_data_provider.dart';

// --- THEME COLORS ---

class _ChatColors {
  final bool isDark;

  _ChatColors(this.isDark);

  static _ChatColors of(BuildContext context) {
    return _ChatColors(Theme.of(context).brightness == Brightness.dark);
  }

  // 1. Foundation
  Color get bgPrimary => isDark ? const Color(0xFF0F0F0F) : const Color(0xFFFDFDFD);
  Color get bgSecondary => isDark ? const Color(0xFFFFFFFF).withOpacity(0.05) : const Color(0xFFF5F5F7);
  Color get surfacePrimary => isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);
  Color get surfaceSecondary => isDark ? const Color(0xFF2C2C2E) : const Color(0xFFFFFFFF);
  Color get surfaceGlass => isDark ? const Color(0xFFFFFFFF).withOpacity(0.10) : Colors.white.withOpacity(0.5); // Fallback for light
  Color get borderSubtle => isDark ? const Color(0xFFFFFFFF).withOpacity(0.10) : const Color(0xFFFFFFFF).withOpacity(0.30);
  List<BoxShadow> get shadowCard => isDark 
      ? [BoxShadow(color: const Color(0xFF000000).withOpacity(0.40), blurRadius: 16, offset: const Offset(0, 6))]
      : [BoxShadow(color: const Color(0xFF475569).withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 6))];

  // 2. Containers
  Color get containerDefault => isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);
  Color get containerHighlight => isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF5F5F7);
  Color get containerSlot => isDark ? const Color(0xFFFFFFFF).withOpacity(0.05) : const Color(0xFFF5F5F7);
  Color get containerSlotAlt => isDark ? const Color(0xFFFFFFFF).withOpacity(0.10) : const Color(0xFFE0E0E2);
  Color get overlayModal => isDark ? const Color(0xFF1A1A1A).withOpacity(0.80) : const Color(0xFFFFFFFF).withOpacity(0.80);

  // 3. Typography
  Color get textPrimary => isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0F172A);
  Color get textSecondary => isDark ? const Color(0xFFFFFFFF).withOpacity(0.70) : const Color(0xFF475569);
  Color get textTertiary => isDark ? const Color(0xFFFFFFFF).withOpacity(0.50) : const Color(0xFF64748B);
  Color get textInverse => isDark ? const Color(0xFF0F172A) : const Color(0xFFFFFFFF);
  Color get textLink => isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);

  // 4. Iconography
  Color get iconPrimary => isDark ? const Color(0xFFFFFFFF).withOpacity(0.70) : const Color(0xFF475569);
  Color get iconSecondary => isDark ? const Color(0xFFFFFFFF).withOpacity(0.40) : const Color(0xFF94A3B8);
  Color get iconBgPrimary => isDark ? const Color(0xFFFFFFFF).withOpacity(0.10) : const Color(0xFFF5F5F7);
  Color get iconBgActive => isDark ? const Color(0xFFFFFFFF).withOpacity(0.10) : const Color(0xFFFFFFFF);

  // 5. Interactive
  Color get actionPrimaryBg => isDark ? const Color(0xFF2C2C2E) : const Color(0xFFFFFFFF);
  Color get actionPrimaryFg => isDark ? const Color(0xFFFFFFFF).withOpacity(0.80) : const Color(0xFF475569);
  Color get actionHover => isDark ? const Color(0xFFFFFFFF).withOpacity(0.05) : const Color(0xFFF8FAFC);
  Color get actionPressed => isDark ? const Color(0xFF000000).withOpacity(0.20) : const Color(0xFFE2E8F0);
  Color get actionDisabledBg => isDark ? const Color(0xFFFFFFFF).withOpacity(0.05) : const Color(0xFFF1F5F9);
  Color get actionDisabledFg => isDark ? const Color(0xFFFFFFFF).withOpacity(0.30) : const Color(0xFF94A3B8);

  // 6. Status
  Color get statusSuccess => isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
  Color get statusWarning => isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
  Color get statusError => isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
  Color get statusInfo => isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
  Color get statusNeutral => isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

  // 7. Input
  Color get inputBg => isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFEFEFE);
  Color get inputBorder => isDark ? const Color(0xFF3C4043) : const Color(0xFFE2E8F0);
  Color get inputBorderFocus => isDark ? const Color(0xFFF8F9FA) : const Color(0xFF3B82F6);
  Color get controlActive => isDark ? const Color(0xFFF5F5F5) : const Color(0xFF2563EB);
  Color get controlTrack => isDark ? const Color(0xFF3C4043) : const Color(0xFFE2E8F0);
}

// --- TYPES (NO MOCK DATA) ---

enum ViewType { AI_COMPANION, CAREGIVER, DOCTOR, SYSTEM, PEACE_OF_MIND, COMMUNITY }

/// Chat session model for care team members and system features
/// This class is kept but NO fake instances are created
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

// INITIAL_SESSIONS removed - no fake data
// First-time users see empty state with helpful guidance

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
    final colors = _ChatColors.of(context);
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
              color: colors.controlTrack, // text-gray-400 with opacity
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
  
  // Production state management
  PatientChatState? _state;
  bool _isLoading = true;
  final PatientChatDataProvider _dataProvider = PatientChatDataProvider();

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
    
    // Load patient data
    _loadPatientChatData();
  }
  
  /// Load patient data from local storage
  /// First-time users get empty state with helpful guidance
  Future<void> _loadPatientChatData() async {
    try {
      // TODO: Get patient name from onboarding/profile storage
      const patientName = 'there'; // Placeholder - will be loaded from storage
      final state = await _dataProvider.loadInitialState(patientName: patientName);
      if (mounted) {
        setState(() {
          _state = state;
          _isLoading = false;
        });
      }
    } catch (e) {
      // On error, show empty state
      if (mounted) {
        setState(() {
          _state = PatientChatState.initial('there');
          _isLoading = false;
        });
      }
    }
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
    final colors = _ChatColors.of(context);
    // Background color transition
    return Scaffold(
      backgroundColor: _isSOSOpen ? colors.bgSecondary : colors.bgPrimary,
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
                      ? colors.bgPrimary.withOpacity(0.8) 
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
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
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
    final colors = _ChatColors.of(context);
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
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: colors.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _greeting,
                style: TextStyle(
                  fontSize: 34,
                  fontFamily: 'Serif', // Uses system serif
                  fontWeight: FontWeight.w400,
                  color: colors.textPrimary,
                  height: 1.1,
                ),
              ),
            ],
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.bgSecondary,
              shape: BoxShape.circle,
            ),
            child: Icon(CupertinoIcons.person_fill, color: colors.iconPrimary, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicIsland() {
    final colors = _ChatColors.of(context);
    final islandColor = colors.isDark ? colors.surfaceSecondary : colors.textPrimary;
    final contentColor = colors.isDark ? colors.textPrimary : colors.textInverse;

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
            color: islandColor,
            borderRadius: BorderRadius.circular(100),
            boxShadow: colors.shadowCard,
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
                    color: colors.statusSuccess,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colors.statusSuccess.withOpacity(0.5),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Guardian Angel',
                style: TextStyle(
                  color: contentColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(CupertinoIcons.sparkles, color: Color(0xFFD8B4FE), size: 12), // purple-300
              const SizedBox(width: 4),
              Icon(CupertinoIcons.chevron_right, color: contentColor.withOpacity(0.5), size: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSOSButton() {
    final colors = _ChatColors.of(context);

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
            color: _isSOSOpen ? colors.statusError : colors.surfacePrimary,
            borderRadius: BorderRadius.circular(16),
            border: _isSOSOpen ? null : Border.all(color: colors.statusError.withOpacity(0.2)),
            boxShadow: _isSOSOpen 
                ? [BoxShadow(color: colors.statusError.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))]
                : colors.shadowCard,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _isSOSOpen ? colors.surfacePrimary : colors.statusError.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.exclamationmark_triangle_fill,
                  color: _isSOSOpen ? colors.statusError : colors.statusError,
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
                      color: _isSOSOpen ? colors.textInverse : colors.textPrimary,
                    ),
                  ),
                  Text(
                    'Tap for immediate help',
                    style: TextStyle(
                      fontSize: 13,
                      color: _isSOSOpen ? colors.textInverse.withOpacity(0.8) : colors.textSecondary,
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
    final colors = _ChatColors.of(context);
    // Use state-driven care team instead of INITIAL_SESSIONS
    final List<ChatSession> careTeam = _state?.careTeam ?? [];
    final hasCareTeam = careTeam.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Care Team',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              // Hide "See All" when no care team members
              if (hasCareTeam)
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => CareTeamDirectoryScreen(sessions: careTeam),
                      ),
                    );
                  },
                  child: Text(
                    'See All',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.textLink,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Show empty state message or care team list
        if (!hasCareTeam)
          _buildEmptyCareTeamState()
        else
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
  
  /// Empty state for care team section
  /// Shows guidance message and add button for first-time users
  Widget _buildEmptyCareTeamState() {
    final colors = _ChatColors.of(context);
    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Empty state message card
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfacePrimary,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colors.borderSubtle,
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No caregivers or doctors added yet',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add your care team to stay connected',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Add button
          _buildAddMemberButton(),
        ],
      ),
    );
  }

  Widget _buildCareTeamMember(ChatSession session) {
    final colors = _ChatColors.of(context);
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
                  color: isDoctor ? colors.statusInfo.withOpacity(0.1) : colors.bgSecondary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDoctor ? colors.statusInfo.withOpacity(0.2) : colors.surfacePrimary,
                    width: 2,
                  ),
                  boxShadow: colors.shadowCard,
                ),
                alignment: Alignment.center,
                child: isDoctor && session.imageUrl != null
                    ? ClipOval(
                        child: Image.network(
                          session.imageUrl!,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Text(session.name[0], style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colors.statusInfo)),
                        ),
                      )
                    : Text(
                        session.name[0],
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDoctor ? colors.statusInfo : colors.textSecondary,
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
                      border: Border.all(color: colors.statusSuccess.withOpacity(0.3), width: 3),
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
                      color: colors.statusInfo,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.bgPrimary, width: 2),
                    ),
                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                    alignment: Alignment.center,
                    child: Text(
                      '${session.unreadCount}',
                      style: TextStyle(
                        color: colors.textInverse,
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
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddMemberButton() {
    final colors = _ChatColors.of(context);
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
              color: colors.containerSlotAlt,
              shape: BoxShape.circle,
              border: Border.all(
                color: colors.borderSubtle,
                width: 2,
                style: BorderStyle.solid,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '+',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w300,
                color: colors.textTertiary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBentoGrid() {
    final colors = _ChatColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'Wellness & Community',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
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
    final colors = _ChatColors.of(context);
    // Use state-driven medication status
    final medicationStatus = _state?.medicationStatus;
    final progress = medicationStatus?.progressPercent ?? 0;
    final statusText = medicationStatus?.status ?? 'No medications added';
    
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MedicationScreen(
              session: ChatSession(
                id: 'sys-1',
                type: ViewType.SYSTEM,
                name: 'Medication',
                subtitle: statusText,
              ),
            ),
          ),
        );
      },
      child: Container(
        height: 160, // Aspect square approx
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surfacePrimary,
          borderRadius: BorderRadius.circular(24),
          boxShadow: colors.shadowCard,
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
                  decoration: BoxDecoration(
                    color: colors.containerHighlight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(CupertinoIcons.capsule_fill, size: 16, color: colors.textTertiary),
                ),
                Text(
                  'TODAY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: colors.textTertiary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            ProgressRing(
              progress: progress.toDouble(),
              color: colors.statusSuccess,
              icon: CupertinoIcons.checkmark_circle_fill,
              size: 48,
            ),
            Column(
              children: [
                Text(
                  'Medication',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                    height: 1.1,
                  ),
                ),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: colors.textTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeaceCard() {
    final colors = _ChatColors.of(context);
    // Use state-driven peace status
    final peaceStatus = _state?.peaceStatus;
    final progress = peaceStatus?.progressPercent ?? 0;
    final statusText = peaceStatus?.timeRemaining ?? 
        (peaceStatus?.status ?? 'Start your journey');
    
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surfacePrimary,
          borderRadius: BorderRadius.circular(24),
          boxShadow: colors.shadowCard,
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
            ProgressRing(
              progress: progress.toDouble(),
              color: const Color(0xFF0D9488), // teal-600
              icon: CupertinoIcons.bolt_fill,
              size: 48,
            ),
            Column(
              children: [
                Text(
                  'Daily Peace',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                    height: 1.1,
                  ),
                ),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: colors.textTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityCard() {
    final colors = _ChatColors.of(context);
    // Use state-driven community status
    final communityStatus = _state?.communityStatus;
    final statusText = communityStatus?.status ?? 'Join the community';
    
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
          color: colors.surfacePrimary,
          borderRadius: BorderRadius.circular(24),
          boxShadow: colors.shadowCard,
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
                    Text(
                      'Community Groups',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Icon(CupertinoIcons.chevron_right, color: colors.iconSecondary, size: 20),
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
