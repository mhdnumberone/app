import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
import '../models/device_file.dart';
import '../utils/logger.dart';
import '../error/error_handler.dart';

/// Android File Manager Service that handles real device storage access
class AndroidFileManagerService {
  static final AndroidFileManagerService _instance = AndroidFileManagerService._internal();
  static AndroidFileManagerService get instance => _instance;
  
  factory AndroidFileManagerService() => _instance;
  
  AndroidFileManagerService._internal();

  // Stream controllers for reactive UI updates
  final StreamController<List<DeviceFile>> _filesController = StreamController<List<DeviceFile>>.broadcast();
  final StreamController<String> _currentPathController = StreamController<String>.broadcast();
  final StreamController<Map<String, dynamic>> _operationStatusController = StreamController<Map<String, dynamic>>.broadcast();
  
  // Public streams
  Stream<List<DeviceFile>> get filesStream => _filesController.stream;
  Stream<String> get currentPathStream => _currentPathController.stream;
  Stream<Map<String, dynamic>> get operationStatusStream => _operationStatusController.stream;
  
  // Current state
  String _currentPath = '';
  List<DeviceFile> _currentFiles = [];
  bool _isInitialized = false;
  
  // Common Android storage paths
  final List<String> _commonPaths = [
    '/storage/emulated/0/',  // Internal storage
    '/storage/emulated/0/Download/',
    '/storage/emulated/0/Pictures/',
    '/storage/emulated/0/DCIM/',
    '/storage/emulated/0/Movies/',
    '/storage/emulated/0/Music/',
    '/storage/emulated/0/Documents/',
    '/storage/emulated/0/Android/data/',
  ];
  
  // File type icons mapping
  final Map<String, String> _fileTypeIcons = {
    'folder': '📁',
    'image': '🖼️',
    'video': '🎬',
    'audio': '🎵',
    'document': '📄',
    'archive': '📦',
    'executable': '⚙️',
    'code': '💻',
    'text': '📝',
    'unknown': '📄'
  };

  /// Initialize the service and request permissions
  Future<bool> initialize() async {
    try {
      AppLogger.info('Initializing Android File Manager Service');
      
      // Request storage permissions
      final hasPermissions = await requestStoragePermissions();
      if (!hasPermissions) {
        AppLogger.warning('Storage permissions not granted');
        return false;
      }
      
      // Set initial path to internal storage
      _currentPath = await _getInitialPath();
      AppLogger.info('Initial path set to: $_currentPath');
      
      // Load files from initial path
      await loadFiles(_currentPath);
      
      _isInitialized = true;
      AppLogger.info('Android File Manager Service initialized successfully');
      return true;
      
    } catch (e) {
      AppLogger.error('Error initializing Android File Manager Service', e);
      return false;
    }
  }

  /// Request storage permissions based on Android version
  Future<bool> requestStoragePermissions() async {
    try {
      AppLogger.info('Requesting storage permissions');
      
      // Check Android version
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final androidVersion = androidInfo.version.sdkInt;
      
      AppLogger.info('Android SDK version: $androidVersion');
      
      if (androidVersion >= 33) {
        // Android 13+ (API 33+) - Use granular media permissions
        final permissions = [
          Permission.photos,
          Permission.videos,
          Permission.audio,
          Permission.manageExternalStorage,
        ];
        
        final results = await permissions.request();
        
        // Check if at least one permission is granted
        bool hasAnyPermission = results.values.any((status) => status.isGranted);
        
        if (!hasAnyPermission) {
          // Try to request MANAGE_EXTERNAL_STORAGE for full access
          final manageStorageStatus = await Permission.manageExternalStorage.request();
          if (manageStorageStatus.isGranted) {
            AppLogger.info('MANAGE_EXTERNAL_STORAGE permission granted');
            return true;
          }
        }
        
        AppLogger.info('Media permissions status: ${results.toString()}');
        return hasAnyPermission;
        
      } else if (androidVersion >= 30) {
        // Android 11-12 (API 30-32) - Try MANAGE_EXTERNAL_STORAGE first
        final manageStorageStatus = await Permission.manageExternalStorage.request();
        if (manageStorageStatus.isGranted) {
          AppLogger.info('MANAGE_EXTERNAL_STORAGE permission granted');
          return true;
        }
        
        // Fall back to legacy storage permissions
        final storageStatus = await Permission.storage.request();
        AppLogger.info('Storage permission status: $storageStatus');
        return storageStatus.isGranted;
        
      } else {
        // Android 10 and below - Use legacy storage permissions
        final storageStatus = await Permission.storage.request();
        AppLogger.info('Storage permission status: $storageStatus');
        return storageStatus.isGranted;
      }
      
    } catch (e) {
      AppLogger.error('Error requesting storage permissions', e);
      return false;
    }
  }

