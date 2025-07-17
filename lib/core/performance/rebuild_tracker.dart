// Comprehensive Rebuild Tracking System
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Performance monitoring and rebuild tracking system
class RebuildTracker {
  static final RebuildTracker _instance = RebuildTracker._internal();
  static RebuildTracker get instance => _instance;
  
  factory RebuildTracker() => _instance;
  RebuildTracker._internal();
  
  final Map<String, RebuildData> _rebuilds = {};
  final Map<String, DateTime> _lastLog = {};
  final Set<String> _enabledScreens = {};
  
  bool _isEnabled = kDebugMode;
  
  /// Enable tracking for specific screens
  void enableForScreens(List<String> screenNames) {
    _enabledScreens.addAll(screenNames);
  }
  
  /// Disable tracking
  void disable() {
    _isEnabled = false;
  }
  
  /// Track widget rebuild
  void trackRebuild(String widgetName, {
    String? reason,
    Map<String, dynamic>? context,
  }) {
    if (!_isEnabled) return;
    
    final now = DateTime.now();
    final key = widgetName;
    
    if (_rebuilds.containsKey(key)) {
      _rebuilds[key]!.incrementCount();
      _rebuilds[key]!.lastRebuild = now;
      if (reason != null) {
        _rebuilds[key]!.addReason(reason);
      }
    } else {
      _rebuilds[key] = RebuildData(
        widgetName: widgetName,
        firstRebuild: now,
        lastRebuild: now,
        reason: reason,
        context: context,
      );
    }
    
    _logIfNeeded(key, now);
  }
  
  /// Track navigation events
  void trackNavigation(String from, String to, {
    Duration? duration,
    String? reason,
  }) {
    if (!_isEnabled) return;
    
    log('🚀 Navigation: $from → $to ${duration != null ? '(${duration.inMilliseconds}ms)' : ''}');
    if (reason != null) {
      log('📋 Reason: $reason');
    }
  }
  
  /// Track performance metrics
  void trackPerformance(String operation, Duration duration, {
    Map<String, dynamic>? metrics,
  }) {
    if (!_isEnabled) return;
    
    final ms = duration.inMilliseconds;
    final severity = _getPerformanceSeverity(ms);
    
    log('⚡ Performance: $operation - ${ms}ms $severity');
    if (metrics != null) {
      log('📊 Metrics: $metrics');
    }
  }
  
  /// Get rebuild statistics
  Map<String, RebuildData> getRebuildStats() {
    return Map.unmodifiable(_rebuilds);
  }
  
  /// Get hot widgets (most rebuilt)
  List<RebuildData> getHotWidgets({int limit = 10}) {
    final widgets = _rebuilds.values.toList();
    widgets.sort((a, b) => b.count.compareTo(a.count));
    return widgets.take(limit).toList();
  }
  
  /// Clear statistics
  void clearStats() {
    _rebuilds.clear();
    _lastLog.clear();
  }
  
  /// Print comprehensive report
  void printReport() {
    if (!_isEnabled) return;
    
    log('\n🔍 REBUILD TRACKER REPORT');
    log('=' * 50);
    
    final hotWidgets = getHotWidgets();
    log('🔥 Top Rebuilt Widgets:');
    for (final widget in hotWidgets) {
      log('  ${widget.widgetName}: ${widget.count} rebuilds');
      if (widget.reasons.isNotEmpty) {
        log('    Reasons: ${widget.reasons.join(', ')}');
      }
    }
    
    log('\n📊 Total Widgets Tracked: ${_rebuilds.length}');
    log('=' * 50);
  }
  
  void _logIfNeeded(String key, DateTime now) {
    final lastLog = _lastLog[key];
    if (lastLog == null || now.difference(lastLog).inMilliseconds > 1000) {
      final data = _rebuilds[key]!;
      log('🔄 Rebuild: ${data.widgetName} (${data.count} times)');
      _lastLog[key] = now;
    }
  }
  
  String _getPerformanceSeverity(int ms) {
    if (ms > 500) return '🚨 CRITICAL';
    if (ms > 200) return '⚠️ HIGH';
    if (ms > 100) return '🟡 MEDIUM';
    return '✅ GOOD';
  }
}

/// Data class for rebuild information
class RebuildData {
  final String widgetName;
  final DateTime firstRebuild;
  DateTime lastRebuild;
  final Map<String, dynamic>? context;
  final Set<String> reasons = {};
  
  int count = 1;
  
  RebuildData({
    required this.widgetName,
    required this.firstRebuild,
    required this.lastRebuild,
    String? reason,
    this.context,
  }) {
    if (reason != null) {
      reasons.add(reason);
    }
  }
  
  void incrementCount() {
    count++;
  }
  
  void addReason(String reason) {
    reasons.add(reason);
  }
  
