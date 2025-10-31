# guardian_onboarding

Reusable, customizable onboarding flow for Flutter apps.

- PageView-based flow with animated indicators and controls
- Works with asset or network images
- Simple API: pass a list of pages and an onCompleted callback

## Quick start

Add to your pubspec (path dependency while developing):

```yaml
dependencies:
  guardian_onboarding:
    path: ../packages/guardian_onboarding
```

Usage:

```dart
import 'package:flutter/material.dart';
import 'package:guardian_onboarding/guardian_onboarding.dart';

class MyOnboarding extends StatelessWidget {
  const MyOnboarding({super.key});

  @override
  Widget build(BuildContext context) {
    final pages = [
      OnboardingPageData.fromAsset(
        title: 'Welcome',
        description: 'Stay safe and connected with your loved ones.',
        assetPath: 'images/1.png',
      ),
      OnboardingPageData.fromAsset(
        title: 'Track',
        description: 'Real-time tracking and alerts.',
        assetPath: 'images/2.png',
      ),
      OnboardingPageData.fromAsset(
        title: 'Get Started',
        description: 'All set! Let\'s begin.',
        assetPath: 'images/3.png',
        buttonText: 'Let\'s go',
      ),
    ];

    return OnboardingFlow(
      pages: pages,
      onCompleted: () {
        // Navigate to your home screen
      },
    );
  }
}
```

## Theming

- Provide a custom background gradient via `backgroundGradient`
- Customize indicator colors with `navActiveColor` / `navInactiveColor`

## Example

See `example/` for a minimal runnable app.

## License

MIT
