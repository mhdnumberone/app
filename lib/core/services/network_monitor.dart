// lib/core/services/network_monitor.dart

import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';

enum NetworkQuality {
  none,
  poor,
  moderate,
  good,
  excellent,
}

enum NetworkType {
  none,
  wifi,
  mobile,
  ethernet,
  vpn,
  other,
}

class NetworkState {
  final bool isConnected;
  final NetworkType type;
  final NetworkQuality quality;
  final int? downloadSpeedKbps;
  final int? pingMs;
  final DateTime lastChecked;
  final bool isMetered;

  NetworkState({
    required this.isConnected,
    required this.type,
    required this.quality,
    this.downloadSpeedKbps,
    this.pingMs,
    DateTime? lastChecked,
    this.isMetered = false,
  }) : lastChecked = lastChecked ?? DateTime.now();

  NetworkState copyWith({
    bool? isConnected,
    NetworkType? type,
    NetworkQuality? quality,
    int? downloadSpeedKbps,
    int? pingMs,
    DateTime? lastChecked,
    bool? isMetered,
  }) {
    return NetworkState(
      isConnected: isConnected ?? this.isConnected,
      type: type ?? this.type,
      quality: quality ?? this.quality,
      downloadSpeedKbps: downloadSpeedKbps ?? this.downloadSpeedKbps,
      pingMs: pingMs ?? this.pingMs,
      lastChecked: lastChecked ?? this.lastChecked,
      isMetered: isMetered ?? this.isMetered,
    );
  }

  bool get canDownloadLargeFiles => 
      isConnected && quality != NetworkQuality.none && quality != NetworkQuality.poor;

  bool get shouldLimitDownloads => 
      !isConnected || quality == NetworkQuality.poor || isMetered;

  @override
  String toString() {
    return 'NetworkState(connected: $isConnected, type: $type, quality: $quality, speed: ${downloadSpeedKbps}kbps, ping: ${pingMs}ms)';
  }
}

class NetworkMonitor {
  static final NetworkMonitor _instance = NetworkMonitor._internal();
  factory NetworkMonitor() => _instance;
  NetworkMonitor._internal();

  // State management
  NetworkState _currentState = NetworkState(
    isConnected: false,
    type: NetworkType.none,
    quality: NetworkQuality.none,
  );

  final ValueNotifier<NetworkState> stateNotifier = ValueNotifier(
    NetworkState(
      isConnected: false,
      type: NetworkType.none,
      quality: NetworkQuality.none,
    ),
  );

  // Configuration
  static const Duration _monitoringInterval = Duration(seconds: 30);
  static const Duration _qualityTestInterval = Duration(minutes: 5);
  static const String _testUrl = 'https://www.google.com';
  static const int _testTimeoutSeconds = 10;

  // Internal state
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _qualityTestTimer;
  Timer? _periodicMonitorTimer;
  bool _isInitialized = false;
  bool _isQualityTesting = false;

  // Getters
  NetworkState get currentState => _currentState;
  bool get isConnected => _currentState.isConnected;
  NetworkType get networkType => _currentState.type;
  NetworkQuality get networkQuality => _currentState.quality;
  bool get canDownloadLargeFiles => _currentState.canDownloadLargeFiles;
  bool get shouldLimitDownloads => _currentState.shouldLimitDownloads;

  /// Initialize the network monitor
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      log('🌐 Initializing NetworkMonitor...');

      // Get initial connectivity state
      await _updateConnectivityState();

      // Listen for connectivity changes
      _connectivitySubscription = Connectivity()
          .onConnectivityChanged
          .listen(_onConnectivityChanged);

      // Start periodic monitoring
      _startPeriodicMonitoring();

      // Start quality testing
      _startQualityTesting();

