import 'package:flutter/material.dart';
import 'enhanced_app_theme.dart';
import '../providers/theme_provider.dart';
import 'enhanced_light_theme.dart';

/// 🚀 Enhanced Light Theme Integration Guide
///
/// This file demonstrates how to integrate the new enhanced light theme
/// into your existing Guardian Angel application.

class EnhancedThemeIntegration {
  // ============================================================================
  // 📱 MAIN APP INTEGRATION
  // ============================================================================

  /// Update your main.dart MaterialApp to use the enhanced theme
  static Widget buildApp() {
    return ListenableBuilder(
      listenable: ThemeProvider.instance,
      builder: (context, child) {
        return MaterialApp(
          title: 'Guardian Angel',
          debugShowCheckedModeBanner: false,

          // 🌟 ENHANCED THEMES
          theme: EnhancedAppTheme.buildEnhancedLightTheme(context),
          darkTheme: EnhancedAppTheme.buildDarkTheme(context),
          themeMode: ThemeProvider.instance.themeMode,

          home: const Scaffold(
            body: Center(child: Text('Enhanced Theme Demo')),
          ),
        );
      },
    );
  }

  // ============================================================================
  // 🎨 COMPONENT USAGE EXAMPLES
  // ============================================================================

  /// Enhanced Card Component Example
  static Widget buildEnhancedCard({
    required Widget child,
    int elevation = 2,
    EdgeInsets? padding,
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EnhancedLightTheme.surfacePrimary,
        borderRadius: BorderRadius.circular(12),
        boxShadow: EnhancedLightTheme.getShadow(elevation),
        border: Border.all(
          color: EnhancedLightTheme.borderPrimary,
          width: 1,
        ),
      ),
      child: child,
    );
  }

  /// Enhanced Primary Button Example
  static Widget buildEnhancedPrimaryButton({
    required String text,
    required VoidCallback onPressed,
    bool isLoading = false,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: EnhancedLightTheme.buttonPrimaryGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: EnhancedLightTheme.buttonShadow,
      ),
      child: MaterialButton(
        onPressed: isLoading ? null : onPressed,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: EnhancedLightTheme.textInverse,
                  strokeWidth: 2,
                ),
              )
            : Text(
                text,
                style: TextStyle(
                  color: EnhancedLightTheme.textInverse,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  /// Enhanced Text Input Example
  static Widget buildEnhancedTextInput({
    required String label,
    String? hint,
    TextEditingController? controller,
    bool isError = false,
    String? errorText,
    IconData? prefixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: EnhancedLightTheme.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: EnhancedLightTheme.surfacePrimary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: EnhancedLightTheme.getBorderColor(isError: isError),
              width: isError ? 2 : 1,
            ),
            boxShadow: EnhancedLightTheme.inputShadow,
          ),
          child: TextFormField(
            controller: controller,
            style: TextStyle(
              color: EnhancedLightTheme.textPrimary,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: EnhancedLightTheme.textPlaceholder,
              ),
              prefixIcon: prefixIcon != null
                  ? Icon(
                      prefixIcon,
                      color: EnhancedLightTheme.iconSecondary,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
        if (isError && errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText,
            style: TextStyle(
              color: EnhancedLightTheme.error,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  /// Enhanced Success/Error Message Example
  static Widget buildStatusMessage({
    required String message,
    required MessageType type,
  }) {
    late Color backgroundColor;
    late Color borderColor;
    late Color textColor;
    late IconData icon;

    switch (type) {
      case MessageType.success:
        backgroundColor = EnhancedLightTheme.successLight;
        borderColor = EnhancedLightTheme.successBorder;
        textColor = EnhancedLightTheme.success;
        icon = Icons.check_circle;
        break;
      case MessageType.error:
        backgroundColor = EnhancedLightTheme.errorLight;
        borderColor = EnhancedLightTheme.errorBorder;
        textColor = EnhancedLightTheme.error;
        icon = Icons.error;
        break;
      case MessageType.warning:
        backgroundColor = EnhancedLightTheme.warningLight;
        borderColor = EnhancedLightTheme.warningBorder;
        textColor = EnhancedLightTheme.warning;
        icon = Icons.warning;
        break;
      case MessageType.info:
        backgroundColor = EnhancedLightTheme.infoLight;
        borderColor = EnhancedLightTheme.infoBorder;
        textColor = EnhancedLightTheme.info;
        icon = Icons.info;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // 🔄 MIGRATION HELPERS
  // ============================================================================

  /// Helper to update existing widgets to use enhanced theme
  static Color migrateColor(String oldColorName) {
    switch (oldColorName) {
      case 'AppTheme.backgroundColor':
        return EnhancedLightTheme.background;
      case 'AppTheme.surfaceColor':
        return EnhancedLightTheme.surfacePrimary;
      case 'AppTheme.primaryText':
        return EnhancedLightTheme.textPrimary;
      case 'AppTheme.secondaryText':
        return EnhancedLightTheme.textSecondary;
      case 'AppTheme.borderColor':
        return EnhancedLightTheme.borderPrimary;
      case 'AppTheme.eliteBlue':
        return EnhancedLightTheme.primary;
      default:
        return EnhancedLightTheme.textPrimary;
    }
  }

  /// Helper to get appropriate shadow for component
  static List<BoxShadow> getComponentShadow(String componentType) {
    switch (componentType) {
      case 'card':
        return EnhancedLightTheme.cardShadow;
      case 'button':
        return EnhancedLightTheme.buttonShadow;
      case 'modal':
        return EnhancedLightTheme.modalShadow;
      case 'input':
        return EnhancedLightTheme.inputShadow;
      default:
        return [];
    }
  }

  // ============================================================================
  // 🧪 THEME TESTING UTILITIES
  // ============================================================================

  /// Test widget to preview all enhanced theme colors
  static Widget buildThemePreview() {
    return Scaffold(
      backgroundColor: EnhancedLightTheme.background,
      appBar: AppBar(
        title: const Text('Enhanced Light Theme Preview'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Color Palette Preview
            _buildColorSection('Primary Colors', [
              _buildColorTile('Primary', EnhancedLightTheme.primary),
              _buildColorTile('Secondary', EnhancedLightTheme.secondary),
              _buildColorTile('Accent', EnhancedLightTheme.accent),
            ]),

            // Surface Colors Preview
            _buildColorSection('Surface Colors', [
              _buildColorTile('Background', EnhancedLightTheme.background),
              _buildColorTile(
                  'Surface Primary', EnhancedLightTheme.surfacePrimary),
              _buildColorTile(
                  'Surface Secondary', EnhancedLightTheme.surfaceSecondary),
            ]),

            // Text Colors Preview
            _buildColorSection('Text Colors', [
              _buildColorTile('Text Primary', EnhancedLightTheme.textPrimary),
              _buildColorTile(
                  'Text Secondary', EnhancedLightTheme.textSecondary),
              _buildColorTile('Text Tertiary', EnhancedLightTheme.textTertiary),
            ]),

            // Component Examples
            const SizedBox(height: 24),
            const Text(
              'Component Examples',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Button Examples
            buildEnhancedPrimaryButton(
              text: 'Primary Button',
              onPressed: () {},
            ),
            const SizedBox(height: 16),

            // Card Example
            buildEnhancedCard(
              child: const Text(
                'Enhanced Card Component\nWith premium shadows and borders',
                style: TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 16),

            // Status Messages
            buildStatusMessage(
              message: 'Success message with proper medical colors',
              type: MessageType.success,
            ),
            const SizedBox(height: 8),
            buildStatusMessage(
              message: 'Error message with clear visual hierarchy',
              type: MessageType.error,
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildColorSection(String title, List<Widget> colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: colors,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  static Widget _buildColorTile(String name, Color color) {
    return Container(
      width: 100,
      height: 60,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: EnhancedLightTheme.borderPrimary),
      ),
      child: Center(
        child: Text(
          name,
          style: TextStyle(
            color: color.computeLuminance() > 0.5
                ? EnhancedLightTheme.textPrimary
                : EnhancedLightTheme.textInverse,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ============================================================================
// 🎯 HELPER ENUMS
// ============================================================================

enum MessageType { success, error, warning, info }

// ============================================================================
// 📋 IMPLEMENTATION CHECKLIST
// ============================================================================

/*
🚀 IMPLEMENTATION STEPS:

1. ✅ Replace main.dart theme configuration:
   - Update MaterialApp theme property
   - Use EnhancedAppTheme.buildEnhancedLightTheme(context)

2. 🔄 Update existing components:
   - Replace AppTheme.* references with EnhancedLightTheme.*
   - Update shadow implementations
   - Apply new gradient system

3. 🎨 Apply enhanced colors:
   - Update card backgrounds to surfacePrimary
   - Replace pure white with off-white backgrounds
   - Apply medical blue for primary actions

4. ♿ Test accessibility:
   - Verify contrast ratios with accessibility tools
   - Test with screen readers
   - Validate touch target sizes (44px minimum)

5. 📱 Test responsiveness:
   - Check theme switching (light/dark)
   - Verify component consistency
   - Test on different screen sizes

6. 🏥 Medical context validation:
   - Review with healthcare professionals
   - Test with elderly users
   - Validate trust and professionalism

✨ EXPECTED RESULTS:
- Premium healthcare interface aesthetics
- WCAG AAA accessibility compliance
- Seamless dark/light theme transitions
- Enhanced user trust and professionalism
- Improved readability and usability

📊 SUCCESS METRICS:
- Contrast ratios: 7:1+ for all text
- Touch targets: 44px+ for all interactive elements
- Theme consistency: 100% component coverage
- User satisfaction: Healthcare professional approval
*/
