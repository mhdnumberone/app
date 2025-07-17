// lib/widgets/download_progress_widget.dart

import 'package:flutter/material.dart';
import '../core/services/download_manager.dart';
import '../core/themes/app_theme_extension.dart';
import '../core/widgets/base_widgets.dart';

class DownloadProgressWidget extends BaseStatelessWidget {
  final String? url;
  final bool showGlobal;
  final Widget? child;

  const DownloadProgressWidget({
    super.key,
    this.url,
    this.showGlobal = false,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, DownloadProgress>>(
      valueListenable: DownloadManager().progressNotifier,
      builder: (context, progressMap, child) {
        if (showGlobal) {
          return _buildGlobalProgress(context, progressMap);
        } else if (url != null) {
          return _buildSpecificProgress(context, progressMap[url!]);
        }
        return child ?? const SizedBox.shrink();
      },
    );
  }

  Widget _buildGlobalProgress(BuildContext context, Map<String, DownloadProgress> progressMap) {
    final activeDownloads = progressMap.values
        .where((p) => p.status == DownloadStatus.downloading)
        .toList();

    if (activeDownloads.isEmpty) {
      return child ?? const SizedBox.shrink();
    }

    return Column(
      children: [
        if (child != null) child!,
        Container(
          margin: const EdgeInsets.all(8),
          child: Column(
            children: activeDownloads
                .take(3) // Show max 3 active downloads
                .map((progress) => _buildProgressItem(context, progress))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSpecificProgress(BuildContext context, DownloadProgress? progress) {
    if (progress == null || progress.status != DownloadStatus.downloading) {
      return child ?? const SizedBox.shrink();
    }

    return Stack(
      children: [
        if (child != null) child!,
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildProgressIndicator(context, progress),
        ),
      ],
    );
  }

  Widget _buildProgressItem(BuildContext context, DownloadProgress progress) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.appTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: context.appTheme.primaryLight.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getIconForFileType(progress.fileName),
                size: 16,
                color: context.appTheme.highlightColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getDisplayName(progress.fileName),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: context.appTheme.textPrimaryColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${(progress.progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 11,
                  color: context.appTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _buildProgressIndicator(context, progress),
          if (progress.totalBytes != null) ...[
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatBytes(progress.downloadedBytes),
                  style: TextStyle(
                    fontSize: 10,
                    color: context.appTheme.textSecondaryColor,
                  ),
                ),
                Text(
                  _formatBytes(progress.totalBytes!),
                  style: TextStyle(
                    fontSize: 10,
                    color: context.appTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(BuildContext context, DownloadProgress progress) {
    return LinearProgressIndicator(
      value: progress.progress,
      backgroundColor: context.appTheme.primaryLight.withOpacity(0.2),
      valueColor: AlwaysStoppedAnimation<Color>(
        progress.status == DownloadStatus.failed
            ? context.appTheme.errorColor
            : context.appTheme.highlightColor,
      ),
      minHeight: 3,
    );
  }

  IconData _getIconForFileType(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'mkv':
        return Icons.videocam;
      case 'mp3':
      case 'wav':
      case 'aac':
      case 'm4a':
        return Icons.audiotrack;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _getDisplayName(String fileName) {
    // Remove timestamp prefix
    final parts = fileName.split('_');
    if (parts.length > 1 && RegExp(r'^\d+$').hasMatch(parts[0])) {
      return parts.skip(1).join('_');
    }
    return fileName;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}

// Overlay widget to show global download progress
class GlobalDownloadProgressOverlay extends BaseStatelessWidget {
  final Widget child;

  const GlobalDownloadProgressOverlay({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          right: 10,
          child: DownloadProgressWidget(showGlobal: true),
        ),
      ],
    );
  }
}

// Simple download button with progress
class DownloadButton extends BaseStatelessWidget {
  final String url;
  final String fileName;
  final String? mediaType;
  final VoidCallback? onCompleted;
  final VoidCallback? onFailed;

  const DownloadButton({
    super.key,
    required this.url,
    required this.fileName,
    this.mediaType,
    this.onCompleted,
    this.onFailed,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, DownloadProgress>>(
      valueListenable: DownloadManager().progressNotifier,
      builder: (context, progressMap, child) {
        final progress = progressMap[url];
        final isDownloading = progress?.status == DownloadStatus.downloading;
        
        if (progress?.status == DownloadStatus.completed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onCompleted?.call();
          });
        } else if (progress?.status == DownloadStatus.failed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onFailed?.call();
          });
        }

        return ElevatedButton(
          onPressed: isDownloading ? null : () => _startDownload(),
          style: ElevatedButton.styleFrom(
            backgroundColor: context.appTheme.highlightColor,
          ),
          child: isDownloading
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        value: progress?.progress,
                        strokeWidth: 2,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${(progress?.progress ?? 0 * 100).toInt()}%'),
                  ],
                )
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.download, size: 16),
                    SizedBox(width: 4),
                    Text('تحميل'),
                  ],
                ),
        );
      },
    );
  }

  void _startDownload() {
    DownloadManager().downloadFile(
      url: url,
      fileName: fileName,
      mediaType: mediaType,
    );
  }
}