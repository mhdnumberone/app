import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../managers/settings_manager.dart';
import 'app_theme_extension.dart';

enum AppThemeType {
  intelligence('Intelligence Dark', 'Dark theme with intelligence colors'),
  dark('Pure Dark', 'Pure dark theme'),
  light('Light', 'Light theme'),
  auto('Auto', 'Follow system theme');

  const AppThemeType(this.name, this.description);
  final String name;
  final String description;
}

/// Enhanced theme system with multiple theme options
class AppThemes {
  
  /// Get theme data based on theme type
  static ThemeData getTheme(AppThemeType themeType) {
    switch (themeType) {
      case AppThemeType.intelligence:
        return _intelligenceTheme;
      case AppThemeType.dark:
        return _darkTheme;
      case AppThemeType.light:
        return _lightTheme;
      case AppThemeType.auto:
        return _intelligenceTheme; // Default for auto
    }
  }

  /// Intelligence theme (original dark theme)
  static ThemeData get _intelligenceTheme {
    const primaryDark = Color(0xFF0D1B2A);
    const primaryColor = Color(0xFF1B263B);
    const primaryLight = Color(0xFF415A77);
    const accentColor = Color(0xFF778DA9);
    const highlightColor = Color(0xFF00A9B7);
    const backgroundColor = Color(0xFF0A0F18);
    const surfaceColor = Color(0xFF101720);
    const textPrimaryColor = Color(0xFFE0E1DD);
    const textSecondaryColor = Color(0xFFB0B3B8);
    const successColor = Color(0xFF4CAF50);
    const warningColor = Color(0xFFFFA000);
    const errorColor = Color(0xFFD32F2F);
    const onPrimaryColor = Color(0xFFE0E1DD); // Assuming onPrimary is textPrimary for this theme

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        secondary: accentColor,
        surface: surfaceColor,
        error: errorColor,
        onPrimary: onPrimaryColor,
        onSecondary: textPrimaryColor,
        onSurface: textPrimaryColor,
        onError: textPrimaryColor,
        brightness: Brightness.dark,
        primaryContainer: primaryDark,
        secondaryContainer: primaryLight,
        tertiary: highlightColor,
        tertiaryContainer: const Color(0xFF004D54),
        outline: primaryLight,
        outlineVariant: primaryLight.withOpacity(0.5),
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: AppBarTheme(
        backgroundColor: primaryDark,
        foregroundColor: textPrimaryColor,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: const IconThemeData(color: textPrimaryColor),
        titleTextStyle: const TextStyle(
          color: textPrimaryColor,
          fontSize: 19,
          fontWeight: FontWeight.w600,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: highlightColor,
        foregroundColor: primaryDark,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: highlightColor,
          foregroundColor: primaryDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: textPrimaryColor, fontSize: 16),
        bodyMedium: TextStyle(color: textSecondaryColor, fontSize: 14),
        titleLarge: TextStyle(color: textPrimaryColor, fontWeight: FontWeight.bold, fontSize: 22),
      ),
      extensions: <ThemeExtension<dynamic>>[
        AppThemeExtension.intelligence(),
      ],
    );
  }

  /// Pure dark theme
  static ThemeData get _darkTheme {
    const primaryColor = Color(0xFF1A1A1A);
    const surfaceColor = Color(0xFF2A2A2A);
    const accentColor = Color(0xFF4CAF50);
    const textColor = Color(0xFFFFFFFF);
    const successColor = Color(0xFF4CAF50);
    const warningColor = Color(0xFFFFA000);
    const errorColor = Color(0xFFD32F2F);
    const onPrimaryColor = Color(0xFFFFFFFF);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: accentColor,
        secondary: accentColor,
        surface: surfaceColor,
        onPrimary: textColor,
        onSecondary: textColor,
        onSurface: textColor,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: primaryColor,
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: textColor,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accentColor,
        foregroundColor: primaryColor,
      ),
      extensions: <ThemeExtension<dynamic>>[
        AppThemeExtension.dark(),
      ],
    );
  }

  /// Light theme
  static ThemeData get _lightTheme {
    const primaryColor = Color(0xFF2196F3);
    const surfaceColor = Color(0xFFFFFFFF);
    const backgroundColor = Color(0xFFF5F5F5);
    const textColor = Color(0xFF212121);
    const successColor = Color(0xFF4CAF50);
    const warningColor = Color(0xFFFFA000);
    const errorColor = Color(0xFFD32F2F);
    const onPrimaryColor = Colors.white;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: primaryColor,
        surface: surfaceColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textColor,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 1,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      extensions: <ThemeExtension<dynamic>>[
        AppThemeExtension.light(),
      ],
    );
  }

  /// Get system UI overlay style for theme
  static SystemUiOverlayStyle getSystemUiOverlayStyle(AppThemeType themeType) {
    switch (themeType) {
      case AppThemeType.light:
        return SystemUiOverlayStyle.dark;
      case AppThemeType.intelligence:
      case AppThemeType.dark:
      case AppThemeType.auto:
        return SystemUiOverlayStyle.light;
    }
  }

  /// Message bubble colors for each theme
  static MessageBubbleColors getMessageBubbleColors(AppThemeType themeType) {
    switch (themeType) {
      case AppThemeType.intelligence:
        return const MessageBubbleColors(
          sentBackground: Color(0xFF1A3A40),
          sentBorder: Color(0xFF007A85),
          receivedBackground: Color(0xFF2C3E50), // لون أفتح وأكثر تباينًا
          receivedBorder: Color(0xFF415A77),
        );
      case AppThemeType.dark:
        return const MessageBubbleColors(
          sentBackground: Color(0xFF4CAF50),
          sentBorder: Color(0xFF388E3C),
          receivedBackground: Color(0xFF424242),
          receivedBorder: Color(0xFF616161),
        );
      case AppThemeType.light:
        return const MessageBubbleColors(
          sentBackground: Color(0xFF2196F3),
          sentBorder: Color(0xFF1976D2),
          receivedBackground: Color(0xFFE0E0E0),
          receivedBorder: Color(0xFFBDBDBD),
        );
      case AppThemeType.auto:
        return const MessageBubbleColors(
          sentBackground: Color(0xFF1A3A40),
          sentBorder: Color(0xFF007A85),
          receivedBackground: Color(0xFF222E3E),
          receivedBorder: Color(0xFF415A77),
        );
    }
  }
}

/// Message bubble color configuration
class MessageBubbleColors {
  final Color sentBackground;
  final Color sentBorder;
  final Color receivedBackground;
  final Color receivedBorder;

  const MessageBubbleColors({
    required this.sentBackground,
    required this.sentBorder,
    required this.receivedBackground,
    required this.receivedBorder,
  });
}

/// Theme extensions for custom colors
extension ThemeDataExtensions on ThemeData {
  MessageBubbleColors get messageBubbleColors {
    // Default to intelligence theme colors
    return const MessageBubbleColors(
      sentBackground: Color(0xFF1A3A40),
      sentBorder: Color(0xFF007A85),
      receivedBackground: Color(0xFF222E3E),
      receivedBorder: Color(0xFF415A77),
    );
  }

  Color get uploadProgressColor => const Color(0xFF00A9B7);
  Color get uploadFailedColor => const Color(0xFFD32F2F);
  Color get uploadRetryColor => const Color(0xFFFFA000);
  Color get onlineStatusColor => const Color(0xFF388E3C);
  Color get offlineStatusColor => const Color(0xFF6C757D);
}