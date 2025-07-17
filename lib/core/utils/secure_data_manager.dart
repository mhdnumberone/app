// lib/core/utils/secure_data_manager.dart

import 'dart:io';
import 'dart:developer';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SecureDataManager {
  // ✅ مجلدات منفصلة للأنواع المختلفة
  static const String _mediaFolderName = 'media_cache';
  static const String _secureDocsFolderName = 'secure_docs';
  static const String _tempFolderName = 'temp_files';

  // ✅ Cache configuration
  static const int maxCacheSizeMB = 500; // 500MB max cache size
  static const int maxFileSizeMB = 100;  // 100MB max file size
  static const int maxCacheFiles = 1000;  // Maximum number of cached files
  static const int cleanupThresholdMB = 400; // Cleanup when cache reaches this size

  static Directory? _mediaCacheDir;
  static Directory? _secureDocsDir;
  static Directory? _tempDir;

  /// ✅ تهيئة المجلدات المحمية
  static Future<void> initialize() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();

      // مجلد الوسائط المحمي (لا يُحذف عند تسجيل الخروج)
      _mediaCacheDir = Directory('${appDir.path}/$_mediaFolderName');
      if (!_mediaCacheDir!.existsSync()) {
        await _mediaCacheDir!.create(recursive: true);
      }

      // مجلد المستندات الأمنية (يُحذف عند تسجيل الخروج)
      _secureDocsDir = Directory('${appDir.path}/$_secureDocsFolderName');
      if (!_secureDocsDir!.existsSync()) {
        await _secureDocsDir!.create(recursive: true);
      }

      // مجلد مؤقت (يُحذف عند تسجيل الخروج وبشكل دوري)
      _tempDir = Directory('${appDir.path}/$_tempFolderName');
      if (!_tempDir!.existsSync()) {
        await _tempDir!.create(recursive: true);
      }

      log('✅ Secure data manager initialized');
    } catch (e) {
      log('❌ Error initializing secure data manager: $e');
    }
  }

  /// ✅ حفظ ملف وسائط (محمي من الحذف) مع إدارة حجم التخزين المؤقت
  static Future<String?> saveMediaFile(List<int> bytes, String fileName, String url) async {
    try {
      if (_mediaCacheDir == null) await initialize();

      // Check file size before saving
      final fileSizeMB = bytes.length / (1024 * 1024);
      if (fileSizeMB > maxFileSizeMB) {
        log('❌ File too large to cache: ${fileSizeMB.toStringAsFixed(2)}MB > ${maxFileSizeMB}MB');
        return null;
      }

      // Check cache size and cleanup if needed
      await _manageCacheSize();

      final filePath = '${_mediaCacheDir!.path}/${_generateSafeFileName(fileName)}';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      // حفظ الربط بين الرابط والملف المحلي مع معلومات إضافية
      await _saveMediaMapping(url, filePath, {
        'size': bytes.length,
        'cached_at': DateTime.now().millisecondsSinceEpoch,
        'access_count': 1,
        'last_accessed': DateTime.now().millisecondsSinceEpoch,
      });

      log('✅ Media file saved: $filePath (${fileSizeMB.toStringAsFixed(2)}MB)');
      return filePath;
    } catch (e) {
      log('❌ Error saving media file: $e');
      return null;
    }
  }

  /// ✅ البحث عن ملف وسائط محفوظ مع تتبع الوصول
  static Future<String?> getMediaFile(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mappingString = prefs.getString('media_mapping') ?? '{}';
      final Map<String, dynamic> mapping = json.decode(mappingString);

      final entryData = mapping[url];
      if (entryData != null) {
        String localPath;
        Map<String, dynamic> metadata = {};
        
        // Handle both old format (string) and new format (object)
        if (entryData is String) {
          localPath = entryData;
        } else if (entryData is Map<String, dynamic>) {
          localPath = entryData['path'] as String;
          metadata = Map<String, dynamic>.from(entryData);
        } else {
          await _removeMediaMapping(url);
          return null;
        }

        final file = File(localPath);
        if (await file.exists()) {
          // Update access tracking
          metadata['access_count'] = (metadata['access_count'] ?? 0) + 1;
          metadata['last_accessed'] = DateTime.now().millisecondsSinceEpoch;
          
          // Save updated metadata
          await _saveMediaMapping(url, localPath, metadata);
          
          return localPath;
        } else {
          // الملف غير موجود، إزالة من الخريطة
          await _removeMediaMapping(url);
        }
      }
    } catch (e) {
      log('❌ Error getting media file: $e');
    }
    return null;
  }

  /// ✅ حفظ ملف مؤقت (يُحذف عند تسجيل الخروج)
  static Future<String?> saveTempFile(List<int> bytes, String fileName) async {
    try {
      if (_tempDir == null) await initialize();

      final filePath = '${_tempDir!.path}/${_generateSafeFileName(fileName)}';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      return filePath;
    } catch (e) {
      log('❌ Error saving temp file: $e');
      return null;
    }
  }

  /// ✅ حفظ مستند أمني (يُحذف عند تسجيل الخروج)
  static Future<String?> saveSecureDoc(List<int> bytes, String fileName) async {
    try {
      if (_secureDocsDir == null) await initialize();

      final filePath = '${_secureDocsDir!.path}/${_generateSafeFileName(fileName)}';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      return filePath;
    } catch (e) {
      log('❌ Error saving secure doc: $e');
      return null;
    }
  }

  /// ✅ حذف الملفات الأمنية والمؤقتة فقط (عند تسجيل الخروج)
  static Future<void> clearSecureDataOnly() async {
    try {
      // حذف المستندات الأمنية
      if (_secureDocsDir != null && _secureDocsDir!.existsSync()) {
        await _clearDirectory(_secureDocsDir!);
        log('🗑️ Secure documents cleared');
      }

      // حذف الملفات المؤقتة
      if (_tempDir != null && _tempDir!.existsSync()) {
        await _clearDirectory(_tempDir!);
        log('🗑️ Temp files cleared');
      }

      // ✅ الاحتفاظ بالوسائط المحفوظة في _mediaCacheDir
      log('✅ Media cache preserved during logout');

    } catch (e) {
      log('❌ Error clearing secure data: $e');
    }
  }

  /// ✅ حذف جميع البيانات (في حالة إلغاء تثبيت التطبيق)
  static Future<void> clearAllData() async {
    try {
      if (_mediaCacheDir != null && _mediaCacheDir!.existsSync()) {
        await _clearDirectory(_mediaCacheDir!);
      }
      if (_secureDocsDir != null && _secureDocsDir!.existsSync()) {
        await _clearDirectory(_secureDocsDir!);
      }
      if (_tempDir != null && _tempDir!.existsSync()) {
        await _clearDirectory(_tempDir!);
      }

      // مسح خريطة الوسائط
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('media_mapping');

      log('🗑️ All data cleared');
    } catch (e) {
      log('❌ Error clearing all data: $e');
    }
  }

  /// ✅ إدارة حجم التخزين المؤقت
  static Future<void> _manageCacheSize() async {
    try {
      if (_mediaCacheDir == null || !_mediaCacheDir!.existsSync()) return;

      final currentSizeMB = await _getDirectorySize(_mediaCacheDir!) ~/ (1024 * 1024);
      
      if (currentSizeMB > cleanupThresholdMB) {
        log('🧹 Cache size (${currentSizeMB}MB) exceeded threshold (${cleanupThresholdMB}MB), cleaning up...');
        await _smartCacheCleanup();
      }
    } catch (e) {
      log('❌ Error managing cache size: $e');
    }
  }

  /// ✅ تنظيف ذكي للتخزين المؤقت
  static Future<void> _smartCacheCleanup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mappingString = prefs.getString('media_mapping') ?? '{}';
      final Map<String, dynamic> mapping = json.decode(mappingString);

      // Create list of files with metadata for smart cleanup
      final List<Map<String, dynamic>> fileStats = [];
      
      for (final entry in mapping.entries) {
        final url = entry.key;
        final data = entry.value;
        
        if (data is Map<String, dynamic>) {
          final path = data['path'] as String?;
          if (path != null && await File(path).exists()) {
            final stat = await File(path).stat();
            fileStats.add({
              'url': url,
              'path': path,
              'size': data['size'] ?? stat.size,
              'cached_at': data['cached_at'] ?? stat.modified.millisecondsSinceEpoch,
              'access_count': data['access_count'] ?? 1,
              'last_accessed': data['last_accessed'] ?? stat.accessed.millisecondsSinceEpoch,
              'file_age_days': DateTime.now().difference(stat.modified).inDays,
            });
          }
        }
      }

      // Sort by priority (least important first)
      fileStats.sort((a, b) {
        // Priority factors: access count, last accessed, file age
        final aScore = (a['access_count'] as int) * 100 + 
                      (DateTime.now().millisecondsSinceEpoch - (a['last_accessed'] as int)) ~/ (1000 * 60 * 60 * 24);
        final bScore = (b['access_count'] as int) * 100 + 
                      (DateTime.now().millisecondsSinceEpoch - (b['last_accessed'] as int)) ~/ (1000 * 60 * 60 * 24);
        return aScore.compareTo(bScore);
      });

      // Remove files until we're under the threshold
      int removedSizeMB = 0;
      int removedCount = 0;
      final targetSizeMB = cleanupThresholdMB - 50; // Remove extra to prevent frequent cleanups

      for (final fileData in fileStats) {
        if (removedSizeMB >= (cleanupThresholdMB - targetSizeMB)) break;
        
        final filePath = fileData['path'] as String;
        final fileSize = fileData['size'] as int;
        final url = fileData['url'] as String;
        
        try {
          await File(filePath).delete();
          await _removeMediaMapping(url);
          removedSizeMB += fileSize ~/ (1024 * 1024);
          removedCount++;
        } catch (e) {
          log('❌ Error deleting cached file: $filePath - $e');
        }
      }

      log('🧹 Smart cleanup completed: removed $removedCount files (${removedSizeMB}MB)');
    } catch (e) {
      log('❌ Error in smart cache cleanup: $e');
    }
  }

  /// ✅ تنظيف دوري للملفات القديمة
  static Future<void> cleanOldFiles({int maxDays = 30}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: maxDays));

      // تنظيف الملفات المؤقتة القديمة
      if (_tempDir != null && _tempDir!.existsSync()) {
        await _cleanOldFilesInDirectory(_tempDir!, cutoffDate);
      }

      // تنظيف الوسائط القديمة جداً (أكثر من 60 يوم)
      if (_mediaCacheDir != null && _mediaCacheDir!.existsSync()) {
        final mediaCutoff = DateTime.now().subtract(Duration(days: 60));
        await _cleanOldFilesInDirectory(_mediaCacheDir!, mediaCutoff);
      }

    } catch (e) {
      log('❌ Error cleaning old files: $e');
    }
  }

  /// ✅ مسح التخزين المؤقت يدوياً
  static Future<Map<String, int>> clearCache({bool keepRecent = true}) async {
    try {
      int deletedFiles = 0;
      int freedSpaceMB = 0;
      
      if (_mediaCacheDir != null && _mediaCacheDir!.existsSync()) {
        final entities = _mediaCacheDir!.listSync();
        final cutoffDate = keepRecent 
            ? DateTime.now().subtract(const Duration(days: 7))
            : DateTime(1970); // Delete all if not keeping recent
        
        for (final entity in entities) {
          if (entity is File) {
            final stat = await entity.stat();
            if (stat.modified.isBefore(cutoffDate)) {
              final sizeMB = stat.size ~/ (1024 * 1024);
              await entity.delete();
              deletedFiles++;
              freedSpaceMB += sizeMB;
            }
          }
        }
      }

      // Clean up mapping for deleted files
      await _cleanupMediaMapping();
      
      log('🧹 Manual cache clear: $deletedFiles files deleted, ${freedSpaceMB}MB freed');
      return {'files': deletedFiles, 'space_mb': freedSpaceMB};
    } catch (e) {
      log('❌ Error clearing cache: $e');
      return {'files': 0, 'space_mb': 0};
    }
  }

  /// ✅ تنظيف خريطة الوسائط من الملفات غير الموجودة
  static Future<void> _cleanupMediaMapping() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mappingString = prefs.getString('media_mapping') ?? '{}';
      final Map<String, dynamic> mapping = json.decode(mappingString);
      
      final keysToRemove = <String>[];
      
      for (final entry in mapping.entries) {
        final data = entry.value;
        String? path;
        
        if (data is String) {
          path = data;
        } else if (data is Map<String, dynamic>) {
          path = data['path'] as String?;
        }
        
        if (path == null || !await File(path).exists()) {
          keysToRemove.add(entry.key);
        }
      }
      
      for (final key in keysToRemove) {
        mapping.remove(key);
      }
      
      await prefs.setString('media_mapping', json.encode(mapping));
      
      if (keysToRemove.isNotEmpty) {
        log('🧹 Cleaned up ${keysToRemove.length} stale cache entries');
      }
    } catch (e) {
      log('❌ Error cleaning up media mapping: $e');
    }
  }

  /// ✅ الحصول على مجلد مؤقت
  static Future<Directory> getTempDirectory() async {
    if (_tempDir == null) await initialize();
    return _tempDir!;
  }

  // ==================== مساعدات خاصة ====================

  static Future<void> _saveMediaMapping(String url, String localPath, [Map<String, dynamic>? metadata]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mappingString = prefs.getString('media_mapping') ?? '{}';
      final Map<String, dynamic> mapping = json.decode(mappingString);

      if (metadata != null) {
        // New format with metadata
        mapping[url] = {
          'path': localPath,
          ...metadata,
        };
      } else {
        // Backward compatibility - convert old string format to new format
        mapping[url] = {
          'path': localPath,
          'cached_at': DateTime.now().millisecondsSinceEpoch,
          'access_count': 1,
          'last_accessed': DateTime.now().millisecondsSinceEpoch,
        };
      }
      
      await prefs.setString('media_mapping', json.encode(mapping));
    } catch (e) {
      log('❌ Error saving media mapping: $e');
    }
  }

  static Future<void> _removeMediaMapping(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mappingString = prefs.getString('media_mapping') ?? '{}';
      final Map<String, dynamic> mapping = json.decode(mappingString);

      mapping.remove(url);
      await prefs.setString('media_mapping', json.encode(mapping));
    } catch (e) {
      log('❌ Error removing media mapping: $e');
    }
  }

  static String _generateSafeFileName(String originalName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = originalName.replaceAll(RegExp(r'[^\w\.-]'), '_');
    return '${timestamp}_$safeName';
  }

  static Future<void> _clearDirectory(Directory directory) async {
    try {
      if (!directory.existsSync()) return;

      final entities = directory.listSync();
      for (final entity in entities) {
        if (entity is File) {
          await entity.delete();
        } else if (entity is Directory) {
          await entity.delete(recursive: true);
        }
      }
      log('🗑️ Directory cleared: ${directory.path}');
    } catch (e) {
      log('❌ Error clearing directory: $e');
    }
  }

  static Future<void> _cleanOldFilesInDirectory(Directory directory, DateTime cutoffDate) async {
    try {
      if (!directory.existsSync()) return;

      final entities = directory.listSync();
      int deletedCount = 0;

      for (final entity in entities) {
        if (entity is File) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoffDate)) {
            await entity.delete();
            deletedCount++;
          }
        }
      }

      if (deletedCount > 0) {
        log('🧹 Cleaned $deletedCount old files from ${directory.path}');
      }
    } catch (e) {
      log('❌ Error cleaning old files: $e');
    }
  }

  /// ✅ احصائيات الاستخدام المفصلة
  static Future<Map<String, dynamic>> getStorageStats() async {
    try {
      int mediaSizeMB = 0;
      int tempSizeMB = 0;
      int secureDocsSizeMB = 0;
      int mediaFileCount = 0;
      int tempFileCount = 0;
      int secureDocsFileCount = 0;

      // Media cache statistics
      if (_mediaCacheDir != null && _mediaCacheDir!.existsSync()) {
        final mediaStats = await _getDirectoryStats(_mediaCacheDir!);
        mediaSizeMB = mediaStats['sizeMB'] as int;
        mediaFileCount = mediaStats['fileCount'] as int;
      }

      // Temp files statistics  
      if (_tempDir != null && _tempDir!.existsSync()) {
        final tempStats = await _getDirectoryStats(_tempDir!);
        tempSizeMB = tempStats['sizeMB'] as int;
        tempFileCount = tempStats['fileCount'] as int;
      }

      // Secure docs statistics
      if (_secureDocsDir != null && _secureDocsDir!.existsSync()) {
        final secureStats = await _getDirectoryStats(_secureDocsDir!);
        secureDocsSizeMB = secureStats['sizeMB'] as int;
        secureDocsFileCount = secureStats['fileCount'] as int;
      }

      // Cache usage analysis
      final prefs = await SharedPreferences.getInstance();
      final mappingString = prefs.getString('media_mapping') ?? '{}';
      final Map<String, dynamic> mapping = json.decode(mappingString);
      
      int totalAccessCount = 0;
      int imageCount = 0;
      int videoCount = 0;
      int audioCount = 0;
      int oldestCacheAge = 0;
      int newestCacheAge = 0;
      
      final now = DateTime.now().millisecondsSinceEpoch;
      final cacheAges = <int>[];
      
      for (final entry in mapping.values) {
        if (entry is Map<String, dynamic>) {
          totalAccessCount += (entry['access_count'] as int? ?? 0);
          final cachedAt = entry['cached_at'] as int? ?? now;
          final age = (now - cachedAt) ~/ (1000 * 60 * 60 * 24); // days
          cacheAges.add(age);
          
          // Count by type based on path extension
          final path = entry['path'] as String? ?? '';
          final extension = path.split('.').last.toLowerCase();
          if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension)) {
            imageCount++;
          } else if (['mp4', 'avi', 'mov', 'mkv'].contains(extension)) {
            videoCount++;
          } else if (['mp3', 'wav', 'aac', 'm4a'].contains(extension)) {
            audioCount++;
          }
        }
      }
      
      if (cacheAges.isNotEmpty) {
        cacheAges.sort();
        oldestCacheAge = cacheAges.last;
        newestCacheAge = cacheAges.first;
      }

      return {
        // Size information
        'mediaCache': mediaSizeMB,
        'tempFiles': tempSizeMB,
        'secureDocs': secureDocsSizeMB,
        'total': mediaSizeMB + tempSizeMB + secureDocsSizeMB,
        
        // File counts
        'mediaCacheFiles': mediaFileCount,
        'tempFilesCount': tempFileCount,
        'secureDocsCount': secureDocsFileCount,
        'totalFiles': mediaFileCount + tempFileCount + secureDocsFileCount,
        
        // Cache configuration
        'maxCacheSizeMB': maxCacheSizeMB,
        'cleanupThresholdMB': cleanupThresholdMB,
        'cacheUsagePercentage': (mediaSizeMB / maxCacheSizeMB * 100).round(),
        
        // Usage analytics
        'totalAccessCount': totalAccessCount,
        'imageFiles': imageCount,
        'videoFiles': videoCount,
        'audioFiles': audioCount,
        'oldestCacheAgeDays': oldestCacheAge,
        'newestCacheAgeDays': newestCacheAge,
        'averageFileAccessCount': mediaFileCount > 0 ? (totalAccessCount / mediaFileCount).round() : 0,
        
        // Status
        'needsCleanup': mediaSizeMB > cleanupThresholdMB,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      log('❌ Error getting storage stats: $e');
      return {'error': e.toString()};
    }
  }

  /// ✅ احصائيات مجلد مفصلة
  static Future<Map<String, int>> _getDirectoryStats(Directory directory) async {
    int totalSize = 0;
    int fileCount = 0;
    
    try {
      final entities = directory.listSync(recursive: true);
      for (final entity in entities) {
        if (entity is File) {
          final stat = await entity.stat();
          totalSize += stat.size;
          fileCount++;
        }
      }
    } catch (e) {
      log('❌ Error calculating directory stats: $e');
    }
    
    return {
      'sizeMB': totalSize ~/ (1024 * 1024),
      'fileCount': fileCount,
    };
  }

  static Future<int> _getDirectorySize(Directory directory) async {
    int totalSize = 0;
    try {
      final entities = directory.listSync(recursive: true);
      for (final entity in entities) {
        if (entity is File) {
          final stat = await entity.stat();
          totalSize += stat.size;
        }
      }
    } catch (e) {
      log('❌ Error calculating directory size: $e');
    }
    return totalSize;
  }
}
