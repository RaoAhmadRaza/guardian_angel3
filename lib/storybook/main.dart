import 'package:flutter/material.dart';
import 'package:storybook_flutter/storybook_flutter.dart';
import 'stories/gradient_button_stories.dart';
import 'stories/custom_text_field_stories.dart';
import 'stories/glass_card_stories.dart';

/// Storybook app for live component previews and development.
///
/// This provides an interactive environment to:
/// - Preview components in isolation
/// - Test different states and configurations
/// - Develop components independently
/// - Document component variations
///
/// Run with: `flutter run lib/storybook/main.dart`
void main() {
  runApp(const StorybookApp());
}

class StorybookApp extends StatelessWidget {
  const StorybookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guardian Angel Storybook',
      home: Storybook(
        stories: [
          // Button components
          ...gradientButtonStories,

          // Input components
          ...customTextFieldStories,

          // Layout components
          ...glassCardStories,
        ],
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
