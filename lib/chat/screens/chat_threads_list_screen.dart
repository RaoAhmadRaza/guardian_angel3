/// ChatThreadsListScreen - Displays list of authorized chat threads.
///
/// This screen shows ONLY chat threads the user is authorized to access.
/// Authorization is based on:
/// 1. Active relationship with the other participant
/// 2. Chat permission granted in the relationship
///
/// Features:
/// - Real-time thread updates from Hive stream
/// - Automatic filtering of unauthorized threads
/// - Unread count display
/// - Last message preview
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../chat.dart';
import '../../theme/colors.dart' show AppColors;

/// Provider for user display names (fetched from relationships or user profiles)
/// For now, we'll use a simple implementation
final threadParticipantNamesProvider = FutureProvider.family<String, ChatThreadModel>(
  (ref, thread) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 'Unknown';

    // Determine who the "other" user is
    final otherUid = thread.patientId == uid ? thread.caregiverId : thread.patientId;

    // TODO: Fetch from user profile service
    // For now, return a placeholder
    return otherUid.isNotEmpty ? 'User ${otherUid.substring(0, 6)}...' : 'Unknown';
  },
);

/// ChatThreadsListScreen widget.
class ChatThreadsListScreen extends ConsumerWidget {
  const ChatThreadsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final threadsAsync = ref.watch(authorizedChatThreadsProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFFDFDFD),
      body: Column(
        children: [
          // Header
          _buildHeader(context, isDark),

          // Access status check
          _buildAccessStatus(ref, isDark),

          // Threads list
          Expanded(
            child: threadsAsync.when(
              data: (threads) => _buildThreadsList(context, ref, threads, isDark),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _buildError(context, e, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 16,
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
          const SizedBox(width: 12),

          // Title
          const Expanded(
            child: Text(
              'Messages',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ),

          // Search (placeholder)
          CupertinoButton(
            padding: const EdgeInsets.all(6),
            minSize: 0,
            onPressed: () {},
            child: const Icon(CupertinoIcons.search, color: Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessStatus(WidgetRef ref, bool isDark) {
    final accessAsync = ref.watch(chatAccessProvider);

    return accessAsync.when(
      data: (ChatAccessStatus result) {
        if (!result.hasAccess) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.orange.withOpacity(0.1),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.exclamationmark_circle,
                  color: Colors.orange.shade700,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    result.reason ?? 'No active relationships with chat permission.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.orange.shade300 : Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildThreadsList(
    BuildContext context,
    WidgetRef ref,
    List<ChatThreadModel> threads,
    bool isDark,
  ) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (threads.isEmpty) {
      return _buildEmptyState(context, isDark);
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(authorizedChatThreadsProvider);
      },
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: threads.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          indent: 80,
          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE2E8F0),
        ),
        itemBuilder: (context, index) {
          final thread = threads[index];
          return _ChatThreadTile(
            thread: thread,
            currentUid: uid ?? '',
            isDark: isDark,
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? const Color(0xFF2C2C2E)
                    : const Color(0xFFF1F5F9),
              ),
              child: Icon(
                CupertinoIcons.chat_bubble_2,
                size: 36,
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No conversations yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Chat with your caregivers or patients here.\n'
              'You need an active relationship to start chatting.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            _buildStartChatButton(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildStartChatButton(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        onPressed: () {
          // TODO: Navigate to relationship/contact list to start new chat
        },
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.plus, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'Start New Chat',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, Object error, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 48,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load conversations',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual chat thread tile widget.
class _ChatThreadTile extends ConsumerWidget {
  final ChatThreadModel thread;
  final String currentUid;
  final bool isDark;

  const _ChatThreadTile({
    required this.thread,
    required this.currentUid,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameAsync = ref.watch(threadParticipantNamesProvider(thread));
    final otherName = nameAsync.maybeWhen(
      data: (name) => name,
      orElse: () => 'Loading...',
    );

    // Get unread count
    final unreadCount = thread.unreadCount;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => _navigateToChat(context, otherName),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            _buildAvatar(otherName),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          otherName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.w500,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatLastMessageTime(thread.lastMessageAt),
                        style: TextStyle(
                          fontSize: 13,
                          color: unreadCount > 0
                              ? const Color(0xFF3B82F6)
                              : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          thread.lastMessagePreview ?? 'No messages yet',
                          style: TextStyle(
                            fontSize: 14,
                            color: unreadCount > 0
                                ? (isDark ? Colors.white70 : const Color(0xFF475569))
                                : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                            fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String name) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.guardianAngelSkyGradient,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
    );
  }

  void _navigateToChat(BuildContext context, String otherName) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => PatientCaregiverChatScreen(
          threadId: thread.id,
          otherUserName: otherName,
        ),
      ),
    );
  }

  String _formatLastMessageTime(DateTime? dt) {
    if (dt == null) return '';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dt.year, dt.month, dt.day);

    if (messageDate == today) {
      // Today - show time
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else if (now.difference(dt).inDays < 7) {
      // This week - show day name
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dt.weekday - 1];
    } else {
      // Older - show date
      return '${dt.day}/${dt.month}';
    }
  }
}
