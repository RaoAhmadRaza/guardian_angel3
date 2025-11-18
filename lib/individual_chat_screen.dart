import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'theme/colors.dart' show AppColors; // access refreshed gradients & status colors

class IndividualChatScreen extends StatefulWidget {
  final String name;
  final String avatarUrl;
  final String mood;
  final String vitals;
  final bool crisis;
  final String? statusText;
  final String? category; // to enable therapist quick connect
  final int? lastHeartbeat; // optional heartbeat for snapshot

  const IndividualChatScreen({
    super.key,
    required this.name,
    required this.avatarUrl,
    required this.mood,
    required this.vitals,
    required this.crisis,
    this.statusText,
    this.category,
    this.lastHeartbeat,
  });

  @override
  State<IndividualChatScreen> createState() => _IndividualChatScreenState();
}

class Message {
  final String text;
  final bool isMe;
  final DateTime at;
  final bool showTime;
  // Wellness layer additions
  final bool isAutoSuggestion; // true for generated check-in / quote / prompt
  final Map<String, dynamic>? meta; // optional metadata (e.g., mood snapshot, quote category)
  Message({
    required this.text,
    required this.isMe,
    required this.at,
    this.showTime = false,
    this.isAutoSuggestion = false,
    this.meta,
  });
}

class _IndividualChatScreenState extends State<IndividualChatScreen> {
  late List<Message> _messages;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  // Voice & Accessibility
  late final stt.SpeechToText _speech;
  bool _isListening = false;
  late final FlutterTts _tts;
  bool _voiceResponseEnabled = false;
  bool _largeFonts = false;
  // Input interactions
  bool _sendPressed = false;
  bool _sendRipple = false;
  bool _pressMood = false;
  bool _pressMic = false;
  bool _pressSOS = false;

  @override
  void initState() {
    super.initState();
    // Init voice features
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
    _initTts();
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    _messages = [
      Message(text: 'Are you coming?', isMe: false, at: DateTime(yesterday.year, yesterday.month, yesterday.day, 18, 30), showTime: false),
      Message(text: 'Yes.', isMe: true, at: DateTime(yesterday.year, yesterday.month, yesterday.day, 19, 05), showTime: true),
      Message(text: 'Hi! Are you coming to clg?', isMe: false, at: DateTime(now.year, now.month, now.day, 11, 20), showTime: false),
      Message(text: 'Yes.', isMe: true, at: DateTime(now.year, now.month, now.day, 11, 40), showTime: false),
      Message(text: 'Okay.', isMe: false, at: DateTime(now.year, now.month, now.day, 11, 50), showTime: false),
      Message(text: "Let's meet in clg.", isMe: true, at: DateTime(now.year, now.month, now.day, 11, 56), showTime: true),
      Message(text: 'Have a nice day!', isMe: true, at: DateTime(now.year, now.month, now.day, 12, 10), showTime: false),
      Message(text: 'Wish you the same!', isMe: false, at: DateTime(now.year, now.month, now.day, 12, 42), showTime: true),
      Message(text: 'Hi!', isMe: false, at: DateTime(now.year, now.month, now.day, 12, 50), showTime: false),
      Message(text: "Hey, what's up?", isMe: false, at: DateTime(now.year, now.month, now.day, 12, 54), showTime: false),
      // Seed an inspirational quote sample
      Message(text: '“Small steps matter. Take a breath.”', isMe: false, at: now.subtract(const Duration(minutes: 5)), isAutoSuggestion: true, meta: {'type': 'quote', 'category': 'breathing'}),
    ];
    // Evaluate initial wellness suggestion
    _maybeInsertWellnessCheck(now);
  }

