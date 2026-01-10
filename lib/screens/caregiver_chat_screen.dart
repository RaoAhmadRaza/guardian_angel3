import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'patient_chat_screen.dart'; // For ChatSession and ViewType
import '../chat/services/chat_service.dart';
import '../chat/models/chat_message_model.dart';
import '../relationships/services/relationship_service.dart';
import '../relationships/models/relationship_model.dart';

/// ============================================================================
/// CaregiverChatScreen - Patient's chat interface to talk to their caregiver
/// 
/// ARCHITECTURE:
/// - Uses ChatService for all message operations (LOCAL-FIRST)
/// - Messages are saved to Hive first, then mirrored to Firestore
/// - Real-time updates via watchMessagesForThread stream
/// - Listens to Firestore for incoming messages from caregiver
/// ============================================================================

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
  
  // ===== REAL DATA STATE =====
  List<ChatMessageModel> _messages = [];
  String? _threadId;
  String? _currentUid;
  bool _isLoading = true;
  String? _errorMessage;
  bool _showSmartReplies = true;
  
  // ===== STREAMS =====
  StreamSubscription<List<ChatMessageModel>>? _messageSubscription;
  
  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _messageSubscription?.cancel();
    // Stop Firestore listener when leaving screen
    if (_threadId != null) {
      ChatService.instance.stopListeningForIncomingMessages(_threadId!);
    }
    super.dispose();
  }

  /// ===== INITIALIZE CHAT - CONNECT TO CHATSERVICE =====
  Future<void> _initializeChat() async {
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Not logged in. Please sign in.';
        });
        return;
      }
      _currentUid = user.uid;
      
      // The session.id contains the caregiver's UID - find the SPECIFIC relationship
      final caregiverId = widget.session.id;
      debugPrint('[CaregiverChatScreen] Patient: $_currentUid, Looking for caregiver: $caregiverId');
      
      // Get all relationships for this patient
      final relResult = await RelationshipService.instance.getRelationshipsForUser(_currentUid!);
      if (!relResult.success || relResult.data == null || relResult.data!.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No caregiver relationships found';
        });
        return;
      }
      
      // Find the SPECIFIC relationship for this caregiver
      RelationshipModel? targetRelationship;
      for (final rel in relResult.data!) {
        if (rel.caregiverId == caregiverId && rel.status == RelationshipStatus.active) {
          targetRelationship = rel;
          debugPrint('[CaregiverChatScreen] Found active relationship: ${rel.id}');
          break;
        }
      }
      
      if (targetRelationship == null) {
        // Try pending relationships too
        for (final rel in relResult.data!) {
          if (rel.caregiverId == caregiverId) {
            targetRelationship = rel;
            debugPrint('[CaregiverChatScreen] Found relationship (status: ${rel.status}): ${rel.id}');
            break;
          }
        }
      }
      
      if (targetRelationship == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No relationship found with this caregiver';
        });
        return;
      }
      
      // Check if chat is enabled for this relationship (check permissions list)
      if (!targetRelationship.permissions.contains('chat')) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Chat is not enabled for this caregiver relationship';
        });
        return;
      }
      
      // Get or create thread for this SPECIFIC relationship
      final threadResult = await ChatService.instance.getOrCreateThreadForRelationship(
        relationshipId: targetRelationship.id,
        patientId: targetRelationship.patientId,
        caregiverId: targetRelationship.caregiverId!,
      );
      if (!threadResult.success || threadResult.data == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = threadResult.errorMessage ?? 'Failed to create chat thread';
        });
        return;
      }
      
      _threadId = threadResult.data!.id;
      
      // Start listening for incoming messages from Firestore
      ChatService.instance.startListeningForIncomingMessages(
        threadId: _threadId!,
        currentUid: _currentUid!,
      );
      
      // Watch messages for real-time updates (from local Hive)
      _messageSubscription = ChatService.instance.watchMessagesForThread(
        _threadId!,
        _currentUid!,
      ).listen((messages) {
        if (mounted) {
          setState(() {
            _messages = messages;
            _isLoading = false;
          });
          _scrollToBottom();
          
          // Mark incoming messages as read
          _markIncomingMessagesAsRead();
        }
      }, onError: (e) {
        debugPrint('[CaregiverChatScreen] Message stream error: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Failed to load messages';
          });
        }
      });
      
    } catch (e) {
      debugPrint('[CaregiverChatScreen] Init error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error initializing chat: $e';
        });
      }
    }
  }
  
  /// ===== MARK INCOMING MESSAGES AS READ =====
  Future<void> _markIncomingMessagesAsRead() async {
    if (_threadId == null || _currentUid == null) return;
    
    await ChatService.instance.markAllUnreadMessagesAsRead(
      threadId: _threadId!,
      currentUid: _currentUid!,
    );
  }

  /// ===== SEND MESSAGE - USES CHATSERVICE =====
  Future<void> _handleSend(String text, [String type = 'text']) async {
    if (text.trim().isEmpty) return;
    if (_threadId == null || _currentUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat not ready. Please wait...')),
      );
      return;
    }

    final content = text.trim();
    _textController.clear();
    setState(() {
      _showSmartReplies = false;
    });
    
    // Send via ChatService (LOCAL-FIRST: saves to Hive, mirrors to Firestore)
    final result = await ChatService.instance.sendTextMessage(
      threadId: _threadId!,
      currentUid: _currentUid!,
      content: content,
    );
    
    if (!result.success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: ${result.errorMessage}'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _handleSend(content, type),
            ),
          ),
        );
      }
    }
    // Message will appear via the stream subscription automatically
  }

  /// ===== RETRY FAILED MESSAGE =====
  Future<void> _retryMessage(ChatMessageModel message) async {
    await ChatService.instance.retryFailedMessages();
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

  /// ===== BUILD MESSAGE AREA - HANDLES LOADING/ERROR/EMPTY STATES =====
  Widget _buildMessageArea() {
    // Loading state
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading messages...',
              style: GoogleFonts.inter(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }
    
    // Error state
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.exclamationmark_circle,
                size: 48,
                color: Colors.red.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.grey.shade700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _initializeChat();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    
    // Empty state
    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.chat_bubble_2,
                size: 64,
                color: Colors.blue.shade200,
              ),
              const SizedBox(height: 16),
              Text(
                'No messages yet',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Send a message to start chatting with ${widget.session.name}',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Messages list
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 20, bottom: 100, left: 16, right: 16),
      itemCount: _messages.length + 1,
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
        final isMe = msg.isFromUser(_currentUid!);
        final isLast = index - 1 == _messages.length - 1;
        return _buildMessageBubble(msg, isMe, isLast);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F1ED),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.4,
              child: Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage("https://www.transparenttextures.com/patterns/stardust.png"),
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
              _buildHeader(),
              Expanded(
                child: _buildMessageArea(),
              ),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_showSmartReplies && !_isLoading && _errorMessage == null)
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
                const SizedBox(height: 12),
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

  Widget _buildMessageBubble(ChatMessageModel msg, bool isMe, bool isLast) {
    if (msg.messageType == ChatMessageType.system) {
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
                      "System Message",
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    Text(
                      msg.content,
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

    Widget statusIcon = const SizedBox.shrink();
    if (isMe) {
      if (msg.localStatus == ChatMessageLocalStatus.failed) {
        statusIcon = GestureDetector(
          onTap: () => _retryMessage(msg),
          child: Icon(Icons.error_outline, size: 14, color: Colors.red.shade400),
        );
      } else if (msg.localStatus == ChatMessageLocalStatus.pending) {
        statusIcon = Icon(Icons.access_time, size: 12, color: Colors.white.withOpacity(0.6));
      } else if (msg.isRead) {
        statusIcon = Icon(Icons.done_all, size: 12, color: Colors.white.withOpacity(0.8));
      } else if (msg.isDelivered) {
        statusIcon = Icon(Icons.done_all, size: 12, color: Colors.white.withOpacity(0.6));
      } else {
        statusIcon = Icon(Icons.check, size: 12, color: Colors.white.withOpacity(0.8));
      }
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
                  colors: msg.localStatus == ChatMessageLocalStatus.failed
                      ? [Colors.red.shade400, Colors.red.shade500]
                      : [Colors.blue.shade500, Colors.blue.shade600],
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
                msg.content,
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
                    _formatTime(msg.createdAt.toLocal()),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isMe ? Colors.white.withOpacity(0.7) : Colors.grey.shade400,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    statusIcon,
                  ],
                ],
              ),
              if (isMe && msg.localStatus == ChatMessageLocalStatus.failed) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => _retryMessage(msg),
                  child: Text(
                    'Tap to retry',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.9),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
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
        bottom: MediaQuery.of(context).padding.bottom + 20,
        top: 16,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F1ED).withOpacity(0.9),
        border: Border(top: BorderSide(color: Colors.grey.shade300.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
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
              padding: const EdgeInsets.only(left: 16, right: 8, top: 2, bottom: 2),
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
                        hintText: "Type a message",
                        hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
                      width: 32,
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
