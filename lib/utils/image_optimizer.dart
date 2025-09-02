import 'package:flutter/material.dart';

/// Utility class for optimizing image loading in onboarding screens
class ImageOptimizer {
  /// Preload images for better performance
  static Future<void> preloadOnboardingImages(BuildContext context) async {
    const imageUrls = [
      "https://images.unsplash.com/photo-1551836022-deb4988cc6c0?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=1000&q=80",
      "https://images.unsplash.com/photo-1516387938699-a93567ec168e?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=1000&q=80",
      "https://images.unsplash.com/photo-1584463027078-b05a8497db44?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=1000&q=80",
      "https://images.unsplash.com/photo-1559757148-5c350d0d3c56?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=1000&q=80",
    ];

    for (final url in imageUrls) {
      try {
        await precacheImage(NetworkImage(url), context);
      } catch (e) {
        // Handle precache errors gracefully
        debugPrint('Failed to precache image: $url - $e');
      }
    }
  }

  /// Get optimized image URL with specific dimensions
  static String getOptimizedImageUrl(String baseUrl,
      {int? width, int? height, int quality = 80}) {
    final uri = Uri.parse(baseUrl);

    if (uri.host.contains('unsplash.com')) {
      final params = Map<String, String>.from(uri.queryParameters);

      if (width != null) params['w'] = width.toString();
      if (height != null) params['h'] = height.toString();
      params['q'] = quality.toString();
      params['fm'] = 'webp'; // Use WebP for better compression

      return uri.replace(queryParameters: params).toString();
    }

    return baseUrl;
  }

  /// Get fallback image widget for error states
  static Widget getFallbackImage({
    required BuildContext context,
    String? title,
    IconData? icon,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon ?? Icons.image_outlined,
            size: 80,
            color: Colors.white.withOpacity(0.6),
          ),
          const SizedBox(height: 16),
          Text(
            title ?? 'Image',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Image credits and attribution
class ImageAttribution {
  static const Map<String, String> credits = {
    "family_protection": "Photo by Nappy on Unsplash",
    "location_tracking": "Photo by Henry Perks on Unsplash",
    "emergency_response": "Photo by Online Marketing on Unsplash",
    "health_monitoring": "Photo by Hush Naidoo Jade Photography on Unsplash",
  };

  /// Get attribution text for an image
  static String getAttribution(String imageKey) {
    return credits[imageKey] ?? "Stock photo";
  }

  /// Show attribution dialog (optional for compliance)
  static void showAttributionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Image Credits'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: credits.entries
              .map((entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      entry.value,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ))
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
