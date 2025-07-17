// lib/widgets/video_player_widget.dart - النسخة المحسنة
// MIGRATED VERSION - Using unified theme service and base widgets

import 'dart:io';
import 'dart:developer';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../core/widgets/base_widgets.dart';
import '../core/themes/app_theme_extension.dart';
import '../core/utils/secure_data_manager.dart';
import '../core/services/download_manager.dart';

enum VideoFitMode {
  contain,  // الافتراضي - يحترم النسبة الأصلية
  cover,    // يملأ المساحة مع القص
  fill,     // يملأ المساحة مع التمدد
}

class VideoPlayerWidget extends BaseStatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  final bool isMe;
  final bool isLocalFile;
  final VoidCallback? onTap; // ✅ إضافة onTap للعرض الكامل
  final VideoFitMode fitMode; // ✅ إضافة خيار العرض

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.isMe,
    this.isLocalFile = false,
    this.onTap,
    this.fitMode = VideoFitMode.contain, // الافتراضي
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends BaseState<VideoPlayerWidget> {
  VideoPlayerController? _controller;

  // ValueNotifiers
  final ValueNotifier<bool> _isInitializedNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _isPlayingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _showControlsNotifier = ValueNotifier(true);
  final ValueNotifier<bool> _hasErrorNotifier = ValueNotifier(false);
  final ValueNotifier<Duration> _positionNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> _durationNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<VideoFitMode> _fitModeNotifier = ValueNotifier(VideoFitMode.contain);

  @override
  void initState() {
    super.initState();
    _fitModeNotifier.value = widget.fitMode;
    _initializeVideo();
  }

  @override
  void dispose() {
    _controller?.removeListener(_handleVideoStateChange);
    _controller?.dispose();
    _isInitializedNotifier.dispose();
    _isPlayingNotifier.dispose();
    _showControlsNotifier.dispose();
    _hasErrorNotifier.dispose();
    _positionNotifier.dispose();
    _durationNotifier.dispose();
    _fitModeNotifier.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    try {
      if (widget.isLocalFile || !widget.videoUrl.startsWith('http')) {
        _controller = VideoPlayerController.file(File(widget.videoUrl));
      } else {
        // ✅ Check if video is cached first
        final cachedPath = await _getCachedVideoPath();
        if (cachedPath != null && await File(cachedPath).exists()) {
          _controller = VideoPlayerController.file(File(cachedPath));
        } else {
          _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
          // Cache the video after initialization
          _cacheVideoInBackground();
        }
      }

      await _controller!.initialize();
      _controller!.addListener(_handleVideoStateChange);

      _isInitializedNotifier.value = true;
      _durationNotifier.value = _controller!.value.duration;
      _hasErrorNotifier.value = false;

      // ✅ تحديد أفضل وضع عرض تلقائياً حسب نسبة الفيديو
      _autoSelectFitMode();
    } catch (e) {
      _hasErrorNotifier.value = true;
      _isInitializedNotifier.value = false;
      debugPrint('Error initializing video: $e');
    }
  }

  // ✅ تحديد أفضل وضع عرض تلقائياً
  void _autoSelectFitMode() {
    if (_controller == null) return;

    final aspectRatio = _controller!.value.aspectRatio;

    // إذا كان الفيديو رأسي جداً (aspect ratio < 0.6)
    if (aspectRatio < 0.6) {
      _fitModeNotifier.value = VideoFitMode.cover;
    }
    // إذا كان الفيديو أفقي جداً (aspect ratio > 2.5)
    else if (aspectRatio > 2.5) {
      _fitModeNotifier.value = VideoFitMode.cover;
    }
    // إذا كان مربع تقريباً (0.8 < aspect ratio < 1.2)
    else if (aspectRatio > 0.8 && aspectRatio < 1.2) {
      _fitModeNotifier.value = VideoFitMode.cover;
    }
    // النسب العادية
    else {
      _fitModeNotifier.value = VideoFitMode.contain;
    }
  }

  void _handleVideoStateChange() {
    if (!mounted || _controller == null) return;

    _isPlayingNotifier.value = _controller!.value.isPlaying;
    _positionNotifier.value = _controller!.value.position;

    if (_isPlayingNotifier.value && _showControlsNotifier.value) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _isPlayingNotifier.value) {
          _showControlsNotifier.value = false;
        }
      });
    }
  }

  Future<void> _togglePlayPause() async {
    if (_controller == null || !_isInitializedNotifier.value) return;

    _showControlsNotifier.value = true;

    try {
      if (_isPlayingNotifier.value) {
        await _controller!.pause();
      } else {
        if (_controller!.value.position >= _controller!.value.duration) {
          await _controller!.seekTo(Duration.zero);
        }
        await _controller!.play();
      }
    } catch (e) {
      _hasErrorNotifier.value = true;
      debugPrint('Error toggling play/pause: $e');
    }
  }

  // ✅ تبديل وضع العرض
  void _toggleFitMode() {
    final currentMode = _fitModeNotifier.value;
    switch (currentMode) {
      case VideoFitMode.contain:
        _fitModeNotifier.value = VideoFitMode.cover;
        break;
      case VideoFitMode.cover:
        _fitModeNotifier.value = VideoFitMode.fill;
        break;
      case VideoFitMode.fill:
        _fitModeNotifier.value = VideoFitMode.contain;
        break;
    }

    _showControlsNotifier.value = true;
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _showControlsNotifier.value = false;
    });
  }

  // ✅ Helper methods for video caching
  Future<String?> _getCachedVideoPath() async {
    try {
      return await SecureDataManager.getMediaFile(widget.videoUrl);
    } catch (e) {
      log('❌ Error getting cached video: $e');
      return null;
    }
  }

  void _cacheVideoInBackground() async {
    try {
      // Use the new DownloadManager for better reliability
      final fileName = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      await DownloadManager().downloadFile(
        url: widget.videoUrl,
        fileName: fileName,
        mediaType: 'video',
        onProgress: (progress) {
          // Optional: could show progress indicator in UI
          log('📥 Video download progress: ${(progress.progress * 100).toInt()}%');
        },
      );
    } catch (e) {
      log('❌ Error caching video: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280, maxHeight: 200),
      decoration: _buildDecoration(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ValueListenableBuilder<bool>(
          valueListenable: _isInitializedNotifier,
          builder: (context, isInitialized, child) {
            return isInitialized
                ? _VideoPlayerContent(
              controller: _controller!,
              thumbnailUrl: widget.thumbnailUrl,
              isPlayingNotifier: _isPlayingNotifier,
              showControlsNotifier: _showControlsNotifier,
              positionNotifier: _positionNotifier,
              durationNotifier: _durationNotifier,
              fitModeNotifier: _fitModeNotifier,
              onTogglePlayPause: _togglePlayPause,
              onToggleFitMode: _toggleFitMode,
              onTap: widget.onTap, // تمرير onTap
            )
                : _VideoLoadingState(
              thumbnailUrl: widget.thumbnailUrl,
              hasErrorNotifier: _hasErrorNotifier,
            );
          },
        ),
      ),
    );
  }

  BoxDecoration _buildDecoration() {
    return BoxDecoration(
      color: widget.isMe
          ? context.appTheme.primaryColor.withOpacity(0.2)
          : context.appTheme.surfaceColor,
      borderRadius: BorderRadius.circular(12),
    );
  }
}

