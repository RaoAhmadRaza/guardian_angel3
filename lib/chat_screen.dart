import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/patient_model.dart';

// Mock Data
enum MessageTag {
  urgent,
  update,
  meds,
  vitals,
}

class ChatMessage {
  final String id;
  final String sender;
  final String text;
  final String timestamp;
  final MessageTag? tag;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.tag,
  });
}

final List<ChatMessage> initialMessages = [
  ChatMessage(
    id: '1',
    sender: 'AI Guardian',
    text: 'SESSION STARTED • OCT 24',
    timestamp: '09:00 AM',
  ),
  ChatMessage(
    id: '2',
    sender: 'Nurse Sarah',
    text: 'Morning Dr. Mitchell. Patient reported slight dizziness after breakfast.',
    timestamp: '09:15 AM',
    tag: MessageTag.update,
  ),
  ChatMessage(
    id: '3',
    sender: 'Doctor',
    text: 'Thanks Sarah. Any change in BP?',
    timestamp: '09:18 AM',
  ),
  ChatMessage(
    id: '4',
    sender: 'Nurse Sarah',
    text: 'BP is 135/85. Slightly elevated but stable.',
    timestamp: '09:20 AM',
    tag: MessageTag.vitals,
  ),
];

class ChatScreen extends StatefulWidget {
  final Patient patient;

  const ChatScreen({super.key, required this.patient});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = List.from(initialMessages);
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  MessageTag? _selectedTag;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(
        id: DateTime.now().toString(),
        sender: 'Doctor',
        text: _controller.text,
        timestamp: TimeOfDay.now().format(context),
        tag: _selectedTag,
      ));
      _controller.clear();
      _selectedTag = null;
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate-50
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) => _buildMessageItem(_messages[index]),
              ),
            ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: const Color(0xFFF1F5F9))), // Slate-100
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)), // Slate-900
            onPressed: () => Navigator.pop(context),
          ),
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFDBEAFE), // Blue-100
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                'CT',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF2563EB), // Blue-600
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CARE TEAM SESSION',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF94A3B8), // Slate-400
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  widget.patient.name,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A), // Slate-900
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.phone_outlined, color: Color(0xFF94A3B8)), // Slate-400
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(ChatMessage msg) {
    if (msg.sender == 'AI Guardian') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0).withOpacity(0.5), // Slate-200/50
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.5)),
            ),
            child: Text(
              msg.text,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF64748B), // Slate-500
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
      );
    }

    final isMe = msg.sender == 'Doctor';
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isMe ? const Color(0xFF2563EB) : Colors.white, // Blue-600 : White
                    borderRadius: BorderRadius.only(
                      topLeft: isMe ? const Radius.circular(22) : const Radius.circular(4),
                      topRight: isMe ? const Radius.circular(4) : const Radius.circular(22),
                      bottomLeft: const Radius.circular(22),
                      bottomRight: const Radius.circular(22),
                    ),
                    border: isMe ? null : Border.all(color: const Color(0xFFF1F5F9)), // Slate-100
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (msg.tag != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isMe ? const Color(0xFF3B82F6) : const Color(0xFFF1F5F9), // Blue-500 : Slate-100
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            msg.tag!.name.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: isMe ? Colors.white : const Color(0xFF64748B), // White : Slate-500
                            ),
                          ),
                        ),
                      Text(
                        msg.text,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isMe ? Colors.white : const Color(0xFF1E293B), // White : Slate-800
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Text(
                          msg.timestamp,
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: isMe ? Colors.white.withOpacity(0.6) : const Color(0xFF94A3B8), // White/60 : Slate-400
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))), // Slate-100
      ),
      child: Column(
        children: [
          // Tags
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: MessageTag.values.map((tag) {
                final isSelected = _selectedTag == tag;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTag = isSelected ? null : tag),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9), // Blue-600 : Slate-100
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tag.name.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: isSelected ? Colors.white : const Color(0xFF94A3B8), // White : Slate-400
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          
          // Input Field
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC), // Slate-50
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFF1F5F9)), // Slate-100
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add, color: Color(0xFF94A3B8)), // Slate-400
                  onPressed: () {},
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Clinical message...',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF94A3B8), // Slate-400
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF0F172A), // Slate-900
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB), // Blue-600
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFBFDBFE), // Blue-200
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

