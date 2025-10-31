# Changelog

## 0.1.5

- Change default: hide indicator on the last page (showIndicatorOnLastPage now defaults to false). Set it to true to keep the dots on the final screen.
- Keep Lottie error fallback (from 0.1.4) for invalid animations.

## 0.1.6

- New layout option `IoLayoutStyle.showcase` (modern media-first card) in addition to breathable/compact.
- Fine-grained color customization: titleColor, descriptionColor, skipTextColor, next button bg/icon colors, primary button bg/fg/shadow, gradientStart/End.
- Final button styles: `IoLastButtonStyle.large` (default) and `IoLastButtonStyle.smallRounded`.
- Subtle bottom-only shadow under image/Lottie for depth.
- README updated with examples and guidance.

## 0.1.4

- Add gradientStartColor and gradientEndColor to customize background gradient when backgroundGradient is not provided.
- Keep the page indicator visible on the last page (it was already shown; ensured no regression and wired color overrides to the flow).
- Harden Lottie rendering with errorBuilder so invalid/zero-length animations won’t crash; shows a subtle placeholder.

## 0.1.3

- Add `onSkip` callback to route to a different screen
- Add `getStartedText` to override the final button label
- Add `isBreathable` layout toggle: true (media inside container), false (title, then plain media, then description)

## 0.1.2

- Add Lottie support (asset and network) via new factory constructors
	- `OnboardingPageData.fromLottieAsset` and `.fromLottieNetwork`
- Update page widget to render image OR lottie based on provided fields
- Update README with Lottie usage

## 0.1.1

- Add homepage and repository links
- Add API documentation comments to public classes and fields

## 0.1.0

- Initial release: IntroOnboardingFlow, IoPage, IoNavigationBar, IoPageIndicator
