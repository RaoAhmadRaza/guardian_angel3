import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

class NewspaperArticleScreen extends StatefulWidget {
  final Map<String, dynamic> article;

  const NewspaperArticleScreen({
    super.key,
    required this.article,
  });

  @override
  State<NewspaperArticleScreen> createState() => _NewspaperArticleScreenState();
}

class _NewspaperArticleScreenState extends State<NewspaperArticleScreen> {
  bool _isPlaying = false;
  bool _isSaved = false;
  bool _isRead = false;
  String _fontSize = 'medium'; // medium, large, extra-large

  double get _bodyFontSize {
    switch (_fontSize) {
      case 'large':
        return 24.0;
      case 'extra-large':
        return 28.0;
      default:
        return 20.0;
    }
  }

  double get _bodyLineHeight {
    switch (_fontSize) {
      case 'extra-large':
        return 1.7;
      default:
        return 1.6;
    }
  }

  void _toggleListen() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  void _toggleSave() {
    setState(() {
      _isSaved = !_isSaved;
    });
  }

  void _toggleRead() {
    setState(() {
      _isRead = !_isRead;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Using light theme colors as per requirement to match React default
    // React: bgSecondary = bg-[#FFFFFF]
    const backgroundColor = Colors.white; 
    const textPrimary = Colors.black;
    const textSecondary = Color(0x993C3C43); // 60% opacity
    const accentColor = Color(0xFF007AFF);
    
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          Column(
            children: [
              _buildTopNav(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 192), // pb-48 = 192px
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 700),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Center(
                            child: Column(
                              children: [
                                Text(
                                  // Use current date or article date if available
                                  'MONDAY, 25 OCTOBER', 
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: textSecondary,
                                    letterSpacing: 2.6, // tracking-[0.2em] approx
                                  ),
                                ),
                                const SizedBox(height: 16), // mb-4
                                Text(
                                  widget.article['title'] ?? 'Article Title',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 36, // md:text-[44px] handled by responsiveness if needed, sticking to mobile base
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                    height: 1.1,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 32), // mb-8
                                Container(
                                  width: 64,
                                  height: 2,
                                  decoration: BoxDecoration(
                                    color: accentColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40), // mb-10 (header margin)

                          // Image
                          Container(
                            margin: const EdgeInsets.only(bottom: 48), // mb-12
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(32),
                              child: Image.network(
                                widget.article['imageUrl'] ?? 'https://via.placeholder.com/800',
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),

                          // Content
                          Text(
                            widget.article['summary'] != null 
                                ? "${widget.article['summary']}\n\nLorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.\n\nDuis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.\n\nSed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo."
                                : "Content placeholder...",
                            style: GoogleFonts.merriweather( // Using Merriweather for body serif
                              fontSize: _bodyFontSize,
                              height: _bodyLineHeight,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Dynamic Action Island
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: const Color(0xFF3C3C43).withOpacity(0.1),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Listen Button
                            Expanded(
                              child: GestureDetector(
                                onTap: _toggleListen,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                                  decoration: BoxDecoration(
                                    color: _isPlaying ? const Color(0xFFFF3B30) : Colors.black,
                                    borderRadius: BorderRadius.circular(100),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (_isPlaying ? const Color(0xFFFF3B30) : Colors.black).withOpacity(0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _isPlaying ? CupertinoIcons.stop_fill : CupertinoIcons.speaker_2_fill,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        _isPlaying ? 'Stop' : 'Listen',
                                        style: GoogleFonts.inter(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(width: 8),

                            // Action Buttons
                            Row(
                              children: [
                                _buildActionButton(
                                  icon: _isSaved ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark,
                                  isActive: _isSaved,
                                  activeColor: accentColor,
                                  onTap: _toggleSave,
                                ),
                                _buildActionButton(
                                  icon: CupertinoIcons.check_mark,
                                  isActive: _isRead,
                                  activeColor: const Color(0xFF34C759),
                                  onTap: _toggleRead,
                                ),
                                _buildActionButton(
                                  icon: CupertinoIcons.share,
                                  isActive: false,
                                  activeColor: accentColor,
                                  onTap: () {},
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopNav(BuildContext context) {
    return Container(
      height: 100, // Adjusted for status bar
      padding: const EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75),
        border: Border(bottom: BorderSide(color: const Color(0xFF3C3C43).withOpacity(0.1))),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back Button
              SizedBox(
                width: 48,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(shape: BoxShape.circle),
                      child: const Icon(CupertinoIcons.back, color: Color(0xFF007AFF)),
                    ),
                  ),
                ),
              ),
              
              // Title
              Expanded(
                child: Text(
                  widget.article['category'] ?? 'Category',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                    color: Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              
              // Right Actions
              SizedBox(
                width: 48,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () {
                      // Cycle font size for demo
                      setState(() {
                        if (_fontSize == 'medium') _fontSize = 'large';
                        else if (_fontSize == 'large') _fontSize = 'extra-large';
                        else _fontSize = 'medium';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(shape: BoxShape.circle),
                      child: const Icon(CupertinoIcons.textformat_size, color: Color(0xFF007AFF)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56, // p-4 equivalent approx
        height: 56,
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.1) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isActive ? activeColor : const Color(0xFF3C3C43).withOpacity(0.6),
          size: 24,
        ),
      ),
    );
  }
}
