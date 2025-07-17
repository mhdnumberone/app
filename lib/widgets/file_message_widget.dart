// lib/widgets/file_message_widget.dart
// MIGRATED VERSION - Using unified theme service and base widgets

import 'dart:io';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../api/apis.dart';
import '../core/widgets/base_widgets.dart';
import '../core/themes/app_theme_extension.dart';
import '../core/localization/app_localizations.dart';
import '../helper/dialogs.dart';
import '../core/utils/permission_manager.dart';

class FileMessageWidget extends BaseStatefulWidget {
  final String fileUrl;
  final String fileName;
  final int? fileSize;
  final bool isMe;
  final bool isLocalFile;

  const FileMessageWidget({
    super.key,
    required this.fileUrl,
    required this.fileName,
    this.fileSize,
    required this.isMe,
    this.isLocalFile = false,
  });

  @override
  State<FileMessageWidget> createState() => _FileMessageWidgetState();
}

class _FileMessageWidgetState extends BaseState<FileMessageWidget> {
  final ValueNotifier<bool> _isDownloadingNotifier = ValueNotifier(false);
  final ValueNotifier<double> _downloadProgressNotifier = ValueNotifier(0.0);

  @override
  void dispose() {
    _isDownloadingNotifier.dispose();
    _downloadProgressNotifier.dispose();
    super.dispose();
  }

  IconData _getFileIcon() {
    final extension = widget.fileName.toLowerCase().split('.').last;
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.archive;
      case 'txt':
        return Icons.text_snippet;
      case 'mp3':
      case 'wav':
      case 'aac':
      case 'm4a':
        return Icons.audiotrack;
      case 'mp4':
      case 'mov':
      case 'avi':
      case 'mkv':
        return Icons.videocam;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'webp':
        return Icons.image;
      case 'apk':
        return Icons.android;
      case 'exe':
        return Icons.apps;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  bool _isImageFile() {
    final extension = widget.fileName.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension);
  }

  bool _isVideoFile() {
    final extension = widget.fileName.toLowerCase().split('.').last;
    return ['mp4', 'mov', 'avi', 'mkv', 'wmv', 'flv'].contains(extension);
  }

  bool _isMediaFile() {
    return _isImageFile() || _isVideoFile();
  }

