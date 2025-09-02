import 'package:flutter/material.dart';
import 'package:storybook_flutter/storybook_flutter.dart';
import '../../widgets.dart';

/// Stories for GlassCard component variations.
///
/// This file contains all the different states and configurations
/// of the GlassCard widget for development and testing.
final List<Story> glassCardStories = [
  Story(
    name: 'Layout/GlassCard/Basic',
    description: 'Basic glass card with default settings',
    builder: (context) => Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
        ),
      ),
      child: Center(
        child: GlassCard(
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.star,
                size: 48,
                color: Colors.white,
              ),
              SizedBox(height: 16),
              Text(
                'Glass Card Content',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'This is a beautiful glass morphism card with blur effects and transparency.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  ),
  Story(
    name: 'Layout/GlassCard/Customizable',
    description: 'Glass card with customizable properties',
    builder: (context) {
      final blur = context.knobs.slider(
        label: 'Blur Amount',
        initial: 20,
        min: 0,
        max: 50,
      );

      final borderRadius = context.knobs.slider(
        label: 'Border Radius',
        initial: 20,
        min: 0,
        max: 40,
      );

      final padding = context.knobs.slider(
        label: 'Padding',
        initial: 24,
        min: 8,
        max: 48,
      );

      return Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          ),
        ),
        child: Center(
          child: GlassCard(
            blur: blur,
            borderRadius: BorderRadius.circular(borderRadius),
            padding: EdgeInsets.all(padding),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tune,
                  size: 48,
                  color: Colors.white,
                ),
                SizedBox(height: 16),
                Text(
                  'Customizable Glass Card',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Adjust the controls to see how the glass effect changes.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    },
  ),
  Story(
    name: 'Layout/GlassCard/Variations',
    description: 'Different glass card variations and styles',
    builder: (context) => Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  borderRadius: BorderRadius.circular(12),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications, color: Colors.white, size: 32),
                      SizedBox(height: 8),
                      Text(
                        'Notifications',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  borderRadius: BorderRadius.circular(12),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.settings, color: Colors.white, size: 32),
                      SizedBox(height: 8),
                      Text(
                        'Settings',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.all(20),
            borderRadius: BorderRadius.circular(16),
            child: const Row(
              children: [
                Icon(Icons.account_circle, color: Colors.white, size: 48),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'John Doe',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'john.doe@example.com',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: Colors.white70),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
];
