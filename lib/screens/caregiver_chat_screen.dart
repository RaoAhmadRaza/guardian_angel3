import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'patient_chat_screen.dart'; // For ChatSession and ViewType

class CaregiverChatScreen extends StatefulWidget {
  final ChatSession session;

  const CaregiverChatScreen({
    super.key,
    required this.session,
  });

  @override
  State<CaregiverChatScreen> createState() => _CaregiverChatScreenState();
}

class _CaregiverChatScreenState extends State<CaregiverChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _showSmartReplies = true;

  @override
  void initState() {
    super.initState();
    // Initial Mock Messages
    _messages = [
      ChatMessage(
        id: '1',
        text: "Hi Mom! Just checking in. Did you take your afternoon meds?",
        sender: 'other',
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
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

  void _handleSend(String text, [String type = 'text']) {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(
        id: DateTime.now().toString(),
        text: text,
        sender: 'user',
        timestamp: DateTime.now(),
        status: 'sent',
        type: type,
      ));
      _textController.clear();
      _showSmartReplies = false;
    });
    
    _scrollToBottom();

    // Simulate Caregiver Reply
    setState(() => _isTyping = true);
    
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isTyping = false;
          // Mark user message as read
          _messages = _messages.map((m) {
            if (m.sender == 'user') return m.copyWith(status: 'read');
            return m;
          }).toList();

          _messages.add(ChatMessage(
            id: DateTime.now().toString(),
            text: "I saw your message. I'm finishing up at the grocery store and will be there in 20 minutes!",
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
      backgroundColor: const Color(0xFFF2F1ED), // Warm Cream
      body: Stack(
        children: [
          // 0. Wallpaper Texture
          Positioned.fill(
            child: Opacity(
              opacity: 0.4,
              child: Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage("https://www.transparenttextures.com/patterns/stardust.png"), // Fallback or similar noise
                    repeat: ImageRepeat.repeat,
                  ),
                ),
                child: CustomPaint(
                  painter: DotPatternPainter(),
                ),
              ),
            ),
          ),

          Column(
            children: [
              // Header
              _buildHeader(),

              // Messages
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(top: 20, bottom: 100, left: 16, right: 16),
                  itemCount: _messages.length + 1, // +1 for "Today" divider
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              "Today",
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade500,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    final msg = _messages[index - 1];
                    final isMe = msg.sender == 'user';
                    final isLast = index - 1 == _messages.length - 1;
                    return _buildMessageBubble(msg, isMe, isLast);
                  },
                ),
              ),
            ],
          ),

          // Bottom Area (Smart Replies + Input Bar)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_showSmartReplies)
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _buildSmartReply("Yes, please 🥛", 'text'),
                        const SizedBox(width: 8),
                        _buildSmartReply("No, I'm good", 'text'),
                        const SizedBox(width: 8),
                        _buildSmartReply("Call me 📞", 'text'),
                        const SizedBox(width: 8),
                        _buildSmartReply("Share Status ✅", 'health-snapshot'),
                      ],
                    ),
                  ),
                const SizedBox(height: 12), // Spacing between chips and input
                _buildInputBar(),
              ],
            ),
          ),
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
            color: const Color(0xFFF2F1ED).withOpacity(0.8),
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
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
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        widget.session.name.isNotEmpty ? widget.session.name[0] : "S",
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.session.name,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(CupertinoIcons.calendar, size: 10, color: Colors.blue),
                            const SizedBox(width: 4),
                            Text(
                              "Visit: 5:00 PM Today",
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(CupertinoIcons.phone_fill, color: Colors.blue.shade600, size: 24),
                  const SizedBox(width: 20),
                  Icon(CupertinoIcons.video_camera_solid, color: Colors.blue.shade600, size: 28),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isMe, bool isLast) {
    if (msg.type == 'health-snapshot') {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16, left: 60),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 20, 12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.green.shade500,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.shade200,
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Afternoon Meds",
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    Text(
                      "Taken at ${msg.timestamp.hour > 12 ? msg.timestamp.hour - 12 : msg.timestamp.hour}:${msg.timestamp.minute.toString().padLeft(2, '0')} PM",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ).animate().slideY(begin: 0.2, end: 0, duration: 300.ms),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          gradient: isMe 
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.blue.shade500, Colors.blue.shade600],
                )
              : null,
          color: isMe ? null : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                msg.text,
                style: GoogleFonts.inter(
                  fontSize: 17,
                  height: 1.3,
                  color: isMe ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(msg.timestamp),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isMe ? Colors.white.withOpacity(0.7) : Colors.grey.shade400,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      msg.status == 'read' ? Icons.done_all : Icons.check,
                      size: 12,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ).animate().fade().slideY(begin: 0.1, end: 0, duration: 200.ms),
    );
  }

  Widget _buildSmartReply(String text, String type) {
    return GestureDetector(
      onTap: () => _handleSend(text, type),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16, 
        right: 16, 
        bottom: MediaQuery.of(context).padding.bottom + 20, // Increased bottom padding
        top: 16 // Increased top padding
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F1ED).withOpacity(0.9),
        border: Border(top: BorderSide(color: Colors.grey.shade300.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          Container(
            width: 40, // Slightly larger
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: const Icon(CupertinoIcons.camera_fill, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(left: 16, right: 8, top: 2, bottom: 2), // Adjusted padding
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      textAlignVertical: TextAlignVertical.center,
                      decoration: InputDecoration(
                        hintText: "Type a message", // Changed placeholder
                        hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14), // Adjusted padding
                        isDense: true,
                      ),
                      style: GoogleFonts.inter(fontSize: 16),
                      onSubmitted: (val) => _handleSend(val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _handleSend(_textController.text),
                    child: Container(
                      width: 32, // Slightly larger
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_upward, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String id;
  final String text;
  final String sender;
  final DateTime timestamp;
  final String status;
  final String type;

  ChatMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
    this.status = 'sent',
    this.type = 'text',
  });

  ChatMessage copyWith({String? status}) {
    return ChatMessage(
      id: id,
      text: text,
      sender: sender,
      timestamp: timestamp,
      status: status ?? this.status,
      type: type,
    );
  }
}

class DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.1)
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += 30) {
      for (double y = 0; y < size.height; y += 30) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
