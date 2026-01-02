import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : const Color(0xFFF2F2F7),
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            backgroundColor: isDarkMode ? Colors.black : const Color(0xFFF2F2F7),
            title: Text(
              'Help & Support',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: isDarkMode ? Colors.white : Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('CONTACT US', isDarkMode),
                  Container(
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        _buildContactTile('Email Support', 'support@guardianangel.com', CupertinoIcons.mail, isDarkMode),
                        Divider(height: 1, indent: 60, color: isDarkMode ? Colors.grey[800] : Colors.grey[200]),
                        _buildContactTile('Call Support', '+1 (800) 123-4567', CupertinoIcons.phone, isDarkMode),
                        Divider(height: 1, indent: 60, color: isDarkMode ? Colors.grey[800] : Colors.grey[200]),
                        _buildContactTile('Live Chat', 'Chat with a support agent', CupertinoIcons.chat_bubble_2, isDarkMode),
                      ],
                    ),
                  ),
                  
                  _buildSectionHeader('FREQUENTLY ASKED QUESTIONS', isDarkMode),
                  Container(
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        _buildExpansionTile(
                          context,
                          'How do I add a guardian?',
                          'Go to Settings > My Guardians and tap the "Add Guardian" button. You can invite them via email or phone number.',
                          isDarkMode,
                          isFirst: true,
                        ),
                        Divider(height: 1, indent: 16, color: isDarkMode ? Colors.grey[800] : Colors.grey[200]),
                        _buildExpansionTile(
                          context,
                          'How does fall detection work?',
                          'The app uses sensors in your connected wearable device to detect sudden falls. If a fall is detected, it will alert your emergency contacts.',
                          isDarkMode,
                        ),
                        Divider(height: 1, indent: 16, color: isDarkMode ? Colors.grey[800] : Colors.grey[200]),
                        _buildExpansionTile(
                          context,
                          'Can I change my health thresholds?',
                          'Yes, navigate to Settings > Health Thresholds to adjust your heart rate limits and fall detection sensitivity.',
                          isDarkMode,
                        ),
                        Divider(height: 1, indent: 16, color: isDarkMode ? Colors.grey[800] : Colors.grey[200]),
                        _buildExpansionTile(
                          context,
                          'Is my data secure?',
                          'We use industry-standard encryption to protect your personal and health data. You can read more in our Privacy Policy.',
                          isDarkMode,
                        ),
                        Divider(height: 1, indent: 16, color: isDarkMode ? Colors.grey[800] : Colors.grey[200]),
                        _buildExpansionTile(
                          context,
                          'How do I pair my watch?',
                          'Go to Settings > My Device and follow the on-screen instructions to pair your compatible wearable device.',
                          isDarkMode,
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildContactTile(String title, String subtitle, IconData icon, bool isDarkMode) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF007AFF)),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: isDarkMode ? Colors.white : Colors.black,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
        ),
      ),
      trailing: const Icon(CupertinoIcons.chevron_forward, size: 20, color: Colors.grey),
      onTap: () {},
    );
  }

  Widget _buildExpansionTile(BuildContext context, String title, String content, bool isDarkMode, {bool isFirst = false, bool isLast = false}) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isDarkMode ? Colors.white : Colors.black,
            fontSize: 15,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              content,
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
