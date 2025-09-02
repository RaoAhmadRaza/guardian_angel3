import 'package:flutter/material.dart';
import 'package:storybook_flutter/storybook_flutter.dart';
import '../../widgets.dart';

/// Stories for GradientButton component variations.
///
/// This file contains all the different states and configurations
/// of the GradientButton widget for development and testing.
final List<Story> gradientButtonStories = [
  Story(
    name: 'Buttons/GradientButton/Primary',
    description: 'Primary gradient button with brand colors',
    builder: (context) => Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GradientButton.primary(
            text: 'Continue',
            onPressed: () {},
          ),
          const SizedBox(height: 16),
          GradientButton.primary(
            text: 'Get Started',
            icon: Icons.arrow_forward,
            onPressed: () {},
          ),
          const SizedBox(height: 16),
          GradientButton.primary(
            text: 'Loading...',
            isLoading: true,
            onPressed: () {},
          ),
        ],
      ),
    ),
  ),
  Story(
    name: 'Buttons/GradientButton/Secondary',
    description: 'Secondary gradient button with muted colors',
    builder: (context) => Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GradientButton.secondary(
            text: 'Cancel',
            onPressed: () {},
          ),
          const SizedBox(height: 16),
          GradientButton.secondary(
            text: 'Back',
            icon: Icons.arrow_back,
            onPressed: () {},
          ),
        ],
      ),
    ),
  ),
  Story(
    name: 'Buttons/GradientButton/Destructive',
    description: 'Destructive action button with warning colors',
    builder: (context) => Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GradientButton.destructive(
            text: 'Delete Account',
            onPressed: () {},
          ),
          const SizedBox(height: 16),
          GradientButton.destructive(
            text: 'Remove',
            icon: Icons.delete_outline,
            onPressed: () {},
          ),
        ],
      ),
    ),
  ),
  Story(
    name: 'Buttons/GradientButton/Success',
    description: 'Success action button with green colors',
    builder: (context) => Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GradientButton.success(
            text: 'Save Changes',
            onPressed: () {},
          ),
          const SizedBox(height: 16),
          GradientButton.success(
            text: 'Complete',
            icon: Icons.check,
            onPressed: () {},
          ),
        ],
      ),
    ),
  ),
  Story(
    name: 'Buttons/GradientButton/Interactive',
    description: 'Interactive gradient button with customizable properties',
    builder: (context) {
      final text = context.knobs.text(
        label: 'Button Text',
        initial: 'Custom Button',
      );

      final isLoading = context.knobs.boolean(
        label: 'Loading State',
        initial: false,
      );

      final hasIcon = context.knobs.boolean(
        label: 'Show Icon',
        initial: false,
      );

      final buttonType = context.knobs.options(
        label: 'Button Type',
        initial: 'primary',
        options: [
          const Option(label: 'Primary', value: 'primary'),
          const Option(label: 'Secondary', value: 'secondary'),
          const Option(label: 'Destructive', value: 'destructive'),
          const Option(label: 'Success', value: 'success'),
        ],
      );

      Widget button;
      switch (buttonType) {
        case 'secondary':
          button = GradientButton.secondary(
            text: text,
            icon: hasIcon ? Icons.star : null,
            isLoading: isLoading,
            onPressed: () {},
          );
          break;
        case 'destructive':
          button = GradientButton.destructive(
            text: text,
            icon: hasIcon ? Icons.warning : null,
            isLoading: isLoading,
            onPressed: () {},
          );
          break;
        case 'success':
          button = GradientButton.success(
            text: text,
            icon: hasIcon ? Icons.check : null,
            isLoading: isLoading,
            onPressed: () {},
          );
          break;
        default:
          button = GradientButton.primary(
            text: text,
            icon: hasIcon ? Icons.arrow_forward : null,
            isLoading: isLoading,
            onPressed: () {},
          );
      }

      return Container(
        padding: const EdgeInsets.all(24),
        child: button,
      );
    },
  ),
];