  @override
  void dispose() {
    _textController.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFFDFDFD),
      body: Column(
        children: [
          // Gradient header like screenshot
          Container(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8, left: 12, right: 12, bottom: 12),
            decoration: BoxDecoration(
              gradient: AppColors.guardianAngelSkyGradient,
            ),
            child: Row(
              children: [
                CupertinoButton(
                  padding: const EdgeInsets.all(6),
                  minSize: 0,
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Icon(CupertinoIcons.back, color: Color(0xFF0F172A)),
                ),
                const SizedBox(width: 6),
                Hero(
                  tag: 'avatar_${widget.name}',
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.getStatusShadowColor(
                            vitals: widget.vitals,
                            mood: widget.mood,
                            crisis: widget.crisis,
                          ).withOpacity(0.38),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.network(
                        widget.avatarUrl,
                        width: 34,
                        height: 34,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Text(
                            widget.name[0].toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF475569)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              widget.name,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(CupertinoIcons.sun_max, size: 16, color: Color(0xFF475569)),
                          const SizedBox(width: 6),
                          const Icon(CupertinoIcons.chat_bubble, size: 16, color: Color(0xFF475569)),
                          const SizedBox(width: 6),
                          const Icon(CupertinoIcons.heart, size: 16, color: Color(0xFF475569)),
                          if ((widget.category ?? '').toLowerCase() == 'therapist') ...[
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: _showTherapistQuickConnect,
                              child: const Text('🩺', style: TextStyle(fontSize: 16)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.crisis ? 'Emergency' : 'Active',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.all(6),
                  minSize: 0,
                  onPressed: _showHealthSnapshot,
                  child: const Text('📊', style: TextStyle(fontSize: 18)),
                ),
                // Voice response toggle
                CupertinoButton(
                  padding: const EdgeInsets.all(6),
                  minSize: 0,
                  onPressed: () => setState(() => _voiceResponseEnabled = !_voiceResponseEnabled),
                  child: Icon(
                    _voiceResponseEnabled ? CupertinoIcons.speaker_2_fill : CupertinoIcons.speaker_2,
                    color: const Color(0xFF0F172A),
                    size: 18,
                  ),
                ),
                // Large font toggle
                CupertinoButton(
                  padding: const EdgeInsets.all(6),
                  minSize: 0,
                  onPressed: () => setState(() => _largeFonts = !_largeFonts),
                  child: Icon(
                    CupertinoIcons.textformat_size,
                    color: const Color(0xFF0F172A),
                    size: 18,
                  ),
                ),
              ],
            ),
          ),

          // Rounded chat surface
          Expanded(
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                  ),
                  child: _buildMessageList(context, isDark),
                ),

                // Input bar overlay
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 8 + MediaQuery.of(context).padding.bottom,
                  child: _buildInputBar(isDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(BuildContext context, bool isDark) {
    final baseDaySize = _largeFonts ? 14.0 : 12.0;
    final dayTextStyle = TextStyle(fontSize: baseDaySize, color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF475569));
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 110),
      itemCount: _messages.length + 2, // account for Yesterday/Today headers
      itemBuilder: (context, index) {
        // Insert day headers roughly similar to screenshot
        if (index == 1) {
          return Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Yesterday', style: dayTextStyle)));
        }
        if (index == 3) {
          return Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Today', style: dayTextStyle)));
        }
        // Map index back to message list
        int msgIndex = index;
        if (index > 3) msgIndex -= 2; // we inserted 2 headers before
        if (index == 2) msgIndex -= 1; // after first header
        if (index == 0) msgIndex = 0;
        if (msgIndex < 0 || msgIndex >= _messages.length) {
          return const SizedBox.shrink();
        }
        final msg = _messages[msgIndex];
        final showTime = msg.showTime;
        final t = TimeOfDay.fromDateTime(msg.at);
        final timeString = t.format(context);
        return Column(
          children: [
            _buildBubble(msg, isDark),
            if (showTime)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(timeString, style: dayTextStyle.copyWith(fontSize: (_largeFonts ? 13 : 11))),
              ),
          ],
        );
      },
    );
  }

