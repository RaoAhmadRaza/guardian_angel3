import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/guardian_ai_service.dart';

/// Chat message model for AI conversations
class _AIChatMessage {
  final String id;
  final bool isUser;
  final String content;
  final DateTime timestamp;
  final bool isError;

  _AIChatMessage({
    required this.id,
    required this.isUser,
    required this.content,
    DateTime? timestamp,
    this.isError = false,
  }) : timestamp = timestamp ?? DateTime.now();
}

class CaregiverAIChatScreen extends StatefulWidget {
  const CaregiverAIChatScreen({super.key});

  @override
  State<CaregiverAIChatScreen> createState() => _CaregiverAIChatScreenState();
}

class _CaregiverAIChatScreenState extends State<CaregiverAIChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_AIChatMessage> _messages = [];
  final GuardianAIService _aiService = GuardianAIService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Clear history for fresh conversation
    _aiService.clearHistory();
    
    // Add welcome message
    _messages.add(_AIChatMessage(
      id: 'welcome',
      isUser: false,
      content: "Hello! I'm Guardian Angel, your AI care companion. I can help you understand health trends, suggest care strategies, or answer questions about caring for your loved one. How can I assist you today?",
      timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    // Add user message
    setState(() {
      _messages.add(_AIChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        isUser: true,
        content: text,
      ));
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      // Get AI response
      final response = await _aiService.sendMessage(text);

      if (mounted) {
        setState(() {
          _messages.add(_AIChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            isUser: false,
            content: response.text,
            isError: response.isError,
          ));
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_AIChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            isUser: false,
            content: "I'm sorry, I couldn't process that request right now. Please try again in a moment.",
            isError: true,
          ));
          _isLoading = false;
        });
      }
    }
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

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inMinutes < 1) return 'Now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) {
      final hour = timestamp.hour;
      final minute = timestamp.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$displayHour:$minute $period';
    }
    return 'Yesterday';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.95),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.chevron_left, color: Color(0xFF7C3AED), size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(CupertinoIcons.sparkles, color: Color(0xFF7C3AED), size: 24),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Guardian AI',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Text(
                  'ALWAYS ONLINE',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF8E8E93),
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.info_circle, color: Color(0xFF7C3AED)),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFF2F2F7), height: 1),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: const Color(0xFFF8FAFC),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(20),
                itemCount: _messages.length + 1, // +1 for disclaimer banner
                itemBuilder: (context, index) {
                  // Disclaimer banner at top
                  if (index == 0) {
                    return _buildDisclaimerBanner();
                  }
                  
                  final msg = _messages[index - 1];
                  return _buildMessageBubble(msg);
                },
              ),
            ),
          ),
          
          // Loading indicator
          if (_isLoading)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: const Color(0xFF7C3AED),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Guardian Angel is thinking...',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ),
            ),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF2F2F7))),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(CupertinoIcons.add, color: Color(0xFF7C3AED)),
                    onPressed: () {
                      // TODO: Add quick actions or attachments
                    },
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: 'Ask Guardian Angel...',
                          hintStyle: GoogleFonts.inter(color: const Color(0xFF8E8E93)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        enabled: !_isLoading,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      CupertinoIcons.arrow_up_circle_fill, 
                      color: _isLoading ? const Color(0xFFC7C7CC) : const Color(0xFF7C3AED), 
                      size: 32,
                    ),
                    onPressed: _isLoading ? null : _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimerBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF).withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE9D5FF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(CupertinoIcons.exclamationmark_shield_fill, color: Color(0xFF7C3AED), size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Assistant Limitations',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF5B21B6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'I can analyze data and provide suggestions, but I cannot provide medical diagnoses. Always consult with healthcare professionals for medical decisions.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF6D28D9).withOpacity(0.7),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_AIChatMessage msg) {
    final isMe = msg.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8, top: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(CupertinoIcons.sparkles, color: Color(0xFF7C3AED), size: 16),
            ),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.70),
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isMe 
                        ? Colors.black 
                        : msg.isError 
                            ? const Color(0xFFFFF0F0) 
                            : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
                      bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: isMe ? null : Border.all(color: Colors.black.withOpacity(0.05)),
                  ),
                  child: Text(
                    msg.content,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isMe 
                          ? Colors.white 
                          : msg.isError 
                              ? const Color(0xFFFF3B30) 
                              : Colors.black,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTimestamp(msg.timestamp),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF8E8E93),
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      const Icon(CupertinoIcons.check_mark, size: 12, color: Colors.black),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