  Duration get totalDuration => lastRebuild.difference(firstRebuild);
  
  @override
  String toString() {
    return 'RebuildData(widget: $widgetName, count: $count, duration: ${totalDuration.inMilliseconds}ms)';
  }
}

/// Widget wrapper for automatic rebuild tracking
class RebuildTrackingWidget extends StatefulWidget {
  final Widget child;
  final String name;
  final String? reason;
  final Map<String, dynamic>? context;
  
  const RebuildTrackingWidget({
    super.key,
    required this.child,
    required this.name,
    this.reason,
    this.context,
  });
  
  @override
  State<RebuildTrackingWidget> createState() => _RebuildTrackingWidgetState();
}

class _RebuildTrackingWidgetState extends State<RebuildTrackingWidget> {
  @override
  Widget build(BuildContext context) {
    RebuildTracker.instance.trackRebuild(
      widget.name,
      reason: widget.reason,
      context: widget.context,
    );
    return widget.child;
  }
}

/// Mixin for automatic rebuild tracking
mixin RebuildTrackingMixin<T extends StatefulWidget> on State<T> {
  String get trackingName => T.toString();
  
  @override
  Widget build(BuildContext context) {
    RebuildTracker.instance.trackRebuild(trackingName);
    return buildTracked(context);
  }
  
  Widget buildTracked(BuildContext context);
}

/// Extension for navigation tracking
extension NavigationTracking on NavigatorState {
  Future<T?> pushTracked<T extends Object?>(
    Route<T> route, {
    String? from,
    String? to,
    String? reason,
  }) {
    final stopwatch = Stopwatch()..start();
    
    return push(route).then((result) {
      stopwatch.stop();
      RebuildTracker.instance.trackNavigation(
        from ?? 'Unknown',
        to ?? route.settings.name ?? 'Unknown',
        duration: stopwatch.elapsed,
        reason: reason,
      );
      return result;
    });
  }
}

/// Custom performance profiler
class PerformanceProfiler {
  static final Map<String, Stopwatch> _stopwatches = {};
  
  static void start(String operation) {
    _stopwatches[operation] = Stopwatch()..start();
  }
  
  static void end(String operation, {Map<String, dynamic>? metrics}) {
    final stopwatch = _stopwatches[operation];
    if (stopwatch != null) {
      stopwatch.stop();
      RebuildTracker.instance.trackPerformance(
        operation,
        stopwatch.elapsed,
        metrics: metrics,
      );
      _stopwatches.remove(operation);
    }
  }
  
  static T measure<T>(String operation, T Function() callback, {Map<String, dynamic>? metrics}) {
    start(operation);
    try {
      return callback();
    } finally {
      end(operation, metrics: metrics);
    }
  }
}

/// Widget profiler
class WidgetProfiler extends StatefulWidget {
  final Widget child;
  final String name;
  
  const WidgetProfiler({
    super.key,
    required this.child,
    required this.name,
  });
  
  @override
  State<WidgetProfiler> createState() => _WidgetProfilerState();
}

class _WidgetProfilerState extends State<WidgetProfiler> {
  late final Stopwatch _stopwatch;
  
  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
  }
  
  @override
  void dispose() {
    _stopwatch.stop();
    RebuildTracker.instance.trackPerformance(
      'Widget Lifetime: ${widget.name}',
      _stopwatch.elapsed,
    );
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Performance monitor widget
class PerformanceMonitor extends StatefulWidget {
  final Widget child;
  final bool showOverlay;
  
  const PerformanceMonitor({
    super.key,
    required this.child,
    this.showOverlay = false,
  });
  
  @override
  State<PerformanceMonitor> createState() => _PerformanceMonitorState();
}

class _PerformanceMonitorState extends State<PerformanceMonitor> {
  @override
  void initState() {
    super.initState();
    RebuildTracker.instance.enableForScreens([
      'ChatScreen',
      'HomeScreen',
      'ProfileScreen',
      'SettingsScreen',
    ]);
  }
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.showOverlay) _buildOverlay(),
      ],
    );
  }
  
  Widget _buildOverlay() {
    return Positioned(
      top: 100,
      right: 10,
      child: Material(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Performance',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              StreamBuilder<double>(
                stream: _getFrameRateStream(),
                builder: (context, snapshot) {
                  final fps = snapshot.data ?? 0.0;
                  return Text(
                    'FPS: ${fps.toStringAsFixed(1)}',
                    style: TextStyle(
                      color: fps > 50 ? Colors.green : Colors.red,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Stream<double> _getFrameRateStream() {
    // Simplified frame rate monitoring
    return Stream.periodic(
      const Duration(milliseconds: 500),
      (i) => 60.0, // Placeholder
    );
  }
}