import 'package:flutter/material.dart';
import 'app_themes.dart';
import 'app_theme_extension.dart';
import '../managers/settings_manager.dart';
import '../constants/design_constants.dart';

/// Centralized theme service to eliminate DRY violations
class ThemeService {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();
  
  static ThemeService get instance => _instance;
  
  /// Get theme colors for the current theme
  ColorScheme getThemeColors([AppThemeType? themeType]) {
    final theme = themeType ?? AppThemeType.intelligence;
    final themeData = AppThemes.getTheme(theme);
    return themeData.colorScheme;
  }
  
  /// Get current theme colors from context
  ColorScheme getCurrentColors(BuildContext context) {
    return Theme.of(context).colorScheme;
  }
  
  /// Get primary color for current theme
  Color getPrimaryColor([AppThemeType? themeType]) {
    return getThemeColors(themeType).primary;
  }
  
  /// Get accent color for current theme
  Color getAccentColor([AppThemeType? themeType]) {
    return getThemeColors(themeType).primary;
  }
  
  /// Get surface color for current theme
  Color getSurfaceColor([AppThemeType? themeType]) {
    return getThemeColors(themeType).surface;
  }
  
  /// Get text primary color for current theme
  Color getTextPrimaryColor([AppThemeType? themeType]) {
    return getThemeColors(themeType).onSurface;
  }
  
  /// Get text secondary color for current theme
  Color getTextSecondaryColor([AppThemeType? themeType]) {
    return getThemeColors(themeType).onSurface.withOpacity(0.7);
  }
  
  /// Get success color for current theme
  Color getSuccessColor([AppThemeType? themeType]) {
    return Colors.green;
  }
  
  /// Get error color for current theme
  Color getErrorColor([AppThemeType? themeType]) {
    return getThemeColors(themeType).error;
  }
  
  /// Get warning color for current theme
  Color getWarningColor([AppThemeType? themeType]) {
    return Colors.orange;
  }
  
  /// Get highlight color for current theme
  Color getHighlightColor([AppThemeType? themeType]) {
    return getThemeColors(themeType).primary;
  }
  
  /// Get common card decoration
  BoxDecoration getCardDecoration({
    AppThemeType? themeType,
    double opacity = 0.1,
    double borderRadius = 12,
  }) {
    final colors = getThemeColors(themeType);
    return BoxDecoration(
      color: colors.primary.withOpacity(opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: colors.primary.withOpacity(opacity * 3),
      ),
    );
  }
  
  /// Get message bubble decoration for sent messages
  BoxDecoration getSentMessageDecoration([AppThemeType? themeType]) {
    final colors = getThemeColors(themeType);
    return BoxDecoration(
      color: colors.primary,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(4),
      ),
    );
  }
  
  /// Get message bubble decoration for received messages
  BoxDecoration getReceivedMessageDecoration([AppThemeType? themeType]) {
    final colors = getThemeColors(themeType);
    return BoxDecoration(
      color: colors.surface,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
        bottomLeft: Radius.circular(4),
        bottomRight: Radius.circular(16),
      ),
    );
  }

  // Design constants access
  /// Get standard border radius values
  static double get borderRadiusSmall => DesignConstants.borderRadiusSmall;
  static double get borderRadiusMedium => DesignConstants.borderRadiusMedium;
  static double get borderRadiusLarge => DesignConstants.borderRadiusLarge;
  static double get borderRadiusXLarge => DesignConstants.borderRadiusXLarge;

  /// Get standard spacing values
  static double get spacingSmall => DesignConstants.spacingSmall;
  static double get spacingMedium => DesignConstants.spacingMedium;
  static double get spacingLarge => DesignConstants.spacingLarge;

  /// Get standard elevation values
  static double get elevationLow => DesignConstants.elevationLow;
  static double get elevationMedium => DesignConstants.elevationMedium;
  static double get elevationHigh => DesignConstants.elevationHigh;

  /// Get responsive width percentage
  static double widthPercent(BuildContext context, double percent) =>
    ResponsiveUtils.widthPercent(context, percent);

  /// Get responsive height percentage
  static double heightPercent(BuildContext context, double percent) =>
    ResponsiveUtils.heightPercent(context, percent);

  /// Get standard container decoration with design tokens
  BoxDecoration getStandardContainerDecoration({
    AppThemeType? themeType,
    double? borderRadius,
    double? elevation,
    Color? backgroundColor,
    double opacity = 1.0,
  }) {
    final colors = getThemeColors(themeType);
    return BoxDecoration(
      color: backgroundColor ?? colors.surface.withOpacity(opacity),
      borderRadius: BorderRadius.circular(borderRadius ?? DesignConstants.borderRadiusMedium),
      boxShadow: elevation != null ? [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: elevation,
          offset: Offset(0, elevation / 2),
        ),
      ] : null,
    );
  }
}

/// Extension for easy theme service access
extension ThemeServiceExtension on BuildContext {
  /// Get theme service instance
  ThemeService get themeService => ThemeService.instance;
  
  /// Get current theme colors
  ColorScheme get currentColors => ThemeService.instance.getCurrentColors(this);
  
  /// Get app theme extension directly
  ColorScheme get appTheme => ThemeService.instance.getCurrentColors(this);
}