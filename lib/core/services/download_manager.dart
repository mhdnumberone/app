// lib/core/services/download_manager.dart

import 'dart:io';
import 'dart:developer';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/secure_data_manager.dart';

enum DownloadStatus {
  pending,
  downloading,
  completed,
  failed,
  cancelled,
}

class DownloadProgress {
  final String url;
  final String fileName;
  final DownloadStatus status;
  final double progress;
  final int? totalBytes;
  final int downloadedBytes;
  final String? error;
  final DateTime startTime;

  DownloadProgress({
    required this.url,
    required this.fileName,
    required this.status,
    this.progress = 0.0,
    this.totalBytes,
    this.downloadedBytes = 0,
    this.error,
    DateTime? startTime,
  }) : startTime = startTime ?? DateTime.now();

  DownloadProgress copyWith({
    DownloadStatus? status,
    double? progress,
    int? totalBytes,
    int? downloadedBytes,
    String? error,
  }) {
    return DownloadProgress(
      url: url,
      fileName: fileName,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      error: error ?? this.error,
      startTime: startTime,
    );
  }
}

class DownloadManager {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal();

  // Active downloads tracking
  final Map<String, Future<String?>> _activeDownloads = {};
  final Map<String, DownloadProgress> _downloadProgress = {};
  
  // Configuration
  static const int maxConcurrentDownloads = 3;
  static const int maxRetries = 3;
  static const Duration downloadTimeout = Duration(minutes: 5);
  static const int maxFileSizeMB = 100;
  
  // Progress notifier for UI updates
  final ValueNotifier<Map<String, DownloadProgress>> progressNotifier =
      ValueNotifier({});

  // Network client with optimized settings
  late final http.Client _httpClient;
  bool _isInitialized = false;

  void initialize() {
    if (_isInitialized) return;
    _httpClient = http.Client();
    _isInitialized = true;
    log('✅ DownloadManager initialized');
  }

  void dispose() {
    if (_isInitialized) {
      _httpClient.close();
      _isInitialized = false;
    }
    progressNotifier.dispose();
    _activeDownloads.clear();
    _downloadProgress.clear();
  }

