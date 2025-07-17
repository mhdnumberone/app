import 'package:flutter/material.dart';
import '../themes/theme_service.dart';
import '../themes/app_theme_extension.dart';
import '../localization/app_localizations.dart';

/// Base stateless widget with theme access
abstract class BaseStatelessWidget extends StatelessWidget {
  const BaseStatelessWidget({super.key});
  
  /// Get theme service
  ThemeService get themeService => ThemeService.instance;
  
  /// Get localization
  AppLocalizations localizations(BuildContext context) => AppLocalizations.of(context)!;
  
  /// Get theme colors from context
  ColorScheme colors(BuildContext context) => Theme.of(context).colorScheme;
  
  /// Build method to be implemented by subclasses
  @override
  Widget build(BuildContext context);
}

/// Base stateful widget with theme access
abstract class BaseStatefulWidget extends StatefulWidget {
  const BaseStatefulWidget({super.key});
}

/// Base state with theme access
abstract class BaseState<T extends BaseStatefulWidget> extends State<T> {
  /// Get theme service
  ThemeService get themeService => ThemeService.instance;
  
  /// Get localization
  AppLocalizations get localizations => AppLocalizations.of(context)!;
  
  /// Get theme colors from context
  ColorScheme get colors => Theme.of(context).colorScheme;
  
  /// Build method to be implemented by subclasses
  @override
  Widget build(BuildContext context);
}

/// Base card widget with consistent styling
class BaseCardWidget extends BaseStatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double? elevation;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  
  const BaseCardWidget({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.elevation,
    this.backgroundColor,
    this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    
    return Container(
      margin: margin ?? const EdgeInsets.all(8),
      child: Material(
        elevation: elevation ?? 2,
        borderRadius: BorderRadius.circular(12),
        color: backgroundColor ?? appColors.surface,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Base loading widget
class BaseLoadingWidget extends BaseStatelessWidget {
  final String? message;
  final double? size;
  
  const BaseLoadingWidget({
    super.key,
    this.message,
    this.size,
  });
  
  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: size ?? 48,
            height: size ?? 48,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(appColors.primary),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: TextStyle(
                fontSize: 16,
                color: appColors.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Base error widget
class BaseErrorWidget extends BaseStatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  
  const BaseErrorWidget({
    super.key,
    required this.message,
    this.onRetry,
  });
  
  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: appColors.error,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: appColors.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: Text(localizations(context).retry),
            ),
          ],
        ],
      ),
    );
  }
}

/// Base empty state widget
class BaseEmptyStateWidget extends BaseStatelessWidget {
  final String message;
  final IconData icon;
  final VoidCallback? onAction;
  final String? actionLabel;
  
  const BaseEmptyStateWidget({
    super.key,
    required this.message,
    required this.icon,
    this.onAction,
    this.actionLabel,
  });
  
  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: appColors.onSurface.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: appColors.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}