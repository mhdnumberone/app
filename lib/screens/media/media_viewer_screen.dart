// lib/screens/media_viewer_screen.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:photo_view/photo_view.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/themes/app_theme_extension.dart';
import '../../core/widgets/base_widgets.dart';
import '../../core/managers/settings_manager.dart';
import '../../helper/dialogs.dart';
import '../../models/message.dart';

class MediaViewerScreen extends StatefulWidget {
  final String mediaUrl;
  final Type mediaType;
  final bool isLocalFile;
  final String? heroTag;
  final String? fileName;

  const MediaViewerScreen({
    super.key,
    required this.mediaUrl,
    required this.mediaType,
    this.isLocalFile = false,
    this.heroTag,
    this.fileName,
  });

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen>
    with TickerProviderStateMixin {

  // ===== VIDEO CONTROLLER =====
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _hasVideoError = false;

  // ===== UI STATE =====
  bool _showControls = true;
  bool _isFullscreen = false;

  // ===== ANIMATION CONTROLLERS =====
  late AnimationController _controlsAnimationController;
  late Animation<double> _controlsAnimation;
  late AnimationController _fadeAnimationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _enterFullscreen();

    if (widget.mediaType == Type.video) {
      _initializeVideo();
    }

    _startControlsTimer();
  }

  @override
  void dispose() {
    _exitFullscreen();
    _videoController?.dispose();
    _controlsAnimationController.dispose();
    _fadeAnimationController.dispose();
    super.dispose();
  }

  // ===== SETUP METHODS =====