  Color _getFileIconColor() {
    final extension = widget.fileName.toLowerCase().split('.').last;
    switch (extension) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      case 'ppt':
      case 'pptx':
        return Colors.orange;
      case 'zip':
      case 'rar':
      case '7z':
        return Colors.purple;
      case 'mp3':
      case 'wav':
      case 'aac':
      case 'm4a':
        return Colors.pink;
      case 'mp4':
      case 'mov':
      case 'avi':
      case 'mkv':
        return Colors.indigo;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'webp':
        return Colors.cyan;
      default:
        return context.appTheme.highlightColor;
    }
  }

  // ✅ طلب صلاحيات التخزين للملفات
  Future<bool> _requestStoragePermissions() async {
    try {
      log('🔍 Requesting storage permissions for file download...');
      
      if (!Platform.isAndroid) {
        log('✅ iOS - no storage permission needed');
        return true;
      }

      // Use direct permission_handler for file operations
      try {
        // For Android 13+, request specific media permissions
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt >= 33) {
          log('📱 Android 13+ detected, requesting granular permissions');
          
          final permissions = await [
            Permission.photos,
            Permission.videos,
            Permission.audio,
            Permission.manageExternalStorage,
          ].request();
          
          final hasAnyPermission = permissions.values.any((status) => status.isGranted);
          
          if (hasAnyPermission) {
            log('✅ Android 13+ permissions granted');
            return true;
          } else {
            log('❌ Android 13+ permissions denied');
            if (mounted) {
              Dialogs.showSnackbar(context, 'تحتاج إلى صلاحية الوصول للملفات للتنزيل');
            }
            return false;
          }
        } else {
          // For older Android versions
          log('📱 Android < 13 detected, requesting storage permission');
          final storageStatus = await Permission.storage.request();
          final manageStorageStatus = await Permission.manageExternalStorage.request();
          
          final hasPermission = storageStatus.isGranted || manageStorageStatus.isGranted;
          
          if (hasPermission) {
            log('✅ Storage permissions granted');
            return true;
          } else {
            log('❌ Storage permissions denied');
            if (mounted) {
              Dialogs.showSnackbar(context, 'تحتاج إلى صلاحية التخزين للتنزيل');
            }
            return false;
          }
        }
      } catch (e) {
        log('❌ Error requesting storage permissions: $e');
        if (mounted) {
          Dialogs.showSnackbar(context, 'خطأ في طلب صلاحيات التخزين');
        }
        return false;
      }
    } catch (e) {
      log('❌ Error in storage permission request: $e');
      return false;
    }
  }

  // ====================== نقاط الدخول =======================

  Future<void> _handleFileTap() async {
    if (_isDownloadingNotifier.value) return;

    // ✅ طلب الصلاحيات أولاً باستخدام PermissionManager
    final hasPermissions = await _requestStoragePermissions();
    if (!hasPermissions) {
      return; // الرسالة سيتم عرضها من داخل _requestStoragePermissions
    }

    await _executeWithRetry(() async {
      if (widget.isLocalFile || !widget.fileUrl.startsWith('http')) {
        await _handleLocalFile();
      } else if (_isMediaFile()) {
        await _saveToGallery();
      } else {
        await _downloadAndOpenFile();
      }
    }, 'handleFileTap');
  }

  Future<void> _handleLocalFile() async {
    try {
      final localFile = File(widget.fileUrl);

      if (!await localFile.exists()) {
        if (mounted) {
          Dialogs.showSnackbar(context, 'الملف غير موجود محلياً');
        }
        return;
      }

      if (_isMediaFile()) {
        await _saveLocalMediaToGallery(localFile);
      } else {
        await OpenFile.open(widget.fileUrl);
        if (mounted) {
          Dialogs.showSnackbar(context, 'تم فتح الملف بنجاح! 📁');
        }
      }
    } catch (e) {
      log('Error handling local file: $e');
      if (mounted) {
        Dialogs.showSnackbar(context, 'خطأ في معالجة الملف المحلي');
      }
    }
  }

  Future<void> _saveLocalMediaToGallery(File localFile) async {
    try {
      if (_isImageFile()) {
        await Gal.putImage(localFile.path, album: "SecureChat");
      } else if (_isVideoFile()) {
        await Gal.putVideo(localFile.path, album: "SecureChat");
      }
      if (mounted) {
        Dialogs.showSnackbar(context, 'تم حفظ الملف في الجاليري بنجاح! 📱');
      }
    } catch (e) {
      log('Error saving local media to gallery: $e');
      if (mounted) {
        Dialogs.showSnackbar(context, 'فشل في حفظ الملف في الجاليري');
      }
    }
  }

  Future<void> _saveToGallery() async {
    try {
      _isDownloadingNotifier.value = true;
      _downloadProgressNotifier.value = 0.0;

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/${widget.fileName}';
      await _downloadWithStreaming(widget.fileUrl, filePath);

      try {
        if (_isImageFile()) {
          await Gal.putImage(filePath, album: "SecureChat");
        } else if (_isVideoFile()) {
          await Gal.putVideo(filePath, album: "SecureChat");
        }

        if (mounted) {
          Dialogs.showSnackbar(context, 'تم حفظ الملف في الجاليري بنجاح! 📱');
        }
      } catch (e) {
        log('Error saving to gallery: $e');
        if (mounted) {
          Dialogs.showSnackbar(context, 'فشل في حفظ الملف في الجاليري');
        }
      } finally {
        _isDownloadingNotifier.value = false;
        _downloadProgressNotifier.value = 0.0;

        // حذف الملف المؤقت
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      log('Error saving to gallery: $e');
      _isDownloadingNotifier.value = false;
      if (mounted) {
        Dialogs.showSnackbar(context, 'حدث خطأ أثناء حفظ الملف');
      }
    }
  }

  Future<void> _downloadAndOpenFile() async {
    try {
      _isDownloadingNotifier.value = true;
      _downloadProgressNotifier.value = 0.0;

      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/${widget.fileName}';

      // التحقق من وجود الملف محلياً
      final localFile = File(filePath);
      if (await localFile.exists()) {
        await OpenFile.open(filePath);
        _isDownloadingNotifier.value = false;
        if (mounted) {
          Dialogs.showSnackbar(context, 'تم فتح الملف بنجاح! 📁');
        }
        return;
      }

      await _downloadWithStreaming(widget.fileUrl, filePath);

      _isDownloadingNotifier.value = false;

      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done && mounted) {
        Dialogs.showSnackbar(context, 'تم التنزيل، لكن فشل في فتح الملف');
      } else if (mounted) {
        Dialogs.showSnackbar(context, 'تم تنزيل وفتح الملف بنجاح! 📁');
      }
    } catch (e) {
      log('Error downloading file: $e');
      _isDownloadingNotifier.value = false;
      if (mounted) {
        Dialogs.showSnackbar(context, 'حدث خطأ أثناء تنزيل الملف');
      }
    }
  }

  Future<void> _downloadWithStreaming(String url, String filePath) async {
    final request = http.Request('GET', Uri.parse(url));
    final response = await request.send();

    if (response.statusCode != 200) {
      throw Exception('فشل في التنزيل - كود الخطأ: ${response.statusCode}');
    }

    final file = File(filePath);
    final sink = file.openWrite();

    int downloaded = 0;
    final totalBytes = response.contentLength ?? 0;

    try {
      await response.stream.listen(
            (chunk) {
          sink.add(chunk);
          downloaded += chunk.length;
          if (totalBytes > 0) {
            _downloadProgressNotifier.value = downloaded / totalBytes;
          }
        },
        onError: (error) {
          throw Exception('خطأ أثناء التنزيل: $error');
        },
      ).asFuture();

      await sink.close();
    } catch (e) {
      await sink.close();
      if (await file.exists()) {
        await file.delete();
      }
      rethrow;
    }
  }

  Future<T> _executeWithRetry<T>(
      Future<T> Function() operation,
      String operationName, {
        int maxRetries = 3,
        Duration delay = const Duration(seconds: 2),
      }) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await operation();
      } catch (e) {
        log('$operationName failed (attempt $attempt/$maxRetries): $e');
        if (attempt == maxRetries) {
          if (mounted) {
            Dialogs.showSnackbar(
                context,
                'فشل في $operationName بعد $maxRetries محاولات'
            );
          }
          rethrow;
        }
        await Future.delayed(delay * attempt);
      }
    }
    throw Exception('Unexpected error in retry mechanism');
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.isMe
        ? context.appTheme.primaryColor.withOpacity(0.2)
        : context.appTheme.surfaceColor;
    final borderColor = widget.isMe
        ? context.appTheme.primaryColor.withOpacity(0.3)
        : context.appTheme.primaryColor.withOpacity(0.2);

    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleFileTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Stack(
              children: [
                Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _getFileIconColor().withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _getFileIcon(),
                            color: _getFileIconColor(),
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.fileName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (widget.fileSize != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _formatFileSize(widget.fileSize),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.appTheme.textSecondaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                widget.isLocalFile
                                    ? (_isMediaFile() ? 'اضغط للحفظ في الجاليري' : 'اضغط للفتح')
                                    : (_isMediaFile() ? 'اضغط للحفظ في الجاليري' : 'اضغط للتنزيل والفتح'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _getFileIconColor(),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ValueListenableBuilder<bool>(
                          valueListenable: _isDownloadingNotifier,
                          builder: (context, isDownloading, child) {
                            return Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _getFileIconColor().withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: isDownloading
                                  ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _getFileIconColor(),
                                  ),
                                ),
                              )
                                  : Icon(
                                widget.isLocalFile
                                    ? (_isMediaFile() ? Icons.save_alt : Icons.open_in_new)
                                    : (_isMediaFile() ? Icons.save_alt : Icons.download),
                                color: _getFileIconColor(),
                                size: 20,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    ValueListenableBuilder<bool>(
                      valueListenable: _isDownloadingNotifier,
                      builder: (context, isDownloading, child) {
                        return isDownloading
                            ? Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: ValueListenableBuilder<double>(
                            valueListenable: _downloadProgressNotifier,
                            builder: (context, progress, child) {
                              return Column(
                                children: [
                                  LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor: Colors.grey.withOpacity(0.2),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _getFileIconColor(),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${(progress * 100).toInt()}%',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _getFileIconColor(),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        )
                            : const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
                _buildUploadProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ✅ دالة مؤشر تقدم الرفع
  Widget _buildUploadProgressIndicator() {
    return ValueListenableBuilder<Map<String, UploadProgress>>(
      valueListenable: APIs.uploadProgressNotifier,
      builder: (context, progressMap, child) {
        // ✅ البحث المحسن عن التقدم
        final progress = progressMap.values.where((p) =>
        p.fileName == widget.fileName ||
            widget.fileUrl.contains(p.messageId) ||
            p.messageId.contains(widget.fileName)
        ).firstOrNull;

        if (progress == null || progress.status == UploadStatus.completed) {
          return const SizedBox.shrink();
        }

        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 3,
            margin: const EdgeInsets.all(4),
            child: LinearProgressIndicator(
              value: progress.progress,
              backgroundColor: Colors.grey.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation(
                progress.status == UploadStatus.failed
                    ? context.appTheme.errorColor
                    : context.appTheme.highlightColor,
              ),
            ),
          ),
        );
      },
    );
  }
}