      _isInitialized = true;
      log('✅ NetworkMonitor initialized - ${_currentState}');
    } catch (e) {
      log('❌ Error initializing NetworkMonitor: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _qualityTestTimer?.cancel();
    _periodicMonitorTimer?.cancel();
    stateNotifier.dispose();
    _isInitialized = false;
    log('🗑️ NetworkMonitor disposed');
  }

  /// Force a network quality check
  Future<void> checkNetworkQuality() async {
    if (_isQualityTesting) return;
    _isQualityTesting = true;

    try {
      log('🔍 Testing network quality...');
      
      if (!_currentState.isConnected) {
        _updateState(_currentState.copyWith(
          quality: NetworkQuality.none,
          downloadSpeedKbps: 0,
          pingMs: null,
        ));
        return;
      }

      // Test connection speed and latency
      final stopwatch = Stopwatch()..start();
      
      try {
        final request = await HttpClient().getUrl(Uri.parse(_testUrl))
            .timeout(Duration(seconds: _testTimeoutSeconds));
        
        final response = await request.close()
            .timeout(Duration(seconds: _testTimeoutSeconds));
        
        stopwatch.stop();
        final pingMs = stopwatch.elapsedMilliseconds;
        
        // Read response to test download speed
        final responseData = <int>[];
        final downloadStopwatch = Stopwatch()..start();
        
        await for (final chunk in response) {
          responseData.addAll(chunk);
          // Stop after reasonable amount of data or time
          if (responseData.length > 50000 || downloadStopwatch.elapsedMilliseconds > 3000) {
            break;
          }
        }
        
        downloadStopwatch.stop();
        
        // Calculate download speed (rough estimate)
        final downloadedBytes = responseData.length;
        final downloadTimeSeconds = downloadStopwatch.elapsedMilliseconds / 1000;
        final downloadSpeedKbps = downloadTimeSeconds > 0 
            ? (downloadedBytes * 8 / downloadTimeSeconds / 1000).round()
            : 0;

        // Determine quality based on ping and speed
        final quality = _calculateNetworkQuality(pingMs, downloadSpeedKbps);

        _updateState(_currentState.copyWith(
          quality: quality,
          downloadSpeedKbps: downloadSpeedKbps,
          pingMs: pingMs,
        ));

        log('📊 Network quality test completed: ${quality.name} (${downloadSpeedKbps}kbps, ${pingMs}ms)');
        
      } catch (e) {
        log('❌ Network quality test failed: $e');
        _updateState(_currentState.copyWith(
          quality: NetworkQuality.poor,
          downloadSpeedKbps: 0,
          pingMs: null,
        ));
      }
      
    } finally {
      _isQualityTesting = false;
    }
  }

  /// Calculate network quality based on metrics
  NetworkQuality _calculateNetworkQuality(int pingMs, int speedKbps) {
    // Poor: High ping or very low speed
    if (pingMs > 1000 || speedKbps < 50) {
      return NetworkQuality.poor;
    }
    
    // Moderate: Medium ping or low speed
    if (pingMs > 500 || speedKbps < 500) {
      return NetworkQuality.moderate;
    }
    
    // Good: Low ping and decent speed
    if (pingMs > 200 || speedKbps < 2000) {
      return NetworkQuality.good;
    }
    
    // Excellent: Very low ping and high speed
    return NetworkQuality.excellent;
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
    log('🔄 Connectivity changed: ${result.name}');
    _updateConnectivityState();
  }

  /// Update connectivity state
  Future<void> _updateConnectivityState() async {
    try {
      final connectivityResults = await Connectivity().checkConnectivity();
      final connectivityResult = connectivityResults.isNotEmpty ? connectivityResults.first : ConnectivityResult.none;
      
      final isConnected = connectivityResult != ConnectivityResult.none;
      final networkType = _mapConnectivityResult(connectivityResult);
      
      // Check if connection is metered (mobile data)
      final isMetered = connectivityResult == ConnectivityResult.mobile;

      _updateState(_currentState.copyWith(
        isConnected: isConnected,
        type: networkType,
        isMetered: isMetered,
        lastChecked: DateTime.now(),
      ));

      // Test quality if connected
      if (isConnected) {
        // Delay quality test to avoid immediate checks
        Timer(const Duration(seconds: 2), () => checkNetworkQuality());
      } else {
        _updateState(_currentState.copyWith(
          quality: NetworkQuality.none,
          downloadSpeedKbps: 0,
          pingMs: null,
        ));
      }
      
    } catch (e) {
      log('❌ Error updating connectivity state: $e');
    }
  }

  /// Map ConnectivityResult to NetworkType
  NetworkType _mapConnectivityResult(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return NetworkType.wifi;
      case ConnectivityResult.mobile:
        return NetworkType.mobile;
      case ConnectivityResult.ethernet:
        return NetworkType.ethernet;
      case ConnectivityResult.vpn:
        return NetworkType.vpn;
      case ConnectivityResult.none:
        return NetworkType.none;
      default:
        return NetworkType.other;
    }
  }

  /// Update state and notify listeners
  void _updateState(NetworkState newState) {
    _currentState = newState;
    stateNotifier.value = newState;
  }

  /// Start periodic monitoring
  void _startPeriodicMonitoring() {
    _periodicMonitorTimer?.cancel();
    _periodicMonitorTimer = Timer.periodic(_monitoringInterval, (_) {
      _updateConnectivityState();
    });
  }

  /// Start quality testing
  void _startQualityTesting() {
    _qualityTestTimer?.cancel();
    _qualityTestTimer = Timer.periodic(_qualityTestInterval, (_) {
      if (_currentState.isConnected) {
        checkNetworkQuality();
      }
    });
  }

  /// Get download recommendation based on network state
  DownloadRecommendation getDownloadRecommendation(int fileSizeMB) {
    if (!isConnected) {
      return DownloadRecommendation.block;
    }

    // Always allow small files
    if (fileSizeMB < 1) {
      return DownloadRecommendation.allow;
    }

    // Consider network quality and type
    switch (networkQuality) {
      case NetworkQuality.excellent:
      case NetworkQuality.good:
        return DownloadRecommendation.allow;
        
      case NetworkQuality.moderate:
        if (fileSizeMB > 50 && shouldLimitDownloads) {
          return DownloadRecommendation.warn;
        }
        return DownloadRecommendation.allow;
        
      case NetworkQuality.poor:
        if (fileSizeMB > 10) {
          return DownloadRecommendation.warn;
        }
        return DownloadRecommendation.allow;
        
      case NetworkQuality.none:
        return DownloadRecommendation.block;
    }
  }

  /// Wait for network connection
  Future<bool> waitForConnection({Duration timeout = const Duration(seconds: 30)}) async {
    if (isConnected) return true;

    final completer = Completer<bool>();
    
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });

    void listener() {
      if (stateNotifier.value.isConnected && !completer.isCompleted) {
        timer.cancel();
        stateNotifier.removeListener(listener);
        completer.complete(true);
      }
    }
    
    stateNotifier.addListener(listener);

    return completer.future;
  }
}

enum DownloadRecommendation {
  allow,    // Download immediately
  warn,     // Show warning to user
  block,    // Don't allow download
}

// Extension for easy listening to network changes
extension NetworkMonitorWidget on NetworkMonitor {
  Widget builder({
    required Widget Function(BuildContext context, NetworkState state) builder,
  }) {
    return ValueListenableBuilder<NetworkState>(
      valueListenable: stateNotifier,
      builder: (context, state, child) => builder(context, state),
    );
  }
}