  /// Main download method with queue management
  Future<String?> downloadFile({
    required String url,
    required String fileName,
    String? mediaType,
    Function(DownloadProgress)? onProgress,
  }) async {
    try {
      // Validate URL
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasAbsolutePath) {
        log('❌ Invalid URL: $url');
        return null;
      }

      // Check if already cached
      final cachedPath = await SecureDataManager.getMediaFile(url);
      if (cachedPath != null && await File(cachedPath).exists()) {
        log('✅ File already cached: $url');
        return cachedPath;
      }

      // Check if already downloading
      if (_activeDownloads.containsKey(url)) {
        log('⏳ Download already in progress: $url');
        return await _activeDownloads[url];
      }

      // Check concurrent download limit
      if (_activeDownloads.length >= maxConcurrentDownloads) {
        log('⏸️ Download queue full, waiting...');
        await _waitForSlot();
      }

      // Start download
      final downloadFuture = _performDownload(
        url: url,
        fileName: fileName,
        mediaType: mediaType,
        onProgress: onProgress,
      );

      _activeDownloads[url] = downloadFuture;

      final result = await downloadFuture;
      _activeDownloads.remove(url);
      
      return result;
    } catch (e) {
      log('❌ Download failed: $url - $e');
      _activeDownloads.remove(url);
      _updateProgress(url, fileName, DownloadStatus.failed, error: e.toString());
      return null;
    }
  }

  /// Perform the actual download with streaming and progress tracking
  Future<String?> _performDownload({
    required String url,
    required String fileName,
    String? mediaType,
    Function(DownloadProgress)? onProgress,
  }) async {
    int retryCount = 0;
    
    while (retryCount < maxRetries) {
      try {
        log('📥 Starting download: $url (attempt ${retryCount + 1}/$maxRetries)');
        
        // Initialize progress
        _updateProgress(url, fileName, DownloadStatus.downloading);

        // Create request with proper headers
        final request = http.Request('GET', Uri.parse(url));
        request.headers.addAll({
          'User-Agent': 'SecureChat/1.0',
          'Accept': '*/*',
          'Connection': 'keep-alive',
        });

        // Send request with timeout
        final response = await _httpClient.send(request)
            .timeout(downloadTimeout);

        if (response.statusCode != 200) {
          throw HttpException('HTTP ${response.statusCode}: ${response.reasonPhrase}');
        }

        // Check file size
        final contentLength = response.contentLength;
        if (contentLength != null && contentLength > maxFileSizeMB * 1024 * 1024) {
          throw Exception('File too large: ${contentLength ~/ (1024 * 1024)}MB > ${maxFileSizeMB}MB');
        }

        // Generate safe filename with proper extension
        final safeFileName = _generateFileName(fileName, mediaType, url);
        
        // Stream download to file
        final filePath = await _streamDownload(
          response: response,
          url: url,
          fileName: safeFileName,
          contentLength: contentLength,
          onProgress: onProgress,
        );

        if (filePath != null) {
          // Verify file integrity
          if (await _verifyFileIntegrity(filePath, contentLength)) {
            // Save to cache
            await SecureDataManager.saveMediaFile(
              await File(filePath).readAsBytes(),
              safeFileName,
              url,
            );
            
            _updateProgress(url, fileName, DownloadStatus.completed, progress: 1.0);
            log('✅ Download completed: $url');
            return filePath;
          } else {
            throw Exception('File integrity check failed');
          }
        }

        throw Exception('Download failed: no file path returned');
        
      } catch (e) {
        retryCount++;
        log('❌ Download attempt failed: $url (${retryCount}/$maxRetries) - $e');
        
        if (retryCount < maxRetries) {
          // Exponential backoff
          final delay = Duration(seconds: (2 << retryCount));
          log('⏳ Retrying in ${delay.inSeconds}s...');
          await Future.delayed(delay);
        } else {
          _updateProgress(url, fileName, DownloadStatus.failed, error: e.toString());
          rethrow;
        }
      }
    }
    
    return null;
  }

  /// Stream download with progress tracking
  Future<String?> _streamDownload({
    required http.StreamedResponse response,
    required String url,
    required String fileName,
    int? contentLength,
    Function(DownloadProgress)? onProgress,
  }) async {
    IOSink? sink;
    try {
      // Create temporary file
      final tempDir = await SecureDataManager.getTempDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      sink = tempFile.openWrite();

      int downloadedBytes = 0;
      final List<int> bytes = [];

      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        downloadedBytes += chunk.length;
        
        // Update progress
        final progress = contentLength != null && contentLength > 0
            ? downloadedBytes / contentLength
            : 0.0;
            
        _updateProgress(
          url,
          fileName,
          DownloadStatus.downloading,
          progress: progress,
          totalBytes: contentLength,
          downloadedBytes: downloadedBytes,
        );

        // Notify callback
        if (_downloadProgress.containsKey(url)) {
          onProgress?.call(_downloadProgress[url]!);
        }
        
        // Write chunk to file
        sink.add(chunk);
      }

      await sink.close();
      sink = null;
      
      // Verify we got expected amount of data
      if (contentLength != null && downloadedBytes != contentLength) {
        throw Exception('Download incomplete: $downloadedBytes/$contentLength bytes');
      }

      return tempFile.path;
    } catch (e) {
      log('❌ Stream download failed: $e');
      // Ensure sink is closed even in error scenarios
      if (sink != null) {
        try {
          await sink.close();
        } catch (closeError) {
          log('❌ Error closing sink: $closeError');
        }
      }
      rethrow;
    }
  }

  /// Generate safe filename with proper extension
  String _generateFileName(String originalName, String? mediaType, String url) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    // Sanitize filename
    String safeName = originalName.replaceAll(RegExp(r'[^\w\.-]'), '_');
    
    // Ensure proper extension based on media type or URL
    String extension = '';
    if (safeName.contains('.')) {
      extension = safeName.split('.').last.toLowerCase();
    } else if (mediaType != null) {
      extension = _getExtensionFromMediaType(mediaType);
    } else {
      extension = _getExtensionFromUrl(url);
    }
    
    if (!safeName.endsWith('.$extension')) {
      safeName = '${safeName.split('.').first}.$extension';
    }
    
    return '${timestamp}_$safeName';
  }

  String _getExtensionFromMediaType(String mediaType) {
    switch (mediaType.toLowerCase()) {
      case 'image':
        return 'jpg';
      case 'video':
        return 'mp4';
      case 'audio':
        return 'mp3';
      default:
        return 'bin';
    }
  }

  String _getExtensionFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      final path = uri.path.toLowerCase();
      if (path.contains('.')) {
        return path.split('.').last;
      }
    }
    return 'bin';
  }

  /// Verify file integrity
  Future<bool> _verifyFileIntegrity(String filePath, int? expectedSize) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;
      
      final actualSize = await file.length();
      
      // Check size if known
      if (expectedSize != null && actualSize != expectedSize) {
        log('❌ File size mismatch: $actualSize != $expectedSize');
        return false;
      }
      
      // Basic file validity check
      if (actualSize == 0) {
        log('❌ File is empty');
        return false;
      }
      
      return true;
    } catch (e) {
      log('❌ File integrity check failed: $e');
      return false;
    }
  }

  /// Update download progress and notify listeners
  void _updateProgress(
    String url,
    String fileName,
    DownloadStatus status, {
    double progress = 0.0,
    int? totalBytes,
    int downloadedBytes = 0,
    String? error,
  }) {
    _downloadProgress[url] = DownloadProgress(
      url: url,
      fileName: fileName,
      status: status,
      progress: progress,
      totalBytes: totalBytes,
      downloadedBytes: downloadedBytes,
      error: error,
    );
    
    // Update notifier for UI
    progressNotifier.value = Map.from(_downloadProgress);
  }

  /// Wait for download slot to become available
  Future<void> _waitForSlot() async {
    while (_activeDownloads.length >= maxConcurrentDownloads) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Cancel download
  Future<void> cancelDownload(String url) async {
    final downloadFuture = _activeDownloads.remove(url);
    _updateProgress(url, '', DownloadStatus.cancelled);
    
    // Try to cancel the actual download if it's still running
    if (downloadFuture != null) {
      try {
        // This won't actually cancel the HTTP request, but will prevent waiting for it
        downloadFuture.ignore();
      } catch (e) {
        log('❌ Error cancelling download: $e');
      }
    }
    
    log('🚫 Download cancelled: $url');
  }

  /// Get download progress for URL
  DownloadProgress? getProgress(String url) {
    return _downloadProgress[url];
  }

  /// Get all active downloads
  List<DownloadProgress> getActiveDownloads() {
    return _downloadProgress.values
        .where((p) => p.status == DownloadStatus.downloading)
        .toList();
  }

  /// Clear completed downloads from tracking
  void clearCompleted() {
    _downloadProgress.removeWhere((key, value) => 
        value.status == DownloadStatus.completed ||
        value.status == DownloadStatus.failed ||
        value.status == DownloadStatus.cancelled);
    progressNotifier.value = Map.from(_downloadProgress);
  }
}