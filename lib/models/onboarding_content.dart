/// Onboarding content model for Guardian Angel app
class OnboardingContent {
  final String title;
  final String description;
  final String imageUrl;
  final String? buttonText;

  const OnboardingContent({
    required this.title,
    required this.description,
    required this.imageUrl,
    this.buttonText,
  });
}

/// Predefined onboarding content for Guardian Angel
class OnboardingData {
  static const List<OnboardingContent> contents = [
    OnboardingContent(
      title: "Welcome to Guardian Angel",
      description:
          "Your trusted companion for family safety and peace of mind. Monitor, protect, and stay connected with your loved ones effortlessly.",
      imageUrl: "images/1.png",
    ),
    OnboardingContent(
      title: "Real-Time Location Tracking",
      description:
          "Keep track of your family members' whereabouts in real-time with our advanced GPS technology. Get instant notifications when they arrive safely.",
      imageUrl: "images/2.png",
    ),
    OnboardingContent(
      title: "Emergency Alerts & SOS",
      description:
          "Instant emergency notifications and one-tap SOS functionality. Your family's safety is our priority, with 24/7 monitoring and rapid response.",
      imageUrl: "images/3.png",
    ),
    OnboardingContent(
      title: "Smart Health Monitoring",
      description:
          "Monitor vital signs, medication reminders, and health metrics. Stay informed about your loved ones' wellbeing with intelligent health insights.",
      imageUrl: "images/4.png",
      buttonText: "Get Started",
    ),
  ];
}
