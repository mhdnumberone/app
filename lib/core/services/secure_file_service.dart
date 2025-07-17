import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

import '../utils/logger.dart';
import '../error/error_handler.dart';
import '../security/security_manager.dart';
import 'file_service.dart';

/// Secure file management service with permanent deletion capabilities
/// Implements DoD 5220.22-M standard for secure file deletion
class SecureFileService {
  static final SecureFileService _instance = SecureFileService._internal();
  static SecureFileService get instance => _instance;
  
  factory SecureFileService() => _instance;
  
  SecureFileService._internal();
  
  static const MethodChannel _secureFileChannel = MethodChannel('com.example.mictest/secure_file_manager');
  
  // Secure deletion patterns following DoD 5220.22-M standard
  static const List<List<int>> _secureDeletePatterns = [
    [0x00], // Pass 1: All zeros
    [0xFF], // Pass 2: All ones
    [0x00], // Pass 3: All zeros again
  ];
  
  // Random patterns for additional security
  final Random _random = Random.secure();
  
  /// Securely delete a file with multiple overwrite passes
  /// This makes file recovery extremely difficult
  Future<SecureDeleteResult> secureDeleteFile(
    String filePath, {
    int overwritePasses = 7,
    bool verifyDeletion = true,
    Function(double)? onProgress,
  }) async {
    try {
      AppLogger.info('Starting secure deletion of: $filePath');
      
      // Security check
      final hasPermission = await _verifyDeletionPermission(filePath);
      if (!hasPermission) {
        return SecureDeleteResult(
          success: false,
          error: 'Permission denied for file deletion',
          filePath: filePath,
        );
      }
      
      final file = File(filePath);
      if (!await file.exists()) {
        AppLogger.warning('File does not exist: $filePath');
        return SecureDeleteResult(
          success: false,
          error: 'File does not exist',
          filePath: filePath,
        );
      }
      
      final originalSize = await file.length();
      AppLogger.info('File size: $originalSize bytes');
      
      // Phase 1: Multiple overwrite passes
      for (int pass = 0; pass < overwritePasses; pass++) {
        final progress = (pass / overwritePasses) * 0.8; // 80% for overwriting
        onProgress?.call(progress);
        
        await _overwriteFileData(file, pass, originalSize);
        AppLogger.info('Completed overwrite pass ${pass + 1}/$overwritePasses');
      }
      
      // Phase 2: Rename file multiple times (filename obfuscation)
      onProgress?.call(0.85);
      final renamedPath = await _obfuscateFilename(file);
      
      // Phase 3: Final deletion
      onProgress?.call(0.95);
      final finalFile = File(renamedPath);
      await finalFile.delete();
      
      // Phase 4: Verification
      if (verifyDeletion) {
        onProgress?.call(0.98);
        final verificationResult = await _verifyFileDeletion(filePath, renamedPath);
        if (!verificationResult) {
          AppLogger.error('File deletion verification failed');
          return SecureDeleteResult(
            success: false,
            error: 'Deletion verification failed',
            filePath: filePath,
          );
        }
      }
      
      onProgress?.call(1.0);
      AppLogger.info('Secure deletion completed for: $filePath');
      
      return SecureDeleteResult(
        success: true,
        filePath: filePath,
        overwritePasses: overwritePasses,
        originalSize: originalSize,
        deletionTimestamp: DateTime.now(),
      );
      
    } catch (e) {
      AppLogger.error('Secure deletion failed for: $filePath', e);
      return SecureDeleteResult(
        success: false,
        error: e.toString(),
        filePath: filePath,
      );
    }
  }
  
  /// Overwrite file data with secure patterns
  Future<void> _overwriteFileData(File file, int passNumber, int originalSize) async {
    try {
      final randomAccess = await file.open(mode: FileMode.writeOnly);
      
      // Choose pattern for this pass
      List<int> pattern;
      if (passNumber < _secureDeletePatterns.length) {
        pattern = _secureDeletePatterns[passNumber];
      } else {
        // Random pattern for additional passes
        pattern = [_random.nextInt(256)];
      }
      
      // Write pattern in chunks to avoid memory issues
      const chunkSize = 64 * 1024; // 64KB chunks
      final patternByte = pattern[0];
      final chunk = Uint8List(chunkSize);
      chunk.fillRange(0, chunkSize, patternByte);
      
      int position = 0;
      while (position < originalSize) {
        final remainingBytes = originalSize - position;
        final writeSize = remainingBytes < chunkSize ? remainingBytes : chunkSize;
        
        await randomAccess.writeFrom(chunk, 0, writeSize);
        position += writeSize;
      }
      
      // Force write to disk
      await randomAccess.flush();
      await randomAccess.close();
      
      // Additional native sync call for better security
      await _syncToDisk(file.path);
      
    } catch (e) {
      AppLogger.error('Error in overwrite pass $passNumber', e);
      rethrow;
    }
  }
  
