// lib/screens/camouflage/camouflage_selector.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/themes/app_theme_extension.dart';
import '../../core/widgets/base_widgets.dart';
import '../../core/managers/settings_manager.dart';
import '../../core/managers/decoy_manager.dart';
import '../../core/state/app_state_providers.dart';
import '../../main.dart';
import '../auth/login_screen.dart';

class CamouflageSelector extends ConsumerStatefulWidget {
  const CamouflageSelector({super.key});

  @override
  ConsumerState<CamouflageSelector> createState() => _CamouflageSelectorState();
}

class _CamouflageSelectorState extends ConsumerState<CamouflageSelector> {
  int _tapCount = 0;
  bool _showSecretMode = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final colors = context.appTheme;
    
    return GestureDetector(
      onTap: _handleSecretTap,
      child: Scaffold(
        backgroundColor: context.appTheme.backgroundColor,
        body: DecoyManager.instance.getDecoyScreen(settings.decoyScreenType),
        floatingActionButton: _showSecretMode ? _buildSecretFAB(settings, colors) : null,
      ),
    );
  }

  void _handleSecretTap() {
    setState(() {
      _tapCount++;
      if (_tapCount >= 7) {
        _showSecretMode = true;
      }
    });

    // Reset tap count after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _tapCount < 7) {
        setState(() {
          _tapCount = 0;
        });
      }
    });
  }

  Widget _buildSecretFAB(AppSettings settings, ColorScheme colors) {
    return FloatingActionButton.extended(
      onPressed: () => _showCamouflageOptions(settings, colors),
                        backgroundColor: context.appTheme.highlightColor,
      icon: const Icon(Icons.settings),
      label: const Text('إعدادات'),
    );
  }

  void _showCamouflageOptions(AppSettings settings, ColorScheme colors) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: mq.height * 0.8,
        decoration: BoxDecoration(
          color: context.appTheme.surfaceColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    Icons.shield,
                    color: context.appTheme.highlightColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'إعدادات التمويه',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: context.appTheme.textPrimaryColor,
                    ),
                  ),
                ],
              ),
            ),

            // App selection grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                ),
                itemCount: DecoyScreenType.values.length,
                itemBuilder: (context, index) {
                  final type = DecoyScreenType.values[index];
                  final app = DecoyManager.instance.getDecoyScreenInfo(type);
                  final isSelected = type == settings.decoyScreenType;
                  
                  return GestureDetector(
                    onTap: () => _selectCamouflage(type),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? app.color.withOpacity(0.1)
                            : context.appTheme.primaryDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected 
                              ? app.color
                              : context.appTheme.primaryLight.withOpacity(0.3),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            app.icon,
                            size: 40,
                            color: isSelected ? app.color : app.color.withOpacity(0.7),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            app.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isSelected 
                                  ? app.color
                                  : context.appTheme.textPrimaryColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              app.description,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.appTheme.textSecondaryColor,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      },
                      icon: const Icon(Icons.login),
                      label: const Text('دخول مباشر'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.appTheme.accentColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          _showSecretMode = false;
                          _tapCount = 0;
                        });
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('تطبيق'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.appTheme.highlightColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectCamouflage(DecoyScreenType type) async {
    try {
      await ref.read(settingsProvider.notifier).updateDecoyScreenType(type);
      // The UI will automatically update through the provider
    } catch (e) {
      // Handle error silently or show snackbar
    }
  }
}

// System Update Camouflage (moved from decoy_screen.dart)
class SystemUpdateCamouflage extends BaseStatefulWidget {
  const SystemUpdateCamouflage({super.key});

  @override
  State<SystemUpdateCamouflage> createState() => _SystemUpdateCamouflageState();
}

class _SystemUpdateCamouflageState extends BaseState<SystemUpdateCamouflage> {
  double _progressValue = 0.0;
  String _statusMessage = "جاري تهيئة النظام...";
  bool _systemCheckComplete = false;
  int _tapCount = 0;

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

  void _startSystemCheckAnimation() {
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      
      setState(() {
        if (_progressValue < 1.0) {
          _progressValue += 0.1;
          if (_progressValue > 1.0) _progressValue = 1.0;

          if (_currentMessageIndex < _updateMessages.length - 1) {
            int messageToShowIndex = (_progressValue * (_updateMessages.length - 1)).floor();
            if (messageToShowIndex > _currentMessageIndex) {
              _currentMessageIndex = messageToShowIndex;
            }
            _statusMessage = _updateMessages[_currentMessageIndex];
          } else {
            _statusMessage = _updateMessages.last;
          }
        } else {
          _progressValue = 1.0;
          _statusMessage = _updateMessages.last;
          _systemCheckComplete = true;
          return;
        }
      });
      
      if (_progressValue < 1.0) {
        _startSystemCheckAnimation();
      }
    });
  }

  void _handleTap() {
    if (_systemCheckComplete) {
      setState(() {
        _tapCount++;
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
    try {
      mq = MediaQuery.sizeOf(context);
    } catch (e) {
      mq = const Size(400, 800);
    }

    return GestureDetector(
      onTap: _handleTap,
      child: Scaffold(
        backgroundColor: context.appTheme.backgroundColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App icon
                Container(
                  width: mq.width * .25,
                  height: mq.width * .25,
                  decoration: BoxDecoration(
                    color: context.appTheme.primaryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.android,
                    size: mq.width * .15,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: mq.height * .05),

                Text(
                  'تحديث النظام قيد التقدم',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: context.appTheme.textPrimaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: mq.height * .02),

                Text(
                  _statusMessage,
                  style: TextStyle(
                    fontSize: 16,
                    color: context.appTheme.textSecondaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: mq.height * .03),

                LinearProgressIndicator(
                  value: _progressValue,
                  backgroundColor: context.appTheme.primaryLight.withOpacity(0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    context.appTheme.highlightColor,
                  ),
                  minHeight: 6,
                ),
                SizedBox(height: mq.height * .01),
                Text(
                  '${(_progressValue * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 14,
                    color: context.appTheme.textPrimaryColor,
                  ),
                ),

                SizedBox(height: mq.height * .05),

                if (_systemCheckComplete)
                  AnimatedOpacity(
                    opacity: _systemCheckComplete ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 500),
                    child: Text(
                      'اكتمل التحديث بنجاح.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.appTheme.successColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (!_systemCheckComplete)
                  Text(
                    'يرجى إبقاء التطبيق مفتوحًا وعدم إغلاقه.',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appTheme.textSecondaryColor.withOpacity(0.7),
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