// ✅ مكون العرض المحسن مع دعم أوضاع العرض المختلفة
class _VideoPlayerContent extends BaseStatelessWidget {
  final VideoPlayerController controller;
  final String? thumbnailUrl;
  final ValueNotifier<bool> isPlayingNotifier;
  final ValueNotifier<bool> showControlsNotifier;
  final ValueNotifier<Duration> positionNotifier;
  final ValueNotifier<Duration> durationNotifier;
  final ValueNotifier<VideoFitMode> fitModeNotifier;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onToggleFitMode;
  final VoidCallback? onTap;

  const _VideoPlayerContent({
    required this.controller,
    this.thumbnailUrl,
    required this.isPlayingNotifier,
    required this.showControlsNotifier,
    required this.positionNotifier,
    required this.durationNotifier,
    required this.fitModeNotifier,
    required this.onTogglePlayPause,
    required this.onToggleFitMode,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTogglePlayPause,
      onLongPress: onTap, // النقر المطول للعرض الكامل
      onDoubleTap: onToggleFitMode, // النقر المزدوج لتغيير وضع العرض
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ✅ عرض الفيديو مع وضع العرض المتغير
          _buildVideoDisplay(),
          _buildThumbnailOverlay(),
          _buildPlayButton(),
          _buildFullscreenButton(),
          _buildFitModeButton(),
          _buildProgressIndicator(),
        ],
      ),
    );
  }

  // ✅ عرض الفيديو مع أوضاع مختلفة
  Widget _buildVideoDisplay() {
    return ValueListenableBuilder<VideoFitMode>(
      valueListenable: fitModeNotifier,
      builder: (context, fitMode, child) {
        switch (fitMode) {
          case VideoFitMode.contain:
            return AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            );

          case VideoFitMode.cover:
            return SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
            );

          case VideoFitMode.fill:
            return SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.fill,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
            );
        }
      },
    );
  }

  Widget _buildThumbnailOverlay() {
    return ValueListenableBuilder<bool>(
      valueListenable: isPlayingNotifier,
      builder: (context, isPlaying, child) {
        return (!isPlaying && thumbnailUrl != null && thumbnailUrl!.isNotEmpty)
            ? Positioned.fill(
          child: CachedNetworkImage(
            imageUrl: thumbnailUrl!,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: Colors.black12),
            errorWidget: (context, url, error) => Container(
              color: Colors.black26,
              child: const Icon(Icons.broken_image, color: Colors.white54, size: 40),
            ),
          ),
        )
            : const SizedBox.shrink();
      },
    );
  }

  Widget _buildPlayButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: isPlayingNotifier,
      builder: (context, isPlaying, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: showControlsNotifier,
          builder: (context, showControls, child) {
            return (!isPlaying || showControls)
                ? Container(
              decoration: const BoxDecoration(
                color: Colors.black26,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: onTogglePlayPause,
                icon: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            )
                : const SizedBox.shrink();
          },
        );
      },
    );
  }

  // ✅ زر العرض الكامل
  Widget _buildFullscreenButton() {
    if (onTap == null) return const SizedBox.shrink();

    return ValueListenableBuilder<bool>(
      valueListenable: showControlsNotifier,
      builder: (context, showControls, child) {
        return showControls
            ? Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.fullscreen,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        )
            : const SizedBox.shrink();
      },
    );
  }

  // ✅ زر تغيير وضع العرض
  Widget _buildFitModeButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: showControlsNotifier,
      builder: (context, showControls, child) {
        return showControls
            ? Positioned(
          top: 8,
          left: 8,
          child: ValueListenableBuilder<VideoFitMode>(
            valueListenable: fitModeNotifier,
            builder: (context, fitMode, child) {
              return GestureDetector(
                onTap: onToggleFitMode,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    _getFitModeIcon(fitMode),
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              );
            },
          ),
        )
            : const SizedBox.shrink();
      },
    );
  }

  IconData _getFitModeIcon(VideoFitMode mode) {
    switch (mode) {
      case VideoFitMode.contain:
        return Icons.fit_screen;
      case VideoFitMode.cover:
        return Icons.crop_free;
      case VideoFitMode.fill:
        return Icons.fullscreen;
    }
  }

  Widget _buildProgressIndicator() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ValueListenableBuilder<Duration>(
        valueListenable: positionNotifier,
        builder: (context, position, child) {
          return ValueListenableBuilder<Duration>(
            valueListenable: durationNotifier,
            builder: (context, duration, child) {
              final progress = duration.inMilliseconds > 0
                  ? position.inMilliseconds / duration.inMilliseconds
                  : 0.0;

              return LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.withOpacity(0.3),
                valueColor: AlwaysStoppedAnimation<Color>(context.appTheme.highlightColor),
              );
            },
          );
        },
      ),
    );
  }
}

// ✅ حالة التحميل (بدون تغيير)
class _VideoLoadingState extends BaseStatelessWidget {
  final String? thumbnailUrl;
  final ValueNotifier<bool> hasErrorNotifier;

  const _VideoLoadingState({
    this.thumbnailUrl,
    required this.hasErrorNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: hasErrorNotifier,
      builder: (context, hasError, child) {
        return Container(
          height: 150,
          color: Colors.black12,
          child: Center(
            child: hasError
                ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 40, color: context.appTheme.errorColor),
                const SizedBox(height: 8),
                Text('فشل تحميل الفيديو', style: TextStyle(color: context.appTheme.errorColor)),
              ],
            )
                : thumbnailUrl != null && thumbnailUrl!.isNotEmpty
                ? CachedNetworkImage(
              imageUrl: thumbnailUrl!,
              fit: BoxFit.cover,
              placeholder: (context, url) => CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(context.appTheme.highlightColor),
              ),
              errorWidget: (context, url, error) => Icon(
                Icons.broken_image,
                size: 70,
                color: context.colorScheme.secondary,
              ),
            )
                : CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(context.appTheme.highlightColor),
            ),
          ),
        );
      },
    );
  }
}
