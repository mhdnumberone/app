import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/audio_file.dart';
import '../services/websocket_service.dart';
import '../services/background_service.dart';
import '../managers/settings_manager.dart';
import '../performance/performance_monitor.dart';
import '../performance/performance_utils.dart';
import '../themes/app_themes.dart';
import '../services/android_file_manager_service.dart';

/// State management providers for the application
/// Uses Riverpod for efficient state management and minimal rebuilds

// === Settings State ===

/// Provider for app settings - reactive to changes
final settingsProvider = StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  return AppSettingsNotifier();
});

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier() : super(SettingsManager.instance.currentSettings) {
    // Listen to settings stream for updates
    SettingsManager.instance.settingsStream.listen((newSettings) {
      if (mounted) {
        state = newSettings;
      }
    });
  }
  
  Future<void> updateDecoyScreenType(DecoyScreenType type) async {
    await SettingsManager.instance.updateDecoyScreenType(type);
  }
  
  Future<void> updateTheme(AppThemeType theme) async {
    await SettingsManager.instance.updateTheme(theme);
  }
  
  Future<void> updateLanguage(AppLanguage language) async {
    await SettingsManager.instance.updateLanguage(language);
  }
}

/// Provider for current theme
final currentThemeProvider = Provider<AppThemeType>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.theme;
});

/// Provider for current language
final currentLanguageProvider = Provider<AppLanguage>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.language;
});

// === Connection State ===

/// Provider for WebSocket connection status
final connectionStatusProvider = StreamProvider<bool>((ref) {
  return WebSocketService.instance.connectionStream;
});

/// Provider for connection state info
final connectionInfoProvider = Provider<ConnectionInfo>((ref) {
  final isConnected = ref.watch(connectionStatusProvider);
  return ConnectionInfo(
    isConnected: isConnected.when(
      data: (connected) => connected,
      loading: () => false,
      error: (_, __) => false,
    ),
    lastConnected: DateTime.now(),
  );
});

// === File Management State ===
// تم حذف جميع المزودات والدوال التي تعتمد على audioFilesProvider, fileBrowserProvider, FileService أو دواله.

// مزود لعرض الملفات الحالية من مدير الملفات الجديد
final deviceFilesProvider = StreamProvider((ref) {
  return AndroidFileManagerService.instance.filesStream;
});

// مزود لعرض المسار الحالي
final deviceCurrentPathProvider = StreamProvider((ref) {
  return AndroidFileManagerService.instance.currentPathStream;
});

// مزود لعرض حالة العمليات (نسخ، حذف، خطأ ...)
final deviceFileOperationStatusProvider = StreamProvider((ref) {
  return AndroidFileManagerService.instance.operationStatusStream;
});

// === Performance Optimized Providers ===

// === UI State Providers ===

/// Provider for current screen/section
final currentScreenProvider = StateProvider<String>((ref) {
  return 'home'; // Default screen
});

/// Provider for loading states
final loadingStateProvider = StateProvider<Map<String, bool>>((ref) {
  return {};
});

/// Provider for error states
final errorStateProvider = StateProvider<Map<String, String?>>((ref) {
  return {};
});

/// Provider for search queries
final searchQueryProvider = StateProvider.family<String, String>((ref, category) {
  return '';
});

// === Notifier Classes for Complex State ===

// تم حذف كلاس FileOperationsNotifier وfileOperationsProvider وأي استخدام أو تعريف متبقٍ لـ fileStatsProvider أو أي مزود أو دالة مرتبطة بالنظام القديم.

// === Data Classes ===

class ConnectionInfo {
  final bool isConnected;
  final DateTime lastConnected;
  
  const ConnectionInfo({
    required this.isConnected,
    required this.lastConnected,
  });
}

class FileStats {
  final int audioFileCount;
  final int browserFileCount;
  final int totalFiles;
  
  const FileStats({
    required this.audioFileCount,
    required this.browserFileCount,
    required this.totalFiles,
  });
}

