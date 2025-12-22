import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'patient_chat_screen.dart'; // For ChatSession and ViewType

class DoctorChatScreen extends StatefulWidget {
  final ChatSession session;

  const DoctorChatScreen({
    super.key,
    required this.session,
  });

  @override
  State<DoctorChatScreen> createState() => _DoctorChatScreenState();
}

class _DoctorChatScreenState extends State<DoctorChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _isMenuOpen = false;

  @override
  void initState() {
    super.initState();
    // Initial Mock Messages
    _messages = [
      ChatMessage(
        id: '1',
        text: "Hello, I've reviewed your latest heart rate logs. Everything looks stable.",
        sender: 'other',
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
        status: 'read',
      ),
    ];
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleSend(String text) {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(
        id: DateTime.now().toString(),
        text: text,
        sender: 'user',
        timestamp: DateTime.now(),
        status: 'sent',
      ));
      _textController.clear();
    });
    
    _scrollToBottom();

    // Simulate Doctor Auto-Reply
    setState(() => _isTyping = true);
    
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(ChatMessage(
            id: DateTime.now().toString(),
            text: "This is an automated response. Dr. Chen is currently with patients. For medical emergencies, please call 911 or use the Emergency button.\n\n— Dr. Chen",
            sender: 'other',
            timestamp: DateTime.now(),
          ));
        });
        _scrollToBottom();
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

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), // gray-50
      body: Stack(
        children: [
          Column(
            children: [
              // Header
              _buildHeader(),

              // Messages
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(top: 60, bottom: 100, left: 16, right: 16), // Top padding for banner
                  itemCount: _messages.length + 1, // +1 for HIPAA notice
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildHIPAANotice();
                    }
                    final msg = _messages[index - 1];
                    final isMe = msg.sender == 'user';
                    return _buildMessageBubble(msg, isMe);
                  },
                ),
              ),
            ],
          ),

          // Appointment Banner
          Positioned(
            top: MediaQuery.of(context).padding.top + 60, // Below header
            left: 0,
            right: 0,
            child: _buildAppointmentBanner(),
          ),

          // Input Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildInputBar(),
          ),

          // Accessory Menu Overlay
          if (_isMenuOpen) _buildAccessoryMenu(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
            color: Colors.white.withOpacity(0.95),
            border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.chevron_left, color: Colors.blue, size: 28),
                        Text(
                          "Chats",
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Stack(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.blue.shade100),
                          image: const DecorationImage(
                            image: NetworkImage("https://images.unsplash.com/photo-1559839734-2b71ea860632?q=80&w=100&auto=format&fit=crop"),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: widget.session.isOnline ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            widget.session.name,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Row(
                              children: [
                                Icon(CupertinoIcons.checkmark_seal_fill, size: 10, color: Colors.blue.shade500),
                                const SizedBox(width: 2),
                                Text(
                                  "VERIFIED",
                                  style: GoogleFonts.inter(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (!widget.session.isOnline)
                        Text(
                          "Replies during clinic hours",
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(CupertinoIcons.info, color: Colors.grey.shade500, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentBanner() {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: Colors.white.withOpacity(0.6)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(CupertinoIcons.calendar, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  "Next Visit: Fri, 10:00 AM (Video)",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade900,
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    children: [
                      Text(
                        "Details",
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(CupertinoIcons.chevron_right, size: 10, color: Colors.blue.shade600),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().slideY(begin: -0.5, end: 0, duration: 400.ms, curve: Curves.easeOutBack);
  }

  Widget _buildHIPAANotice() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24, top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.lock_fill, size: 12, color: Colors.grey.shade400),
          const SizedBox(width: 6),
          Text(
            "END-TO-END ENCRYPTED • HIPAA COMPLIANT",
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade400,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8, bottom: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade100),
                image: const DecorationImage(
                  image: NetworkImage("https://images.unsplash.com/photo-1559839734-2b71ea860632?q=80&w=100&auto=format&fit=crop"),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
            decoration: BoxDecoration(
              color: isMe ? Colors.blue.shade500 : Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isMe ? 20 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 20),
              ),
              border: isMe ? null : Border.all(color: Colors.grey.shade100.withOpacity(0.5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isMe ? 20 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 20),
              ),
              child: BackdropFilter(
                filter: isMe ? ImageFilter.blur(sigmaX: 0, sigmaY: 0) : ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        msg.text,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          height: 1.4,
                          color: isMe ? Colors.white : Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTime(msg.timestamp),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: isMe ? Colors.blue.shade100 : Colors.grey.shade400,
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.done_all,
                              size: 12,
                              color: Colors.blue.shade100,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ).animate().fade().slideY(begin: 0.1, end: 0, duration: 200.ms),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16, 
        right: 16, 
        bottom: MediaQuery.of(context).padding.bottom + 12,
        top: 12
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() => _isMenuOpen = true),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(CupertinoIcons.add, color: Colors.grey.shade600, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TextField(
                controller: _textController,
                decoration: InputDecoration(
                  hintText: "Message Dr. Emily...",
                  hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                style: GoogleFonts.inter(fontSize: 16),
                onSubmitted: (val) => _handleSend(val),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => _handleSend(_textController.text),
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child: const Icon(CupertinoIcons.mic_fill, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessoryMenu() {
    return GestureDetector(
      onTap: () => setState(() => _isMenuOpen = false),
      child: Container(
        color: Colors.white.withOpacity(0.8),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 120, left: 24, right: 24),
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                mainAxisSpacing: 24,
                crossAxisSpacing: 24,
                children: [
                  _buildMenuItem(CupertinoIcons.camera_fill, "Camera", Colors.grey.shade100, Colors.black),
                  _buildMenuItem(CupertinoIcons.photo_fill, "Photos", Colors.grey.shade100, Colors.black),
                  _buildMenuItem(CupertinoIcons.heart_fill, "Vitals", Colors.red.shade50, Colors.red),
                  _buildMenuItem(CupertinoIcons.location_solid, "Location", Colors.green.shade50, Colors.green),
                  _buildMenuItem(CupertinoIcons.doc_text_fill, "Report", Colors.blue.shade50, Colors.blue),
                ],
              ),
            ),
          ),
        ),
      ).animate().fade(duration: 200.ms),
    );
  }

  Widget _buildMenuItem(IconData icon, String label, Color bg, Color fg) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: fg, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    ).animate().slideY(begin: 0.5, end: 0, duration: 300.ms, curve: Curves.easeOutBack);
  }
}

class ChatMessage {
  final String id;
  final String text;
  final String sender;
  final DateTime timestamp;
  final String status;

  ChatMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
    this.status = 'sent',
  });
}
