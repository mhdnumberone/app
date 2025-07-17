// المسار: lib/screens/decoy_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/themes/app_theme_extension.dart';
import '../../core/widgets/base_widgets.dart';
import '../../main.dart';
import '../auth/login_screen.dart';

class DecoyScreen extends BaseStatefulWidget {
  const DecoyScreen({super.key});

  @override
  State<DecoyScreen> createState() => _DecoyScreenState();
}

class _DecoyScreenState extends BaseState<DecoyScreen> {
  double _progressValue = 0.0;
  String _statusMessage = "جاري تهيئة النظام...";
  bool _systemCheckComplete = false;
  int _tapCount = 0;
  Timer? _progressTimer;
  bool _initialized = false;

  // رسائل محاكاة التحديث
  final List<String> _updateMessages = [
    "التحقق من وجود تحديثات...",
    "تنزيل حزمة التحديث الأساسية (25%)...",
    "تنزيل حزمة التحديث الأساسية (75%)...",
    "تثبيت مكونات النظام...",
    "تحميل وحدات الأمان...",
    "التحقق من سلامة المكونات...",
    "تحسين أداء التطبيقات...",
    "إعادة تشغيل الخدمات الأساسية...",
    "تنظيف الملفات المؤقتة...",
    "فحص النظام الأساسي مكتمل.",
  ];
  int _currentMessageIndex = 0;

  @override
  void initState() {
    super.initState();
    _startSystemCheckAnimation();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize localized status message when context is available
    if (!_initialized) {
      try {
        final localizations = AppLocalizations.of(context);
        if (localizations != null && mounted) {
          setState(() {
            _statusMessage = localizations.initializingSystem;
          });
        }
        _initialized = true;
      } catch (e) {
        // Keep the default message if localization fails
        _initialized = true;
      }
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  void _startSystemCheckAnimation() {
    _progressTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_progressValue < 1.0) {
          _progressValue += 0.1; // زيادة تدريجية أكثر لمحاكاة واقعية
          if (_progressValue > 1.0) _progressValue = 1.0;

          // تحديث رسالة الحالة بناءً على التقدم
          if (_currentMessageIndex < _updateMessages.length - 1) {
            // تغيير الرسالة بشكل متناسب مع التقدم التقريبي
            int messageToShowIndex =
            (_progressValue * (_updateMessages.length - 1)).floor();
            if (messageToShowIndex > _currentMessageIndex) {
              _currentMessageIndex = messageToShowIndex;
            }
            _statusMessage = _updateMessages[_currentMessageIndex];
          } else {
            _statusMessage = _updateMessages.last;
          }
        } else {
          _progressValue = 1.0;
          _statusMessage = _updateMessages.last; // "فحص النظام الأساسي مكتمل."
          _systemCheckComplete = true;
          timer.cancel();
          // Optionally, navigate automatically after completion
          // Navigator.pushReplacement(
          //   context,
          //   MaterialPageRoute(builder: (_) => const LoginScreen()),
          // );
        }
      });
    });
  }

  void _handleTap() {
    if (_systemCheckComplete) {
      setState(() {
        _tapCount++;
        // You might still want to keep the tap count for navigation logic
        if (_tapCount >= 5) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // التأكد من تهيئة mq بشكل آمن
    try {
      mq = MediaQuery.sizeOf(context);
    } catch (e) {
      // Fallback values if MediaQuery fails
      mq = const Size(400, 800);
    }
    final ThemeData theme = Theme.of(context);
    final AppThemeExtension appColors = context.appTheme;
    final TextTheme textTheme = theme.textTheme;

    return GestureDetector(
      onTap: _handleTap,
      child: Scaffold(
        backgroundColor: appColors.backgroundColor, // استخدام لون خلفية الثيم
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                // شعار التطبيق أو أيقونة تحديث
                Container(
                  width: mq.width * .25,
                  height: mq.width * .25,
                  child: Image.asset(
                    'assets/images/icon.png',
                    width: mq.width * .25,
                    height: mq.width * .25,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: mq.width * .25,
                        height: mq.width * .25,
                        decoration: BoxDecoration(
                          color: appColors.primaryColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.android,
                          size: mq.width * .15,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: mq.height * .05),

                Text(
                  AppLocalizations.of(context)?.systemUpdateInProgress ?? 'تحديث النظام قيد التقدم',
                  style: textTheme.headlineSmall?.copyWith(
                    color: appColors.textPrimaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: mq.height * .02),

                Text(
                  _statusMessage,
                  style: textTheme.titleMedium?.copyWith(
                    color: appColors.textSecondaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: mq.height * .03),

                LinearProgressIndicator(
                  value: _progressValue,
                  backgroundColor: appColors.primaryLight.withOpacity(0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    appColors.highlightColor,
                  ),
                  minHeight: 6, // زيادة سمك شريط التقدم
                ),
                SizedBox(height: mq.height * .01),
                Text(
                  '${(_progressValue * 100).toInt()}%',
                  style: textTheme.bodyMedium?.copyWith(
                    color: appColors.textPrimaryColor,
                  ),
                ),

                SizedBox(height: mq.height * .05),

                if (_systemCheckComplete)
                  AnimatedOpacity(
                    opacity: _systemCheckComplete ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 500),
                    child: Column(
                      children: [
                        Text(
                          'اكتمل التحديث بنجاح.',
                          style: textTheme.titleMedium?.copyWith(
                            color: appColors.successColor,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        // Removed the "Tap to continue" and "Remaining taps" messages
                      ],
                    ),
                  ),
                if (!_systemCheckComplete)
                  Text(
                    'يرجى إبقاء التطبيق مفتوحًا وعدم إغلاقه.',
                    style: textTheme.bodySmall?.copyWith(
                      color: appColors.textSecondaryColor.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}