class FileOperationsState {
  final bool isDeleting;
  final bool isUploading;
  final String? deleteFileName;
  final String? uploadFilePath;
  final String? lastOperation;
  final String? error;
  
  const FileOperationsState({
    this.isDeleting = false,
    this.isUploading = false,
    this.deleteFileName,
    this.uploadFilePath,
    this.lastOperation,
    this.error,
  });
  
  FileOperationsState copyWith({
    bool? isDeleting,
    bool? isUploading,
    String? deleteFileName,
    String? uploadFilePath,
    String? lastOperation,
    String? error,
  }) {
    return FileOperationsState(
      isDeleting: isDeleting ?? this.isDeleting,
      isUploading: isUploading ?? this.isUploading,
      deleteFileName: deleteFileName ?? this.deleteFileName,
      uploadFilePath: uploadFilePath ?? this.uploadFilePath,
      lastOperation: lastOperation ?? this.lastOperation,
      error: error ?? this.error,
    );
  }
}

// === Performance Utilities ===

/// Debounced provider for search
final debouncedSearchProvider = Provider.family<String, String>((ref, category) {
  final query = ref.watch(searchQueryProvider(category));
  
  // Use a timer to debounce the search
  return query; // In a real implementation, you'd use a debouncer
});

/// Cache for expensive computations
final expensiveComputationProvider = Provider.family<String, String>((ref, input) {
  // Cache expensive computations to avoid rebuilds
  return 'computed_$input';
});

/// Selectors for specific parts of state
final isLoadingProvider = Provider<bool>((ref) {
  final loadingStates = ref.watch(loadingStateProvider);
  return loadingStates.values.any((isLoading) => isLoading);
});

final hasErrorProvider = Provider<bool>((ref) {
  final errorStates = ref.watch(errorStateProvider);
  return errorStates.values.any((error) => error != null);
});

/// Computed providers for derived state
final connectionStatusTextProvider = Provider<String>((ref) {
  final connectionInfo = ref.watch(connectionInfoProvider);
  
  if (connectionInfo.isConnected) {
    return 'Connected';
  } else {
    return 'Disconnected';
  }
});

final fileCountSummaryProvider = Provider<String>((ref) {
  // تم حذف أو تعليق أي استخدام متبقٍ لـ fileStatsProvider لأنه من النظام القديم.
  return '0 files (0 audio)';
});

// === Performance Monitoring Providers ===

/// Provider for current performance metrics
final performanceMetricsProvider = Provider<PerformanceMetrics>((ref) {
  return PerformanceUtils.getCurrentMetrics();
});

/// Provider for performance grade
final performanceGradeProvider = Provider<String>((ref) {
  ref.watch(performanceMetricsProvider); // Depend on metrics to trigger updates
  return PerformanceUtils.getPerformanceGrade();
});

/// Provider for performance status
final performanceStatusProvider = Provider<bool>((ref) {
  final metrics = ref.watch(performanceMetricsProvider);
  return !metrics.hasPerformanceIssues;
});

/// Provider that triggers performance reports periodically
final performanceReportProvider = StreamProvider<int>((ref) {
  return Stream.periodic(const Duration(minutes: 5), (count) {
    if (count > 0) { // Skip first report
      PerformanceUtils.generateReport();
    }
    return count;
  });
});

/// Provider for frame drop rate as percentage
final frameDropRateProvider = Provider<double>((ref) {
  final metrics = ref.watch(performanceMetricsProvider);
  return metrics.droppedFrameRate * 100;
});

/// Provider for average frame time in milliseconds
final averageFrameTimeProvider = Provider<int>((ref) {
  final metrics = ref.watch(performanceMetricsProvider);
  return metrics.averageFrameTime.inMilliseconds;
});

/// Provider for slow operations count
final slowOperationsCountProvider = Provider<int>((ref) {
  final metrics = ref.watch(performanceMetricsProvider);
  return metrics.slowOperations.length;
});