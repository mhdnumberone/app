// lib/core/constants/design_constants.dart
// Design tokens for consistent styling throughout the app

import 'package:flutter/material.dart';

class DesignConstants {
  // Border radius values - extracted from hardcoded values throughout the app
  static const double borderRadiusSmall = 8.0;
  static const double borderRadiusMedium = 12.0;
  static const double borderRadiusLarge = 15.0;
  static const double borderRadiusXLarge = 20.0;
  static const double borderRadiusRounded = 30.0;

  // Spacing values
  static const double spacingXSmall = 4.0;
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 16.0;
  static const double spacingLarge = 24.0;
  static const double spacingXLarge = 32.0;

  // Elevation values
  static const double elevationNone = 0.0;
  static const double elevationLow = 2.0;
  static const double elevationMedium = 4.0;
  static const double elevationHigh = 8.0;
  static const double elevationMax = 16.0;

  // Icon sizes
  static const double iconSmall = 16.0;
  static const double iconMedium = 24.0;
  static const double iconLarge = 32.0;
  static const double iconXLarge = 48.0;

  // Animation durations
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationMedium = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);

  // Opacity values
  static const double opacityDisabled = 0.3;
  static const double opacitySubtle = 0.6;
  static const double opacityMedium = 0.8;
  static const double opacityFull = 1.0;
}

// Responsive design utilities
class ResponsiveUtils {
  static double widthPercent(BuildContext context, double percent) =>
      MediaQuery.of(context).size.width * percent;

  static double heightPercent(BuildContext context, double percent) =>
      MediaQuery.of(context).size.height * percent;

  // Responsive spacing based on screen size
  static double responsiveSpacing(BuildContext context, double baseSpacing) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 360) {
      return baseSpacing * 0.8; // Smaller screens
    } else if (screenWidth > 800) {
      return baseSpacing * 1.2; // Larger screens
    }
    return baseSpacing; // Default
  }

  // Responsive text scaling
  static double responsiveTextScale(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 360) {
      return 0.9; // Smaller text on small screens
    } else if (screenWidth > 800) {
      return 1.1; // Larger text on large screens
    }
    return 1.0; // Default scale
  }
}

// Animation utilities
class AnimationUtils {
  static Animation<double> createFadeAnimation(
    AnimationController controller, {
    double begin = 0.0,
    double end = 1.0,
    Curve curve = Curves.easeInOut,
  }) {
    return Tween<double>(
      begin: begin,
      end: end,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: curve,
    ));
  }

  static Animation<Offset> createSlideAnimation(
    AnimationController controller, {
    Offset begin = const Offset(1.0, 0.0),
    Offset end = Offset.zero,
    Curve curve = Curves.easeInOut,
  }) {
    return Tween<Offset>(
      begin: begin,
      end: end,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: curve,
    ));
  }
}
