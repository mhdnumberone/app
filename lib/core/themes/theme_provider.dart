import 'package:flutter/material.dart';
import 'app_themes.dart';
import 'app_theme_extension.dart';

/// Theme provider and utilities for unified theme management
/// (تم تبسيطه ليعتمد فقط على ThemeData وColorScheme)

/// Extension on BuildContext for easy theme access
extension ThemeExtension on BuildContext {
  /// Get current color scheme
  ColorScheme get colors => Theme.of(this).colorScheme;
  /// Get current theme data
  ThemeData get theme => Theme.of(this);
  /// Get text theme
  TextTheme get textTheme => Theme.of(this).textTheme;
}

/// Common theme utilities
class ThemeUtils {
  /// Get message bubble colors based on theme
  static MessageBubbleColors getMessageBubbleColors(BuildContext context) {
    final theme = Theme.of(context);
    // استخدم MessageBubbleColors من AppThemes حسب نوع الثيم
    return AppThemes.getMessageBubbleColors(AppThemeType.intelligence);
  }

  /// Get card decoration with theme colors
  static BoxDecoration getCardDecoration(BuildContext context, {double opacity = 0.1}) {
    final colors = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: colors.primary.withOpacity(opacity),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: colors.primary.withOpacity(opacity * 3)),
    );
  }

  /// Get elevated button style with theme colors
  static ElevatedButtonThemeData getElevatedButtonTheme(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}