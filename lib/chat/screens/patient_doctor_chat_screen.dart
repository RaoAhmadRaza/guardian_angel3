/// PatientDoctorChatScreen - Chat screen for Patient ↔ Doctor communication.
///
/// This screen displays chat between a Patient and Doctor.
/// It ENFORCES doctor relationship validation before allowing any interaction.
///
/// Features:
/// - Real-time messages from Hive stream
/// - Optimistic send (immediate local display)
/// - Automatic access revocation detection
/// - Offline-first with Firestore mirroring
/// - Visual distinction from caregiver chat (different header gradient)
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/chat_message_model.dart';
import '../services/doctor_chat_service.dart';
import '../providers/doctor_chat_provider.dart';
import '../../theme/colors.dart' show AppColors;

/// Individual chat screen between Patient and Doctor.
class PatientDoctorChatScreen extends ConsumerStatefulWidget {
  final String threadId;
  final String otherUserName;
  final String? otherUserAvatarUrl;
  final String? specialty; // Doctor's specialty (if patient is viewing)
  final String? organization; // Doctor's organization

  const PatientDoctorChatScreen({
    super.key,
    required this.threadId,
    required this.otherUserName,
    this.otherUserAvatarUrl,
    this.specialty,
    this.organization,
  });

  @override
  ConsumerState<PatientDoctorChatScreen> createState() => _PatientDoctorChatScreenState();
}

