import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'performance_monitor.dart';

/// Utility class for performance-related operations
class PerformanceUtils {
  static final PerformanceMonitor _monitor = PerformanceMonitor.instance;
  
  /// Measure the performance of an async operation
  static Future<T> measureAsync<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    return _monitor.measureAsyncOperation(operationName, operation);
  }
  
  /// Measure the performance of a synchronous operation
  static T measure<T>(
    String operationName,
    T Function() operation,
  ) {
    return _monitor.measureOperation(operationName, operation);
  }
  
  /// Log memory usage at a specific point
  static void logMemoryUsage(String context) {
    _monitor.logMemoryUsage(context);
  }
  
  /// Check for potential memory leaks
  static void checkMemoryLeaks() {
    _monitor.checkForMemoryLeaks();
  }
  
  /// Get current performance metrics
  static PerformanceMetrics getCurrentMetrics() {
    return _monitor.getCurrentMetrics();
  }
  
  /// Reset all performance metrics
  static void reset() {
    _monitor.resetMetrics();
  }
  
  /// Generate and log a performance report
  static void generateReport() {
    if (kDebugMode) {
      log('Generating performance report...');
      final metrics = getCurrentMetrics();
      
      final report = StringBuffer();
      report.writeln('=== Performance Summary ===');
      report.writeln('Average frame time: ${metrics.averageFrameTime.inMilliseconds}ms');
      report.writeln('Dropped frame rate: ${(metrics.droppedFrameRate * 100).toStringAsFixed(1)}%');
      report.writeln('Total operations: ${metrics.totalOperations}');
      report.writeln('Slow operations: ${metrics.slowOperations.length}');
      
      if (metrics.slowOperations.isNotEmpty) {
        report.writeln('\nSlow Operations:');
        for (final op in metrics.slowOperations) {
          report.writeln('  ${op.name}: ${op.duration.inMilliseconds}ms');
        }
      }
      
      if (metrics.hasPerformanceIssues) {
        report.writeln('\n⚠️ Performance issues detected!');
      } else {
        report.writeln('\n✅ Performance looks good');
      }
      
      log(report.toString());
    }
  }
  
  /// Create a performance-aware timer
  static Timer createPerformanceTimer(Duration duration, void Function() callback) {
    return Timer.periodic(duration, (timer) {
      measure('timer_callback_${timer.hashCode}', callback);
    });
  }
  
  /// Debounce function calls for performance
  static Function debounce(
    Function func,
    Duration delay, {
    String? operationName,
  }) {
    Timer? timer;
    return ([arg1, arg2, arg3, arg4, arg5]) {
      timer?.cancel();
      timer = Timer(delay, () {
        if (operationName != null) {
          measure(operationName, () => func(arg1, arg2, arg3, arg4, arg5));
        } else {
          func(arg1, arg2, arg3, arg4, arg5);
        }
      });
    };
  }
  
  /// Throttle function calls for performance
  static Function throttle(
    Function func,
    Duration delay, {
    String? operationName,
  }) {
    bool isThrottled = false;
    return ([arg1, arg2, arg3, arg4, arg5]) {
      if (isThrottled) return;
      
      isThrottled = true;
      Timer(delay, () => isThrottled = false);
      
      if (operationName != null) {
        measure(operationName, () => func(arg1, arg2, arg3, arg4, arg5));
      } else {
        func(arg1, arg2, arg3, arg4, arg5);
      }
    };
  }
  
  /// Measure widget build performance
  static Widget measureWidgetBuild(
    String widgetName,
    Widget Function() builder,
  ) {
    return measure('${widgetName}_build', builder);
  }
  
  /// Performance-aware Future.delayed
  static Future<T> delayedOperation<T>(
    Duration delay,
    String operationName,
    T Function() operation,
  ) async {
    final stopwatch = Stopwatch()..start();
    await Future.delayed(delay);
    final result = measure(operationName, operation);
    stopwatch.stop();
    
    if (kDebugMode && stopwatch.elapsedMilliseconds > delay.inMilliseconds + 100) {
      log('Warning: delayed operation "$operationName" took longer than expected: ${stopwatch.elapsedMilliseconds}ms');
    }
    
    return result;
  }
  
  /// Check if current performance is acceptable
  static bool isPerformanceAcceptable() {
    final metrics = getCurrentMetrics();
    return !metrics.hasPerformanceIssues;
  }
  
  /// Get performance grade (A-F)
  static String getPerformanceGrade() {
    final metrics = getCurrentMetrics();
    
    // Calculate score based on multiple factors
    int score = 100;
    
    // Frame rate score (60%)
    if (metrics.droppedFrameRate > 0.2) score -= 30;
    else if (metrics.droppedFrameRate > 0.1) score -= 15;
    else if (metrics.droppedFrameRate > 0.05) score -= 5;
    
    // Frame time score (30%)
    if (metrics.averageFrameTime.inMilliseconds > 20) score -= 20;
    else if (metrics.averageFrameTime.inMilliseconds > 16) score -= 10;
    
    // Slow operations score (10%)
    if (metrics.slowOperations.length > 5) score -= 10;
    else if (metrics.slowOperations.length > 2) score -= 5;
    
    // Return grade
    if (score >= 90) return 'A';
    if (score >= 80) return 'B';
    if (score >= 70) return 'C';
    if (score >= 60) return 'D';
    return 'F';
  }
}