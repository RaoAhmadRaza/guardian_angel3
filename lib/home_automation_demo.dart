/// Home Automation Workflow Demo
/// Run this file to test the complete workflow implementation

import 'test/home_automation_workflow_test.dart';
import 'package:flutter/material.dart';

/// Monochrome emotional palette (Chunk 1)
/// Focused, calm, minimal – with gentle optional warmth tints.
class HomeAutomationPalette {
  // Core tones
  static const Color base = Color(0xFFF9FAFB); // soft white-gray background
  static const Color accent = Color(0xFFE5E7EB); // cards / bubbles / surfaces
  static const Color contrast = Color(0xFF1C1C1E); // deep neutral for text
  static const Color highlight = Color(0xFF8E8E93); // inactive / subtle icons

  // Optional comforting warmth (choose one in future refinements)
  static const Color warmBlueTint = Color(0xFFE9F2F8); // faint muted blue
  static const Color warmSandTint = Color(0xFFF4EDE3); // soft sand beige

  // Helpers --------------------------------------------------------------
  static BoxDecoration cardSurface({bool elevated = false, bool blue = false, bool sand = false}) {
    final Color baseColor = accent;
    final overlay = blue
        ? warmBlueTint
        : sand
            ? warmSandTint
            : baseColor;
    return BoxDecoration(
      color: overlay,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: accent.withOpacity(0.85), width: 1),
      boxShadow: elevated
          ? [
              BoxShadow(
                color: contrast.withOpacity(0.08),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ]
          : [],
    );
  }

  static TextStyle titleStyle({bool subtle = false}) => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.25,
        color: subtle ? highlight : contrast,
      );
  static TextStyle bodyStyle({double size = 13, bool dim = false}) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: dim ? highlight : contrast,
      );
}

void main() {
  print('🏠 GUARDIAN ANGEL - HOME AUTOMATION WORKFLOW DEMO\n');
  // Preview palette values (console only demonstration)
  print('Monochrome Palette:');
  for (final e in [
    ['base', HomeAutomationPalette.base],
    ['accent', HomeAutomationPalette.accent],
    ['contrast', HomeAutomationPalette.contrast],
    ['highlight', HomeAutomationPalette.highlight],
    ['warmBlueTint', HomeAutomationPalette.warmBlueTint],
    ['warmSandTint', HomeAutomationPalette.warmSandTint],
  ]) {
    print(' - ${e[0]}: ${(e[1] as Color).value.toRadixString(16)}');
  }

  // Run all workflow tests
  HomeAutomationWorkflowTest.runAllTests();

  // Print summary
  HomeAutomationWorkflowTest.printWorkflowSummary();
}
