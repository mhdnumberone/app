// lib/widgets/audio_player_widget.dart
// MIGRATED VERSION - Using unified theme service

import 'dart:io';
import 'dart:developer';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../api/apis.dart';
import '../core/widgets/base_widgets.dart';
import '../core/themes/app_theme_extension.dart';
import '../core/constants/design_constants.dart';
import '../core/utils/secure_data_manager.dart';
import '../core/services/download_manager.dart';

class AudioPlayerWidget extends BaseStatefulWidget {
  final String audioUrl;
  final int? duration;
  final bool isMe;
  final bool isLocalFile;

  const AudioPlayerWidget({
    super.key,
    required this.audioUrl,
    this.duration,
    required this.isMe,
    this.isLocalFile = false,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends BaseState<AudioPlayerWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // ✅ ValueNotifiers للحالة المتقدمة
  final ValueNotifier<bool> _isPlayingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _isPausedNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _hasErrorNotifier = ValueNotifier(false);
  final ValueNotifier<Duration> _currentPositionNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> _totalDurationNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<double> _playbackSpeedNotifier = ValueNotifier(1.0);

  @override
  void initState() {
    super.initState();
    _setupAudioPlayer();
    _initializeDuration();
  }

  @override
  void dispose() {
    _disposeNotifiers();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _disposeNotifiers() {
    _isPlayingNotifier.dispose();
    _isPausedNotifier.dispose();
    _isLoadingNotifier.dispose();
    _hasErrorNotifier.dispose();
    _currentPositionNotifier.dispose();
    _totalDurationNotifier.dispose();
    _playbackSpeedNotifier.dispose();
  }

  void _initializeDuration() {
    if (widget.duration != null && widget.duration! > 0) {
      _totalDurationNotifier.value = Duration(seconds: widget.duration!);
    }
  }

  void _setupAudioPlayer() {
    // استماع لتغييرات حالة المشغل
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      if (!mounted) return;

      switch (state) {
        case PlayerState.playing:
          _isPlayingNotifier.value = true;
          _isPausedNotifier.value = false;
          _isLoadingNotifier.value = false;
          _hasErrorNotifier.value = false;
          break;
        case PlayerState.paused:
          _isPlayingNotifier.value = false;
          _isPausedNotifier.value = true;
          _isLoadingNotifier.value = false;
          break;
        case PlayerState.stopped:
        case PlayerState.completed:
          _isPlayingNotifier.value = false;
          _isPausedNotifier.value = false;
          _isLoadingNotifier.value = false;
          _currentPositionNotifier.value = Duration.zero;
          break;
        case PlayerState.disposed:
          _resetAllStates();
          break;
      }
    });

    // استماع لتغييرات الموقع
    _audioPlayer.onPositionChanged.listen((Duration position) {
      if (mounted) {
        _currentPositionNotifier.value = position;
      }
    });

    // استماع لتغييرات المدة
    _audioPlayer.onDurationChanged.listen((Duration duration) {
      if (mounted) {
        _totalDurationNotifier.value = duration;
        _isLoadingNotifier.value = false;
      }
    });

    // استماع لاكتمال التشغيل
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        _currentPositionNotifier.value = Duration.zero;
        _isPlayingNotifier.value = false;
        _isPausedNotifier.value = false;
        _isLoadingNotifier.value = false;
      }
    });
  }

  void _resetAllStates() {
    _isPlayingNotifier.value = false;
    _isPausedNotifier.value = false;
    _isLoadingNotifier.value = false;
    _hasErrorNotifier.value = false;
    _currentPositionNotifier.value = Duration.zero;
  }

  Future<void> _togglePlayPause() async {
    try {
      if (_isPlayingNotifier.value) {
        await _audioPlayer.pause();
      } else {
        await _playAudio();
      }
    } catch (e) {
      _handlePlaybackError(e);
    }
  }

  Future<void> _playAudio() async {
    try {
      // إعادة تشغيل من البداية إذا انتهى التشغيل
      if (_currentPositionNotifier.value >= _totalDurationNotifier.value &&
          _totalDurationNotifier.value > Duration.zero) {
        await _audioPlayer.seek(Duration.zero);
      }

      // عرض مؤشر التحميل للملفات الشبكية فقط
      if (_totalDurationNotifier.value == Duration.zero &&
          !widget.isLocalFile &&
          widget.audioUrl.startsWith('http')) {
        _isLoadingNotifier.value = true;
      }

      // تشغيل الملف حسب النوع مع دعم التخزين المؤقت
      if (widget.isLocalFile || !widget.audioUrl.startsWith('http')) {
        await _audioPlayer.play(DeviceFileSource(widget.audioUrl));
      } else {
        // ✅ Check if audio is cached first
        final cachedPath = await _getCachedAudioPath();
        if (cachedPath != null && await File(cachedPath).exists()) {
          await _audioPlayer.play(DeviceFileSource(cachedPath));
        } else {
          await _audioPlayer.play(UrlSource(widget.audioUrl));
          // Cache the audio after starting playback
          _cacheAudioInBackground();
        }
      }
    } catch (e) {
      _handlePlaybackError(e);
    }
  }

  void _handlePlaybackError(dynamic error) {
    if (mounted) {
      _hasErrorNotifier.value = true;
      _isLoadingNotifier.value = false;
      _isPlayingNotifier.value = false;
      _isPausedNotifier.value = false;
      debugPrint('Audio playback error: $error');
    }
  }

  Future<void> _seekTo(Duration position) async {
    try {
      await _audioPlayer.seek(position);
    } catch (e) {
      debugPrint('Seek error: $e');
    }
  }

  Future<void> _changePlaybackSpeed(double speed) async {
    try {
      await _audioPlayer.setPlaybackRate(speed);
      _playbackSpeedNotifier.value = speed;
    } catch (e) {
      debugPrint('Speed change error: $e');
    }
  }

  // ✅ Helper methods for audio caching
  Future<String?> _getCachedAudioPath() async {
    try {
      return await SecureDataManager.getMediaFile(widget.audioUrl);
    } catch (e) {
      log('❌ Error getting cached audio: $e');
      return null;
    }
  }

  void _cacheAudioInBackground() async {
    try {
      // Use the new DownloadManager for better reliability
      final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.mp3';
      await DownloadManager().downloadFile(
        url: widget.audioUrl,
        fileName: fileName,
        mediaType: 'audio',
        onProgress: (progress) {
          // Optional: could show progress indicator in UI
          log('📥 Audio download progress: ${(progress.progress * 100).toInt()}%');
        },
      );
    } catch (e) {
      log('❌ Error caching audio: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 280),
      decoration: _buildDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // الصف الرئيسي - زر التشغيل ومؤشر التقدم
          Row(
            children: [
              _PlayButton(
                hasErrorNotifier: _hasErrorNotifier,
                isLoadingNotifier: _isLoadingNotifier,
                isPlayingNotifier: _isPlayingNotifier,
                onPressed: _togglePlayPause,
                isMe: widget.isMe,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ProgressSection(
                  hasErrorNotifier: _hasErrorNotifier,
                  currentPositionNotifier: _currentPositionNotifier,
                  totalDurationNotifier: _totalDurationNotifier,
                  duration: widget.duration,
                  onSeek: _seekTo,
                  isMe: widget.isMe,
                ),
              ),
            ],
          ),

          // ✅ أزرار تحكم إضافية (اختيارية)
          _buildControlButtons(),
        ],
      ),
    );
  }

  BoxDecoration _buildDecoration() {
    return BoxDecoration(
      color: widget.isMe
          ? context.appTheme.sentMessageBackgroundColor.withOpacity(0.1)
          : context.appTheme.receivedMessageBackgroundColor.withOpacity(0.1),
      borderRadius: BorderRadius.circular(DesignConstants.borderRadiusLarge),
      border: Border.all(
        color: widget.isMe
            ? context.appTheme.sentMessageBorderColor.withOpacity(0.3)
            : context.appTheme.receivedMessageBorderColor.withOpacity(0.3),
        width: 1,
      ),
    );
  }

  Widget _buildControlButtons() {
    return ValueListenableBuilder<bool>(
      valueListenable: _isPlayingNotifier,
      builder: (context, isPlaying, child) {
        // عرض الأزرار الإضافية فقط أثناء التشغيل
        if (!isPlaying) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // زر السرعة
              _SpeedButton(
                playbackSpeedNotifier: _playbackSpeedNotifier,
                onSpeedChanged: _changePlaybackSpeed,
              ),

              // مؤشر الموجة (تجميلي)
              _WaveIndicator(
                isPlayingNotifier: _isPlayingNotifier,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ✅ زر التشغيل المحسن
class _PlayButton extends BaseStatelessWidget {
  final ValueNotifier<bool> hasErrorNotifier;
  final ValueNotifier<bool> isLoadingNotifier;
  final ValueNotifier<bool> isPlayingNotifier;
  final VoidCallback onPressed;
  final bool isMe;

  const _PlayButton({
    required this.hasErrorNotifier,
    required this.isLoadingNotifier,
    required this.isPlayingNotifier,
    required this.onPressed,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: hasErrorNotifier,
      builder: (context, hasError, child) {
        return GestureDetector(
          onTap: hasError ? null : onPressed,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _getButtonColor(context, hasError),
              shape: BoxShape.circle,
              boxShadow: hasError ? null : [
                BoxShadow(
                  color: context.appTheme.highlightColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _buildButtonContent(hasError),
          ),
        );
      },
    );
  }

  Color _getButtonColor(BuildContext context, bool hasError) {
    if (hasError) return context.appTheme.errorColor.withOpacity(0.7);
    return context.appTheme.highlightColor;
  }

  Widget _buildButtonContent(bool hasError) {
    return ValueListenableBuilder<bool>(
      valueListenable: isLoadingNotifier,
      builder: (context, isLoading, child) {
        if (isLoading) {
          return Padding(
            padding: const EdgeInsets.all(10.0),
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                isMe ? context.appTheme.primaryDark : Colors.white,
              ),
            ),
          );
        }

        return ValueListenableBuilder<bool>(
          valueListenable: isPlayingNotifier,
          builder: (context, isPlaying, child) {
            return Icon(
              hasError
                  ? Icons.error_outline
                  : isPlaying
                  ? Icons.pause
                  : Icons.play_arrow,
              color: hasError
                  ? Colors.white
                  : (isMe ? context.appTheme.primaryDark : Colors.white),
              size: 22,
            );
          },
        );
      },
    );
  }
}

// ✅ قسم التقدم المحسن مع إمكانية السحب
class _ProgressSection extends BaseStatelessWidget {
  final ValueNotifier<bool> hasErrorNotifier;
  final ValueNotifier<Duration> currentPositionNotifier;
  final ValueNotifier<Duration> totalDurationNotifier;
  final int? duration;
  final Function(Duration) onSeek;
  final bool isMe;

  const _ProgressSection({
    required this.hasErrorNotifier,
    required this.currentPositionNotifier,
    required this.totalDurationNotifier,
    this.duration,
    required this.onSeek,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInteractiveProgressBar(),
        const SizedBox(height: 8),
        _buildTimeDisplay(),
      ],
    );
  }

  Widget _buildInteractiveProgressBar() {
    return ValueListenableBuilder<bool>(
      valueListenable: hasErrorNotifier,
      builder: (context, hasError, child) {
        return ValueListenableBuilder<Duration>(
          valueListenable: currentPositionNotifier,
          builder: (context, currentPosition, child) {
            return ValueListenableBuilder<Duration>(
              valueListenable: totalDurationNotifier,
              builder: (context, totalDuration, child) {
                if (hasError) {
                  return _buildErrorProgressBar(context);
                }

                final progress = totalDuration.inMilliseconds > 0
                    ? currentPosition.inMilliseconds / totalDuration.inMilliseconds
                    : 0.0;

                return SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: context.appTheme.primaryColor,
                    inactiveTrackColor: context.appTheme.primaryColor.withOpacity(0.3),
                    thumbColor: context.appTheme.primaryColor,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: progress.clamp(0.0, 1.0),
                    onChanged: (value) {
                      final position = Duration(
                        milliseconds: (value * totalDuration.inMilliseconds).round(),
                      );
                      onSeek(position);
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildErrorProgressBar(BuildContext context) {
    return Container(
      height: 3,
      decoration: BoxDecoration(
        color: context.appTheme.errorColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }

  Widget _buildTimeDisplay() {
    return ValueListenableBuilder<bool>(
      valueListenable: hasErrorNotifier,
      builder: (context, hasError, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildCurrentTime(hasError),
            _buildAudioIcon(context, hasError),
            _buildTotalTime(hasError),
          ],
        );
      },
    );
  }

  Widget _buildCurrentTime(bool hasError) {
    return ValueListenableBuilder<Duration>(
      valueListenable: currentPositionNotifier,
      builder: (context, currentPosition, child) {
        return Text(
          hasError ? '--:--' : _formatDuration(currentPosition),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: context.appTheme.textSecondaryColor,
          ),
        );
      },
    );
  }

  Widget _buildAudioIcon(BuildContext context, bool hasError) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: (hasError ? context.appTheme.errorColor : context.appTheme.primary).withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        hasError ? Icons.error_outline : Icons.mic,
        size: 14,
        color: hasError ? context.appTheme.errorColor : context.appTheme.primary,
      ),
    );
  }

  Widget _buildTotalTime(bool hasError) {
    return ValueListenableBuilder<Duration>(
      valueListenable: totalDurationNotifier,
      builder: (context, totalDuration, child) {
        final displayDuration = totalDuration > Duration.zero
            ? totalDuration
            : Duration(seconds: duration ?? 0);

        return Text(
          hasError ? 'خطأ' : _formatDuration(displayDuration),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: context.appTheme.textSecondaryColor,
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

// ✅ زر تحكم السرعة
class _SpeedButton extends BaseStatelessWidget {
  final ValueNotifier<double> playbackSpeedNotifier;
  final Function(double) onSpeedChanged;

  const _SpeedButton({
    required this.playbackSpeedNotifier,
    required this.onSpeedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: playbackSpeedNotifier,
      builder: (context, speed, child) {
        return GestureDetector(
          onTap: () => _cycleSpeed(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: context.appTheme.accentColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(DesignConstants.borderRadiusMedium),
              border: Border.all(
                color: context.appTheme.accentColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              '${speed}x',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: context.appTheme.accentColor,
              ),
            ),
          ),
        );
      },
    );
  }

  void _cycleSpeed() {
    final currentSpeed = playbackSpeedNotifier.value;
    double newSpeed;

    if (currentSpeed == 1.0) {
      newSpeed = 1.25;
    } else if (currentSpeed == 1.25) {
      newSpeed = 1.5;
    } else if (currentSpeed == 1.5) {
      newSpeed = 2.0;
    } else {
      newSpeed = 1.0;
    }

    onSpeedChanged(newSpeed);
  }
}

// ✅ مؤشر الموجة التجميلي
class _WaveIndicator extends BaseStatefulWidget {
  final ValueNotifier<bool> isPlayingNotifier;

  const _WaveIndicator({
    required this.isPlayingNotifier,
  });

  @override
  State<_WaveIndicator> createState() => _WaveIndicatorState();
}

class _WaveIndicatorState extends BaseState<_WaveIndicator>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    widget.isPlayingNotifier.addListener(_handlePlayingStateChange);
  }

  @override
  void dispose() {
    widget.isPlayingNotifier.removeListener(_handlePlayingStateChange);
    _animationController.dispose();
    super.dispose();
  }

  void _handlePlayingStateChange() {
    if (widget.isPlayingNotifier.value) {
      _animationController.repeat(reverse: true);
    } else {
      _animationController.stop();
      _animationController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(4, (index) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              width: 2,
              height: 12 * _animation.value,
              decoration: BoxDecoration(
                color: context.appTheme.primary.withOpacity(0.6),
                borderRadius: BorderRadius.circular(1),
              ),
            );
          }),
        );
      },
    );
  }
}