  void _setupAnimations() {
    _controlsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _controlsAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controlsAnimationController,
      curve: Curves.easeInOut,
    ));

    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_fadeAnimationController);

    _controlsAnimationController.forward();
    _fadeAnimationController.forward();
  }

  void _enterFullscreen() {
    // ✅ إظهار أشرطة النظام بشكل دائم مع تمكين التفاعل الكامل
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values, // إظهار جميع أشرطة النظام
    );
    
    // ✅ تخصيص ألوان أشرطة النظام للمحتوى المظلم
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.black54, // خلفية شبه شفافة للشريط العلوي
        statusBarIconBrightness: Brightness.light, // أيقونات فاتحة
        systemNavigationBarColor: Colors.black54, // خلفية شبه شفافة للشريط السفلي
        systemNavigationBarIconBrightness: Brightness.light, // أيقونات فاتحة
      ),
    );
    
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _isFullscreen = true;
  }

  void _exitFullscreen() {
    // ✅ استعادة أشرطة النظام العادية
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    
    // ✅ استعادة ألوان أشرطة النظام الافتراضية
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent, // استعادة الشفافية الافتراضية
        statusBarIconBrightness: Brightness.dark, // أيقونات داكنة للواجهة العادية
        systemNavigationBarColor: Colors.white, // خلفية بيضاء للشريط السفلي
        systemNavigationBarIconBrightness: Brightness.dark, // أيقونات داكنة
      ),
    );
    
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    _isFullscreen = false;
  }

  // ===== VIDEO METHODS =====

  Future<void> _initializeVideo() async {
    try {
      if (widget.isLocalFile || !widget.mediaUrl.startsWith('http')) {
        _videoController = VideoPlayerController.file(File(widget.mediaUrl));
      } else {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.mediaUrl));
      }

      await _videoController!.initialize();

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
          _hasVideoError = false;
        });

        _videoController!.addListener(_handleVideoStateChange);
        _videoController!.play();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasVideoError = true;
          _isVideoInitialized = false;
        });
      }
      debugPrint('Error initializing video: $e');
    }
  }

  void _handleVideoStateChange() {
    if (!mounted || _videoController == null) return;

    if (_videoController!.value.hasError) {
      setState(() {
        _hasVideoError = true;
      });
    }
  }

  void _toggleVideoPlayback() {
    if (_videoController == null || !_isVideoInitialized) return;

    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
      } else {
        _videoController!.play();
      }
    });

    _showControlsTemporarily();
  }

  void _seekVideo(Duration position) {
    _videoController?.seekTo(position);
    _showControlsTemporarily();
  }

  // ===== UI CONTROL METHODS =====

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });

    if (_showControls) {
      _controlsAnimationController.forward();
      _startControlsTimer();
    } else {
      _controlsAnimationController.reverse();
    }
  }

  void _showControlsTemporarily() {
    setState(() {
      _showControls = true;
    });
    _controlsAnimationController.forward();
    _startControlsTimer();
  }

  void _startControlsTimer() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted &&
          _videoController != null &&
          _videoController!.value.isPlaying) {
        setState(() {
          _showControls = false;
        });
        _controlsAnimationController.reverse();
      }
    });
  }

  // ===== MEDIA ACTIONS =====

  Future<void> _saveMedia() async {
    try {
      if (widget.mediaType == Type.image) {
        await _saveImage();
      } else if (widget.mediaType == Type.video) {
        await _saveVideo();
      }

      if (mounted) {
        Dialogs.showSnackbar(context, 'تم حفظ الملف بنجاح');
      }
    } catch (e) {
      if (mounted) {
        Dialogs.showSnackbar(context, 'فشل في حفظ الملف');
      }
    }
  }

  Future<void> _saveImage() async {
    if (widget.isLocalFile || !widget.mediaUrl.startsWith('http')) {
      await Gal.putImage(widget.mediaUrl);
    } else {
      final response = await http.get(Uri.parse(widget.mediaUrl));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final fileName = widget.fileName ?? 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        await Gal.putImage(file.path);
      }
    }
  }

  Future<void> _saveVideo() async {
    if (widget.isLocalFile || !widget.mediaUrl.startsWith('http')) {
      await Gal.putVideo(widget.mediaUrl);
    } else {
      final response = await http.get(Uri.parse(widget.mediaUrl));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final fileName = widget.fileName ?? 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        await Gal.putVideo(file.path);
      }
    }
  }

  Future<void> _shareMedia() async {
    try {
      if (widget.isLocalFile || !widget.mediaUrl.startsWith('http')) {
        await Share.shareXFiles([XFile(widget.mediaUrl)]);
      } else {
        await Share.share(widget.mediaUrl);
      }
    } catch (e) {
      if (mounted) {
        Dialogs.showSnackbar(context, 'فشل في مشاركة الملف');
      }
    }
  }

  // ===== UI BUILDERS =====

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // ✅ دعم زر العودة في Android
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) {
          _exitFullscreen();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ===== MAIN CONTENT =====
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleControls,
                child: widget.mediaType == Type.image
                    ? _buildImageViewer()
                    : _buildVideoViewer(),
              ),
            ),

            // ===== TOP CONTROLS =====
            _buildTopControls(),

            // ===== BOTTOM CONTROLS (VIDEO ONLY) =====
            if (widget.mediaType == Type.video && _isVideoInitialized)
              _buildVideoControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildImageViewer() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: widget.heroTag != null
            ? Hero(
          tag: widget.heroTag!,
          child: _buildPhotoView(),
        )
            : _buildPhotoView(),
      ),
    );
  }

  Widget _buildPhotoView() {
    if (widget.isLocalFile || !widget.mediaUrl.startsWith('http')) {
      return PhotoView(
        imageProvider: FileImage(File(widget.mediaUrl)),
        minScale: PhotoViewComputedScale.contained * 0.5,
        maxScale: PhotoViewComputedScale.covered * 4.0,
        initialScale: PhotoViewComputedScale.contained,
        basePosition: Alignment.center,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        gaplessPlayback: true,
        enableRotation: true,
        filterQuality: FilterQuality.high,
        heroAttributes: widget.heroTag != null
            ? PhotoViewHeroAttributes(tag: widget.heroTag!)
            : null,
        loadingBuilder: (context, event) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        errorBuilder: (context, error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.white, size: 64),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.failedToLoadImage,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
        ),
      );
    } else {
      return PhotoView(
        imageProvider: CachedNetworkImageProvider(widget.mediaUrl),
        minScale: PhotoViewComputedScale.contained * 0.5,
        maxScale: PhotoViewComputedScale.covered * 4.0,
        initialScale: PhotoViewComputedScale.contained,
        basePosition: Alignment.center,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        gaplessPlayback: true,
        enableRotation: true,
        filterQuality: FilterQuality.high,
        heroAttributes: widget.heroTag != null
            ? PhotoViewHeroAttributes(tag: widget.heroTag!)
            : null,
        loadingBuilder: (context, event) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        errorBuilder: (context, error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.white, size: 64),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.failedToLoadImage,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildVideoViewer() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: _buildVideoContent(),
      ),
    );
  }

  Widget _buildVideoContent() {
    if (_hasVideoError) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: Colors.white, size: 64),
            SizedBox(height: 16),
            Text(
              'فشل في تحميل الفيديو',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      );
    }

    if (!_isVideoInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Center(
      child: _buildSmartVideoDisplay(),
    );
  }

  Widget _buildSmartVideoDisplay() {
    final aspectRatio = _videoController!.value.aspectRatio;
    final screenSize = MediaQuery.of(context).size;
    final screenAspectRatio = screenSize.width / screenSize.height;

    // ذكي: اختيار أفضل طريقة عرض حسب نسبة الفيديو
    if (aspectRatio < 0.6) {
      // فيديو رأسي جداً - استخدم cover
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _videoController!.value.size.width,
            height: _videoController!.value.size.height,
            child: VideoPlayer(_videoController!),
          ),
        ),
      );
    } else if (aspectRatio > 0.8 && aspectRatio < 1.2) {
      // فيديو مربع - استخدم cover
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _videoController!.value.size.width,
            height: _videoController!.value.size.height,
            child: VideoPlayer(_videoController!),
          ),
        ),
      );
    } else {
      // نسب عادية - استخدم AspectRatio
      return AspectRatio(
        aspectRatio: aspectRatio,
        child: VideoPlayer(_videoController!),
      );
    }
  }

  Widget _buildTopControls() {
    return AnimatedBuilder(
      animation: _controlsAnimation,
      builder: (context, child) {
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Transform.translate(
            offset: Offset(0, -120 * (1 - _controlsAnimation.value)),
            child: Opacity(
              opacity: _controlsAnimation.value,
              child: Container(
                height: 120, // ✅ زيادة الارتفاع لاستيعاب شريط الحالة
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        // زر العودة
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 16),

                        // العنوان
                        Expanded(
                          child: Text(
                            _getMediaTitle(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        const SizedBox(width: 16),

                        // زر الخيارات
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: _showMediaOptions,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: const Icon(
                                Icons.more_vert,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoControls() {
    return AnimatedBuilder(
      animation: _controlsAnimation,
      builder: (context, child) {
        return Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Transform.translate(
            offset: Offset(0, 150 * (1 - _controlsAnimation.value)),
            child: Opacity(
              opacity: _controlsAnimation.value,
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // شريط التقدم
                      _buildVideoProgressBar(),

                      const SizedBox(height: 20),

                      // أزرار التحكم
                      _buildVideoPlaybackControls(),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoProgressBar() {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(milliseconds: 100)),
      builder: (context, snapshot) {
        if (_videoController == null || !_isVideoInitialized) {
          return const SizedBox.shrink();
        }

        final position = _videoController!.value.position;
        final duration = _videoController!.value.duration;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white.withOpacity(0.3),
                  thumbColor: Colors.white,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                ),
                child: Slider(
                  value: position.inMilliseconds.toDouble(),
                  max: duration.inMilliseconds.toDouble(),
                  onChanged: (value) {
                    _seekVideo(Duration(milliseconds: value.toInt()));
                  },
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(position),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    Text(
                      _formatDuration(duration),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVideoPlaybackControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // زر الترجيع
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () {
              final currentPosition = _videoController!.value.position;
              final newPosition = currentPosition - const Duration(seconds: 10);
              _seekVideo(newPosition.isNegative ? Duration.zero : newPosition);
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              child: const Icon(
                Icons.replay_10,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ),

        const SizedBox(width: 20),

        // زر التشغيل/الإيقاف
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(32),
            onTap: _toggleVideoPlayback,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2),
              ),
              child: Icon(
                _videoController!.value.isPlaying
                    ? Icons.pause
                    : Icons.play_arrow,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
        ),

        const SizedBox(width: 20),

        // زر التقديم
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () {
              final currentPosition = _videoController!.value.position;
              final duration = _videoController!.value.duration;
              final newPosition = currentPosition + const Duration(seconds: 10);
              _seekVideo(newPosition > duration ? duration : newPosition);
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              child: const Icon(
                Icons.forward_10,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===== HELPER METHODS =====

  String _getMediaTitle() {
    if (widget.fileName != null && widget.fileName!.isNotEmpty) {
      return widget.fileName!;
    }

    switch (widget.mediaType) {
      case Type.image:
        return 'صورة';
      case Type.video:
        return 'فيديو';
      default:
        return 'ملف وسائط';
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    } else {
      return '$minutes:$seconds';
    }
  }

  void _showMediaOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // مؤشر السحب
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 16),

            // خيار الحفظ
            _MediaOption(
              icon: Icons.download_rounded,
              title: 'حفظ',
              subtitle: widget.mediaType == Type.image
                  ? 'حفظ الصورة في المعرض'
                  : 'حفظ الفيديو في المعرض',
              onTap: () {
                Navigator.pop(context);
                _saveMedia();
              },
            ),

            // خيار المشاركة
            _MediaOption(
              icon: Icons.share_rounded,
              title: 'مشاركة',
              subtitle: 'مشاركة الملف مع التطبيقات الأخرى',
              onTap: () {
                Navigator.pop(context);
                _shareMedia();
              },
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ===== HELPER WIDGETS =====

class _MediaOption extends BaseStatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MediaOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = context.appTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: appColors.highlightColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: appColors.highlightColor,
                  size: 24,
                ),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[600],
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
