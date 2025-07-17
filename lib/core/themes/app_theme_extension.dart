import 'package:flutter/material.dart';

/// Unified theme extension that provides all custom colors and theme properties
/// This is the single source of truth for all theme-related properties
@immutable
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  // Primary colors
  final Color primaryLight;
  final Color primaryDark;
  
  // Surface colors  
  final Color surfaceColor;
  final Color backgroundColor;
  
  // Text colors
  final Color textPrimaryColor;
  final Color textSecondaryColor;
  
  // Accent colors
  final Color accentColor;
  final Color highlightColor;
  
  // Status colors
  final Color successColor;
  final Color warningColor;
  final Color errorColor;
  
  // Additional colors
  final Color unreadIndicatorColor;
  final Color borderColor;
  
  // Message colors
  final Color sentMessageBackgroundColor;
  final Color sentMessageBorderColor;
  final Color receivedMessageBackgroundColor;
  final Color receivedMessageBorderColor;
  
  // Standard Flutter color mappings
  final Color primaryColor;
  final Color onPrimaryColor;
  final Color onSurface;
  final Color secondary;
  final Color onPrimary;
  final Color primary;

  const AppThemeExtension({
    required this.primaryLight,
    required this.primaryDark,
    required this.surfaceColor,
    required this.backgroundColor,
    required this.textPrimaryColor,
    required this.textSecondaryColor,
    required this.accentColor,
    required this.highlightColor,
    required this.successColor,
    required this.warningColor,
    required this.errorColor,
    required this.unreadIndicatorColor,
    required this.borderColor,
    required this.sentMessageBackgroundColor,
    required this.sentMessageBorderColor,
    required this.receivedMessageBackgroundColor,
    required this.receivedMessageBorderColor,
    required this.primaryColor,
    required this.onPrimaryColor,
    required this.onSurface,
    required this.secondary,
    required this.onPrimary,
    required this.primary,
  });

  @override
  AppThemeExtension copyWith({
    Color? primaryLight,
    Color? primaryDark,
    Color? surfaceColor,
    Color? backgroundColor,
    Color? textPrimaryColor,
    Color? textSecondaryColor,
    Color? accentColor,
    Color? highlightColor,
    Color? successColor,
    Color? warningColor,
    Color? errorColor,
    Color? unreadIndicatorColor,
    Color? borderColor,
    Color? sentMessageBackgroundColor,
    Color? sentMessageBorderColor,
    Color? receivedMessageBackgroundColor,
    Color? receivedMessageBorderColor,
    Color? primaryColor,
    Color? onPrimaryColor,
    Color? onSurface,
    Color? secondary,
    Color? onPrimary,
    Color? primary,
  }) {
    return AppThemeExtension(
      primaryLight: primaryLight ?? this.primaryLight,
      primaryDark: primaryDark ?? this.primaryDark,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textPrimaryColor: textPrimaryColor ?? this.textPrimaryColor,
      textSecondaryColor: textSecondaryColor ?? this.textSecondaryColor,
      accentColor: accentColor ?? this.accentColor,
      highlightColor: highlightColor ?? this.highlightColor,
      successColor: successColor ?? this.successColor,
      warningColor: warningColor ?? this.warningColor,
      errorColor: errorColor ?? this.errorColor,
      unreadIndicatorColor: unreadIndicatorColor ?? this.unreadIndicatorColor,
      borderColor: borderColor ?? this.borderColor,
      sentMessageBackgroundColor: sentMessageBackgroundColor ?? this.sentMessageBackgroundColor,
      sentMessageBorderColor: sentMessageBorderColor ?? this.sentMessageBorderColor,
      receivedMessageBackgroundColor: receivedMessageBackgroundColor ?? this.receivedMessageBackgroundColor,
      receivedMessageBorderColor: receivedMessageBorderColor ?? this.receivedMessageBorderColor,
      primaryColor: primaryColor ?? this.primaryColor,
      onPrimaryColor: onPrimaryColor ?? this.onPrimaryColor,
      onSurface: onSurface ?? this.onSurface,
      secondary: secondary ?? this.secondary,
      onPrimary: onPrimary ?? this.onPrimary,
      primary: primary ?? this.primary,
    );
  }

  @override
  AppThemeExtension lerp(AppThemeExtension? other, double t) {
    if (other is! AppThemeExtension) {
      return this;
    }
    return AppThemeExtension(
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      surfaceColor: Color.lerp(surfaceColor, other.surfaceColor, t)!,
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t)!,
      textPrimaryColor: Color.lerp(textPrimaryColor, other.textPrimaryColor, t)!,
      textSecondaryColor: Color.lerp(textSecondaryColor, other.textSecondaryColor, t)!,
      accentColor: Color.lerp(accentColor, other.accentColor, t)!,
      highlightColor: Color.lerp(highlightColor, other.highlightColor, t)!,
      successColor: Color.lerp(successColor, other.successColor, t)!,
      warningColor: Color.lerp(warningColor, other.warningColor, t)!,
      errorColor: Color.lerp(errorColor, other.errorColor, t)!,
      unreadIndicatorColor: Color.lerp(unreadIndicatorColor, other.unreadIndicatorColor, t)!,
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
      sentMessageBackgroundColor: Color.lerp(sentMessageBackgroundColor, other.sentMessageBackgroundColor, t)!,
      sentMessageBorderColor: Color.lerp(sentMessageBorderColor, other.sentMessageBorderColor, t)!,
      receivedMessageBackgroundColor: Color.lerp(receivedMessageBackgroundColor, other.receivedMessageBackgroundColor, t)!,
      receivedMessageBorderColor: Color.lerp(receivedMessageBorderColor, other.receivedMessageBorderColor, t)!,
      primaryColor: Color.lerp(primaryColor, other.primaryColor, t)!,
      onPrimaryColor: Color.lerp(onPrimaryColor, other.onPrimaryColor, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
    );
  }

  /// Factory constructor for Intelligence theme
  factory AppThemeExtension.intelligence() {
    return const AppThemeExtension(
      primaryLight: Color(0xFF2C5F2D),
      primaryDark: Color(0xFF1A3B1A),
      surfaceColor: Color(0xFF151515),
      backgroundColor: Color(0xFF0A0A0A),
      textPrimaryColor: Color(0xFFE0E0E0),
      textSecondaryColor: Color(0xFF9E9E9E),
      accentColor: Color(0xFF4CAF50),
      highlightColor: Color(0xFF66BB6A),
      successColor: Color(0xFF4CAF50),
      warningColor: Color(0xFFFF9800),
      errorColor: Color(0xFFF44336),
      unreadIndicatorColor: Color(0xFF4CAF50),
      borderColor: Color(0xFF2C5F2D),
      sentMessageBackgroundColor: Color(0xFF1A3B1A),
      sentMessageBorderColor: Color(0xFF2C5F2D),
      receivedMessageBackgroundColor: Color(0xFF151515),
      receivedMessageBorderColor: Color(0xFF2C5F2D),
      primaryColor: Color(0xFF4CAF50),
      onPrimaryColor: Color(0xFFFFFFFF),
      onSurface: Color(0xFFE0E0E0),
      secondary: Color(0xFF66BB6A),
    );
  }

  /// Factory constructor for Dark theme
  factory AppThemeExtension.dark() {
    return const AppThemeExtension(
      primaryLight: Color(0xFF484848),
      primaryDark: Color(0xFF1C1C1C),
      surfaceColor: Color(0xFF2A2A2A),
      backgroundColor: Color(0xFF121212),
      textPrimaryColor: Color(0xFFFFFFFF),
      textSecondaryColor: Color(0xFFB3B3B3),
      accentColor: Color(0xFF90CAF9),
      highlightColor: Color(0xFF64B5F6),
      successColor: Color(0xFF81C784),
      warningColor: Color(0xFFFFB74D),
      errorColor: Color(0xFFE57373),
      unreadIndicatorColor: Color(0xFF90CAF9),
      borderColor: Color(0xFF484848),
      sentMessageBackgroundColor: Color(0xFF1C1C1C),
      sentMessageBorderColor: Color(0xFF484848),
      receivedMessageBackgroundColor: Color(0xFF2A2A2A),
      receivedMessageBorderColor: Color(0xFF484848),
      primaryColor: Color(0xFF90CAF9),
      onPrimaryColor: Color(0xFF000000),
      onSurface: Color(0xFFFFFFFF),
      secondary: Color(0xFF64B5F6),
    );
  }

  /// Factory constructor for Light theme
  factory AppThemeExtension.light() {
    return const AppThemeExtension(
      primaryLight: Color(0xFF90CAF9),
      primaryDark: Color(0xFF1976D2),
      surfaceColor: Color(0xFFF5F5F5),
      backgroundColor: Color(0xFFFFFFFF),
      textPrimaryColor: Color(0xFF212121),
      textSecondaryColor: Color(0xFF757575),
      accentColor: Color(0xFF2196F3),
      highlightColor: Color(0xFF64B5F6),
      successColor: Color(0xFF4CAF50),
      warningColor: Color(0xFFFF9800),
      errorColor: Color(0xFFF44336),
      unreadIndicatorColor: Color(0xFF2196F3),
      borderColor: Color(0xFFE0E0E0),
      sentMessageBackgroundColor: Color(0xFFE3F2FD),
      sentMessageBorderColor: Color(0xFF2196F3),
      receivedMessageBackgroundColor: Color(0xFFF5F5F5),
      receivedMessageBorderColor: Color(0xFFE0E0E0),
      primaryColor: Color(0xFF2196F3),
      onPrimaryColor: Color(0xFFFFFFFF),
      onSurface: Color(0xFF212121),
      secondary: Color(0xFF64B5F6),
    );
  }
}

/// Extension on BuildContext for easy theme access
extension ThemeAccessExtension on BuildContext {
  /// Get the current theme's AppThemeExtension
  AppThemeExtension get appTheme {
    final extension = Theme.of(this).extension<AppThemeExtension>();
    if (extension == null) {
      throw FlutterError(
        'AppThemeExtension not found in current theme.\n'
        'Please ensure AppThemeExtension is added to your ThemeData.',
      );
    }
    return extension;
  }
  
  /// Get the standard ColorScheme
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  
  /// Get the TextTheme
  TextTheme get textTheme => Theme.of(this).textTheme;
  
  /// Convenience getters for commonly used theme properties
  ThemeData get theme => Theme.of(this);
  bool get isDarkMode => theme.brightness == Brightness.dark;
}