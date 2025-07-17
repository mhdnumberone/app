import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../utils/logger.dart';

/// Performance monitoring system to track app performance and identify bottlenecks
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  static PerformanceMonitor get instance => _instance;
  
  factory PerformanceMonitor() => _instance;
  
  PerformanceMonitor._internal() {
    _startMonitoring();
  }
  
  // Performance metrics
  final Map<String, Duration> _operationTimes = {};
  final Map<String, int> _operationCounts = {};
  final List<FrameMetrics> _frameMetrics = [];
  final Map<String, DateTime> _ongoingOperations = {};
  
  // Thresholds for performance warnings
  static const Duration _slowOperationThreshold = Duration(milliseconds: 100);
  static const Duration _verySlowOperationThreshold = Duration(milliseconds: 500);
  static const int _maxFrameMetrics = 100;
  
  bool _isMonitoring = false;
  Timer? _reportTimer;
  
  void _startMonitoring() {
    if (_isMonitoring) return;
    
    _isMonitoring = true;
    
    // Monitor frame rendering performance
    if (kDebugMode) {
      SchedulerBinding.instance.addTimingsCallback(_onFrameMetrics);
    }
    
    // Periodic performance reporting
    _reportTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _generatePerformanceReport();
    });
    
    AppLogger.info('Performance monitoring started');
  }
  
  void stopMonitoring() {
    if (!_isMonitoring) return;
    
    _isMonitoring = false;
    _reportTimer?.cancel();
    
    if (kDebugMode) {
      SchedulerBinding.instance.removeTimingsCallback(_onFrameMetrics);
    }
    
    AppLogger.info('Performance monitoring stopped');
  }
  
  /// Start timing an operation
  void startOperation(String operationName) {
    _ongoingOperations[operationName] = DateTime.now();
    _operationCounts[operationName] = (_operationCounts[operationName] ?? 0) + 1;
  }
  
  /// End timing an operation
  void endOperation(String operationName) {
    final startTime = _ongoingOperations.remove(operationName);
    if (startTime == null) {
      AppLogger.warning('Attempted to end operation "$operationName" that was not started');
      return;
    }
    
    final duration = DateTime.now().difference(startTime);
    _operationTimes[operationName] = duration;
    
    // Log slow operations
    if (duration > _verySlowOperationThreshold) {
      AppLogger.warning('Very slow operation: $operationName took ${duration.inMilliseconds}ms');
    } else if (duration > _slowOperationThreshold) {
      AppLogger.info('Slow operation: $operationName took ${duration.inMilliseconds}ms');
    }
  }
  
  /// Measure the time of a function execution
  T measureOperation<T>(String operationName, T Function() operation) {
    startOperation(operationName);
    try {
      return operation();
    } finally {
      endOperation(operationName);
    }
  }
  
  /// Measure the time of an async function execution
  Future<T> measureAsyncOperation<T>(String operationName, Future<T> Function() operation) async {
    startOperation(operationName);
    try {
      return await operation();
    } finally {
      endOperation(operationName);
    }
  }
  
  /// Handle frame metrics for rendering performance
  void _onFrameMetrics(List<FrameTiming> timings) {
    for (final timing in timings) {
      final metrics = FrameMetrics(
        buildDuration: timing.buildDuration,
        rasterDuration: timing.rasterDuration,
        totalDuration: timing.totalSpan,
        timestamp: DateTime.now(),
      );
      
      _frameMetrics.add(metrics);
      
      // Keep only recent metrics
      if (_frameMetrics.length > _maxFrameMetrics) {
        _frameMetrics.removeAt(0);
      }
      
      // Log problematic frames
      if (metrics.totalDuration > const Duration(milliseconds: 16)) {
        AppLogger.warning('Dropped frame: ${metrics.totalDuration.inMilliseconds}ms');
      }
    }
  }
  
  /// Generate a comprehensive performance report
  void _generatePerformanceReport() {
    if (!kDebugMode) return;
    
    final report = StringBuffer();
    report.writeln('=== Performance Report ===');
    
    // Operation performance
    if (_operationTimes.isNotEmpty) {
      report.writeln('\nOperation Performance:');
      _operationTimes.entries
          .toList()
          ..sort((a, b) => b.value.compareTo(a.value))
          ..forEach((entry) {
            final count = _operationCounts[entry.key] ?? 0;
            report.writeln('  ${entry.key}: ${entry.value.inMilliseconds}ms (${count}x)');
          });
    }
    
    // Frame performance
    if (_frameMetrics.isNotEmpty) {
      final avgBuildTime = _frameMetrics
          .map((m) => m.buildDuration.inMicroseconds)
          .reduce((a, b) => a + b) / _frameMetrics.length;
      
      final avgRasterTime = _frameMetrics
          .map((m) => m.rasterDuration.inMicroseconds)
          .reduce((a, b) => a + b) / _frameMetrics.length;
      
      final droppedFrames = _frameMetrics
          .where((m) => m.totalDuration > const Duration(milliseconds: 16))
          .length;
      
      report.writeln('\nFrame Performance:');
      report.writeln('  Average build time: ${(avgBuildTime / 1000).toStringAsFixed(2)}ms');
      report.writeln('  Average raster time: ${(avgRasterTime / 1000).toStringAsFixed(2)}ms');
      report.writeln('  Dropped frames: $droppedFrames/${_frameMetrics.length}');
    }
    
    // Memory usage (if available)
    try {
      report.writeln('\nMemory Performance: Check Flutter Inspector');
    } catch (e) {
      // Performance overlay may not be available
    }
    
    AppLogger.info(report.toString());
  }
  
  /// Get current performance metrics
  PerformanceMetrics getCurrentMetrics() {
    final recentFrames = _frameMetrics.length > 10 
        ? _frameMetrics.sublist(_frameMetrics.length - 10)
        : _frameMetrics;
    
    final avgFrameTime = recentFrames.isNotEmpty
        ? recentFrames
            .map((m) => m.totalDuration.inMicroseconds)
            .reduce((a, b) => a + b) / recentFrames.length
        : 0.0;
    
    final droppedFrameRate = recentFrames.isNotEmpty
        ? recentFrames
            .where((m) => m.totalDuration > const Duration(milliseconds: 16))
            .length / recentFrames.length
        : 0.0;
    
    return PerformanceMetrics(
      averageFrameTime: Duration(microseconds: avgFrameTime.round()),
      droppedFrameRate: droppedFrameRate,
      slowOperations: _operationTimes.entries
          .where((entry) => entry.value > _slowOperationThreshold)
          .map((entry) => SlowOperation(entry.key, entry.value))
          .toList(),
      totalOperations: _operationCounts.values.fold(0, (a, b) => a + b),
    );
  }
  
  /// Reset all performance metrics
  void resetMetrics() {
    _operationTimes.clear();
    _operationCounts.clear();
    _frameMetrics.clear();
    _ongoingOperations.clear();
    
    AppLogger.info('Performance metrics reset');
  }
  
  /// Log memory usage
  void logMemoryUsage(String context) {
    if (kDebugMode) {
      // This would require additional platform-specific implementation
      AppLogger.info('Memory usage check: $context');
    }
  }
  
  /// Check for potential memory leaks
  void checkForMemoryLeaks() {
    // Check for operations that haven't been completed
    if (_ongoingOperations.isNotEmpty) {
      AppLogger.warning('Potential memory leaks - ongoing operations: ${_ongoingOperations.keys.join(", ")}');
    }
    
    // Check for excessive operation counts
    _operationCounts.forEach((operation, count) {
      if (count > 1000) {
        AppLogger.warning('High operation count for "$operation": $count times');
      }
    });
  }
  
  void dispose() {
    stopMonitoring();
    resetMetrics();
  }
}

