import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'patient_chat_screen.dart'; // For ChatSession and ViewType
import '../chat/services/doctor_chat_service.dart';
import '../chat/models/chat_message_model.dart';
import '../relationships/services/doctor_relationship_service.dart';
import '../relationships/models/doctor_relationship_model.dart';

/// ============================================================================
/// DoctorChatScreen - Patient's chat interface to talk to their doctor
/// 
/// ARCHITECTURE:
/// - Uses DoctorChatService for all message operations (LOCAL-FIRST)
/// - Messages are saved to Hive first, then mirrored to Firestore
/// - Real-time updates via watchDoctorMessagesForThread stream
/// - Listens to Firestore for incoming messages from doctor
/// ============================================================================

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
  
  // ===== REAL DATA STATE =====
  List<ChatMessageModel> _messages = [];
  String? _threadId;
  String? _currentUid;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isMenuOpen = false;
  bool _isSending = false;
  bool _accessRevoked = false;
  
  // ===== STREAMS =====
  StreamSubscription<List<ChatMessageModel>>? _messageSubscription;
  StreamSubscription<bool>? _accessSubscription;
  
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
    _accessSubscription?.cancel();
    // Stop Firestore listener when leaving screen
    if (_threadId != null) {
      DoctorChatService.instance.stopListeningForIncomingDoctorMessages(_threadId!);
    }
    super.dispose();
  }

  /// ===== INITIALIZE CHAT - CONNECT TO DOCTORCHATSERVICE =====
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
      
      // The session.id contains the doctor's UID - find the specific relationship
      final doctorId = widget.session.id;
      debugPrint('[DoctorChatScreen] Looking for relationship with doctor: $doctorId');
      
      // Get all relationships and find the one for this specific doctor
      final relResult = await DoctorRelationshipService.instance.getRelationshipsForUser(_currentUid!);
      if (!relResult.success || relResult.data == null || relResult.data!.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No doctor relationship found. Please link with this doctor first.';
        });
        return;
      }
      
      // Find the specific relationship for this doctor
      DoctorRelationshipModel? targetRelationship;
      for (final rel in relResult.data!) {
        if (rel.doctorId == doctorId && rel.status == DoctorRelationshipStatus.active) {
          targetRelationship = rel;
          break;
        }
      }
      
      if (targetRelationship == null) {
        // Check if there's a pending relationship with this doctor
        final pendingRel = relResult.data!.where(
          (r) => r.doctorId == doctorId && r.status == DoctorRelationshipStatus.pending
        ).firstOrNull;
        
        if (pendingRel != null) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Doctor relationship is pending. Waiting for ${widget.session.name} to accept your invite.';
          });
          return;
        }
        
        setState(() {
          _isLoading = false;
          _errorMessage = 'No active relationship with ${widget.session.name}. Please connect first.';
        });
        return;
      }
      
      // Verify chat permission
      if (!targetRelationship.hasPermission('chat')) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Chat is not enabled with ${widget.session.name}. Please request chat permission.';
        });
        return;
      }
      
      // Get or create thread for THIS SPECIFIC relationship
      final threadResult = await DoctorChatService.instance.getOrCreateDoctorThreadForRelationship(
        relationshipId: targetRelationship.id,
        patientId: targetRelationship.patientId,
        doctorId: targetRelationship.doctorId!,
      );
      if (!threadResult.success || threadResult.data == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = threadResult.errorMessage ?? 'Failed to create doctor chat thread';
        });
        return;
      }
      
      _threadId = threadResult.data!.id;
      debugPrint('[DoctorChatScreen] Thread initialized: $_threadId for doctor: $doctorId');
      
      // Start listening for incoming messages from Firestore
      DoctorChatService.instance.startListeningForIncomingDoctorMessages(
        threadId: _threadId!,
        currentUid: _currentUid!,
      );
      
      // Watch messages from local Hive (real-time updates)
      _messageSubscription = DoctorChatService.instance
          .watchDoctorMessagesForThread(_threadId!, _currentUid!)
          .listen(
        (messages) {
          if (mounted) {
            setState(() {
              _messages = messages;
              _isLoading = false;
            });
            // Scroll to bottom when new messages arrive
            _scrollToBottom();
          }
        },
        onError: (e) {
          debugPrint('[DoctorChatScreen] Message stream error: $e');
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = 'Failed to load messages';
            });
          }
        },
      );
      
      // Mark messages as read
      await DoctorChatService.instance.markDoctorThreadAsRead(
        threadId: _threadId!,
        currentUid: _currentUid!,
      );
      
      // Watch for access revocation
      _accessSubscription = DoctorChatService.instance
          .watchDoctorChatAccessForUser(_currentUid!)
          .listen((allowed) {
        if (!allowed && mounted) {
          setState(() => _accessRevoked = true);
          _showAccessRevokedDialog();
        }
      });
      
    } catch (e) {
      debugPrint('[DoctorChatScreen] Init error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to initialize chat: $e';
        });
      }
    }
  }

  void _showAccessRevokedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Doctor Chat Access Revoked'),
        content: const Text(
          'Your relationship with the doctor has been revoked or chat permission has been removed. '
          'You can no longer send messages in this conversation.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// ===== SEND MESSAGE - USES DOCTORCHATSERVICE =====
  Future<void> _handleSend(String text) async {
    if (text.trim().isEmpty || _isSending || _accessRevoked) return;
    if (_threadId == null || _currentUid == null) return;
    
    final content = text.trim();
    _textController.clear();
    HapticFeedback.lightImpact();
    
    setState(() => _isSending = true);
    
    // Send via DoctorChatService (saves to Hive, mirrors to Firestore)
    final result = await DoctorChatService.instance.sendDoctorTextMessage(
      threadId: _threadId!,
      currentUid: _currentUid!,
      content: content,
    );
    
    if (mounted) {
      setState(() => _isSending = false);
      
      if (!result.success) {
        // Show error but message is saved locally for retry
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Failed to send message'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _retryFailedMessages(),
            ),
          ),
        );
        // Restore text if send failed
        _textController.text = content;
      } else {
        _scrollToBottom();
      }
    }
  }
  
  /// ===== RETRY FAILED MESSAGES =====
  Future<void> _retryFailedMessages() async {
    await DoctorChatService.instance.retryFailedDoctorMessages();
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
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return "$hour:$minute $period";
  }

  @override
  Widget build(BuildContext context) {
    // Show loading state
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
              ),
              const SizedBox(height: 16),
              Text(
                'Connecting to Dr. ${widget.session.name}...',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Show error state
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(CupertinoIcons.chevron_left, color: Colors.blue),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.session.name,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.exclamationmark_triangle,
                  size: 64,
                  color: Colors.orange.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'Unable to Load Chat',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _errorMessage = null;
                    });
                    _initializeChat();
                  },
                  icon: const Icon(CupertinoIcons.refresh),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Stack(
        children: [
          Column(
            children: [
              // Header
              _buildHeader(),

              // Messages
              Expanded(
                child: _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(top: 60, bottom: 100, left: 16, right: 16),
                        itemCount: _messages.length + 1, // +1 for HIPAA notice
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _buildHIPAANotice();
                          }
                          final msg = _messages[index - 1];
                          final isMe = msg.isFromUser(_currentUid!);
                          return _buildMessageBubble(msg, isMe);
                        },
                      ),
              ),
            ],
          ),

          // Appointment Banner
          if (_messages.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
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
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.chat_bubble_2,
              size: 40,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Start a conversation',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Send a message to ${widget.session.name}. They typically respond during clinic hours.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
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
                        ),
                        child: widget.session.imageUrl != null
                            ? ClipOval(
                                child: Image.network(
                                  widget.session.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Center(
                                    child: Text(
                                      _getInitials(widget.session.name),
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade600,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  _getInitials(widget.session.name),
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade600,
                                  ),
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
                      Text(
                        widget.session.subtitle ?? (widget.session.isOnline ? "Online" : "Replies during clinic hours"),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: widget.session.isOnline ? Colors.green : Colors.grey.shade500,
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
  
  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
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
                  "Next Visit: Schedule via Details",
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

  Widget _buildMessageBubble(ChatMessageModel msg, bool isMe) {
    final isFailed = msg.localStatus == ChatMessageLocalStatus.failed;
    final isPending = msg.localStatus == ChatMessageLocalStatus.pending;
    
    return GestureDetector(
      onTap: isFailed ? () => _retryFailedMessages() : null,
      child: Align(
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
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: widget.session.imageUrl != null
                    ? ClipOval(
                        child: Image.network(
                          widget.session.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(
                              _getInitials(widget.session.name),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade600,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          _getInitials(widget.session.name),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade600,
                          ),
                        ),
                      ),
              ),
            ],
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
              decoration: BoxDecoration(
                color: isMe 
                    ? (isFailed ? Colors.red.shade400 : Colors.blue.shade500) 
                    : Colors.white.withOpacity(0.8),
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
                  child: Opacity(
                    opacity: isPending ? 0.6 : 1.0,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            msg.content,
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
                                _formatTime(msg.createdAt),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: isMe ? Colors.blue.shade100 : Colors.grey.shade400,
                                ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 4),
                                if (isFailed)
                                  Icon(
                                    CupertinoIcons.exclamationmark_circle_fill,
                                    size: 12,
                                    color: Colors.white.withOpacity(0.8),
                                  )
                                else if (isPending)
                                  SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.blue.shade100,
                                      ),
                                    ),
                                  )
                                else if (msg.readAt != null)
                                  Icon(
                                    Icons.done_all,
                                    size: 12,
                                    color: Colors.green.shade300,
                                  )
                                else if (msg.deliveredAt != null)
                                  Icon(
                                    Icons.done_all,
                                    size: 12,
                                    color: Colors.blue.shade100,
                                  )
                                else
                                  Icon(
                                    Icons.done,
                                    size: 12,
                                    color: Colors.blue.shade100,
                                  ),
                              ],
                            ],
                          ),
                          if (isFailed && isMe)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Tap to retry',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ).animate().fade().slideY(begin: 0.1, end: 0, duration: 200.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    final bool canSend = !_accessRevoked && _threadId != null;
    
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
            onTap: canSend ? () => setState(() => _isMenuOpen = true) : null,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: canSend ? Colors.grey.shade100 : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.add, 
                color: canSend ? Colors.grey.shade600 : Colors.grey.shade400, 
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: canSend ? Colors.grey.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TextField(
                controller: _textController,
                enabled: canSend,
                decoration: InputDecoration(
                  hintText: canSend 
                      ? "Message ${widget.session.name}..."
                      : "Chat unavailable",
                  hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                style: GoogleFonts.inter(fontSize: 16),
                onSubmitted: canSend ? (val) => _handleSend(val) : null,
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: canSend && !_isSending 
                ? () => _handleSend(_textController.text) 
                : null,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: canSend ? Colors.blue : Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
              child: _isSending
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(CupertinoIcons.arrow_up, color: Colors.white, size: 18),
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
