import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'newspaper_article_screen.dart';
import 'package:guardian_angel_fyp/services/news_service.dart';

class NewspaperHomeScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? articles;
  
  const NewspaperHomeScreen({
    super.key,
    this.articles,
  });

  @override
  State<NewspaperHomeScreen> createState() => _NewspaperHomeScreenState();
}

class _NewspaperHomeScreenState extends State<NewspaperHomeScreen> {
  String _selectedCategory = 'For You';
  final List<String> _categories = ['For You', 'World', 'Business', 'Tech', 'Science', 'Health', 'Sports', 'Arts'];
  
  late List<Map<String, dynamic>> _articles;
  bool _isLoading = false;

  Future<void> _fetchArticles(String category) async {
    setState(() {
      _selectedCategory = category;
      _isLoading = true;
    });

    try {
      final articles = await NewsService().fetchDailyNews(category: category);
      if (mounted) {
        setState(() {
          _articles = articles;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching articles: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _articles = widget.articles ?? [
      {
        'id': '1',
        'title': 'Global Climate Summit Reaches Historic Agreement',
        'summary': 'World leaders have unanimously agreed to ambitious new carbon reduction targets, signaling a major shift in global environmental policy.',
        'category': 'World',
        'readingTime': '5 min read',
        'imageUrl': 'https://images.unsplash.com/photo-1621274790572-7c32596bc67f?auto=format&fit=crop&q=80&w=2000',
        'isHero': true,
      },
      {
        'id': '2',
        'title': 'The Future of AI in Healthcare',
        'summary': 'New breakthroughs in artificial intelligence are revolutionizing early disease detection and personalized treatment plans.',
        'category': 'Tech',
        'readingTime': '4 min read',
        'imageUrl': 'https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?auto=format&fit=crop&q=80&w=800',
        'isHero': false,
      },
      {
        'id': '3',
        'title': 'Sustainable Architecture Trends',
        'summary': 'Architects are increasingly turning to eco-friendly materials and energy-efficient designs to build the cities of tomorrow.',
        'category': 'Arts',
        'readingTime': '3 min read',
        'imageUrl': 'https://images.unsplash.com/photo-1518780664697-55e3ad937233?auto=format&fit=crop&q=80&w=800',
        'isHero': false,
      },
      {
        'id': '4',
        'title': 'SpaceX Launches New Satellite Constellation',
        'summary': 'The latest launch aims to provide high-speed internet coverage to remote areas across the globe.',
        'category': 'Science',
        'readingTime': '6 min read',
        'imageUrl': 'https://images.unsplash.com/photo-1516849841032-87cbac4d88f7?auto=format&fit=crop&q=80&w=800',
        'isHero': false,
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE, d MMMM').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7), // bgPrimary
      body: Column(
        children: [
          _buildTopNav(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MORNING EDITION',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF3C3C43).withOpacity(0.6), // textSecondary
                          letterSpacing: 1.5, // tracking-[0.15em]
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateStr,
                        style: GoogleFonts.playfairDisplay( // Serif font
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: Colors.black, // textPrimary
                          height: 1.1,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // Category Row
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = category == _selectedCategory;
                      return GestureDetector(
                        onTap: () => _fetchArticles(category),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.black : Colors.white, // actionPrimaryBg : bgSecondary
                            borderRadius: BorderRadius.circular(20),
                            border: isSelected ? null : Border.all(color: const Color(0xFF3C3C43).withOpacity(0.1)), // borderSubtle
                          ),
                          child: Text(
                            category,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : Colors.black, // actionPrimaryFg : textPrimary
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 32),

                // Articles
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_articles.isNotEmpty) ...[
                  _buildArticleCard(_articles[0], isHero: true),
                  const SizedBox(height: 24),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 1, // Using 1 column for mobile as per design, md:grid-cols-2 in React
                      mainAxisSpacing: 24,
                      childAspectRatio: 2.8, // Adjusted for horizontal card layout
                    ),
                    itemCount: _articles.length - 1,
                    itemBuilder: (context, index) {
                      return _buildArticleCard(_articles[index + 1], isHero: false);
                    },
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text(
                        'No articles found for $_selectedCategory',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF3C3C43).withOpacity(0.6),
                        ),
                      ),
                    ),
                  ),
                
                const SizedBox(height: 64),
                
                // Footer
                Center(
                  child: Column(
                    children: [
                      Text(
                        'GUARDIAN ANGEL EDITORIAL',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF3C3C43).withOpacity(0.3), // textTertiary
                          letterSpacing: 3.0, // tracking-[0.3em]
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildFooterDot(),
                          const SizedBox(width: 16),
                          _buildFooterDot(),
                          const SizedBox(width: 16),
                          _buildFooterDot(),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
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
        color: Colors.white.withOpacity(0.75), // surfaceGlass
        border: Border(bottom: BorderSide(color: const Color(0xFF3C3C43).withOpacity(0.1))), // borderSubtle
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back Button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: const Icon(CupertinoIcons.back, color: Color(0xFF007AFF)), // textLink
            ),
          ),
          
          // Title
          Expanded(
            child: Text(
              'Guardian Angel',
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay( // Serif italic
                fontSize: 17,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
                color: Colors.black, // textPrimary
              ),
            ),
          ),
          
          // Right Actions
          Row(
            children: [
              GestureDetector(
                onTap: () {}, // onTextSizeToggle
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  child: const Icon(CupertinoIcons.textformat_size, color: Color(0xFF007AFF)), // textLink
                ),
              ),
              GestureDetector(
                onTap: () {}, // onOpenSettings
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  child: const Icon(CupertinoIcons.settings, color: Color(0xFF007AFF)), // textLink
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildArticleCard(Map<String, dynamic> article, {required bool isHero}) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => NewspaperArticleScreen(article: article),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white, // surfacePrimary
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05), // shadow-ios approximation
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: isHero
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    child: SizedBox(
                      height: 240,
                      width: double.infinity,
                      child: Image.network(
                        article['imageUrl'],
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              article['category'].toString().toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF3C3C43).withOpacity(0.6), // textSecondary
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              ' • ${article['readingTime']}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF3C3C43).withOpacity(0.3), // textTertiary
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          article['title'],
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black, // textPrimary
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          article['summary'],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            color: const Color(0xFF3C3C43).withOpacity(0.6), // textSecondary
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: SizedBox(
                        width: 100,
                        height: 100,
                        child: Image.network(
                          article['imageUrl'],
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 16, 24, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Text(
                                article['category'].toString().toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF3C3C43).withOpacity(0.6), // textSecondary
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                ' • ${article['readingTime']}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF3C3C43).withOpacity(0.3), // textTertiary
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            article['title'],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black, // textPrimary
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFooterDot() {
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        shape: BoxShape.circle,
      ),
    );
  }
}
