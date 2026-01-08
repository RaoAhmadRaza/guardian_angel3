import 'dart:convert';
import 'package:http/http.dart' as http;

class NewsService {
  static const String _apiToken = 'DUZpYggJLNqcvMlNmVhTfD0Rg6DmzZ3vuRX0yevQ';
  static const String _baseUrl = 'https://api.thenewsapi.com/v1/news/all';

  Future<List<Map<String, dynamic>>> fetchDailyNews({String? category}) async {
    try {
      String apiCategories = 'general,health,science,tech,business';
      
      if (category != null && category != 'For You') {
        switch (category) {
          case 'World':
            apiCategories = 'general,politics';
            break;
          case 'Business':
            apiCategories = 'business';
            break;
          case 'Tech':
            apiCategories = 'tech';
            break;
          case 'Science':
            apiCategories = 'science';
            break;
          case 'Health':
            apiCategories = 'health';
            break;
          case 'Sports':
            apiCategories = 'sports';
            break;
          case 'Arts':
            apiCategories = 'entertainment';
            break;
          default:
            apiCategories = 'general';
        }
      }

      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'api_token': _apiToken,
        'language': 'en',
        'locale': 'us',
        'limit': '5',
        'categories': apiCategories
      });

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> articles = data['data'] ?? [];

        return articles.asMap().entries.map((entry) {
          final index = entry.key;
          final article = entry.value;
          
          return {
            'id': article['uuid'] ?? index.toString(),
            'title': article['title'] ?? 'No Title',
            'summary': article['description'] ?? article['snippet'] ?? 'No summary available.',
            'content': article['snippet'] ?? 'Full content not available via this API.', // TheNewsAPI free tier usually gives snippets
            'category': (article['categories'] as List?)?.firstOrNull?.toString().capitalize() ?? 'General',
            'readingTime': '4 min read', // Mocked as API doesn't provide this
            'imageUrl': article['image_url'] ?? 'https://via.placeholder.com/800',
            'isHero': index == 0, // First article is hero
            'date': article['published_at'] ?? DateTime.now().toIso8601String(),
          };
        }).toList();
      } else {
        throw Exception('Failed to load news: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching news: $e');
      // Return empty list or throw, depending on how we want to handle it.
      // For now, return empty list so the UI doesn't crash.
      return [];
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
