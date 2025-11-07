import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'theme/colors.dart' show AppColors;
import 'package:animated_notch_bottom_bar/animated_notch_bottom_bar/animated_notch_bottom_bar.dart';

/// Chat list screen showing active users and recent conversations
/// Implements full light/dark theme support per UI analysis documentation
class ChatScreenNew extends StatefulWidget {
  const ChatScreenNew({super.key});

  @override
  State<ChatScreenNew> createState() => _ChatScreenNewState();
}

class _ChatScreenNewState extends State<ChatScreenNew> {
  /// Controller to handle bottom nav bar
  late NotchBottomBarController _controller;
  int _currentIndex = 1; // Start at Chat tab (index 1)

  @override
  void initState() {
    super.initState();
    _controller = NotchBottomBarController(index: _currentIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Mock data for active users (horizontal scrollable section)
  final List<Map<String, dynamic>> activeUsers = [
    {
      'name': 'Joy',
      'avatar': 'https://i.pravatar.cc/150?img=33',
      'color': const Color(0xFF4DD4E8)
    },
    {
      'name': 'Sai',
      'avatar': 'https://i.pravatar.cc/150?img=45',
      'color': const Color(0xFF7CDAA5)
    },
    {
      'name': 'Vysh',
      'avatar': 'https://i.pravatar.cc/150?img=47',
      'color': const Color(0xFFD94D8C)
    },
    {
      'name': 'Jay',
      'avatar': 'https://i.pravatar.cc/150?img=12',
      'color': const Color(0xFF6B5FED)
    },
  ];

  // Mock data for chat conversations
  final List<Map<String, dynamic>> chats = [
    {
      'name': 'Vysh',
      'message': 'Hey, what\'s up?',
      'time': '12:42 PM',
      'avatar': 'https://i.pravatar.cc/150?img=47',
      'unreadCount': 1,
      'isRead': false,
    },
    {
      'name': 'Jay',
      'message': 'Vyshnavi',
      'time': '11:56 AM',
      'avatar': 'https://i.pravatar.cc/150?img=12',
      'unreadCount': 0,
      'isRead': true,
      'hasCheckMark': true,
    },
    {
      'name': 'Sai',
      'message': 'Vyshnavi',
      'time': 'Today',
      'avatar': 'https://i.pravatar.cc/150?img=45',
      'unreadCount': 0,
      'isRead': false,
    },
    {
      'name': 'Joy',
      'message': 'Vyshnavi',
      'time': 'Yesterday',
      'avatar': 'https://i.pravatar.cc/150?img=33',
      'unreadCount': 0,
      'isRead': true,
      'hasDoubleCheck': true,
    },
    {
      'name': 'Tejas',
      'message': 'Vyshnavi',
      'time': '03/08/2025',
      'avatar': 'https://i.pravatar.cc/150?img=56',
      'unreadCount': 0,
      'isRead': true,
      'hasDoubleCheck': true,
      'isDelivered': true,
    },
    {
      'name': 'Bhanu',
      'message': 'Vyshnavi',
      'time': '01/08/2025',
      'avatar': 'https://i.pravatar.cc/150?img=43',
      'unreadCount': 0,
      'isRead': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDarkMode = brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF1A1A1A)
          : const Color(0xFFFDFDFD),
      extendBody: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: isDarkMode
              ? AppColors.getPrimaryGradient(Brightness.dark)
              : AppColors.getPrimaryGradient(Brightness.light),
        ),
        child: Column(
          children: [
            // Header section with gradient background
            _buildHeader(isDarkMode),
        
            // Chat list section
            Expanded(
              child: _buildChatList(isDarkMode),
            ),
          ],
        ),
      ),
      // Bottom navigation bar positioned at the absolute bottom (no wrapper container)
      bottomNavigationBar: AnimatedNotchBottomBar(
        notchBottomBarController: _controller,
        color: isDarkMode
            ? const Color(0xFF2C2C2E) // match NextScreen for consistency
            : const Color(0xFFFDFDFD),
        showLabel: true,
        textOverflow: TextOverflow.visible,
        maxLine: 1,
        shadowElevation: isDarkMode ? 8 : 5,
        kBottomRadius: 28.0,
        notchColor: isDarkMode
            ? const Color(0xFF3C3C3E)
            : const Color(0xFF475569),
        removeMargins: false,
        bottomBarWidth: 500,
        showShadow: true,
        durationInMilliSeconds: 220,
        itemLabelStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: isDarkMode
              ? const Color(0xFF8E8E93)
              : const Color(0xFF475569),
        ),
        elevation: isDarkMode ? 12 : 8,
        bottomBarItems: [
            BottomBarItem(
              inActiveItem: Icon(
                CupertinoIcons.house,
                color: isDarkMode
                    ? const Color(0xFF8E8E93)
                    : const Color(0xFF475569).withOpacity(0.6),
              ),
              activeItem: Icon(
                CupertinoIcons.house_fill,
                color: isDarkMode ? const Color(0xFFFFFFFF) : const Color(0xFF0F172A),
              ),
              itemLabel: 'Home',
            ),
            BottomBarItem(
              inActiveItem: Icon(
                CupertinoIcons.chat_bubble,
                color: isDarkMode
                    ? const Color(0xFF8E8E93)
                    : const Color(0xFF475569).withOpacity(0.6),
              ),
              activeItem: Icon(
                CupertinoIcons.chat_bubble_fill,
                color: isDarkMode ? const Color(0xFFFFFFFF) : const Color(0xFF0F172A),
              ),
              itemLabel: 'Chat',
            ),
            BottomBarItem(
              inActiveItem: Icon(
                CupertinoIcons.lightbulb,
                color: isDarkMode
                    ? const Color(0xFF8E8E93)
                    : const Color(0xFF475569).withOpacity(0.6),
              ),
              activeItem: Icon(
                CupertinoIcons.lightbulb_fill,
                color: isDarkMode ? const Color(0xFFFFFFFF) : const Color(0xFF0F172A),
              ),
              itemLabel: 'Automation',
            ),
            BottomBarItem(
              inActiveItem: Icon(
                CupertinoIcons.gear,
                color: isDarkMode
                    ? const Color(0xFF8E8E93)
                    : const Color(0xFF475569).withOpacity(0.6),
              ),
              activeItem: Icon(
                CupertinoIcons.gear_solid,
                color: isDarkMode ? const Color(0xFFFFFFFF) : const Color(0xFF0F172A),
              ),
              itemLabel: 'Settings',
            ),
          ],
          onTap: (index) {
            HapticFeedback.lightImpact();
            _controller.jumpTo(index);
            setState(() {
              _currentIndex = index;
            });
            // TODO: Navigate to respective screens based on index
            // 0: Home, 1: Chat, 2: Automation, 3: Settings
          },
          kIconSize: 24.0,
        ),
      // Floating action button for new chat
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          // TODO: Navigate to new chat screen
        },
        backgroundColor: isDarkMode
            ? const Color(0xFF2C2C2E)
            : const Color(0xFF0F172A),
        elevation: isDarkMode ? 8 : 6,
        child: Icon(
          Icons.add,
          color: isDarkMode ? Colors.white : const Color(0xFFFDFDFD),
          size: 28,
        ),
      ),
    );
  }

  /// Build header section with gradient background and active users
  Widget _buildHeader(bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDarkMode
              ? [
                  const Color(0xFF2C2C2E),
                  const Color(0xFF1C1C1E),
                ]
              : [
                  const Color(0xFFFAD961),
                  const Color(0xFFF6C23A),
                ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: isDarkMode
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: const Color(0xFF475569).withOpacity(0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Text(
              'Chats',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.5,
                height: 1.1,
              ),
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.08)
                    : Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDarkMode
                      ? const Color(0xFF3C3C3E)
                      : AppColors.lightBorder,
                  width: 1,
                ),
                boxShadow: isDarkMode
                    ? []
                    : [
                        BoxShadow(
                          color: const Color(0xFF475569).withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.search,
                    color: isDarkMode
                        ? const Color(0xFF8E8E93)
                        : AppColors.lightTextSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Search',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDarkMode
                          ? const Color(0xFF8E8E93)
                          : AppColors.lightTextPlaceholder,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Active users section
          _buildActiveUsersSection(isDarkMode),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// Build "Active" label with green indicator and horizontal scrollable user avatars
  Widget _buildActiveUsersSection(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "Active" label with green dot
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Row(
            children: [
              Text(
                'Active',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981), // Green active indicator
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Horizontal scrollable active users
        SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: activeUsers.length,
            itemBuilder: (context, index) {
              final user = activeUsers[index];
              return _buildActiveUserAvatar(
                name: user['name'],
                avatarUrl: user['avatar'],
                backgroundColor: user['color'],
                isDarkMode: isDarkMode,
              );
            },
          ),
        ),
      ],
    );
  }

  /// Build individual active user avatar with name
  Widget _buildActiveUserAvatar({
    required String name,
    required String avatarUrl,
    required Color backgroundColor,
    required bool isDarkMode,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDarkMode
                    ? const Color(0xFF3C3C3E)
                    : Colors.white.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: isDarkMode
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: backgroundColor.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: ClipOval(
              child: Image.network(
                avatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback to colored circle with initial
                  return Center(
                    child: Text(
                      name[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.9)
                  : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Build scrollable chat list with theme-aware styling
  Widget _buildChatList(bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF1C1C1E)
            : const Color(0xFFFDFDFD),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8),
        itemCount: chats.length,
        itemBuilder: (context, index) {
          final chat = chats[index];
          return _buildChatListItem(
            name: chat['name'],
            message: chat['message'],
            time: chat['time'],
            avatarUrl: chat['avatar'],
            unreadCount: chat['unreadCount'],
            isRead: chat['isRead'],
            hasCheckMark: chat['hasCheckMark'] ?? false,
            hasDoubleCheck: chat['hasDoubleCheck'] ?? false,
            isDelivered: chat['isDelivered'] ?? false,
            isDarkMode: isDarkMode,
          );
        },
      ),
    );
  }

  /// Build individual chat list item with theme-aware colors and glassmorphism
  Widget _buildChatListItem({
    required String name,
    required String message,
    required String time,
    required String avatarUrl,
    required int unreadCount,
    required bool isRead,
    required bool isDarkMode,
    bool hasCheckMark = false,
    bool hasDoubleCheck = false,
    bool isDelivered = false,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        // TODO: Navigate to conversation screen
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDarkMode
              ? const Color(0xFF2C2C2E)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDarkMode
                ? const Color(0xFF3C3C3E)
                : AppColors.lightBorder,
            width: 1,
          ),
          boxShadow: isDarkMode
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: const Color(0xFF475569).withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDarkMode
                      ? const Color(0xFF3C3C3E)
                      : AppColors.lightBorder,
                  width: 1,
                ),
              ),
              child: ClipOval(
                child: Image.network(
                  avatarUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: isDarkMode
                          ? const Color(0xFF3C3C3E)
                          : const Color(0xFFF5F5F7),
                      child: Center(
                        child: Text(
                          name[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: isDarkMode
                                ? const Color(0xFF8E8E93)
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(width: 14),

            // Name and message
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDarkMode
                          ? Colors.white
                          : const Color(0xFF0F172A),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Check marks for sent messages
                      if (hasCheckMark || hasDoubleCheck || isDelivered) ...[
                        Icon(
                          hasDoubleCheck || isDelivered
                              ? CupertinoIcons.checkmark_alt_circle_fill
                              : CupertinoIcons.checkmark_alt,
                          size: 14,
                          color: isDelivered
                              ? const Color(0xFF10B981)
                              : isDarkMode
                                  ? const Color(0xFF8E8E93)
                                  : AppColors.lightTextTertiary,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          message,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.7)
                                : AppColors.lightTextSecondary,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Time and unread badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode
                        ? const Color(0xFF8E8E93)
                        : AppColors.lightTextTertiary,
                  ),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFAD961),
                          Color(0xFFF6C23A),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFAD961).withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Center(
                      child: Text(
                        unreadCount.toString(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
