import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:guardian_angel_fyp/services/news_service.dart';
import 'newspaper_home_screen.dart';

class NewspaperLoadingScreen extends StatefulWidget {
  const NewspaperLoadingScreen({super.key});

  @override
  State<NewspaperLoadingScreen> createState() => _NewspaperLoadingScreenState();
}

class _NewspaperLoadingScreenState extends State<NewspaperLoadingScreen> {
  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  Future<void> _loadNews() async {
    // Minimum delay to show animation
    final minDelay = Future.delayed(const Duration(seconds: 3));
    final newsFuture = NewsService().fetchDailyNews();
    
    try {
      final results = await Future.wait([minDelay, newsFuture]);
      final articles = results[1] as List<Map<String, dynamic>>;

      if (mounted) {
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(
            builder: (context) => NewspaperHomeScreen(articles: articles.isNotEmpty ? articles : null),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error loading news: $e');
      if (mounted) {
        // Fallback to mock data if error
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(builder: (context) => const NewspaperHomeScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7), // bgPrimary
      body: Padding(
        padding: const EdgeInsets.all(40.0), // p-10
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Spinner
              SizedBox(
                width: 40, // w-10
                height: 40, // h-10
                child: CircularProgressIndicator(
                  strokeWidth: 2, // border-2
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)), // border-t-[#007AFF]
                  backgroundColor: const Color(0xFF007AFF).withOpacity(0.2), // border-[#007AFF]/20
                ),
              ),
              const SizedBox(height: 32), // mb-8 (32px)

              // Text 1
              Text(
                'Preparing Morning Edition',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 20, // text-[20px]
                  fontWeight: FontWeight.bold, // font-bold
                  color: Colors.black, // textPrimary
                ),
              ),
              const SizedBox(height: 8), // space-y-2 (approx 8px)

              // Text 2
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240), // max-w-[240px]
                child: Text(
                  'Curating a peaceful reading experience for you.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 15, // text-[15px]
                    color: const Color(0xFF3C3C43).withOpacity(0.6), // textSecondary
                    height: 1.625, // leading-relaxed
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
