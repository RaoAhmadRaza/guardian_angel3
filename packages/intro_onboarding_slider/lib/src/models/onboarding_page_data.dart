import 'package:flutter/widgets.dart';

/// Data model for a single onboarding page in the onboarding slider.
///
/// Provide [title], [description], and an [image] provider. Optionally, set
/// [buttonText] to show a primary button on the last page.
class OnboardingPageData {
  final String title;
  final String description;
  final ImageProvider? image;
  final String? buttonText; // Only shown on last page when provided

  /// If provided, a local lottie asset path (e.g., 'assets/anim.json').
  final String? lottieAsset;

  /// If provided, a network lottie URL.
  final String? lottieUrl;

  /// Create a page with a custom [ImageProvider] (asset/network/memory).
  const OnboardingPageData({
    required this.title,
    required this.description,
    this.image,
    this.buttonText,
    this.lottieAsset,
    this.lottieUrl,
  });

  /// Convenience: create a page from a local asset image.
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

  /// Convenience: create a page from a network image URL.
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

  /// Convenience: create a page that renders a local Lottie animation asset.
  factory OnboardingPageData.fromLottieAsset({
    required String title,
    required String description,
    required String assetPath,
    String? buttonText,
  }) {
    return OnboardingPageData(
      title: title,
      description: description,
      lottieAsset: assetPath,
      buttonText: buttonText,
    );
  }

  /// Convenience: create a page that renders a network Lottie animation.
  factory OnboardingPageData.fromLottieNetwork({
    required String title,
    required String description,
    required String url,
    String? buttonText,
  }) {
    return OnboardingPageData(
      title: title,
      description: description,
      lottieUrl: url,
      buttonText: buttonText,
    );
  }
}
