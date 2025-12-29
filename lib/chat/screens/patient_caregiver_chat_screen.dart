/// PatientCaregiverChatScreen - Chat screen with relationship validation.
///
/// This screen displays chat between a Patient and Caregiver.
/// It ENFORCES relationship validation before allowing any interaction.
///
/// Features:
/// - Real-time messages from Hive stream
/// - Optimistic send (immediate local display)
/// - Automatic access revocation detection
/// - Offline-first with Firestore mirroring
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../chat.dart';
import '../../theme/colors.dart' show AppColors;

/// Individual chat screen between Patient and Caregiver.
class PatientCaregiverChatScreen extends ConsumerStatefulWidget {
  final String threadId;
  final String otherUserName;
  final String? otherUserAvatarUrl;

  const PatientCaregiverChatScreen({
    super.key,
    required this.threadId,
    required this.otherUserName,
    this.otherUserAvatarUrl,
  });

  @override
  ConsumerState<PatientCaregiverChatScreen> createState() => _PatientCaregiverChatScreenState();
}

class _PatientCaregiverChatScreenState extends ConsumerState<PatientCaregiverChatScreen> {
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
    ChatService.instance.stopListeningForIncomingMessages(widget.threadId);
    super.dispose();
  }

  Future<void> _initChat() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Start listening for incoming messages
    ChatService.instance.startListeningForIncomingMessages(
      threadId: widget.threadId,
      currentUid: uid,
    );

    // Mark thread as read
    await ChatService.instance.markThreadAsRead(
      threadId: widget.threadId,
      currentUid: uid,
    );

    // Watch for access revocation
    _accessSubscription = ChatService.instance.watchChatAccessForUser(uid).listen((allowed) {
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
        title: const Text('Chat Access Revoked'),
        content: const Text(
          'Your relationship has been revoked or chat permission has been removed. '
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

    final result = await ChatService.instance.sendTextMessage(
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
    final messagesAsync = ref.watch(chatMessagesProvider(widget.threadId));

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFFDFDFD),
      body: Column(
        children: [
          // Header
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
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 12,
        right: 12,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        gradient: AppColors.guardianAngelSkyGradient,
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

          // Avatar
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
          const SizedBox(width: 12),

          // Name and status
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
                Text(
                  _accessRevoked ? 'Access revoked' : 'Online',
                  style: TextStyle(
                    fontSize: 13,
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
      color: const Color(0xFFE2E8F0),
      child: Center(
        child: Text(
          widget.otherUserName.isNotEmpty ? widget.otherUserName[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
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
              'Chat access has been revoked. You cannot send new messages.',
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
              CupertinoIcons.chat_bubble_2,
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
              'Send a message to start the conversation',
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
            color: isMe
                ? (isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB))
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
                  hintText: _accessRevoked ? 'Chat disabled' : 'Message...',
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

          // Send button
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
                        colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
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
              // TODO: View profile
            },
            child: const Text('View Profile'),
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
