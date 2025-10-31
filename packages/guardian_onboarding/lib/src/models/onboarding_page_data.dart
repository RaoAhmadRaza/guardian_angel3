import 'package:flutter/widgets.dart';

/// Data model for a single onboarding page
class OnboardingPageData {
  final String title;
  final String description;
  final ImageProvider image;
  final String? buttonText; // Only shown on last page when provided

  const OnboardingPageData({
    required this.title,
    required this.description,
    required this.image,
    this.buttonText,
  });

  /// Convenience constructor for assets
  factory OnboardingPageData.fromAsset({
    required String title,
    required String description,
    required String assetPath,
    String? buttonText,
    AssetBundle? bundle,
    String? package,
  }) {
    return OnboardingPageData(
      title: title,
      description: description,
      image: AssetImage(assetPath, bundle: bundle, package: package),
      buttonText: buttonText,
    );
  }

  /// Convenience constructor for network images
  factory OnboardingPageData.fromNetwork({
    required String title,
    required String description,
    required String url,
    String? buttonText,
  }) {
    return OnboardingPageData(
      title: title,
      description: description,
      image: NetworkImage(url),
      buttonText: buttonText,
    );
  }
}