/// Performance metrics data class
class PerformanceMetrics {
  final Duration averageFrameTime;
  final double droppedFrameRate;
  final List<SlowOperation> slowOperations;
  final int totalOperations;
  
  const PerformanceMetrics({
    required this.averageFrameTime,
    required this.droppedFrameRate,
    required this.slowOperations,
    required this.totalOperations,
  });
  
  bool get hasPerformanceIssues {
    return droppedFrameRate > 0.1 || // More than 10% dropped frames
           averageFrameTime > const Duration(milliseconds: 16) || // Slow frames
           slowOperations.isNotEmpty; // Slow operations detected
  }
}

/// Frame metrics data class
class FrameMetrics {
  final Duration buildDuration;
  final Duration rasterDuration;
  final Duration totalDuration;
  final DateTime timestamp;
  
  const FrameMetrics({
    required this.buildDuration,
    required this.rasterDuration,
    required this.totalDuration,
    required this.timestamp,
  });
}

/// Slow operation data class
class SlowOperation {
  final String name;
  final Duration duration;
  
  const SlowOperation(this.name, this.duration);
}

/// Widget to display performance overlay
class PerformanceOverlayWidget extends StatefulWidget {
  final Widget child;
  
  const PerformanceOverlayWidget({
    super.key,
    required this.child,
  });
  
  @override
  State<PerformanceOverlayWidget> createState() => _PerformanceOverlayWidgetState();
}

class _PerformanceOverlayWidgetState extends State<PerformanceOverlayWidget> {
  Timer? _updateTimer;
  PerformanceMetrics? _metrics;
  
  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          _metrics = PerformanceMonitor.instance.getCurrentMetrics();
        });
      });
    }
  }
  
  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    if (!kDebugMode || _metrics == null) {
      return widget.child;
    }
    
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 50,
          right: 10,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Performance',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Frame: ${_metrics!.averageFrameTime.inMilliseconds}ms',
                  style: TextStyle(
                    color: _metrics!.averageFrameTime.inMilliseconds > 16 
                        ? Colors.red 
                        : Colors.green,
                    fontSize: 10,
                  ),
                ),
                Text(
                  'Dropped: ${(_metrics!.droppedFrameRate * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: _metrics!.droppedFrameRate > 0.1 
                        ? Colors.red 
                        : Colors.green,
                    fontSize: 10,
                  ),
                ),
                Text(
                  'Ops: ${_metrics!.totalOperations}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Mixin for widgets that want to monitor their performance
mixin PerformanceTrackingMixin<T extends StatefulWidget> on State<T> {
  late final String _widgetName;
  
  @override
  void initState() {
    super.initState();
    _widgetName = T.toString();
    PerformanceMonitor.instance.startOperation('${_widgetName}_build');
  }
  
  @override
  Widget build(BuildContext context) {
    return PerformanceMonitor.instance.measureOperation(
      '${_widgetName}_build',
      () => buildWithTracking(context),
    );
  }
  
  /// Override this method instead of build() when using this mixin
  Widget buildWithTracking(BuildContext context);
  
  @override
  void dispose() {
    PerformanceMonitor.instance.endOperation('${_widgetName}_lifecycle');
    super.dispose();
  }
}