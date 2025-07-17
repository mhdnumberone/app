import 'package:intl/intl.dart';

/// Represents a file or directory on the device
class DeviceFile {
  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final DateTime lastModified;
  final String extension;
  final FileType type;
  final String icon;

  DeviceFile({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.size,
    required this.lastModified,
    required this.extension,
    required this.type,
    required this.icon,
  });

  /// Get formatted file size
  String get formattedSize {
    if (isDirectory) return '';
    
    if (size < 1024) return '${size}B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)}KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  /// Get formatted last modified date
  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(lastModified);
    
    if (difference.inDays == 0) {
      return 'Today ${DateFormat('HH:mm').format(lastModified)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${DateFormat('HH:mm').format(lastModified)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(lastModified);
    }
  }

  /// Get detailed file information
  Map<String, dynamic> get fileInfo {
    return {
      'name': name,
      'path': path,
      'isDirectory': isDirectory,
      'size': size,
      'formattedSize': formattedSize,
      'lastModified': lastModified.toIso8601String(),
      'formattedDate': formattedDate,
      'extension': extension,
      'type': type.name,
      'icon': icon,
    };
  }

  /// Check if file is an image
  bool get isImage => type == FileType.image;

  /// Check if file is a video
  bool get isVideo => type == FileType.video;

  /// Check if file is an audio file
  bool get isAudio => type == FileType.audio;

  /// Check if file is a document
  bool get isDocument => type == FileType.document;

  /// Check if file can be opened/previewed
  bool get canPreview {
    return isImage || isVideo || isAudio || isDocument || type == FileType.text;
  }

  /// Get parent directory path
  String get parentPath {
    if (path == '/') return '/';
    final parts = path.split('/');
    parts.removeLast();
    return parts.join('/');
  }

  @override
  String toString() {
    return 'DeviceFile(name: $name, path: $path, isDirectory: $isDirectory, size: $size, type: ${type.name})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeviceFile && other.path == path;
  }

  @override
  int get hashCode => path.hashCode;
}

/// Represents different types of files
enum FileType {
  folder,
  image,
  video,
  audio,
  document,
  archive,
  executable,
  code,
  text,
  unknown
}

/// Represents a storage location on the device
class StorageLocation {
  final String name;
  final String path;
  final String type;
  final String icon;
  final bool isAccessible;
  final int totalSpace;
  final int freeSpace;

  StorageLocation({
    required this.name,
    required this.path,
    required this.type,
    required this.icon,
    required this.isAccessible,
    required this.totalSpace,
    required this.freeSpace,
  });

  /// Get formatted total space
  String get formattedTotalSpace {
    if (totalSpace < 1024 * 1024 * 1024) return '${(totalSpace / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(totalSpace / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  /// Get formatted free space
  String get formattedFreeSpace {
    if (freeSpace < 1024 * 1024 * 1024) return '${(freeSpace / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(freeSpace / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  /// Get usage percentage
  double get usagePercentage {
    if (totalSpace == 0) return 0.0;
    return ((totalSpace - freeSpace) / totalSpace) * 100;
  }

  @override
  String toString() {
    return 'StorageLocation(name: $name, path: $path, type: $type, isAccessible: $isAccessible)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StorageLocation && other.path == path;
  }

  @override
  int get hashCode => path.hashCode;
}

/// Represents file operation results
class FileOperationResult {
  final bool success;
  final String message;
  final String? errorCode;
  final Map<String, dynamic>? data;

  FileOperationResult({
    required this.success,
    required this.message,
    this.errorCode,
    this.data,
  });

  factory FileOperationResult.success(String message, {Map<String, dynamic>? data}) {
    return FileOperationResult(
      success: true,
      message: message,
      data: data,
    );
  }

  factory FileOperationResult.error(String message, {String? errorCode}) {
    return FileOperationResult(
      success: false,
      message: message,
      errorCode: errorCode,
    );
  }

  @override
  String toString() {
    return 'FileOperationResult(success: $success, message: $message, errorCode: $errorCode)';
  }
}