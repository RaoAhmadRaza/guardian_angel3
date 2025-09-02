import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

/// Example implementation showing how to use the new responsive theme system
class ResponsiveExampleWidget extends StatelessWidget {
  const ResponsiveExampleWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Get screen width for responsive calculations
    final screenWidth = MediaQuery.of(context).size.width;
    final deviceType = AppBreakpoints.getDeviceType(screenWidth);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      // App bar using new theme system
      appBar: AppBar(
        title: Text(
          'Responsive Guardian Angel',
          style: AppTypography.titleLarge(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),

      body: SingleChildScrollView(
        padding: AppSpacing.getResponsivePagePadding(screenWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Responsive heading
            Text(
              'Welcome to Guardian Angel',
              style: AppTypography.headlineLarge(
                context,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),

            SizedBox(
                height: AppSpacing.getResponsiveSectionSpacing(screenWidth)),

            // Gradient card using new theme system
            Container(
              width: double.infinity,
              padding: AppSpacing.getResponsiveCardPadding(screenWidth),
              decoration: BoxDecoration(
                gradient: AppTheme.getPrimaryGradient(context),
                borderRadius: AppSpacing.getResponsiveBorderRadius(screenWidth),
                boxShadow: AppTheme.getCardShadow(context),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Device Type: ${deviceType.name}',
                    style: AppTypography.titleMedium(
                      context,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: AppSpacing.md),
                  Text(
                    'Screen Width: ${screenWidth.round()}px',
                    style: AppTypography.bodyLarge(
                      context,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  SizedBox(height: AppSpacing.md),
                  Text(
                    'This text automatically scales based on screen size and accessibility settings.',
                    style: AppTypography.bodyMedium(
                      context,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(
                height: AppSpacing.getResponsiveSectionSpacing(screenWidth)),

            // Responsive button grid
            _buildResponsiveButtonGrid(context, screenWidth),

            SizedBox(
                height: AppSpacing.getResponsiveSectionSpacing(screenWidth)),

            // Color showcase
            _buildColorShowcase(context),

            SizedBox(
                height: AppSpacing.getResponsiveSectionSpacing(screenWidth)),

            // Typography showcase
            _buildTypographyShowcase(context),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveButtonGrid(BuildContext context, double screenWidth) {
    final isTabletOrLarger = screenWidth >= AppBreakpoints.tablet;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Responsive Buttons',
          style: AppTypography.headlineSmall(context),
        ),
        SizedBox(height: AppSpacing.lg),

        // Responsive layout - grid for tablets/desktop, column for mobile
        if (isTabletOrLarger)
          Row(
            children: [
              Expanded(child: _buildPrimaryButton(context)),
              SizedBox(width: AppSpacing.lg),
              Expanded(child: _buildSecondaryButton(context)),
              SizedBox(width: AppSpacing.lg),
              Expanded(child: _buildOutlinedButton(context)),
            ],
          )
        else
          Column(
            children: [
              _buildPrimaryButton(context),
              SizedBox(height: AppSpacing.md),
              _buildSecondaryButton(context),
              SizedBox(height: AppSpacing.md),
              _buildOutlinedButton(context),
            ],
          ),
      ],
    );
  }

  Widget _buildPrimaryButton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: AppSpacing.buttonHeight,
      decoration: BoxDecoration(
        gradient: AppTheme.getPrimaryGradient(context),
        borderRadius: AppSpacing.largeRadius,
        boxShadow: AppTheme.getButtonShadow(context),
      ),
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.largeRadius,
          ),
        ),
        child: Text(
          'Primary Action',
          style: AppTypography.labelLarge(
            context,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppSpacing.buttonHeight,
      child: ElevatedButton(
        onPressed: () {},
        child: Text(
          'Secondary Action',
          style: AppTypography.labelLarge(context),
        ),
      ),
    );
  }

  Widget _buildOutlinedButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppSpacing.buttonHeight,
      child: OutlinedButton(
        onPressed: () {},
        child: Text(
          'Outlined Action',
          style: AppTypography.labelLarge(context),
        ),
      ),
    );
  }

  Widget _buildColorShowcase(BuildContext context) {
    final isDark = AppTheme.isDarkTheme(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Color System',
          style: AppTypography.headlineSmall(context),
        ),
        SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            _buildColorSwatch(
              'Primary',
              AppColors.lightPrimary,
              context,
            ),
            _buildColorSwatch(
              'Secondary',
              AppColors.lightSecondary,
              context,
            ),
            _buildColorSwatch(
              'Success',
              isDark ? AppColors.successDark : AppColors.successLight,
              context,
            ),
            _buildColorSwatch(
              'Warning',
              isDark ? AppColors.warningDark : AppColors.warningLight,
              context,
            ),
            _buildColorSwatch(
              'Error',
              isDark ? AppColors.errorDark : AppColors.errorLight,
              context,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildColorSwatch(String label, Color color, BuildContext context) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color,
            borderRadius: AppSpacing.mediumRadius,
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
        ),
        SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: AppTypography.labelSmall(context),
        ),
      ],
    );
  }

  Widget _buildTypographyShowcase(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Responsive Typography',
          style: AppTypography.headlineSmall(context),
        ),
        SizedBox(height: AppSpacing.lg),

        // Typography samples with different scales
        _buildTypographySample(
          'Display Large',
          'Display typography scales with screen size',
          AppTypography.displayLarge(context),
          context,
        ),
        _buildTypographySample(
          'Headline Medium',
          'Headlines are optimized for readability',
          AppTypography.headlineMedium(context),
          context,
        ),
        _buildTypographySample(
          'Title Large',
          'Titles maintain hierarchy across devices',
          AppTypography.titleLarge(context),
          context,
        ),
        _buildTypographySample(
          'Body Large',
          'Body text adapts to user accessibility preferences automatically',
          AppTypography.bodyLarge(context),
          context,
        ),
        _buildTypographySample(
          'Label Medium',
          'Labels scale appropriately for touch targets',
          AppTypography.labelMedium(context),
          context,
        ),
      ],
    );
  }

  Widget _buildTypographySample(
    String title,
    String sample,
    TextStyle style,
    BuildContext context,
  ) {
    return Padding(
      padding: AppSpacing.verticalSm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.labelMedium(
              context,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          SizedBox(height: AppSpacing.xs),
          Text(sample, style: style),
        ],
      ),
    );
  }
}