  /// Get the initial path to start browsing from
  Future<String> _getInitialPath() async {
    try {
      // Try to get external storage directory
      Directory? externalDir;
      
      if (Platform.isAndroid) {
        // Try different methods to get external storage
        try {
          externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            // Navigate to the root of external storage
            final rootPath = '/storage/emulated/0/';
            if (await Directory(rootPath).exists()) {
              return rootPath;
            }
          }
        } catch (e) {
          AppLogger.warning('Could not get external storage directory: $e');
        }
        
        // Fall back to common Android paths
        for (final commonPath in _commonPaths) {
          if (await Directory(commonPath).exists()) {
            return commonPath;
          }
        }
      }
      
      // Final fallback to app documents directory
      final documentsDir = await getApplicationDocumentsDirectory();
      return documentsDir.path;
      
    } catch (e) {
      AppLogger.error('Error getting initial path', e);
      return '/';
    }
  }

  /// Load files from the specified directory
  Future<bool> loadFiles(String directoryPath) async {
    try {
      AppLogger.info('Loading files from: $directoryPath');
      
      final directory = Directory(directoryPath);
      if (!await directory.exists()) {
        AppLogger.warning('Directory does not exist: $directoryPath');
        return false;
      }
      
      final files = <DeviceFile>[];
      
      // Add parent directory option if not at root
      if (directoryPath != '/' && directoryPath != '/storage/emulated/0/') {
        final parentPath = Directory(directoryPath).parent.path;
        files.add(DeviceFile(
          name: '..',
          path: parentPath,
          isDirectory: true,
          size: 0,
          lastModified: DateTime.now(),
          extension: '',
          type: FileType.folder,
          icon: _fileTypeIcons['folder']!,
        ));
      }
      
      // Get directory contents
      final entities = await directory.list().toList();
      
      // Sort entities: directories first, then files
      entities.sort((a, b) {
        if (a is Directory && b is File) return -1;
        if (a is File && b is Directory) return 1;
        return a.path.toLowerCase().compareTo(b.path.toLowerCase());
      });
      
      for (final entity in entities) {
        try {
          final stat = await entity.stat();
          final isDirectory = entity is Directory;
          final name = path.basename(entity.path);
          
          // Skip hidden files and system files
          if (name.startsWith('.') && name != '..') continue;
          
          final extension = isDirectory ? '' : path.extension(name).toLowerCase();
          final fileType = isDirectory ? FileType.folder : _getFileType(extension);
          
          files.add(DeviceFile(
            name: name,
            path: entity.path,
            isDirectory: isDirectory,
            size: stat.size,
            lastModified: stat.modified,
            extension: extension,
            type: fileType,
            icon: _fileTypeIcons[fileType.name] ?? _fileTypeIcons['unknown']!,
          ));
          
        } catch (e) {
          AppLogger.warning('Error processing file: ${entity.path}, $e');
          continue;
        }
      }
      
      _currentFiles = files;
      _currentPath = directoryPath;
      
      // Update streams
      _filesController.add(files);
      _currentPathController.add(directoryPath);
      
      AppLogger.info('Loaded ${files.length} files from $directoryPath');
      return true;
      
    } catch (e) {
      AppLogger.error('Error loading files from $directoryPath', e);
      return false;
    }
  }

  /// Navigate to a specific directory
  Future<bool> navigateToDirectory(String directoryPath) async {
    try {
      AppLogger.info('Navigating to: $directoryPath');
      
      final directory = Directory(directoryPath);
      if (!await directory.exists()) {
        _operationStatusController.add({
          'type': 'error',
          'message': 'Directory does not exist: $directoryPath'
        });
        return false;
      }
      
      return await loadFiles(directoryPath);
      
    } catch (e) {
      AppLogger.error('Error navigating to directory: $directoryPath', e);
      _operationStatusController.add({
        'type': 'error',
        'message': 'Could not access directory: $directoryPath'
      });
      return false;
    }
  }

  /// Get available storage locations
  Future<List<StorageLocation>> getStorageLocations() async {
    try {
      AppLogger.info('Getting storage locations');
      
      final locations = <StorageLocation>[];
      
      // Internal storage
      const internalPath = '/storage/emulated/0/';
      if (await Directory(internalPath).exists()) {
        final stat = await Directory(internalPath).stat();
        locations.add(StorageLocation(
          name: 'Internal Storage',
          path: internalPath,
          type: 'internal',
          icon: '💾',
          isAccessible: true,
          totalSpace: 0, // Could be calculated if needed
          freeSpace: 0,
        ));
      }
      
      // Try to find external SD card
      final externalPaths = [
        '/storage/sdcard1/',
        '/storage/extSdCard/',
        '/storage/external_SD/',
      ];
      
      for (final extPath in externalPaths) {
        if (await Directory(extPath).exists()) {
          locations.add(StorageLocation(
            name: 'External SD Card',
            path: extPath,
            type: 'external',
            icon: '💳',
            isAccessible: true,
            totalSpace: 0,
            freeSpace: 0,
          ));
          break;
        }
      }
      
      // Add common directories
      final commonDirs = [
        {'name': 'Downloads', 'path': '/storage/emulated/0/Download/', 'icon': '⬇️'},
        {'name': 'Pictures', 'path': '/storage/emulated/0/Pictures/', 'icon': '🖼️'},
        {'name': 'DCIM', 'path': '/storage/emulated/0/DCIM/', 'icon': '📸'},
        {'name': 'Movies', 'path': '/storage/emulated/0/Movies/', 'icon': '🎬'},
        {'name': 'Music', 'path': '/storage/emulated/0/Music/', 'icon': '🎵'},
        {'name': 'Documents', 'path': '/storage/emulated/0/Documents/', 'icon': '📄'},
      ];
      
      for (final dir in commonDirs) {
        if (await Directory(dir['path']!).exists()) {
          locations.add(StorageLocation(
            name: dir['name']!,
            path: dir['path']!,
            type: 'folder',
            icon: dir['icon']!,
            isAccessible: true,
            totalSpace: 0,
            freeSpace: 0,
          ));
        }
      }
      
      AppLogger.info('Found ${locations.length} storage locations');
      return locations;
      
    } catch (e) {
      AppLogger.error('Error getting storage locations', e);
      return [];
    }
  }

  /// Search for files
  Future<List<DeviceFile>> searchFiles(String query, {String? rootPath}) async {
    try {
      AppLogger.info('Searching for files: $query');
      
      final searchRoot = rootPath ?? _currentPath;
      final results = <DeviceFile>[];
      
      await _searchRecursive(Directory(searchRoot), query.toLowerCase(), results);
      
      AppLogger.info('Found ${results.length} files matching: $query');
      return results;
      
    } catch (e) {
      AppLogger.error('Error searching files', e);
      return [];
    }
  }

  /// Recursive search helper
  Future<void> _searchRecursive(Directory directory, String query, List<DeviceFile> results) async {
    try {
      final entities = await directory.list().toList();
      
      for (final entity in entities) {
        final name = path.basename(entity.path).toLowerCase();
        
        // Skip hidden files
        if (name.startsWith('.')) continue;
        
        if (name.contains(query)) {
          final stat = await entity.stat();
          final isDirectory = entity is Directory;
          final extension = isDirectory ? '' : path.extension(name).toLowerCase();
          final fileType = isDirectory ? FileType.folder : _getFileType(extension);
          
          results.add(DeviceFile(
            name: path.basename(entity.path),
            path: entity.path,
            isDirectory: isDirectory,
            size: stat.size,
            lastModified: stat.modified,
            extension: extension,
            type: fileType,
            icon: _fileTypeIcons[fileType.name] ?? _fileTypeIcons['unknown']!,
          ));
        }
        
        // Recursively search subdirectories (limit depth to avoid infinite loops)
        if (entity is Directory && results.length < 1000) {
          await _searchRecursive(entity, query, results);
        }
      }
      
    } catch (e) {
      // Silently ignore directories we can't access
      AppLogger.warning('Could not search directory: ${directory.path}');
    }
  }

  /// Delete a file or directory
  Future<bool> deleteFile(String filePath) async {
    try {
      AppLogger.info('Deleting file: $filePath');
      
      final file = File(filePath);
      final directory = Directory(filePath);
      
      if (await file.exists()) {
        await file.delete();
      } else if (await directory.exists()) {
        await directory.delete(recursive: true);
      } else {
        AppLogger.warning('File does not exist: $filePath');
        return false;
      }
      
      // Refresh current directory
      await loadFiles(_currentPath);
      
      _operationStatusController.add({
        'type': 'success',
        'message': 'File deleted successfully'
      });
      
      AppLogger.info('File deleted successfully: $filePath');
      return true;
      
    } catch (e) {
      AppLogger.error('Error deleting file: $filePath', e);
      final error = _parseFileError(e, filePath);
      _operationStatusController.add({
        'type': 'error',
        'message': error.message,
        'error': error,
      });
      return false;
    }
  }

  /// Rename a file or directory
  Future<bool> renameFile(String oldPath, String newName) async {
    try {
      AppLogger.info('Renaming file: $oldPath to $newName');
      
      final oldFile = File(oldPath);
      final oldDirectory = Directory(oldPath);
      final parentDir = Directory(oldPath).parent.path;
      final newPath = path.join(parentDir, newName);
      
      // Check if new name already exists
      if (await File(newPath).exists() || await Directory(newPath).exists()) {
        _operationStatusController.add({
          'type': 'error',
          'message': 'A file with that name already exists'
        });
        return false;
      }
      
      if (await oldFile.exists()) {
        await oldFile.rename(newPath);
      } else if (await oldDirectory.exists()) {
        await oldDirectory.rename(newPath);
      } else {
        AppLogger.warning('File does not exist: $oldPath');
        return false;
      }
      
      // Refresh current directory
      await loadFiles(_currentPath);
      
      _operationStatusController.add({
        'type': 'success',
        'message': 'File renamed successfully'
      });
      
      AppLogger.info('File renamed successfully: $oldPath to $newPath');
      return true;
      
    } catch (e) {
      AppLogger.error('Error renaming file: $oldPath', e);
      final error = _parseFileError(e, oldPath);
      _operationStatusController.add({
        'type': 'error',
        'message': error.message,
        'error': error,
      });
      return false;
    }
  }

  /// Copy a file or directory
  Future<bool> copyFile(String sourcePath, String destinationPath) async {
    try {
      AppLogger.info('Copying file: $sourcePath to $destinationPath');
      
      final sourceFile = File(sourcePath);
      final sourceDirectory = Directory(sourcePath);
      
      if (await sourceFile.exists()) {
        await sourceFile.copy(destinationPath);
      } else if (await sourceDirectory.exists()) {
        await _copyDirectory(sourceDirectory, Directory(destinationPath));
      } else {
        AppLogger.warning('Source file does not exist: $sourcePath');
        return false;
      }
      
      // Refresh current directory
      await loadFiles(_currentPath);
      
      _operationStatusController.add({
        'type': 'success',
        'message': 'File copied successfully'
      });
      
      AppLogger.info('File copied successfully: $sourcePath to $destinationPath');
      return true;
      
    } catch (e) {
      AppLogger.error('Error copying file: $sourcePath', e);
      final error = _parseFileError(e, sourcePath);
      _operationStatusController.add({
        'type': 'error',
        'message': error.message,
        'error': error,
      });
      return false;
    }
  }

  /// Move a file or directory
  Future<bool> moveFile(String sourcePath, String destinationPath) async {
    try {
      AppLogger.info('Moving file: $sourcePath to $destinationPath');
      
      final sourceFile = File(sourcePath);
      final sourceDirectory = Directory(sourcePath);
      
      if (await sourceFile.exists()) {
        await sourceFile.rename(destinationPath);
      } else if (await sourceDirectory.exists()) {
        await sourceDirectory.rename(destinationPath);
      } else {
        AppLogger.warning('Source file does not exist: $sourcePath');
        return false;
      }
      
      // Refresh current directory
      await loadFiles(_currentPath);
      
      _operationStatusController.add({
        'type': 'success',
        'message': 'File moved successfully'
      });
      
      AppLogger.info('File moved successfully: $sourcePath to $destinationPath');
      return true;
      
    } catch (e) {
      AppLogger.error('Error moving file: $sourcePath', e);
      final error = _parseFileError(e, sourcePath);
      _operationStatusController.add({
        'type': 'error',
        'message': error.message,
        'error': error,
      });
      return false;
    }
  }

  /// Helper method to copy directory recursively
  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    
    await for (final entity in source.list()) {
      if (entity is Directory) {
        final newDirectory = Directory(path.join(destination.path, path.basename(entity.path)));
        await _copyDirectory(entity, newDirectory);
      } else if (entity is File) {
        final newFile = File(path.join(destination.path, path.basename(entity.path)));
        await entity.copy(newFile.path);
      }
    }
  }

  /// Create a new file with content
  Future<bool> createFile(String parentPath, String fileName, String content) async {
    try {
      AppLogger.info('Creating file: $fileName in $parentPath');
      
      final filePath = path.join(parentPath, fileName);
      final file = File(filePath);
      
      if (await file.exists()) {
        _operationStatusController.add({
          'type': 'error',
          'message': 'File already exists'
        });
        return false;
      }
      
      await file.writeAsString(content);
      
      // Refresh current directory
      await loadFiles(_currentPath);
      
      _operationStatusController.add({
        'type': 'success',
        'message': 'File created successfully'
      });
      
      AppLogger.info('File created successfully: $filePath');
      return true;
      
    } catch (e) {
      AppLogger.error('Error creating file: $fileName', e);
      final error = _parseFileError(e, parentPath);
      _operationStatusController.add({
        'type': 'error',
        'message': error.message,
        'error': error,
      });
      return false;
    }
  }

  /// Get file content as string (for text files)
  Future<String?> getFileContent(String filePath) async {
    try {
      final file = File(filePath);
      
      if (!await file.exists()) {
        return null;
      }
      
      // Check file size to avoid loading huge files
      final stat = await file.stat();
      if (stat.size > 1024 * 1024) { // 1MB limit
        throw Exception('File too large to read');
      }
      
      return await file.readAsString();
      
    } catch (e) {
      AppLogger.error('Error reading file content: $filePath', e);
      return null;
    }
  }

  /// Get file bytes (for binary files)
  Future<Uint8List?> getFileBytes(String filePath) async {
    try {
      final file = File(filePath);
      
      if (!await file.exists()) {
        return null;
      }
      
      // Check file size to avoid loading huge files
      final stat = await file.stat();
      if (stat.size > 10 * 1024 * 1024) { // 10MB limit
        throw Exception('File too large to read');
      }
      
      return await file.readAsBytes();
      
    } catch (e) {
      AppLogger.error('Error reading file bytes: $filePath', e);
      return null;
    }
  }

  /// Create a new directory
  Future<bool> createDirectory(String parentPath, String directoryName) async {
    try {
      AppLogger.info('Creating directory: $directoryName in $parentPath');
      
      final directoryPath = path.join(parentPath, directoryName);
      final directory = Directory(directoryPath);
      
      if (await directory.exists()) {
        _operationStatusController.add({
          'type': 'error',
          'message': 'Directory already exists'
        });
        return false;
      }
      
      await directory.create(recursive: true);
      
      // Refresh current directory
      await loadFiles(_currentPath);
      
      _operationStatusController.add({
        'type': 'success',
        'message': 'Directory created successfully'
      });
      
      AppLogger.info('Directory created successfully: $directoryPath');
      return true;
      
    } catch (e) {
      AppLogger.error('Error creating directory: $directoryName', e);
      final error = _parseFileError(e, parentPath);
      _operationStatusController.add({
        'type': 'error',
        'message': error.message,
        'error': error,
      });
      return false;
    }
  }

  /// Get file type based on extension
  FileType _getFileType(String extension) {
    switch (extension.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.gif':
      case '.bmp':
      case '.webp':
        return FileType.image;
      
      case '.mp4':
      case '.avi':
      case '.mkv':
      case '.mov':
      case '.wmv':
      case '.flv':
      case '.webm':
        return FileType.video;
      
      case '.mp3':
      case '.wav':
      case '.aac':
      case '.flac':
      case '.ogg':
      case '.m4a':
        return FileType.audio;
      
      case '.pdf':
      case '.doc':
      case '.docx':
      case '.xls':
      case '.xlsx':
      case '.ppt':
      case '.pptx':
        return FileType.document;
      
      case '.zip':
      case '.rar':
      case '.7z':
      case '.tar':
      case '.gz':
        return FileType.archive;
      
      case '.apk':
      case '.exe':
      case '.msi':
        return FileType.executable;
      
      case '.dart':
      case '.java':
      case '.kt':
      case '.js':
      case '.py':
      case '.cpp':
      case '.c':
      case '.h':
        return FileType.code;
      
      case '.txt':
      case '.md':
      case '.xml':
      case '.json':
      case '.yaml':
      case '.yml':
        return FileType.text;
      
      default:
        return FileType.unknown;
    }
  }

  /// Get current path
  String get currentPath => _currentPath;

  /// Get current files
  List<DeviceFile> get currentFiles => _currentFiles;

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Parse file operation errors
  AppError _parseFileError(dynamic error, String? filePath) {
    return ErrorHandler.handleFileError(error);
  }

  /// Dispose resources
  void dispose() {
    _filesController.close();
    _currentPathController.close();
    _operationStatusController.close();
  }
}