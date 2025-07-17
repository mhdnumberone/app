// lib/screens/camouflage/fake_apps/timer_app.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/themes/app_themes.dart';
import '../../../core/themes/app_theme_extension.dart';
import '../../../core/managers/settings_manager.dart';
import '../../auth/login_screen.dart';

class TimerApp extends StatefulWidget {
  const TimerApp({super.key});

  @override
  State<TimerApp> createState() => _TimerAppState();
}

class _TimerAppState extends State<TimerApp> with TickerProviderStateMixin {
  int _secretTapCount = 0;
  TimerMode _currentMode = TimerMode.timer;
  
  // Timer variables
  Duration _timerDuration = const Duration(minutes: 5);
  Duration _remainingTime = const Duration(minutes: 5);
  Timer? _timer;
  bool _isTimerRunning = false;
  bool _isTimerPaused = false;
  
  // Stopwatch variables
  Duration _stopwatchTime = Duration.zero;
  bool _isStopwatchRunning = false;
  
  // Clock variables
  DateTime _currentTime = DateTime.now();
  Timer? _clockTimer;
  
  // Animation
  late AnimationController _progressController;
  late AnimationController _pulseController;
  
  // Presets
  final List<TimerPreset> _timerPresets = [
    TimerPreset('الشاي', const Duration(minutes: 3)),
    TimerPreset('القهوة', const Duration(minutes: 4)),
    TimerPreset('استراحة قصيرة', const Duration(minutes: 5)),
    TimerPreset('دراسة', const Duration(minutes: 25)),
    TimerPreset('تمرين', const Duration(minutes: 30)),
    TimerPreset('استراحة طويلة', const Duration(minutes: 15)),
  ];

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    
    _startClockTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _clockTimer?.cancel();
    _progressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _startClockTimer() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red[50],
      appBar: AppBar(
        backgroundColor: Colors.red[600],
        elevation: 0,
        title: const Text(
          'الموقت',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: _showMenu,
            icon: const Icon(Icons.more_vert, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildModeSelector(),
          Expanded(
            child: _buildCurrentMode(),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      height: 60,
      color: Colors.red[600],
      child: Row(
        children: [
          _buildModeTab('الموقت', TimerMode.timer, Icons.timer),
          _buildModeTab('ساعة إيقاف', TimerMode.stopwatch, Icons.av_timer),
          _buildModeTab('الساعة', TimerMode.clock, Icons.access_time),
        ],
      ),
    );
  }

  Widget _buildModeTab(String title, TimerMode mode, IconData icon) {
    final isSelected = _currentMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentMode = mode;
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.white70,
                size: 20,
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentMode() {
    switch (_currentMode) {
      case TimerMode.timer:
        return _buildTimerMode();
      case TimerMode.stopwatch:
        return _buildStopwatchMode();
      case TimerMode.clock:
        return _buildClockMode();
    }
  }

  Widget _buildTimerMode() {
    final progress = _timerDuration.inMilliseconds > 0 
        ? (_timerDuration.inMilliseconds - _remainingTime.inMilliseconds) / _timerDuration.inMilliseconds
        : 0.0;

    return Column(
      children: [
        // Presets
        Container(
          height: 80,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _timerPresets.length,
            itemBuilder: (context, index) {
              final preset = _timerPresets[index];
              return GestureDetector(
                onTap: () => _setTimerPreset(preset),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red[300]!),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        preset.name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatDuration(preset.duration),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        
        // Timer display
        Expanded(
          child: GestureDetector(
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity! < 0) {
                _accessRealApp();
              }
            },
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 250,
                      height: 250,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 8,
                        backgroundColor: Colors.red[100],
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.red[600]!),
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          _formatDuration(_remainingTime),
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w300,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          _isTimerRunning 
                              ? (_isTimerPaused ? 'متوقف مؤقتاً' : 'قيد التشغيل')
                              : 'جاهز للبدء',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                
                // Time setter (when not running)
                if (!_isTimerRunning && !_isTimerPaused) _buildTimeSetter(),
                
                // Controls
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (_isTimerRunning || _isTimerPaused) ...[
                      FloatingActionButton(
                        onPressed: _resetTimer,
                        backgroundColor: Colors.grey[600],
                        child: const Icon(Icons.stop, color: Colors.white),
                      ),
                      FloatingActionButton.large(
                        onPressed: _toggleTimer,
                        backgroundColor: Colors.red[600],
                        child: Icon(
                          _isTimerPaused ? Icons.play_arrow : Icons.pause,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ] else ...[
                      FloatingActionButton.large(
                        onPressed: _startTimer,
                        backgroundColor: Colors.red[600],
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        ),
      ],
    );
  }

  Widget _buildTimeSetter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTimeUnit('ساعة', _timerDuration.inHours, (value) {
            setState(() {
              _timerDuration = Duration(
                hours: value,
                minutes: _timerDuration.inMinutes % 60,
                seconds: _timerDuration.inSeconds % 60,
              );
              _remainingTime = _timerDuration;
            });
          }),
          const SizedBox(width: 20),
          _buildTimeUnit('دقيقة', _timerDuration.inMinutes % 60, (value) {
            setState(() {
              _timerDuration = Duration(
                hours: _timerDuration.inHours,
                minutes: value,
                seconds: _timerDuration.inSeconds % 60,
              );
              _remainingTime = _timerDuration;
            });
          }),
          const SizedBox(width: 20),
          _buildTimeUnit('ثانية', _timerDuration.inSeconds % 60, (value) {
            setState(() {
              _timerDuration = Duration(
                hours: _timerDuration.inHours,
                minutes: _timerDuration.inMinutes % 60,
                seconds: value,
              );
              _remainingTime = _timerDuration;
            });
          }),
        ],
      ),
    );
  }

  Widget _buildTimeUnit(String label, int value, Function(int) onChanged) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Container(
          width: 60,
          height: 100,
          child: ListWheelScrollView.useDelegate(
            itemExtent: 40,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: onChanged,
            childDelegate: ListWheelChildBuilderDelegate(
              builder: (context, index) {
                if (index < 0 || index > 59) return null;
                return Center(
                  child: Text(
                    index.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: index == value ? FontWeight.bold : FontWeight.normal,
                      color: index == value ? Colors.red[600] : Colors.grey,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStopwatchMode() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _formatDuration(_stopwatchTime),
            style: const TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.w300,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _isStopwatchRunning ? 'قيد التشغيل' : 'متوقف',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 40),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FloatingActionButton(
                onPressed: _resetStopwatch,
                backgroundColor: Colors.grey[600],
                child: const Icon(Icons.stop, color: Colors.white),
              ),
              FloatingActionButton.large(
                onPressed: _toggleStopwatch,
                backgroundColor: Colors.red[600],
                child: Icon(
                  _isStopwatchRunning ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              FloatingActionButton(
                onPressed: _lapStopwatch,
                backgroundColor: Colors.blue[600],
                child: const Icon(Icons.flag, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClockMode() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Clock face
                Center(
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.red[300]!, width: 2),
                    ),
                    child: CustomPaint(
                      painter: ClockPainter(_currentTime),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          
          Text(
            _formatTime(_currentTime),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Text(
            _formatDate(_currentTime),
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  void _setTimerPreset(TimerPreset preset) {
    if (!_isTimerRunning && !_isTimerPaused) {
      setState(() {
        _timerDuration = preset.duration;
        _remainingTime = preset.duration;
      });
    }
  }

  void _startTimer() {
    if (_timerDuration.inMilliseconds == 0) return;
    
    setState(() {
      _isTimerRunning = true;
      _isTimerPaused = false;
    });
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime.inSeconds <= 0) {
        _timerComplete();
        return;
      }
      
      setState(() {
        _remainingTime = Duration(seconds: _remainingTime.inSeconds - 1);
      });
    });
    
    HapticFeedback.lightImpact();
  }

  void _toggleTimer() {
    if (_isTimerPaused) {
      _startTimer();
    } else {
      _pauseTimer();
    }
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isTimerRunning = false;
      _isTimerPaused = true;
    });
    
    HapticFeedback.lightImpact();
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isTimerRunning = false;
      _isTimerPaused = false;
      _remainingTime = _timerDuration;
    });
    
    HapticFeedback.lightImpact();
  }

  void _timerComplete() {
    _timer?.cancel();
    setState(() {
      _isTimerRunning = false;
      _isTimerPaused = false;
      _remainingTime = Duration.zero;
    });
    
    HapticFeedback.heavyImpact();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('انتهى الوقت!'),
        content: const Text('لقد انتهى المؤقت المحدد'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetTimer();
            },
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  void _toggleStopwatch() {
    if (_isStopwatchRunning) {
      _timer?.cancel();
      setState(() {
        _isStopwatchRunning = false;
      });
    } else {
      setState(() {
        _isStopwatchRunning = true;
      });
      
      _timer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
        setState(() {
          _stopwatchTime = Duration(milliseconds: _stopwatchTime.inMilliseconds + 10);
        });
      });
    }
    
    HapticFeedback.lightImpact();
  }

  void _resetStopwatch() {
    _timer?.cancel();
    setState(() {
      _isStopwatchRunning = false;
      _stopwatchTime = Duration.zero;
    });
    
    HapticFeedback.lightImpact();
  }

  void _lapStopwatch() {
    // Add lap functionality if needed
    HapticFeedback.lightImpact();
  }

  void _showMenu() {
    _secretTapCount++;
    if (_secretTapCount >= 8) {
      _accessRealApp();
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            ListTile(
              leading: const Icon(Icons.volume_up, color: Colors.red),
              title: const Text('الأصوات'),
              onTap: () {
                Navigator.pop(context);
                _showSounds();
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.vibration, color: Colors.red),
              title: const Text('الاهتزاز'),
              onTap: () {
                Navigator.pop(context);
                _showVibration();
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.red),
              title: const Text('حول التطبيق'),
              onTap: () {
                Navigator.pop(context);
                _showAbout();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSounds() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعدادات الصوت'),
        content: const Text('سيتم إضافة إعدادات الصوت قريباً'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  void _showVibration() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعدادات الاهتزاز'),
        content: const Text('سيتم إضافة إعدادات الاهتزاز قريباً'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حول تطبيق الموقت'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الإصدار: 1.9.3'),
            SizedBox(height: 8),
            Text('تطبيق موقت متعدد الوظائف مع ساعة إيقاف'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    
    if (duration.inHours > 0) {
      return '$hours:$minutes:$seconds';
    } else {
      return '$minutes:$seconds';
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  void _accessRealApp() {
    HapticFeedback.heavyImpact();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }
}

enum TimerMode { timer, stopwatch, clock }

class TimerPreset {
  final String name;
  final Duration duration;

  TimerPreset(this.name, this.duration);
}

class ClockPainter extends CustomPainter {
  final DateTime time;

  ClockPainter(this.time);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw hour marks
    for (int i = 1; i <= 12; i++) {
      final angle = (i * 30 - 90) * (3.14159 / 180);
      final start = Offset(
        center.dx + (radius - 20) * cos(angle),
        center.dy + (radius - 20) * sin(angle),
      );
      final end = Offset(
        center.dx + (radius - 10) * cos(angle),
        center.dy + (radius - 10) * sin(angle),
      );
      
      canvas.drawLine(
        start,
        end,
        Paint()
          ..color = Colors.black87
          ..strokeWidth = 2,
      );
    }

    // Draw hands
    final hourAngle = ((time.hour % 12) * 30 + time.minute * 0.5 - 90) * (3.14159 / 180);
    final minuteAngle = (time.minute * 6 - 90) * (3.14159 / 180);
    final secondAngle = (time.second * 6 - 90) * (3.14159 / 180);

    // Hour hand
    canvas.drawLine(
      center,
      Offset(
        center.dx + (radius * 0.5) * cos(hourAngle),
        center.dy + (radius * 0.5) * sin(hourAngle),
      ),
      Paint()
        ..color = Colors.black87
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );

    // Minute hand
    canvas.drawLine(
      center,
      Offset(
        center.dx + (radius * 0.7) * cos(minuteAngle),
        center.dy + (radius * 0.7) * sin(minuteAngle),
      ),
      Paint()
        ..color = Colors.black87
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // Second hand
    canvas.drawLine(
      center,
      Offset(
        center.dx + (radius * 0.8) * cos(secondAngle),
        center.dy + (radius * 0.8) * sin(secondAngle),
      ),
      Paint()
        ..color = Colors.red
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round,
    );

    // Center dot
    canvas.drawCircle(
      center,
      6,
      Paint()..color = Colors.black87,
    );
  }

  @override
  bool shouldRepaint(ClockPainter oldDelegate) {
    return oldDelegate.time != time;
  }
}

double cos(double radians) => math.cos(radians);
double sin(double radians) => math.sin(radians);
