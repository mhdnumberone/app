// lib/core/navigation/smooth_page_transition.dart
import 'package:flutter/material.dart';

/// Smooth page transition similar to WhatsApp's chat navigation
class SmoothPageTransition<T> extends PageRouteBuilder<T> {
  final Widget child;
  final String? heroTag;
  final Curve curve;
  final Duration duration;
  final Duration reverseDuration;

  SmoothPageTransition({
    required this.child,
    this.heroTag,
    this.curve = Curves.easeInOutCubic,
    this.duration = const Duration(milliseconds: 300),
    this.reverseDuration = const Duration(milliseconds: 250),
    RouteSettings? settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: duration,
          reverseTransitionDuration: reverseDuration,
          settings: settings,
        );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // ✅ WhatsApp-style smooth slide transition with fade
    return _buildSmoothTransition(
      context: context,
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }

  Widget _buildSmoothTransition({
    required BuildContext context,
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
    required Widget child,
  }) {
    const begin = Offset(1.0, 0.0);
    const end = Offset.zero;
    final tween = Tween(begin: begin, end: end);
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: curve,
    );

    // ✅ Slide transition with smooth easing
    final slideTransition = SlideTransition(
      position: tween.animate(curvedAnimation),
      child: child,
    );

    // ✅ Fade transition for extra smoothness
    final fadeTransition = FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: Interval(0.0, 0.7, curve: curve),
      ),
      child: slideTransition,
    );

    // ✅ Scale transition for the previous page (like WhatsApp)
    if (secondaryAnimation.status != AnimationStatus.dismissed) {
      return Stack(
        children: [
          // Previous page scales down slightly
          SlideTransition(
            position: Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(-0.3, 0.0),
            ).animate(CurvedAnimation(
              parent: secondaryAnimation,
              curve: curve,
            )),
            child: ScaleTransition(
              scale: Tween<double>(
                begin: 1.0,
                end: 0.9,
              ).animate(CurvedAnimation(
                parent: secondaryAnimation,
                curve: curve,
              )),
              child: Container(),
            ),
          ),
          // New page slides in
          fadeTransition,
        ],
      );
    }

    return fadeTransition;
  }
}

/// Chat-specific smooth transition with Hero animation support
class ChatPageTransition<T> extends PageRouteBuilder<T> {
  final Widget child;
  final Widget? sourceWidget;
  final String? heroTag;

  ChatPageTransition({
    required this.child,
    this.sourceWidget,
    this.heroTag,
    RouteSettings? settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          settings: settings,
        );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _buildChatTransition(
      context: context,
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }

  Widget _buildChatTransition({
    required BuildContext context,
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
    required Widget child,
  }) {
    // ✅ Multi-layered smooth transition
    final slideAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOutCubic,
    );

    final fadeAnimation = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    final scaleAnimation = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.2, 1.0, curve: Curves.easeInOutCubic),
    );

    // ✅ Main slide transition
    Widget slideTransition = SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(slideAnimation),
      child: child,
    );

    // ✅ Subtle scale effect
    slideTransition = ScaleTransition(
      scale: Tween<double>(
        begin: 0.95,
        end: 1.0,
      ).animate(scaleAnimation),
      child: slideTransition,
    );

    // ✅ Fade in effect
    slideTransition = FadeTransition(
      opacity: fadeAnimation,
      child: slideTransition,
    );

    // ✅ Handle back navigation with previous page animation
    if (secondaryAnimation.status != AnimationStatus.dismissed) {
      return Stack(
        children: [
          // Previous page (chat list) slides and scales
          SlideTransition(
            position: Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(-0.25, 0.0),
            ).animate(CurvedAnimation(
              parent: secondaryAnimation,
              curve: Curves.easeInOutCubic,
            )),
            child: ScaleTransition(
              scale: Tween<double>(
                begin: 1.0,
                end: 0.95,
              ).animate(CurvedAnimation(
                parent: secondaryAnimation,
                curve: Curves.easeInOutCubic,
              )),
              child: FadeTransition(
                opacity: Tween<double>(
                  begin: 1.0,
                  end: 0.8,
                ).animate(CurvedAnimation(
                  parent: secondaryAnimation,
                  curve: Curves.easeInOutCubic,
                )),
                child: Container(), // Previous page content
              ),
            ),
          ),
          // New page (chat screen)
          slideTransition,
        ],
      );
    }

    return slideTransition;
  }
}

/// Extension for easy navigation with smooth transitions
extension SmoothNavigation on BuildContext {
  /// Navigate to chat screen with smooth transition
  Future<T?> pushChatScreen<T extends Object?>(
    Widget screen, {
    String? heroTag,
    Widget? sourceWidget,
  }) {
    return Navigator.of(this).push<T>(
      ChatPageTransition<T>(
        child: screen,
        heroTag: heroTag,
        sourceWidget: sourceWidget,
      ),
    );
  }

  /// Navigate with custom smooth transition
  Future<T?> pushSmooth<T extends Object?>(
    Widget screen, {
    String? heroTag,
    Curve curve = Curves.easeInOutCubic,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return Navigator.of(this).push<T>(
      SmoothPageTransition<T>(
        child: screen,
        heroTag: heroTag,
        curve: curve,
        duration: duration,
      ),
    );
  }
}

/// Pre-configured transitions for different screen types
class AppTransitions {
  /// WhatsApp-style chat navigation
  static Route<T> chatScreen<T>(Widget screen, {String? heroTag}) {
    return ChatPageTransition<T>(
      child: screen,
      heroTag: heroTag,
    );
  }

  /// Smooth general navigation
  static Route<T> smooth<T>(Widget screen, {Curve? curve}) {
    return SmoothPageTransition<T>(
      child: screen,
      curve: curve ?? Curves.easeInOutCubic,
    );
  }

  /// Fast navigation for frequently used screens
  static Route<T> fast<T>(Widget screen) {
    return SmoothPageTransition<T>(
      child: screen,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  /// Slow, smooth navigation for important screens
  static Route<T> elegant<T>(Widget screen) {
    return SmoothPageTransition<T>(
      child: screen,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutQuart,
    );
  }
}