  Widget _buildBubble(Message msg, bool isDark) {
    final maxBubbleWidth = MediaQuery.of(context).size.width * 0.72;
    // Minimal, calm bubble palette handled via gradient/shadow below
    final textColor = isDark ? Colors.black : const Color(0xFF0F172A);
    final fontSize = _largeFonts ? 17.0 : 14.0;
    // Bubble system spacing (8–12px internal padding, adaptive for large fonts)
    final hPad = _largeFonts ? 14.0 : 12.0;
    final vPad = _largeFonts ? 10.0 : 8.0;
    final avatar = ClipOval(
      child: Image.network(widget.avatarUrl, width: _largeFonts ? 30 : 28, height: _largeFonts ? 30 : 28, fit: BoxFit.cover),
    );
    // New bubble decoration:
    // - Sender: soft grey gradient (#EAEAEA -> #F5F5F5)
    // - Receiver: pure white with subtle shadow
    // - Corner radius: 24px
    // - No outlines/borders (auto suggestions italic only)
    final bubbleDecoration = BoxDecoration(
      gradient: msg.isMe
          ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFEAEAEA), Color(0xFFF5F5F5)],
            )
          : null,
      color: msg.isMe ? null : Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: msg.isMe
          ? [
              // Very soft elevation for sent bubbles
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 1)),
            ]
          : [
              // Receiver bubble subtle shadow
              BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 3)),
            ],
    );
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxBubbleWidth),
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: bubbleDecoration,
      child: Text(
        msg.text,
        style: TextStyle(
          fontSize: fontSize,
          color: textColor,
          fontStyle: msg.isAutoSuggestion ? FontStyle.italic : FontStyle.normal,
        ),
      ),
    );

    return Padding(
      // Vertical gap between messages: 16px
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
      child: Row(
        mainAxisAlignment: msg.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: msg.isMe
            ? [
                // right side: bubble, avatar, checks
                bubble,
                const SizedBox(width: 8),
                avatar,
                const SizedBox(width: 6),
                const Icon(CupertinoIcons.checkmark_alt, size: 16, color: Color(0xFF0F172A)),
                const SizedBox(width: 2),
                const Icon(CupertinoIcons.checkmark_alt, size: 16, color: Color(0xFF0F172A)),
              ]
            : [
                avatar,
                const SizedBox(width: 8),
                bubble,
              ],
      ),
    );
  }

  Widget _buildInputBar(bool isDark) {
    final double barHeight = _largeFonts ? 64 : 56;
    final Color textColor = const Color(0xFF0F172A);
    final Color iconColor = const Color(0xFF0F172A);
    final Color hintColor = textColor.withOpacity(0.6);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: barHeight,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85), // translucent white card
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            // Mood icon (grayscale)
            GestureDetector(
              onTapDown: (_) {
                setState(() => _pressMood = true);
              },
              onTapCancel: () => setState(() => _pressMood = false),
              onTapUp: (_) {
                setState(() => _pressMood = false);
                HapticFeedback.lightImpact();
                _showMoodTracker();
              },
              child: AnimatedScale(
                duration: const Duration(milliseconds: 160),
                scale: _pressMood ? 0.92 : 1.0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(CupertinoIcons.smiley, color: iconColor.withOpacity(0.8), size: 20),
                ),
              ),
            ),
            // Voice icon (grayscale)
            GestureDetector(
              onTapDown: (_) => setState(() => _pressMic = true),
              onTapCancel: () => setState(() => _pressMic = false),
              onTapUp: (_) {
                setState(() => _pressMic = false);
                HapticFeedback.lightImpact();
                _toggleListening();
              },
              child: AnimatedScale(
                duration: const Duration(milliseconds: 160),
                scale: _pressMic ? 0.92 : 1.0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(_isListening ? CupertinoIcons.mic_fill : CupertinoIcons.mic, color: iconColor.withOpacity(0.8), size: 20),
                ),
              ),
            ),
            // SOS icon (grayscale)
            GestureDetector(
              onTapDown: (_) => setState(() => _pressSOS = true),
              onTapCancel: () => setState(() => _pressSOS = false),
              onTapUp: (_) {
                setState(() => _pressSOS = false);
                HapticFeedback.mediumImpact();
                _triggerSOS();
              },
              child: AnimatedScale(
                duration: const Duration(milliseconds: 160),
                scale: _pressSOS ? 0.92 : 1.0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(CupertinoIcons.exclamationmark_circle, color: iconColor.withOpacity(0.8), size: 20),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Input
            Expanded(
              child: TextField(
                controller: _textController,
                style: TextStyle(color: textColor, fontSize: _largeFonts ? 18 : 15),
                cursorColor: textColor.withOpacity(0.9),
                decoration: InputDecoration(
                  hintText: 'Message…',
                  hintStyle: TextStyle(color: hintColor, fontSize: _largeFonts ? 18 : 15),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            // Send button: arrow.up.circle with soft ripple
            GestureDetector(
              onTapDown: (_) => setState(() => _sendPressed = true),
              onTapCancel: () => setState(() => _sendPressed = false),
              onTapUp: (_) {
                setState(() {
                  _sendPressed = false;
                  _sendRipple = true;
                });
                HapticFeedback.lightImpact();
                Timer(const Duration(milliseconds: 180), () {
                  if (mounted) setState(() => _sendRipple = false);
                });
                _sendMessage();
              },
              child: AnimatedScale(
                duration: const Duration(milliseconds: 160),
                scale: _sendPressed ? 0.92 : 1.0,
                curve: Curves.easeOutCubic,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedScale(
                        duration: const Duration(milliseconds: 180),
                        scale: _sendRipple ? 1.25 : 0.8,
                        curve: Curves.easeOut,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: _sendRipple ? 0.25 : 0.0,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: iconColor.withOpacity(0.2),
                            ),
                          ),
                        ),
                      ),
                      Icon(CupertinoIcons.arrow_up_circle, color: iconColor.withOpacity(0.9), size: 26),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _triggerSOS() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('SOS'),
        content: const Text('Emergency signal has been sent.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _addMessage(Message(text: text, isMe: true, at: DateTime.now(), showTime: false));
    _textController.clear();
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
    _maybeInsertWellnessCheck(DateTime.now());
  }

  void _showHealthSnapshot() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final heartRate = widget.lastHeartbeat != null ? '${widget.lastHeartbeat} bpm' : '—';
    const spo2 = '97%';
    const sleep = 'Good';
    final mood = widget.mood[0].toUpperCase() + widget.mood.substring(1);
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('📊'),
                  const SizedBox(width: 8),
                  Text('Health Snapshot', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(CupertinoIcons.xmark),
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    onPressed: () => Navigator.of(ctx).pop(),
                  )
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _snapshotChip(isDark, 'Heart Rate', heartRate, CupertinoIcons.heart_fill),
                  _snapshotChip(isDark, 'SpO₂', spo2, CupertinoIcons.waveform_path_ecg),
                  _snapshotChip(isDark, 'Sleep', sleep, CupertinoIcons.bed_double),
                  _snapshotChip(isDark, 'Mood', mood, CupertinoIcons.smiley),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _snapshotChip(bool isDark, String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF3C3C3E) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: isDark ? Colors.white : const Color(0xFF475569)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF64748B))),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
            ],
          ),
        ],
      ),
    );
  }

  void _showTherapistQuickConnect() {
    if ((widget.category ?? '').toLowerCase() != 'therapist') return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🩺'),
                  const SizedBox(width: 8),
                  Text('Therapist Connect', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(CupertinoIcons.xmark),
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    onPressed: () => Navigator.of(ctx).pop(),
                  )
                ],
              ),
              const SizedBox(height: 10),
              Text('Recent notes (sample):', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF64748B))),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF3C3C3E) : const Color(0xFFE2E8F0)),
                ),
                child: const Text('• Focus on breathing exercises.\n• Weekly check-in scheduled.\n• Mood improved vs last visit.', style: TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {},
                      child: const Text('View Notes'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {},
                      child: const Text('Schedule Session'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Wellness layer helpers -------------------------------------------------
  void _showMoodTracker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('😊'),
                  const SizedBox(width: 8),
                  Text('Mood Check-In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(CupertinoIcons.xmark),
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    onPressed: () => Navigator.of(ctx).pop(),
                  )
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final mood in ['😊','🙂','😐','🙁','😢','😡'])
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _messages.add(
                            Message(
                              text: 'Mood logged: $mood',
                              isMe: true,
                              at: DateTime.now(),
                              isAutoSuggestion: true,
                              meta: {'type': 'mood', 'value': mood},
                            ),
                          );
                        });
                        Navigator.of(ctx).pop();
                        _maybeInsertWellnessCheck(DateTime.now());
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border: Border.all(color: isDark ? const Color(0xFF3C3C3E) : const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(mood, style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ignore: unused_element
  void _showQuotePicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const quotes = [
      '“You are stronger than yesterday.”',
      '“Breathe. One moment at a time.”',
      '“Progress, not perfection.”',
      '“Rest is productive.”',
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('✨'),
                  const SizedBox(width: 8),
                  Text('Thoughts & Quotes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(CupertinoIcons.xmark),
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    onPressed: () => Navigator.of(ctx).pop(),
                  )
                ],
              ),
              const SizedBox(height: 10),
              for (final q in quotes)
                ListTile(
                  leading: const Text('💬', style: TextStyle(fontSize: 20)),
                  title: Text(q, style: TextStyle(fontSize: 14, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                  onTap: () {
                    _addMessage(
                      Message(
                        text: q,
                        isMe: false,
                        at: DateTime.now(),
                        isAutoSuggestion: true,
                        meta: {'type': 'quote'},
                      ),
                    );
                    Navigator.of(ctx).pop();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _maybeInsertWellnessCheck(DateTime now) {
    if (_messages.isEmpty) return;
    final lastUserMessage = _messages.lastWhere((m) => m.isMe, orElse: () => _messages.last);
    final diff = now.difference(lastUserMessage.at);
    // Insert a gentle nudge if > 6 hours since last self message and no recent suggestion in past hour
    final hasRecentSuggestion = _messages.any((m) => m.isAutoSuggestion && now.difference(m.at) < const Duration(hours: 1));
    if (diff > const Duration(hours: 6) && !hasRecentSuggestion) {
      _addMessage(
        Message(
          text: 'It’s been a while since you checked in. How are you feeling?',
          isMe: false,
          at: now,
          isAutoSuggestion: true,
          meta: {'type': 'check-in'},
        ),
      );
    }
  }

  // Centralized message add to optionally speak incoming messages
  void _addMessage(Message m) async {
    setState(() => _messages.add(m));
    if (_voiceResponseEnabled && !m.isMe) {
      await _speakText(m.text);
    }
  }

  // Voice features ---------------------------------------------------------
  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.48);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> _speakText(String text) async {
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    final available = await _speech.initialize(
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') {
          setState(() => _isListening = false);
        }
      },
      onError: (e) {
        setState(() => _isListening = false);
      },
    );
    if (!available) return;

    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        final recognized = result.recognizedWords;
        if (recognized.isEmpty) return;
        // Append/update text field with recognition
        _textController.text = recognized;
        _textController.selection = TextSelection.fromPosition(
          TextPosition(offset: _textController.text.length),
        );
      },
      listenMode: stt.ListenMode.confirmation,
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      localeId: 'en_US',
    );
  }

  // Ask Internet (local demo lookup) --------------------------------------
  // ignore: unused_element
  void _showAskInternet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final controller = TextEditingController();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🔍'),
                  const SizedBox(width: 8),
                  Text('Ask Internet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(CupertinoIcons.xmark),
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    onPressed: () => Navigator.of(ctx).pop(),
                  )
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'e.g. calming prayer, breathing exercise, quick question...',
                  hintStyle: TextStyle(color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF64748B), fontSize: 14),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF3C3C3E) : const Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final q = controller.text.trim();
                        if (q.isEmpty) return;
                        Navigator.of(ctx).pop();
                        final answer = _lookupAnswer(q);
                        _addMessage(Message(text: '🔍 $q', isMe: true, at: DateTime.now()));
                        _addMessage(Message(text: answer, isMe: false, at: DateTime.now(), isAutoSuggestion: true, meta: {'type': 'lookup', 'query': q}));
                      },
                      child: const Text('Search'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text('Quick Picks', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final qp in ['Calming prayer','Breathing exercise','Gratitude prompt','Positive affirmation'])
                    GestureDetector(
                      onTap: () {
                        Navigator.of(ctx).pop();
                        final answer = _lookupAnswer(qp);
                        _addMessage(Message(text: '🔍 $qp', isMe: true, at: DateTime.now()));
                        _addMessage(Message(text: answer, isMe: false, at: DateTime.now(), isAutoSuggestion: true, meta: {'type': 'lookup', 'query': qp}));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isDark ? const Color(0xFF3C3C3E) : const Color(0xFFE2E8F0)),
                        ),
                        child: Text(qp, style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _lookupAnswer(String query) {
    final lower = query.toLowerCase();
    if (lower.contains('prayer')) {
      return '“May peace flow through your breath and calm your heart.”';
    } else if (lower.contains('breathing')) {
      return 'Try 4-7-8 breathing: inhale 4s, hold 7s, exhale 8s — repeat 4 times.';
    } else if (lower.contains('gratitude')) {
      return 'Gratitude prompt: “Name one person who made today easier for you.”';
    } else if (lower.contains('affirmation')) {
      return 'Affirmation: “You are worthy of care and patience.”';
    }
    return 'No curated response found. Consider a calming breath and gentle stretch.';
  }
}
