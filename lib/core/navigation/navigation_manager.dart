// Comprehensive Navigation State Management System
import 'dart:developer';
import 'package:flutter/material.dart';
import '../performance/rebuild_tracker.dart';
import '../../models/chat_user.dart';
import '../../screens/chat/chat_screen.dart';

/// Navigation state manager to prevent unnecessary rebuilds
class NavigationManager {
  static final NavigationManager _instance = NavigationManager._internal();
  static NavigationManager get instance => _instance;
  
  factory NavigationManager() => _instance;
  NavigationManager._internal();
  
  // Cache for screen instances
  final Map<String, Widget> _screenCache = {};
  final Map<String, GlobalKey> _screenKeys = {};
  
  // Navigation state tracking
  final List<String> _navigationHistory = [];
  String? _currentScreen;
  
  // Chat screen management
  final Map<String, ChatScreen> _chatScreens = {};
  final Map<String, GlobalKey<NavigatorState>> _chatKeys = {};
  
  /// Get or create cached screen
  Widget getCachedScreen(String screenName, Widget Function() builder) {
    if (!_screenCache.containsKey(screenName)) {
      _screenCache[screenName] = builder();
      _screenKeys[screenName] = GlobalKey();
    }
    return _screenCache[screenName]!;
  }
  
  /// Navigate to chat screen with caching
  Future<T?> navigateToChat<T>(
    BuildContext context,
    ChatUser user, {
    bool useCache = true,
  }) async {
    final screenName = 'chat_${user.id}';
    
    PerformanceProfiler.start('Navigate to Chat');
    
    try {
      Widget chatScreen;
      
      if (useCache && _chatScreens.containsKey(user.id)) {
        chatScreen = _chatScreens[user.id]!;
        log('🔄 Using cached chat screen for ${user.name}');
      } else {
        chatScreen = ChatScreen(user: user);
        if (useCache) {
          _chatScreens[user.id] = chatScreen as ChatScreen;
          _chatKeys[user.id] = GlobalKey<NavigatorState>();
        }
        log('🆕 Created new chat screen for ${user.name}');
      }
      
      _trackNavigation(_currentScreen ?? 'Unknown', screenName);
      
      log('Attempting to push route for screen: $screenName');
      final result = await Navigator.push<T>(
        context,
        OptimizedPageRoute(
          builder: (context) {
            log('Building OptimizedPageRoute for: $screenName');
            return chatScreen;
          },
          settings: RouteSettings(name: screenName),
        ),
      );
      log('Navigation to $screenName completed.');
      
      PerformanceProfiler.end('Navigate to Chat');
      return result;
      
    } catch (e) {
      PerformanceProfiler.end('Navigate to Chat');
      log('❌ Navigation error: $e');
      rethrow;
    }
  }
  
  /// Navigate with optimization
  Future<T?> navigateOptimized<T>(
    BuildContext context,
    Widget screen,
    String screenName, {
    bool useCache = false,
    bool clearStack = false,
  }) async {
    PerformanceProfiler.start('Navigate Optimized');
    
    try {
      final widget = useCache ? getCachedScreen(screenName, () => screen) : screen;
      
      _trackNavigation(_currentScreen ?? 'Unknown', screenName);
      
      Future<T?> navigationFuture;
      
      if (clearStack) {
        navigationFuture = Navigator.pushAndRemoveUntil<T>(
          context,
          OptimizedPageRoute(
            builder: (context) => widget,
            settings: RouteSettings(name: screenName),
          ),
          (route) => false,
        );
      } else {
        navigationFuture = Navigator.push<T>(
          context,
          OptimizedPageRoute(
            builder: (context) => widget,
            settings: RouteSettings(name: screenName),
          ),
        );
      }
      
      final result = await navigationFuture;
      PerformanceProfiler.end('Navigate Optimized');
      return result;
      
    } catch (e) {
      PerformanceProfiler.end('Navigate Optimized');
      log('❌ Navigation error: $e');
      rethrow;
    }
  }
  
  /// Pop with tracking
  void popTracked(BuildContext context, [dynamic result]) {
    final currentRoute = ModalRoute.of(context);
    final routeName = currentRoute?.settings.name ?? 'Unknown';
    
    _trackNavigation(routeName, _getPreviousScreen());
    Navigator.pop(context, result);
  }
  
  /// Clear chat cache for specific user
  void clearChatCache(String userId) {
    _chatScreens.remove(userId);
    _chatKeys.remove(userId);
    log('🗑️ Cleared chat cache for user: $userId');
  }
  
  /// Clear all cached screens
  void clearAllCache() {
    _screenCache.clear();
    _screenKeys.clear();
    _chatScreens.clear();
    _chatKeys.clear();
    log('🗑️ Cleared all navigation cache');
  }
  
  /// Get navigation history
  List<String> getNavigationHistory() {
    return List.unmodifiable(_navigationHistory);
  }
  
  /// Track navigation internally
  void _trackNavigation(String from, String to) {
    _navigationHistory.add('$from → $to');
    _currentScreen = to;
    
    // Keep only last 50 entries
    if (_navigationHistory.length > 50) {
      _navigationHistory.removeAt(0);
    }
    
    RebuildTracker.instance.trackNavigation(from, to);
  }
  
  /// Get previous screen name
  String _getPreviousScreen() {
    if (_navigationHistory.isNotEmpty) {
      final lastEntry = _navigationHistory.last;
      return lastEntry.split(' → ').first;
    }
    return 'Unknown';
  }
  
  /// Preload chat screen
  void preloadChatScreen(ChatUser user) {
    if (!_chatScreens.containsKey(user.id)) {
      _chatScreens[user.id] = ChatScreen(user: user);
      _chatKeys[user.id] = GlobalKey<NavigatorState>();
      log('📥 Preloaded chat screen for ${user.name}');
    }
  }
  