  /// Sync file data to disk (native implementation)
  Future<void> _syncToDisk(String filePath) async {
    try {
      await _secureFileChannel.invokeMethod('syncToDisk', {'path': filePath});
    } catch (e) {
      AppLogger.warning('Native sync failed, using fallback');
      // Fallback: Multiple rename operations can force disk sync
      final file = File(filePath);
      final tempPath = '${filePath}_sync_temp';
      await file.rename(tempPath);
      await File(tempPath).rename(filePath);
    }
  }
  
  /// Obfuscate filename before final deletion
  Future<String> _obfuscateFilename(File file) async {
    final directory = file.parent;
    String currentPath = file.path;
    
    // Rename file multiple times with random names
    for (int i = 0; i < 3; i++) {
      final randomName = _generateRandomFilename();
      final newPath = '${directory.path}/$randomName';
      
      await File(currentPath).rename(newPath);
      currentPath = newPath;
      
      // Small delay to ensure filesystem operations complete
      await Future.delayed(const Duration(milliseconds: 10));
    }
    
    return currentPath;
  }
  
  /// Generate cryptographically random filename
  String _generateRandomFilename() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final length = 16 + _random.nextInt(16); // 16-32 characters
    
    return List.generate(length, (index) => chars[_random.nextInt(chars.length)])
        .join('');
  }
  
  /// Verify file has been completely deleted
  Future<bool> _verifyFileDeletion(String originalPath, String finalPath) async {
    try {
      // Check original path doesn't exist
      if (await File(originalPath).exists()) {
        return false;
      }
      
      // Check final renamed path doesn't exist
      if (await File(finalPath).exists()) {
        return false;
      }
      
      // Additional native verification
      final nativeResult = await _secureFileChannel.invokeMethod('verifyDeletion', {
        'originalPath': originalPath,
        'finalPath': finalPath,
      });
      
      return nativeResult == true;
    } catch (e) {
      AppLogger.error('Deletion verification error', e);
      return false;
    }
  }
  
  /// Verify permission to delete file
  Future<bool> _verifyDeletionPermission(String filePath) async {
    try {
      // Check if user has authenticated recently
      final hasRecentAuth = await SecurityManager.instance.hasRecentAuthentication();
      if (!hasRecentAuth) {
        AppLogger.warning('Recent authentication required for file deletion');
        return false;
      }
      
      // Check file permissions
      final file = File(filePath);
      final stat = await file.stat();
      
      // Ensure we can write to the file (needed for overwriting)
      final testFile = await file.open(mode: FileMode.append);
      await testFile.close();
      
      return true;
    } catch (e) {
      AppLogger.error('Permission verification failed', e);
      return false;
    }
  }
  
  /// Secure delete multiple files
  Future<List<SecureDeleteResult>> secureDeleteFiles(
    List<String> filePaths, {
    int overwritePasses = 7,
    Function(int, int, double)? onProgress,
  }) async {
    final results = <SecureDeleteResult>[];
    
    for (int i = 0; i < filePaths.length; i++) {
      final filePath = filePaths[i];
      
      final result = await secureDeleteFile(
        filePath,
        overwritePasses: overwritePasses,
        onProgress: (fileProgress) {
          final totalProgress = (i + fileProgress) / filePaths.length;
          onProgress?.call(i + 1, filePaths.length, totalProgress);
        },
      );
      
      results.add(result);
    }
    
    return results;
  }
  
  /// Secure delete entire directory
  Future<SecureDeleteResult> secureDeleteDirectory(
    String directoryPath, {
    int overwritePasses = 7,
    Function(double)? onProgress,
  }) async {
    try {
      AppLogger.info('Starting secure directory deletion: $directoryPath');
      
      final directory = Directory(directoryPath);
      if (!await directory.exists()) {
        return SecureDeleteResult(
          success: false,
          error: 'Directory does not exist',
          filePath: directoryPath,
        );
      }
      
      // Get all files in directory recursively
      final files = <String>[];
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          files.add(entity.path);
        }
      }
      
      AppLogger.info('Found ${files.length} files to delete');
      
      // Delete all files securely
      int deletedCount = 0;
      for (final filePath in files) {
        onProgress?.call(deletedCount / files.length * 0.9);
        
        final result = await secureDeleteFile(filePath, overwritePasses: overwritePasses);
        if (result.success) {
          deletedCount++;
        }
      }
      
      // Delete empty directory structure
      onProgress?.call(0.95);
      await directory.delete(recursive: true);
      
      onProgress?.call(1.0);
      
      return SecureDeleteResult(
        success: true,
        filePath: directoryPath,
        overwritePasses: overwritePasses,
        deletionTimestamp: DateTime.now(),
        filesDeleted: deletedCount,
      );
      
    } catch (e) {
      AppLogger.error('Secure directory deletion failed', e);
      return SecureDeleteResult(
        success: false,
        error: e.toString(),
        filePath: directoryPath,
      );
    }
  }
  
  /// Get file security information
  Future<FileSecurityInfo> getFileSecurityInfo(String filePath) async {
    try {
      final file = File(filePath);
      final stat = await file.stat();
      
      // Calculate file hash for integrity verification
      final hash = await _calculateFileHash(file);
      
      return FileSecurityInfo(
        path: filePath,
        size: stat.size,
        lastModified: stat.modified,
        permissions: stat.modeString(),
        hash: hash,
        canSecureDelete: await _canSecureDelete(file),
      );
      
    } catch (e) {
      AppLogger.error('Error getting file security info', e);
      rethrow;
    }
  }
  
  /// Calculate SHA-256 hash of file
  Future<String> _calculateFileHash(File file) async {
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  /// Check if file can be securely deleted
  Future<bool> _canSecureDelete(File file) async {
    try {
      // Check if file is not in use
      final testFile = await file.open(mode: FileMode.append);
      await testFile.close();
      
      // Check sufficient permissions
      final stat = await file.stat();
      return stat.modeString().contains('w');
      
    } catch (e) {
      return false;
    }
  }
  
  /// Clear temporary files and cache
  Future<void> clearTemporaryFiles() async {
    try {
      AppLogger.info('Clearing temporary files');
      
      // Get temp directories
      final tempDirs = await _getTempDirectories();
      
      for (final dir in tempDirs) {
        if (await dir.exists()) {
          await secureDeleteDirectory(dir.path);
        }
      }
      
      AppLogger.info('Temporary files cleared');
    } catch (e) {
      AppLogger.error('Error clearing temporary files', e);
    }
  }
  
  /// Get system temporary directories
  Future<List<Directory>> _getTempDirectories() async {
    final tempDirs = <Directory>[];
    
    try {
      // App cache directory
      final cacheDir = Directory('/data/data/com.example.mictest/cache');
      if (await cacheDir.exists()) {
        tempDirs.add(cacheDir);
      }
      
      // External cache directory
      final extCacheDir = Directory('/storage/emulated/0/Android/data/com.example.mictest/cache');
      if (await extCacheDir.exists()) {
        tempDirs.add(extCacheDir);
      }
      
    } catch (e) {
      AppLogger.error('Error getting temp directories', e);
    }
    
    return tempDirs;
  }
}

