import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

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
              'About',
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
            child: Column(
              children: [
                const SizedBox(height: 40),
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    CupertinoIcons.heart_fill,
                    size: 60,
                    color: Color(0xFF007AFF),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Guardian Angel',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Version 2.1.0 (Build 1042)',
                  style: TextStyle(
                    fontSize: 15,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        _buildListTile('Terms of Service', isDarkMode),
                        Divider(height: 1, indent: 16, color: isDarkMode ? Colors.grey[800] : Colors.grey[200]),
                        _buildListTile('Privacy Policy', isDarkMode),
                        Divider(height: 1, indent: 16, color: isDarkMode ? Colors.grey[800] : Colors.grey[200]),
                        _buildListTile('Open Source Licenses', isDarkMode, onTap: () {
                          showLicensePage(
                            context: context,
                            applicationName: 'Guardian Angel',
                            applicationVersion: '2.1.0',
                            applicationIcon: const Icon(Icons.health_and_safety),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Text(
                    'Guardian Angel is designed to help you monitor your health and stay connected with your loved ones. Our mission is to provide peace of mind through technology.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '© 2026 Guardian Angel Inc.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile(String title, bool isDarkMode, {VoidCallback? onTap}) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(CupertinoIcons.chevron_forward, size: 20, color: Colors.grey),
      onTap: onTap ?? () {},
    );
  }
}