  /// Memory management
  void cleanupMemory() {
    // Remove screens that haven't been used recently
    final cutoff = DateTime.now().subtract(const Duration(minutes: 10));
    
    // This is a simplified cleanup - you might want to add timestamp tracking
    if (_chatScreens.length > 10) {
      final oldestKey = _chatScreens.keys.first;
      _chatScreens.remove(oldestKey);
      _chatKeys.remove(oldestKey);
      log('🧹 Cleaned up old chat screen: $oldestKey');
    }
  }
}

/// Optimized page route to prevent rebuilds
class OptimizedPageRoute<T> extends PageRouteBuilder<T> {
  final Widget screen;
  
  OptimizedPageRoute({
    required WidgetBuilder builder,
    RouteSettings? settings,
    Duration transitionDuration = const Duration(milliseconds: 300),
  }) : screen = builder(null as BuildContext),
       super(
         pageBuilder: (context, animation, secondaryAnimation) => builder(context),
         transitionDuration: transitionDuration,
         settings: settings,
       );
  
  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Optimized slide transition
    return SlideTransition(
      position: animation.drive(
        Tween(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeInOut)),
      ),
      child: child,
    );
  }
}

/// Navigation aware widget base class
abstract class NavigationAwareWidget extends StatefulWidget {
  const NavigationAwareWidget({super.key});
  
  @override
  State<NavigationAwareWidget> createState();
}

abstract class NavigationAwareWidgetState<T extends NavigationAwareWidget> extends State<T> {
  String get screenName => T.toString();
  
  @override
  void initState() {
    super.initState();
    NavigationManager.instance._currentScreen = screenName;
  }
  
  @override
  Widget build(BuildContext context) {
    return RebuildTrackingWidget(
      name: screenName,
      child: buildScreen(context),
    );
  }
  
  Widget buildScreen(BuildContext context);
}

/// Mixin for navigation tracking
mixin NavigationTrackingMixin<T extends StatefulWidget> on State<T> {
  String get screenName => T.toString();
  
  @override
  void initState() {
    super.initState();
    NavigationManager.instance._currentScreen = screenName;
  }
  
  /// Navigate to chat with tracking
  Future<void> navigateToChat(ChatUser user) async {
    await NavigationManager.instance.navigateToChat(
      context,
      user,
      useCache: true,
    );
  }
  
  /// Navigate with tracking
  Future<T?> navigateTracked<T>(Widget screen, String screenName) async {
    return NavigationManager.instance.navigateOptimized<T>(
      context,
      screen,
      screenName,
    );
  }
  
  /// Pop with tracking
  void popTracked([dynamic result]) {
    NavigationManager.instance.popTracked(context, result);
  }
}

/// Chat screen cache manager
class ChatScreenCacheManager {
  static final ChatScreenCacheManager _instance = ChatScreenCacheManager._internal();
  static ChatScreenCacheManager get instance => _instance;
  
  factory ChatScreenCacheManager() => _instance;
  ChatScreenCacheManager._internal();
  
  final Map<String, ChatScreen> _cache = {};
  final Map<String, DateTime> _lastAccess = {};
  
  /// Get or create chat screen
  ChatScreen getChatScreen(ChatUser user) {
    final userId = user.id;
    
    if (_cache.containsKey(userId)) {
      _lastAccess[userId] = DateTime.now();
      return _cache[userId]!;
    }
    
    final chatScreen = ChatScreen(user: user);
    _cache[userId] = chatScreen;
    _lastAccess[userId] = DateTime.now();
    
    // Clean up old entries
    _cleanupOldEntries();
    
    return chatScreen;
  }
  
  /// Remove from cache
  void remove(String userId) {
    _cache.remove(userId);
    _lastAccess.remove(userId);
  }
  
  /// Clear all cache
  void clear() {
    _cache.clear();
    _lastAccess.clear();
  }
  
  /// Cleanup old entries
  void _cleanupOldEntries() {
    if (_cache.length <= 10) return;
    
    final cutoff = DateTime.now().subtract(const Duration(minutes: 5));
    final toRemove = <String>[];
    
    for (final entry in _lastAccess.entries) {
      if (entry.value.isBefore(cutoff)) {
        toRemove.add(entry.key);
      }
    }
    
    for (final userId in toRemove) {
      _cache.remove(userId);
      _lastAccess.remove(userId);
    }
    
    log('🧹 Cleaned up ${toRemove.length} old chat screens');
  }
}

/// Route observer for navigation tracking
class NavigationObserver extends RouteObserver<PageRoute<dynamic>> {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    
    final routeName = route.settings.name ?? 'Unknown';
    final previousRouteName = previousRoute?.settings.name ?? 'Unknown';
    
    RebuildTracker.instance.trackNavigation(previousRouteName, routeName);
  }
  
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    
    final routeName = route.settings.name ?? 'Unknown';
    final previousRouteName = previousRoute?.settings.name ?? 'Unknown';
    
    RebuildTracker.instance.trackNavigation(routeName, previousRouteName);
  }
}

/// Navigation extensions
extension NavigationExtensions on BuildContext {
  /// Push with tracking
  Future<T?> pushTracked<T>(Widget screen, String screenName) {
    return NavigationManager.instance.navigateOptimized<T>(
      this,
      screen,
      screenName,
    );
  }
  
  /// Push chat with caching
  Future<T?> pushChat<T>(ChatUser user) {
    return NavigationManager.instance.navigateToChat<T>(this, user);
  }
  
  /// Pop with tracking
  void popTracked([dynamic result]) {
    NavigationManager.instance.popTracked(this, result);
  }
}