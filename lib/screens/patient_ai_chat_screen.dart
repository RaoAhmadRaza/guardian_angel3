import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'patient_ai_chat/patient_ai_chat_state.dart';
import 'patient_ai_chat/patient_ai_chat_data_provider.dart';

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

class PatientAIChatScreen extends StatefulWidget {
  const PatientAIChatScreen({super.key});

  @override
  State<PatientAIChatScreen> createState() => _PatientAIChatScreenState();
}

class _PatientAIChatScreenState extends State<PatientAIChatScreen> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  
  // Production state management
  PatientAIChatState? _state;
  final PatientAIChatDataProvider _dataProvider = PatientAIChatDataProvider();
  
  // Local UI state (not persisted)
  bool _isMenuOpen = false;
  
  // Animation Controllers
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Load state from local storage
    _loadChatState();
  }
  
  /// Load chat state from local storage
  /// First-time users get empty state with welcome message only
  Future<void> _loadChatState() async {
    try {
      final state = await _dataProvider.loadInitialState();
      if (mounted) {
        setState(() {
          _state = state;
        });
      }
    } catch (e) {
      // On error, show empty state
      if (mounted) {
        setState(() {
          _state = PatientAIChatState.initial();
        });
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _handleSend([String? message]) {
    if (_state == null) return;
    final text = message ?? _textController.text;
    if (text.trim().isEmpty) return;
    
    final newMessage = ChatMessage(
      id: DateTime.now().toString(),
      text: text,
      sender: 'user',
      timestamp: DateTime.now(),
      status: 'sending',
    );
    
    setState(() {
      _state = _state!.copyWith(
        messages: [..._state!.messages, newMessage],
        isAITyping: true,
      );
      _textController.clear();
    });
    
    _scrollToBottom();

    // TODO: Replace with real AI service call
    // For now, just mark as not typing after delay (no fake response)
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _state = _state!.copyWith(isAITyping: false);
        });
      }
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = _ChatColors.of(context);
    return Scaffold(
      backgroundColor: colors.bgPrimary,
      body: Stack(
        children: [
          // 1. Ambient Glow Background
          Positioned.fill(
            child: OverflowBox(
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              child: Stack(
                children: [
                  // Indigo Blob
                  Positioned(
                    top: -100,
                    left: -100,
                    width: 400,
                    height: 400,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.indigo.withOpacity(colors.isDark ? 0.1 : 0.2),
                            blurRadius: 80,
                            spreadRadius: 20,
                          ),
                        ],
                      ),
                    ).animate(onPlay: (c) => c.repeat(reverse: true))
                     .scale(duration: 4.seconds, begin: const Offset(1, 1), end: const Offset(1.2, 1.2)),
                  ),
                  // Pink Blob
                  Positioned(
                    top: 50,
                    right: -50,
                    width: 300,
                    height: 300,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.pink.withOpacity(colors.isDark ? 0.1 : 0.2),
                            blurRadius: 80,
                            spreadRadius: 20,
                          ),
                        ],
                      ),
                    ).animate(onPlay: (c) => c.repeat(reverse: true))
                     .scale(delay: 2.seconds, duration: 5.seconds, begin: const Offset(1, 1), end: const Offset(1.3, 1.3)),
                  ),
                  // Purple Blob
                  Positioned(
                    bottom: -50,
                    left: 50,
                    width: 350,
                    height: 350,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purple.withOpacity(colors.isDark ? 0.1 : 0.2),
                            blurRadius: 80,
                            spreadRadius: 20,
                          ),
                        ],
                      ),
                    ).animate(onPlay: (c) => c.repeat(reverse: true))
                     .scale(delay: 4.seconds, duration: 6.seconds, begin: const Offset(1, 1), end: const Offset(1.2, 1.2)),
                  ),
                  // Iridescent Overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomLeft,
                        end: Alignment.topRight,
                        colors: [
                          colors.bgPrimary.withOpacity(0),
                          colors.bgPrimary.withOpacity(0),
                          colors.bgPrimary.withOpacity(0.4),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Siri-style Thinking Glow (when typing)
          if (_state?.isAITyping == true)
            Positioned.fill(
              child: IgnorePointer(
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: colors.statusInfo.withOpacity(0.2),
                            blurRadius: 80,
                            spreadRadius: 20,
                            offset: Offset.zero,
                          )
                        ],
                      ),
                    ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(duration: 1.seconds),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.5,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              colors.statusInfo.withOpacity(0.1),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          Column(
            children: [
              // 3. Header
              _buildHeader(),
              
              // 4. Messages Area
              Expanded(
                child: Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(top: 100, bottom: 160, left: 16, right: 16),
                      itemCount: _state?.messages.length ?? 0,
                      itemBuilder: (context, index) {
                        final messages = _state!.messages;
                        final msg = messages[index];
                        final isMe = msg.sender == 'user';
                        final isLast = index == messages.length - 1;
                        return _buildMessageBubble(msg, isMe, isLast);
                      },
                    ),
                    
                    // Refine Status Pill (The Floater)
                    Positioned(
                      top: 16,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(100),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(12, 6, 16, 6),
                              decoration: BoxDecoration(
                                color: colors.surfaceGlass,
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(color: colors.borderSubtle),
                                boxShadow: colors.shadowCard,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Status indicator dot - gray when idle, green when monitoring
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: (_state?.isMonitoringActive == true) ? colors.statusSuccess : colors.statusNeutral,
                                      shape: BoxShape.circle,
                                      boxShadow: (_state?.isMonitoringActive == true) ? [
                                        BoxShadow(
                                          color: colors.statusSuccess.withOpacity(0.6),
                                          blurRadius: 8,
                                        ),
                                      ] : null,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    height: 12,
                                    width: 1,
                                    color: colors.borderSubtle,
                                  ),
                                  const SizedBox(width: 10),
                                  Icon(CupertinoIcons.heart_fill, size: 14, color: (_state?.hasHealthDevice == true) ? colors.statusError : colors.statusNeutral),
                                  const SizedBox(width: 6),
                                  // State-driven BPM display
                                  Text(
                                    _state?.heartRateDisplay ?? '-- BPM',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: colors.textPrimary,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    height: 12,
                                    width: 1,
                                    color: colors.borderSubtle,
                                  ),
                                  const SizedBox(width: 10),
                                  // State-driven monitoring status
                                  Text(
                                    _state?.monitoringStatusText ?? 'Idle',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ).animate().slideY(begin: -0.5, end: 0, duration: 500.ms, curve: Curves.easeOutBack),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 5. Smart Stack Widgets (if few messages)
          if ((_state?.messages.length ?? 0) <= 1 && _state?.isAITyping != true)
            Positioned(
              bottom: 140,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 112, // h-28 = 7rem = 112px
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    // Call Caregiver Widget - ONLY shown if caregiver exists
                    if (_state?.hasCaregiver == true)
                      _buildSmartWidget(
                        width: MediaQuery.of(context).size.width * 0.85,
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: colors.bgSecondary,
                                shape: BoxShape.circle,
                                boxShadow: colors.shadowCard,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _state!.caregiver!.initial,
                                style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Call ${_state!.caregiver!.name}",
                                    style: GoogleFonts.inter(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: colors.textPrimary,
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _state!.caregiver!.subtitle,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: colors.textSecondary,
                                      height: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _state!.caregiver!.isOnline ? colors.statusSuccess : colors.statusNeutral,
                                shape: BoxShape.circle,
                                boxShadow: _state!.caregiver!.isOnline ? [
                                  BoxShadow(
                                    color: colors.statusSuccess.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ] : null,
                              ),
                              child: Icon(Icons.phone, color: colors.textInverse, size: 20),
                            ),
                          ],
                        ),
                        onTap: () => _handleSend("Call ${_state!.caregiver!.name}"),
                      ),
                    if (_state?.hasCaregiver == true)
                      const SizedBox(width: 16),
                    // Mood Widget - Always visible
                    _buildSmartWidget(
                      width: MediaQuery.of(context).size.width * 0.45,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: colors.statusInfo.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(CupertinoIcons.cloud_rain_fill, color: colors.statusInfo, size: 20),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Log Mood",
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: colors.textPrimary,
                                  height: 1.1,
                                ),
                              ),
                              Text(
                                "How are you?",
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: colors.textSecondary,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      onTap: () => _handleSend("I want to log my mood"),
                    ),
                    const SizedBox(width: 16),
                    // Relax Widget - Always visible
                    _buildSmartWidget(
                      width: MediaQuery.of(context).size.width * 0.45,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(CupertinoIcons.wind, color: Colors.purple.shade400, size: 20),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Relax",
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: colors.textPrimary,
                                  height: 1.1,
                                ),
                              ),
                              Text(
                                "Breathing",
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: colors.textSecondary,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      onTap: () => _handleSend("Help me relax"),
                    ),
                  ],
                ),
              ),
            ),

          // 6. Input Bar (Floating Capsule)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildInputBar(),
          ),

          // 7. Attachment Menu Overlay
          if (_isMenuOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _isMenuOpen = false),
                child: Container(
                  color: Colors.white.withOpacity(0.8),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Stack(
                      children: [
                        Positioned(
                          bottom: 140,
                          left: 24,
                          right: 24,
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildMenuItem(CupertinoIcons.camera_fill, 'Camera', colors.bgSecondary, colors.textPrimary, 0),
                                  _buildMenuItem(CupertinoIcons.photo_fill, 'Photos', colors.bgSecondary, colors.textPrimary, 50),
                                  _buildMenuItem(CupertinoIcons.heart_fill, 'Vitals', colors.statusError.withOpacity(0.1), colors.statusError, 100),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildMenuItem(CupertinoIcons.location_solid, 'Location', colors.statusSuccess.withOpacity(0.1), colors.statusSuccess, 150),
                                  _buildMenuItem(CupertinoIcons.doc_text_fill, 'Report', colors.statusInfo.withOpacity(0.1), colors.statusInfo, 200),
                                  const SizedBox(width: 80), // Spacer for grid alignment
                                ],
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          bottom: 40,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: GestureDetector(
                              onTap: () => setState(() => _isMenuOpen = false),
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.close, color: Colors.grey.shade600, size: 24),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ).animate().fade(duration: 300.ms),
            ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String label, Color bgColor, Color iconColor, int delay) {
    final colors = _ChatColors.of(context);
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            boxShadow: colors.shadowCard,
          ),
          child: Icon(icon, color: iconColor, size: 32),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.textSecondary,
          ),
        ),
      ],
    ).animate().slideY(begin: 0.5, end: 0, duration: 400.ms, delay: Duration(milliseconds: delay), curve: Curves.easeOutBack).fade(duration: 400.ms, delay: Duration(milliseconds: delay));
  }

  Widget _buildHeader() {
    final colors = _ChatColors.of(context);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 12,
            bottom: 12,
            left: 16,
            right: 16,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceGlass,
            border: Border(bottom: BorderSide(color: colors.borderSubtle)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back Button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Row(
                  children: [
                    Icon(Icons.arrow_back_ios_new, size: 24, color: colors.iconPrimary),
                    const SizedBox(width: 4),
                    Text(
                      "Chats",
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              // Center Avatar & Title
              Row(
                children: [
                  // Halo Avatar
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: colors.statusInfo.withOpacity(0.1),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colors.statusInfo.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      // Halo Pulse
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.statusInfo.withOpacity(0.3), width: 2),
                        ),
                      ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1)).fade(begin: 0.6, end: 0.3),
                      // Outer Pulse
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.purple.withOpacity(0.3), width: 1),
                        ),
                      ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1.2, 1.2), end: const Offset(1.4, 1.4)).fade(begin: 0.3, end: 0.0),
                      
                      Icon(CupertinoIcons.cloud_sun_fill, size: 20, color: colors.statusInfo),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Guardian Angel",
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),

              // Right Action
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.bgSecondary.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.more_horiz, color: colors.iconSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isMe, bool isLast) {
    final colors = _ChatColors.of(context);
    return Padding(
      padding: EdgeInsets.only(top: isMe ? 8 : 24, bottom: isLast ? 24 : 0),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            // AI Avatar
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8, bottom: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                  colors: [Colors.indigo.shade400, Colors.purple.shade400],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.shade200,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(CupertinoIcons.cloud_sun_fill, size: 16, color: Colors.white),
            ),
          ],

          Flexible(
            child: Container(
              decoration: BoxDecoration(
                color: isMe 
                    ? colors.statusInfo // Blue-500
                    : colors.surfaceGlass,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(26),
                  topRight: const Radius.circular(26),
                  bottomLeft: Radius.circular(isMe ? 26 : 2),
                  bottomRight: Radius.circular(isMe ? 2 : 26),
                ),
                boxShadow: [
                  if (isMe)
                    BoxShadow(
                      color: colors.statusInfo.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  else
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                ],
                border: isMe ? null : Border.all(color: colors.borderSubtle),
              ),
              child: ClipRRect( // For backdrop blur on AI messages
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(26),
                  topRight: const Radius.circular(26),
                  bottomLeft: Radius.circular(isMe ? 26 : 2),
                  bottomRight: Radius.circular(isMe ? 2 : 26),
                ),
                child: BackdropFilter(
                  filter: isMe ? ImageFilter.blur() : ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.text,
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            height: 1.4,
                            color: isMe ? colors.textInverse : colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              _formatTime(msg.timestamp),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: isMe ? colors.textInverse.withOpacity(0.7) : colors.textTertiary,
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              Icon(
                                msg.status == 'read' ? Icons.done_all : Icons.check,
                                size: 12,
                                color: colors.textInverse.withOpacity(0.7),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ).animate().fade(duration: 300.ms).slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
    );
  }

  Widget _buildSmartWidget({required Widget child, required double width, required VoidCallback onTap}) {
    final colors = _ChatColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: width,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surfaceGlass,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: colors.borderSubtle),
              boxShadow: colors.shadowCard,
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    final colors = _ChatColors.of(context);
    return Container(
      padding: EdgeInsets.only(
        left: 20, 
        right: 20, 
        bottom: MediaQuery.of(context).padding.bottom + 20,
        top: 20
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end, // Align items to the bottom
        children: [
          // Accessory Button
          GestureDetector(
            onTap: () => setState(() => _isMenuOpen = true),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors.bgSecondary.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Center(
                    child: Icon(Icons.add, color: colors.iconPrimary, size: 24),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Unified Input Capsule
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.surfaceGlass,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: colors.borderSubtle),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 40,
                        offset: const Offset(0, 8),
                      ),
                      if (_state?.isRecording == true)
                        BoxShadow(
                          color: Colors.purple.withOpacity(0.25),
                          blurRadius: 50,
                          offset: const Offset(0, 12),
                        ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center, // Center items vertically within the capsule
                    children: [
                      // Mode Toggle
                      GestureDetector(
                        onTap: () {
                          if (_state == null) return;
                          setState(() {
                            _state = _state!.copyWith(
                              inputMode: _state!.inputMode == InputMode.voice 
                                  ? InputMode.keyboard 
                                  : InputMode.voice,
                            );
                          });
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.transparent,
                          ),
                          child: Icon(
                            _state?.inputMode == InputMode.voice ? Icons.keyboard : Icons.mic,
                            color: colors.iconSecondary,
                            size: 24,
                          ),
                        ),
                      ),
                      
                      // Center Content
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: _state?.inputMode == InputMode.voice
                              ? GestureDetector(
                                  onTap: () {
                                    if (_state == null) return;
                                    setState(() {
                                      _state = _state!.copyWith(
                                        isRecording: !_state!.isRecording,
                                      );
                                    });
                                  },
                                  // Only show animated waveform when ACTUALLY recording
                                  child: _state?.isRecording == true
                                      ? Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: List.generate(5, (index) {
                                            return Container(
                                              width: 6,
                                              margin: const EdgeInsets.symmetric(horizontal: 2),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.bottomCenter,
                                                  end: Alignment.topCenter,
                                                  colors: [Colors.indigo, Colors.purple, Colors.pink],
                                                ),
                                                borderRadius: BorderRadius.circular(100),
                                              ),
                                            ).animate(onPlay: (c) => c.repeat(reverse: true))
                                             .scaleY(
                                               begin: 0.4, 
                                               end: 1.5, 
                                               duration: Duration(milliseconds: 300 + (index * 100)),
                                               curve: Curves.easeInOut,
                                             );
                                          }),
                                        )
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            // Show "Thinking..." only when AI is actually processing
                                            if (_state?.isAITyping == true)
                                              Text(
                                                "Thinking...",
                                                style: GoogleFonts.inter(
                                                  color: Colors.indigo.shade500,
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 15,
                                                ),
                                              ).animate(onPlay: (c) => c.repeat(reverse: true)).fade()
                                            else
                                              Text(
                                                "Tap to speak",
                                                style: GoogleFonts.inter(
                                                  color: colors.textTertiary,
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            const SizedBox(width: 8),
                                            // Static Waveform - only decorative, no animation
                                            Row(
                                              children: [3, 6, 4, 8, 5, 10, 4, 7, 3, 5, 8, 4, 6, 3, 7, 4, 8, 5, 3].map((h) {
                                                return Container(
                                                  width: 2,
                                                  height: h.toDouble(),
                                                  margin: const EdgeInsets.symmetric(horizontal: 1),
                                                  decoration: BoxDecoration(
                                                    color: (_state?.isAITyping == true) ? Colors.indigo.shade400 : colors.textTertiary,
                                                    borderRadius: BorderRadius.circular(100),
                                                  ),
                                                );
                                              }).toList(),
                                            ).animate().fade(begin: 0.4, end: 0.4),
                                          ],
                                        ),
                                )
                              : TextField(
                                  controller: _textController,
                                  decoration: InputDecoration(
                                    hintText: "Type a message...",
                                    hintStyle: GoogleFonts.inter(
                                      color: colors.textTertiary,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 17,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                  style: GoogleFonts.inter(
                                    color: colors.textPrimary,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  onChanged: (val) => setState(() {}),
                                  onSubmitted: (_) => _handleSend(),
                                ),
                        ),
                      ),

                      // Right Action
                      GestureDetector(
                        onTap: (_state?.inputMode == InputMode.keyboard && _textController.text.isNotEmpty) 
                            ? _handleSend 
                            : () {
                                if (_state == null) return;
                                setState(() {
                                  _state = _state!.copyWith(isRecording: !_state!.isRecording);
                                });
                              },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (_state?.inputMode == InputMode.keyboard && _textController.text.isNotEmpty)
                                ? colors.statusInfo
                                : (_state?.isRecording == true)
                                    ? colors.statusError
                                    : colors.bgSecondary.withOpacity(0.5),
                            boxShadow: [
                              if (_state?.inputMode == InputMode.keyboard && _textController.text.isNotEmpty)
                                BoxShadow(
                                  color: colors.statusInfo.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                            ],
                          ),
                          child: Center(
                            child: (_state?.inputMode == InputMode.keyboard && _textController.text.isNotEmpty)
                                ? Icon(Icons.arrow_upward, color: colors.textInverse, size: 20)
                                : (_state?.isRecording == true)
                                    ? Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: colors.textInverse,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      )
                                    : Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: colors.statusError,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'pm' : 'am';
    return "$hour:$minute$period";
  }
}

// ChatMessage class moved to patient_ai_chat/patient_ai_chat_state.dart