class _PatientDoctorChatScreenState extends ConsumerState<PatientDoctorChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  bool _isSending = false;
  bool _accessRevoked = false;
  StreamSubscription? _accessSubscription;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    _accessSubscription?.cancel();
    DoctorChatService.instance.stopListeningForIncomingDoctorMessages(widget.threadId);
    super.dispose();
  }

  Future<void> _initChat() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Start listening for incoming messages
    DoctorChatService.instance.startListeningForIncomingDoctorMessages(
      threadId: widget.threadId,
      currentUid: uid,
    );

    // Mark thread as read
    await DoctorChatService.instance.markDoctorThreadAsRead(
      threadId: widget.threadId,
      currentUid: uid,
    );

    // Watch for access revocation
    _accessSubscription = DoctorChatService.instance.watchDoctorChatAccessForUser(uid).listen((allowed) {
      if (!allowed && mounted) {
        setState(() => _accessRevoked = true);
        _showAccessRevokedDialog();
      }
    });
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

  Future<void> _sendMessage() async {
    final content = _textController.text.trim();
    if (content.isEmpty || _isSending || _accessRevoked) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSending = true);
    _textController.clear();
    HapticFeedback.lightImpact();

    final result = await DoctorChatService.instance.sendDoctorTextMessage(
      threadId: widget.threadId,
      currentUid: uid,
      content: content,
    );

    if (mounted) {
      setState(() => _isSending = false);

      if (!result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Failed to send message'),
            backgroundColor: Colors.red,
          ),
        );
        // Restore text if send failed
        _textController.text = content;
      } else {
        // Scroll to bottom after sending
        _scrollToBottom();
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final messagesAsync = ref.watch(doctorChatMessagesProvider(widget.threadId));

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFFDFDFD),
      body: Column(
        children: [
          // Header with doctor-specific gradient
          _buildHeader(isDark),

          // Access revoked banner
          if (_accessRevoked) _buildAccessRevokedBanner(isDark),

          // Messages
          Expanded(
            child: messagesAsync.when(
              data: (messages) => _buildMessagesList(messages, isDark),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),

          // Input bar
          _buildInputBar(isDark),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    // Use a different gradient for doctor chat to visually distinguish it
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 12,
        right: 12,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        // Doctor chat uses a teal/green gradient to distinguish from caregiver chat
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF0D9488), const Color(0xFF14B8A6)]
              : [const Color(0xFF5EEAD4), const Color(0xFF99F6E4)],
        ),
      ),
      child: Row(
        children: [
          // Back button
          CupertinoButton(
            padding: const EdgeInsets.all(6),
            minSize: 0,
            onPressed: () => Navigator.of(context).pop(),
            child: const Icon(CupertinoIcons.back, color: Color(0xFF0F172A)),
          ),
          const SizedBox(width: 8),

          // Avatar with medical icon overlay
          Stack(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: widget.otherUserAvatarUrl != null
                      ? Image.network(
                          widget.otherUserAvatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildAvatarFallback(),
                        )
                      : _buildAvatarFallback(),
                ),
              ),
              // Medical badge
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF059669),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Icon(
                    CupertinoIcons.heart_fill,
                    size: 9,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Name, specialty, and status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUserName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (widget.specialty != null)
                  Text(
                    widget.specialty!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                Text(
                  _accessRevoked ? 'Access revoked' : 'Available',
                  style: TextStyle(
                    fontSize: 12,
                    color: _accessRevoked
                        ? Colors.red
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          // Options button
          CupertinoButton(
            padding: const EdgeInsets.all(6),
            minSize: 0,
            onPressed: () => _showOptionsSheet(),
            child: const Icon(CupertinoIcons.ellipsis_vertical, color: Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback() {
    return Container(
      color: const Color(0xFFD1FAE5),
      child: Center(
        child: Text(
          widget.otherUserName.isNotEmpty ? widget.otherUserName[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF059669),
          ),
        ),
      ),
    );
  }

  Widget _buildAccessRevokedBanner(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.red.withOpacity(0.1),
      child: Row(
        children: [
          const Icon(CupertinoIcons.exclamationmark_triangle, color: Colors.red, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Doctor chat access has been revoked. You cannot send new messages.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.red.shade300 : Colors.red.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(List<ChatMessageModel> messages, bool isDark) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.heart_circle,
              size: 64,
              color: isDark ? Colors.white24 : Colors.black12,
            ),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a conversation with your doctor',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white38 : Colors.black26,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isMe = message.senderId == uid;
        final showTimestamp = index == 0 ||
            messages[index].createdAt.difference(messages[index - 1].createdAt).inMinutes > 10;

        return _buildMessageBubble(message, isMe, showTimestamp, isDark);
      },
    );
  }

  Widget _buildMessageBubble(
    ChatMessageModel message,
    bool isMe,
    bool showTimestamp,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (showTimestamp)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                _formatTimestamp(message.createdAt),
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ),
          ),

        Container(
          margin: EdgeInsets.only(
            top: 4,
            bottom: 4,
            left: isMe ? 64 : 0,
            right: isMe ? 0 : 64,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            // Use teal colors for doctor chat bubbles (when sent by me)
            color: isMe
                ? (isDark ? const Color(0xFF0D9488) : const Color(0xFF14B8A6))
                : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMe ? 18 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                message.content,
                style: TextStyle(
                  fontSize: 15,
                  color: isMe
                      ? Colors.white
                      : (isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: isMe
                          ? Colors.white70
                          : (isDark ? Colors.white38 : Colors.black38),
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    _buildStatusIcon(message, isDark),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIcon(ChatMessageModel message, bool isDark) {
    IconData icon;
    Color color;

    if (message.localStatus == ChatMessageLocalStatus.pending) {
      icon = CupertinoIcons.clock;
      color = Colors.white54;
    } else if (message.localStatus == ChatMessageLocalStatus.failed) {
      icon = CupertinoIcons.exclamationmark_circle;
      color = Colors.red;
    } else if (message.isRead) {
      icon = CupertinoIcons.checkmark_seal_fill;
      color = Colors.white;
    } else if (message.isDelivered) {
      icon = CupertinoIcons.checkmark_alt_circle_fill;
      color = Colors.white70;
    } else {
      icon = CupertinoIcons.checkmark;
      color = Colors.white70;
    }

    return Icon(icon, size: 14, color: color);
  }

  Widget _buildInputBar(bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        children: [
          // Attachment button (placeholder)
          CupertinoButton(
            padding: const EdgeInsets.all(8),
            minSize: 0,
            onPressed: _accessRevoked ? null : () {},
            child: Icon(
              CupertinoIcons.plus_circle,
              color: _accessRevoked
                  ? Colors.grey
                  : (isDark ? Colors.white54 : const Color(0xFF64748B)),
              size: 26,
            ),
          ),

          // Text input
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _textController,
                focusNode: _inputFocusNode,
                enabled: !_accessRevoked,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: _accessRevoked ? 'Chat disabled' : 'Message your doctor...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),

          // Send button with teal gradient for doctor chat
          CupertinoButton(
            padding: const EdgeInsets.all(8),
            minSize: 0,
            onPressed: _accessRevoked || _isSending ? null : _sendMessage,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _accessRevoked
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
                      ),
                color: _accessRevoked ? Colors.grey : null,
              ),
              child: Icon(
                _isSending ? CupertinoIcons.clock : CupertinoIcons.arrow_up,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showOptionsSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              // TODO: View doctor profile
            },
            child: const Text('View Doctor Profile'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              // TODO: View medical records shared
            },
            child: const Text('Shared Medical Records'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              // TODO: Mute notifications
            },
            child: const Text('Mute Notifications'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dt.year, dt.month, dt.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
