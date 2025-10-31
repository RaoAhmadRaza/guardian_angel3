# intro_onboarding_slider

A simple, reusable onboarding slider for Flutter apps.
## New in 0.1.5


- Full color customization: title/description text, skip/next buttons, indicator colors, final button foreground/background/shadow, gradient start/end.
- Final button styles: `large` (default) and `smallRounded`.
- Three layouts: `breathable`, `compact` (non-breathable), and `showcase` (a modern, elevated media-first look).
- Subtle bottom-only shadow under media (image or Lottie) for depth.

### Quick usage

```dart
IntroOnboardingFlow(
  pages: [
    OnboardingPageData.fromLottieNetwork(
      'https://assets9.lottiefiles.com/packages/lf20_valid.json',
      title: 'Insights That Adapt to You',
      description: 'Smart recommendations for intensity, recovery, and habits—helping you build sustainable, consistent fitness.',
      buttonText: 'Get Started',
    ),
    // ... more pages
  ],
  onCompleted: () {},
  // Colors
  gradientStartColor: const Color(0xFFF9FAFB),
  gradientEndColor: const Color(0xFFF3F4F6),
  navActiveColor: Colors.black87,
  navInactiveColor: Colors.black26,
  titleColor: Colors.black,
  descriptionColor: Colors.black54,
  primaryButtonBgColor: Colors.white,
  primaryButtonFgColor: Colors.black,
  primaryButtonShadowColor: Colors.black26,
  skipTextColor: Colors.black54,
  nextButtonBgColor: const Color(0xFFF5F5F5),
  nextButtonIconColor: Colors.black87,
  // Layout
  layoutStyle: IoLayoutStyle.showcase,
  showIndicatorOnLastPage: false,
  lastButtonStyle: IoLastButtonStyle.smallRounded,
)
```

### Layout styles

- breathable: Media in a styled container, generous spacing.
- compact: Title above media, tighter but now with better spacing between title/media/description.
- showcase: Larger media on a soft gradient card; great for animations.

### Tips

- For Lottie links, ensure the animation has valid frames (op > ip) and fr > 0. Invalid files will show a subtle placeholder instead of crashing.

- PageView-based flow with animated indicators and controls
- Works with asset or network images
- Clean API: pass a list of pages and an onCompleted callback

## Usage

```dart
import 'package:intro_onboarding_slider/intro_onboarding_slider.dart';

final pages = [
  OnboardingPageData.fromAsset(
    title: 'Welcome',
    description: 'Keep your users in the loop.',
    assetPath: 'images/1.png',
  ),
  OnboardingPageData.fromNetwork(
    title: 'Beautiful',
    description: 'Animations and a simple API.',
    url: 'https://picsum.photos/seed/2/800/600',
  ),
  // Lottie from local asset
  OnboardingPageData.fromLottieAsset(
    title: 'Delightful',
    description: 'Use Lottie animations from assets.',
    assetPath: 'assets/anim.json',
  ),
  // Lottie from network
  OnboardingPageData.fromLottieNetwork(
    title: 'Connected',
    description: 'Or load Lottie from a URL.',
    url: 'https://example.com/anim.json',
    buttonText: 'Let\'s go',
  ),
  OnboardingPageData.fromAsset(
    title: 'Get Started',
    description: 'All set! Let\'s begin.',
    assetPath: 'images/3.png',
    buttonText: 'Let\'s go',
  ),
];

return IntroOnboardingFlow(
  pages: pages,
  onCompleted: () {
    // Navigate to your app's home screen
  },
  // v0.1.3 options:
  onSkip: () {
    // Navigate elsewhere on Skip
  },
  getStartedText: 'Start Now',
  isBreathable: true, // false -> title, then media without container, then description
);
```

## Theming

- Provide `backgroundGradient` for a custom backdrop
- Customize indicator colors with `navActiveColor` / `navInactiveColor`

## License

MIT
