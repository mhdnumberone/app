import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../core/themes/app_theme_extension.dart';
import '../core/widgets/base_widgets.dart';

class AudioRecorderWidget extends BaseStatefulWidget {
  final Function(String audioPath, int duration) onRecordComplete;
  final VoidCallback onCancel;

  const AudioRecorderWidget({
    super.key,
    required this.onRecordComplete,
    required this.onCancel,
  });

  @override
  State<AudioRecorderWidget> createState() => _AudioRecorderWidgetState();
}

class _AudioRecorderWidgetState extends BaseState<AudioRecorderWidget>
    with TickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();

  // ✅ استخدام ValueNotifier بدلاً من setState
  final ValueNotifier<bool> _isRecordingNotifier = ValueNotifier(false);
  final ValueNotifier<int> _recordDurationNotifier = ValueNotifier(0);
  final ValueNotifier<bool> _hasErrorNotifier = ValueNotifier(false);

  late AnimationController _pulseController;
  late AnimationController _waveController;
  String? _audioPath;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _isRecordingNotifier.dispose();
    _recordDurationNotifier.dispose();
    _hasErrorNotifier.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
  }

  Future<void> _startRecording() async {
    final permission = await Permission.microphone.request();
    if (permission != PermissionStatus.granted) {
      _hasErrorNotifier.value = true;
      widget.onCancel();
      return;
    }

    try {
      if (await _recorder.hasPermission()) {
        final Directory tempDir = await getTemporaryDirectory();
        final String filePath =
            '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: filePath,
        );

        // ✅ استخدام ValueNotifier
        _isRecordingNotifier.value = true;
        _audioPath = filePath;
        _recordDurationNotifier.value = 0;
        _hasErrorNotifier.value = false;

        _pulseController.repeat(reverse: true);
        _waveController.repeat(reverse: true);
        _startTimer();
      } else {
        _hasErrorNotifier.value = true;
        widget.onCancel();
      }
    } catch (e) {
      _hasErrorNotifier.value = true;
      widget.onCancel();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isRecordingNotifier.value) {
        // ✅ لا setState - فقط تحديث ValueNotifier
        _recordDurationNotifier.value++;
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _stopRecording() async {
    if (_isRecordingNotifier.value) {
      _timer?.cancel();
      final path = await _recorder.stop();
      _isRecordingNotifier.value = false;
      _pulseController.stop();
      _waveController.stop();

      if (path != null && _recordDurationNotifier.value > 0) {
        widget.onRecordComplete(path, _recordDurationNotifier.value);
      } else {
        widget.onCancel();
      }
    }
  }

  Future<void> _cancelRecording() async {
    if (_isRecordingNotifier.value) {
      _timer?.cancel();
      await _recorder.stop();
      _isRecordingNotifier.value = false;
      _pulseController.stop();
      _waveController.stop();

      if (_audioPath != null) {
        final file = File(_audioPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    }
    widget.onCancel();
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _CancelButton(onPressed: _cancelRecording),
          _RecordingIndicator(
            pulseController: _pulseController,
            hasErrorNotifier: _hasErrorNotifier,
          ),
          const SizedBox(width: 16),
          _DurationDisplay(durationNotifier: _recordDurationNotifier),
          const Spacer(),
          _WaveAnimation(
            waveController: _waveController,
            isRecordingNotifier: _isRecordingNotifier,
          ),
          const Spacer(),
          _SendButton(onPressed: _stopRecording),
        ],
      ),
    );
  }
}

// ✅ مكونات منفصلة للأداء المحسن
class _CancelButton extends BaseStatelessWidget {
  final VoidCallback onPressed;

  const _CancelButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: const Icon(Icons.close),
      color: context.appTheme.errorColor,
    );
  }
}

class _RecordingIndicator extends BaseStatelessWidget {
  final AnimationController pulseController;
  final ValueNotifier<bool> hasErrorNotifier;

  const _RecordingIndicator({
    required this.pulseController,
    required this.hasErrorNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: hasErrorNotifier,
      builder: (context, hasError, child) {
        return AnimatedBuilder(
          animation: pulseController,
          builder: (context, child) {
            return Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: (hasError ? Colors.grey : context.appTheme.errorColor).withOpacity(
                  0.3 + 0.7 * pulseController.value,
                ),
                shape: BoxShape.circle,
              ),
            );
          },
        );
      },
    );
  }
}

class _DurationDisplay extends BaseStatelessWidget {
  final ValueNotifier<int> durationNotifier;

  const _DurationDisplay({required this.durationNotifier});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: durationNotifier,
      builder: (context, duration, child) {
        return Text(
          _formatDuration(duration),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        );
      },
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}

class _WaveAnimation extends BaseStatelessWidget {
  final AnimationController waveController;
  final ValueNotifier<bool> isRecordingNotifier;

  const _WaveAnimation({
    required this.waveController,
    required this.isRecordingNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isRecordingNotifier,
      builder: (context, isRecording, child) {
        return AnimatedBuilder(
          animation: waveController,
          builder: (context, child) {
            return Row(
              children: List.generate(5, (index) {
                final baseHeight = 4.0;
                final maxHeight = 20.0;
                final animationOffset = (index * 0.2) % 1.0;
                final animationValue = (waveController.value + animationOffset) % 1.0;
                final height = baseHeight +
                    (maxHeight - baseHeight) *
                        (0.5 + 0.5 * (1 - (animationValue - 0.5).abs() * 2));

                return Container(
                  width: 3,
                  height: height,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: isRecording ? context.appTheme.highlightColor : Colors.grey,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                );
              }),
            );
          },
        );
      },
    );
  }
}

class _SendButton extends BaseStatelessWidget {
  final VoidCallback onPressed;

  const _SendButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: context.appTheme.successColor,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.send,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}