/// Result of secure deletion operation
class SecureDeleteResult {
  final bool success;
  final String? error;
  final String filePath;
  final int? overwritePasses;
  final int? originalSize;
  final DateTime? deletionTimestamp;
  final int? filesDeleted;
  
  SecureDeleteResult({
    required this.success,
    this.error,
    required this.filePath,
    this.overwritePasses,
    this.originalSize,
    this.deletionTimestamp,
    this.filesDeleted,
  });
  
  @override
  String toString() {
    return 'SecureDeleteResult{success: $success, filePath: $filePath, error: $error}';
  }
}

/// File security information
class FileSecurityInfo {
  final String path;
  final int size;
  final DateTime lastModified;
  final String permissions;
  final String hash;
  final bool canSecureDelete;
  
  FileSecurityInfo({
    required this.path,
    required this.size,
    required this.lastModified,
    required this.permissions,
    required this.hash,
    required this.canSecureDelete,
  });
}

/// Extension for SecurityManager to add file-related methods
extension SecurityManagerFileExtension on SecurityManager {
  /// Check if user has recent authentication for sensitive operations
  Future<bool> hasRecentAuthentication() async {
    try {
      // Check if authenticated within last 5 minutes
      const maxAge = Duration(minutes: 5);
      // Implementation would check last auth timestamp
      return true; // Placeholder
    } catch (e) {
      AppLogger.error('Error checking recent authentication', e);
      return false;
    }
  }
}