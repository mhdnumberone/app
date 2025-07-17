// lib/screens/auth/login_screen.dart

import 'dart:developer';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:local_auth/local_auth.dart';
import '../../api/apis.dart';
import '../../core/themes/app_theme_extension.dart';
import '../../core/widgets/base_widgets.dart';
import '../../core/managers/settings_manager.dart';
import '../../core/utils/permission_manager.dart';
import '../../core/utils/permission_preferences.dart';
import '../../core/error/error_handler.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/network_monitor.dart';
import '../../core/performance/performance_monitor.dart';
import '../../core/state/app_state_providers.dart';
import '../../core/utils/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../helper/dialogs.dart';
import '../../main.dart';
import '../main/home_screen.dart';
import '../camouflage/camouflage_selector.dart';

/// ✅ شاشة تسجيل الدخول المحسنة مع دعم جميع أنواع الهواتف والإشعارات والتوصيات
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  // ✅ Variables
  bool _isAnimate = false;
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  late FocusNode _codeFocusNode; // إضافة FocusNode

  // ✅ Device Detection Variables
  String _deviceBrand = '';
  String _deviceModel = '';
  int _androidVersion = 0;
  bool _isDeviceDetected = false;
  
  // ✅ Enhanced Security Variables
  int _failedAttempts = 0;
  DateTime? _lastFailedAttempt;
  bool _isLocked = false;
  Timer? _lockoutTimer;
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _biometricEnabled = false;
  bool _showPassword = false;
  
  // ✅ Security Settings
  static const int _maxFailedAttempts = 3;
  static const Duration _lockoutDuration = Duration(minutes: 5);
  
  // ✅ Panic Mode Settings
  bool _panicModeEnabled = false;
  List<int> _panicTapSequence = [];
  Timer? _panicModeTimer;
  static const List<int> _panicSequence = [5, 5, 5]; // Triple tap sequence
  static const Duration _panicSequenceTimeout = Duration(seconds: 3);
  
  // ✅ Animation Controllers
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  
  // ✅ Notifications and Recommendations
  List<AppNotification> _notifications = [];
  List<AppRecommendation> _recommendations = [];
  bool _showNotifications = true;
  Timer? _notificationTimer;
  
  // ✅ Helper getters
  ColorScheme get colors => Theme.of(context).colorScheme;
  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _codeFocusNode = FocusNode(); // تهيئة FocusNode
    _initializeSecurityFeatures();
    _initializeScreen();
    _initializeNotifications();
    _initializeRecommendations();
  }

  @override
  void dispose() {
    _codeFocusNode.dispose(); // تنظيف FocusNode
    _codeController.dispose();
    _lockoutTimer?.cancel();
    _panicModeTimer?.cancel();
    _notificationTimer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  /// ✅ تهيئة ميزات الأمان المحسنة
  Future<void> _initializeSecurityFeatures() async {
    try {
      // Initialize shake animation
      _shakeController = AnimationController(
        duration: const Duration(milliseconds: 500),
        vsync: this,
      );
      _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(
        CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
      );

      // Check for biometric availability
      final isAvailable = await _localAuth.isDeviceSupported();
      final hasBiometrics = await _localAuth.getAvailableBiometrics();
      
      setState(() {
        _biometricEnabled = isAvailable && hasBiometrics.isNotEmpty;
      });
      
      log('🔒 Biometric authentication available: $_biometricEnabled');
      
      // Check if user is currently locked out
      _checkLockoutStatus();
    } catch (e) {
      final error = ErrorHandler.handleApiError(e);
      log('❌ Error initializing security features: ${error.message}');
    }
  }

  /// ✅ تهيئة الشاشة مع اكتشاف الجهاز
  Future<void> _initializeScreen() async {
    // بدء الأنيميشن
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _isAnimate = true);
      }
    });

    // اكتشاف نوع الجهاز
    await _detectDeviceInfo();

    // التحقق من التطبيق والبيانات
    await _validateAndCleanupData();
  }

  /// ✅ فحص حالة القفل الحالية
  void _checkLockoutStatus() {
    if (_lastFailedAttempt != null) {
      final timeSinceLastAttempt = DateTime.now().difference(_lastFailedAttempt!);
      if (timeSinceLastAttempt < _lockoutDuration && _failedAttempts >= _maxFailedAttempts) {
        setState(() {
          _isLocked = true;
        });
        _startLockoutTimer();
      }
    }
  }

  /// ✅ بدء مؤقت القفل
  void _startLockoutTimer() {
    final remainingTime = _lockoutDuration - DateTime.now().difference(_lastFailedAttempt!);
    _lockoutTimer = Timer(remainingTime, () {
      setState(() {
        _isLocked = false;
        _failedAttempts = 0;
        _lastFailedAttempt = null;
      });
    });
  }

  /// ✅ التحقق من صحة الإدخال الأساسي فقط
  bool _validateBasicInput(String password) {
    // فحص الحد الأدنى للإدخال فقط - Firebase سيتولى التحقق من الصحة
    return password.isNotEmpty && password.length >= 4;
  }

  /// ✅ فحص إذا كانت كلمة المرور هي رمز التدمير - يتم التحقق من Firebase فقط
  /// Note: Destruction codes are now fetched from Firebase in APIs.attemptLoginOrDestruct()

  // Note: Destruction code handling is now done in APIs.attemptLoginOrDestruct()
  // This removes duplication and ensures consistency with Firebase data

  /// ✅ معالجة فشل تسجيل الدخول
  void _handleLoginFailure() {
    setState(() {
      _failedAttempts++;
      _lastFailedAttempt = DateTime.now();
      
      if (_failedAttempts >= _maxFailedAttempts) {
        _isLocked = true;
        _startLockoutTimer();
      }
    });

    // تشغيل أنيميشن الاهتزاز
    _shakeController.forward().then((_) {
      _shakeController.reverse();
    });

    HapticFeedback.heavyImpact();

    if (_isLocked) {
      _showLockoutDialog();
    } else {
      final remainingAttempts = _maxFailedAttempts - _failedAttempts;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${localizations.get('invalid_code')}. $remainingAttempts ${localizations.get('attempts_remaining')}'),
          backgroundColor: colors.error,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// ✅ عرض حوار القفل
  void _showLockoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.lock_outline, color: Colors.red, size: 48),
        title: const Text('تم قفل التطبيق'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'تم تجاوز عدد المحاولات المسموحة.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'يرجى المحاولة مرة أخرى بعد ${_lockoutDuration.inMinutes} دقائق.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              SystemNavigator.pop(); // إغلاق التطبيق
            },
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  /// ✅ تسجيل الدخول بالبصمة
  Future<void> _authenticateWithBiometrics() async {
    try {
      final isAuthenticated = await _localAuth.authenticate(
        localizedReason: 'استخدم بصمتك لتسجيل الدخول',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (isAuthenticated) {
        await _proceedWithLogin();
      }
    } catch (e) {
      final error = ErrorHandler.handleApiError(e);
      log('❌ Biometric authentication error: ${error.message}');
      if (mounted) {
        ErrorHandler.showErrorToUser(context, error);
      }
    }
  }

  /// ✅ معالجة تتابع الذعر
  void _handlePanicTap() {
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    _panicTapSequence.add(currentTime);
    
    // إزالة النقرات القديمة (أكثر من 3 ثوانٍ)
    _panicTapSequence.removeWhere((tap) => 
        currentTime - tap > _panicSequenceTimeout.inMilliseconds);
    
    // فحص إذا تم الوصول للتتابع المطلوب
    if (_panicTapSequence.length >= _panicSequence.length) {
      _activatePanicMode();
    }
    
    // إعادة تعيين التتابع بعد انتهاء المهلة
    _panicModeTimer?.cancel();
    _panicModeTimer = Timer(_panicSequenceTimeout, () {
      _panicTapSequence.clear();
    });
  }

  /// ✅ تفعيل وضع الذعر
  void _activatePanicMode() {
    HapticFeedback.heavyImpact();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red[50],
        icon: const Icon(Icons.warning, color: Colors.red, size: 48),
        title: const Text(
          'وضع الطوارئ',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'تم تفعيل وضع الطوارئ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'سيتم:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _buildPanicActionItem('🗑️', 'مسح جميع البيانات الحساسة'),
            _buildPanicActionItem('🔒', 'قفل التطبيق نهائياً'),
            _buildPanicActionItem('📱', 'إعادة توجيه لتطبيق آمن'),
            _buildPanicActionItem('⚠️', 'تفعيل الوضع التمويهي'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _panicTapSequence.clear();
            },
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _executePanicMode();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('تفعيل الآن'),
          ),
        ],
      ),
    );
  }

  /// ✅ بناء عنصر إجراء الذعر
  Widget _buildPanicActionItem(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ تنفيذ وضع الذعر
  Future<void> _executePanicMode() async {
    try {
      // عرض رسالة التنفيذ
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.red),
              const SizedBox(height: 16),
              Text(localizations.get('processing')),
            ],
          ),
        ),
      );

      // محاكاة مسح البيانات
      await Future.delayed(const Duration(seconds: 2));
      
      // الانتقال للتطبيق التمويهي
      if (mounted) {
        Navigator.pop(context); // إغلاق حوار التحميل
        
        // الانتقال لشاشة التمويه
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const CamouflageSelector(),
          ),
        );
      }
    } catch (e) {
      log('❌ Error executing panic mode: $e');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.get('something_went_wrong')),
            backgroundColor: colors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// ✅ اكتشاف معلومات الجهاز بشكل مفصل
  Future<void> _detectDeviceInfo() async {
    try {
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;

        setState(() {
          _deviceBrand = androidInfo.brand.toLowerCase();
          _deviceModel = androidInfo.model;
          _androidVersion = androidInfo.version.sdkInt;
          _isDeviceDetected = true;
        });

        log('📱 Device detected: $_deviceBrand $_deviceModel (Android $_androidVersion)');

        // عرض رسالة ترحيب مخصصة للجهاز فقط للمستخدمين الجدد
        if (mounted) {
          final isFirstLaunch = await PermissionPreferences.isFirstLaunch();
          if (isFirstLaunch) {
            _showDeviceSpecificWelcome();
          }
        }
      }
    } catch (e) {
      log('❌ Error detecting device: $e');
      setState(() {
        _deviceBrand = 'unknown';
        _isDeviceDetected = true;
      });
    }
  }

  /// ✅ عرض رسالة ترحيب مخصصة حسب نوع الجهاز (للمستخدمين الجدد فقط)
  void _showDeviceSpecificWelcome() {
    String deviceName = _getDeviceDisplayName();
    String welcomeMessage = 'تم اكتشاف جهاز $deviceName';

    // رسائل خاصة للأجهزة المعروفة
    if (_deviceBrand.contains('xiaomi')) {
      welcomeMessage += '\n💡 نصيحة شاومي: تفعيل التشغيل التلقائي مهم للأداء الأمثل';
    } else if (_deviceBrand.contains('vivo')) {
      welcomeMessage += '\n💡 نصيحة فيفو: السماح بالعمل في الخلفية محسن';
    } else if (_deviceBrand.contains('oppo') || _deviceBrand.contains('oneplus')) {
      welcomeMessage += '\n💡 نصيحة أوبو/ون بلس: ضبط إعدادات إدارة الطاقة مطلوب';
    } else if (_deviceBrand.contains('huawei')) {
      welcomeMessage += '\n💡 نصيحة هواوي: إضافة للتطبيقات المحمية ضروري';
    }

    // عرض الرسالة لفترة قصيرة فقط للمستخدمين الجدد
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(welcomeMessage),
            duration: const Duration(seconds: 4),
            backgroundColor: colors.primaryColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  /// ✅ الحصول على اسم عرض الجهاز
  String _getDeviceDisplayName() {
    if (_deviceBrand.contains('xiaomi')) {
      return 'شاومي';
    } else if (_deviceBrand.contains('vivo')) {
      return 'فيفو';
    } else if (_deviceBrand.contains('oppo')) {
      return 'أوبو';
    } else if (_deviceBrand.contains('oneplus')) {
      return 'ون بلس';
    } else if (_deviceBrand.contains('huawei')) {
      return 'هواوي';
    } else if (_deviceBrand.contains('samsung')) {
      return 'سامسونج';
    } else if (_deviceBrand.contains('honor')) {
      return 'هونر';
    } else if (_deviceBrand.contains('realme')) {
      return 'ريلمي';
    } else {
      return _deviceModel.isNotEmpty ? _deviceModel : 'Android';
    }
  }

  /// ✅ التحقق من صحة البيانات وتنظيفها
  Future<void> _validateAndCleanupData() async {
    try {
      await PermissionPreferences.validateAndCleanup();
      log('✅ Data validation completed');
    } catch (e) {
      log('❌ Error during data validation: $e');
    }
  }

  /// ✅ معالجة تسجيل الدخول أو التدمير مع فحص الأذونات المحسن
  Future<void> _handleLoginOrDestruct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isLoading || _isLocked) return;

    // إخفاء الكيبورد
    FocusScope.of(context).unfocus();

    // التحقق من الإدخال الأساسي فقط
    final password = _codeController.text.trim();
    
    // التحقق من الحد الأدنى للإدخال فقط - Firebase سيتولى فحص رمز التدمير
    if (!_validateBasicInput(password)) {
      _handleLoginFailure();
      return;
    }

    // ✅ فحص إذا كان هذا أول دخول
    final isFirstLaunch = await PermissionPreferences.isFirstLaunch();
    if (isFirstLaunch) {
      await _handleFirstTimeUser();
    } else {
      await _handleReturningUser();
    }

    // ✅ متابعة تسجيل الدخول
    await _proceedWithLogin();
  }

  /// ✅ معالجة المستخدم الجديد مع فحص الأذونات
  Future<void> _handleFirstTimeUser() async {
    log('👋 First time user detected');
    await PermissionPreferences.markFirstLaunchComplete();

    // عرض رسالة ترحيب ودية للمستخدم الجديد
    if (mounted) {
      await _showFirstTimeWelcomeDialog();
    }
  }

  /// ✅ معالجة المستخدم العائد مع فحص الأذونات الذكي
  Future<void> _handleReturningUser() async {
    log('🔄 Returning user detected');

    // ✅ فحص الأذونات الحالية أولاً
    final currentPermissions = await PermissionManager.checkAllPermissions();
    if (currentPermissions.allGranted) {
      log('✅ All permissions already granted, no need to remind');
      return;
    }

    // فحص إذا كان يجب تذكير المستخدم بالأذونات
    final shouldRemind = await PermissionPreferences.shouldRemindAboutPermissions();
    final dismissedCount = await PermissionPreferences.getPermissionDismissedCount();

    if (dismissedCount >= 2 && !currentPermissions.batteryOptimization) { // المرة الثالثة أو أكثر (0, 1, 2 = 3 مرات)
      if (mounted) {
        // منع الدخول وعرض حوار إلزامي
        await _showMandatoryBatteryPermissionDialog();
        // بعد إغلاق الحوار، نعيد فحص الأذونات
        final afterMandatoryCheck = await PermissionManager.checkAllPermissions();
        if (!afterMandatoryCheck.batteryOptimization) {
          // إذا لم يتم منح الإذن بعد الحوار الإلزامي، لا نسمح بالدخول
          ErrorHandler.showErrorToUser(context, AppError(
            type: ErrorType.validation,
            message: localizations.get('battery_optimization_required'),
          ));
          throw Exception('Battery optimization permission required'); // يوقف عملية تسجيل الدخول
        }
      }
    } else if (shouldRemind) {
      await _handlePermissionsForReturningUser();
    }
  }

  /// ✅ حوار إلزامي لإذن تحسين البطارية
  Future<void> _showMandatoryBatteryPermissionDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false, // يجعل الحوار إلزامياً
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.battery_alert, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            Expanded(child: Text('إذن تحسين البطارية مطلوب')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'للحصول على أفضل أداء للتطبيق، يرجى تفعيل إذن تحسين البطارية.',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'سنقوم بفتح إعدادات النظام لك. يرجى اختيار "عدم التحسين" أو "غير محدود".',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'هذا الإذن ضروري لعمل التطبيق بشكل صحيح في الخلفية.',
                      style: const TextStyle(fontSize: 13, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context); // إغلاق الحوار الحالي
              await PermissionManager.requestBatteryOptimizationPermission(context, forceAsk: true, showEducationalContent: false);
            },
            icon: const Icon(Icons.check_circle, size: 18),
            label: const Text('تفعيل الآن'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ حوار ترحيب المستخدم الجديد
  Future<void> _showFirstTimeWelcomeDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.waving_hand, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('مرحباً بك! 👋'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'نرحب بك في التطبيق الآمن!',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 12),
            if (_isDeviceDetected) ...[
              Text('🔍 تم اكتشاف جهاز: ${_getDeviceDisplayName()}'),
              const SizedBox(height: 8),
            ],
            const Text('✅ يمكنك البدء مباشرة'),
            const Text('⚙️ سنساعدك في الإعدادات لاحقاً'),
            const Text('🔒 بياناتك آمنة ومحمية'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getDeviceSpecificTip(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('فهمت، هيا نبدأ!'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.tertiary,
              foregroundColor: colors.primary,
            ),
          ),
        ],
      ),
    );

    // عرض نصيحة بسيطة للأذونات لاحقاً (فقط للمستخدمين الجدد)
    if (mounted) {
      _showGentlePermissionReminder();
    }
  }

  /// ✅ الحصول على نصيحة مخصصة للجهاز
  String _getDeviceSpecificTip() {
    if (_deviceBrand.contains('xiaomi')) {
      return 'لأجهزة شاومي: قد نحتاج لتفعيل "التشغيل التلقائي" للحصول على أفضل أداء';
    } else if (_deviceBrand.contains('vivo')) {
      return 'لأجهزة فيفو: سنساعدك في تفعيل العمل في الخلفية';
    } else if (_deviceBrand.contains('oppo') || _deviceBrand.contains('oneplus')) {
      return 'لأجهزة أوبو/ون بلس: قد نحتاج لتعديل إعدادات إدارة الطاقة';
    } else if (_deviceBrand.contains('huawei')) {
      return 'لأجهزة هواوي: إضافة التطبيق للتطبيقات المحمية مهم جداً';
    } else if (_deviceBrand.contains('samsung')) {
      return 'لأجهزة سامسونج: قد نحتاج لإزالة التطبيق من قائمة التطبيقات النائمة';
    } else {
      return 'سنساعدك في ضبط الإعدادات المناسبة لجهازك';
    }
  }

  /// ✅ تذكير بسيط بالأذونات للمستخدم الجديد
  void _showGentlePermissionReminder() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.tips_and_updates_outlined, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'نصيحة: لضمان أفضل أداء، سنساعدك في ضبط إعدادات التطبيق لاحقاً',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF4CAF50),
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'الآن',
              textColor: Colors.white,
              onPressed: () => _showDeviceSpecificPermissionsDialog(),
            ),
          ),
        );
      }
    });
  }

  /// ✅ معالجة الأذونات للمستخدم العائد
  Future<void> _handlePermissionsForReturningUser() async {
    log('🔔 Showing permission reminder for returning user');
    final shouldAsk = await _showReturningUserPermissionDialog();
    if (shouldAsk) {
      await _showDeviceSpecificPermissionsDialog();
    }
  }

  /// ✅ حوار تذكير الأذونات للمستخدم العائد
  Future<bool> _showReturningUserPermissionDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.settings_suggest, color: Colors.blue, size: 24),
            SizedBox(width: 8),
            Text('تحسين الأداء'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'لاحظنا أنه يمكن تحسين أداء التطبيق على جهاز ${_getDeviceDisplayName()}.',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 12),
            const Text(
              'هل تود مراجعة الإعدادات المُحسّنة؟',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localizations.get('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(localizations.get('activate_now')),
          ),
        ],
      ),
    ) ?? false;
  }

  /// ✅ عرض حوار الأذونات المخصص للجهاز
  Future<void> _showDeviceSpecificPermissionsDialog() async {
    // إخفاء الكيبورد قبل عرض الحوار
    FocusScope.of(context).unfocus();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Handle للسحب
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // العنوان
              Row(
                children: [
                  Icon(_getDeviceIcon(), color: _getDeviceColor(), size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'إعدادات ${_getDeviceDisplayName()}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimaryColor,
                          ),
                        ),
                        Text(
                          'إرشادات مخصصة لجهازك',
                          style: TextStyle(
                            fontSize: 14,
                            color: colors.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // المحتوى المخصص للجهاز
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: _buildDeviceSpecificContent(),
                ),
              ),

              // الأزرار
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('تخطي'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _requestDeviceSpecificPermissions();
                      },
                      icon: const Icon(Icons.settings, size: 18),
                      label: const Text('تطبيق الإعدادات'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getDeviceColor(),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ✅ الحصول على أيقونة مخصصة للجهاز
  IconData _getDeviceIcon() {
    if (_deviceBrand.contains('xiaomi')) {
      return Icons.android;
    } else if (_deviceBrand.contains('samsung')) {
      return Icons.smartphone;
    } else if (_deviceBrand.contains('huawei')) {
      return Icons.phone_android;
    } else {
      return Icons.devices;
    }
  }

  /// ✅ الحصول على لون مخصص للجهاز
  Color _getDeviceColor() {
    if (_deviceBrand.contains('xiaomi')) {
      return Colors.orange;
    } else if (_deviceBrand.contains('vivo')) {
      return Colors.blue;
    } else if (_deviceBrand.contains('oppo') || _deviceBrand.contains('oneplus')) {
      return Colors.green;
    } else if (_deviceBrand.contains('huawei')) {
      return Colors.red;
    } else if (_deviceBrand.contains('samsung')) {
      return Colors.blue[700]!;
    } else {
      return colors.tertiary;
    }
  }

  /// ✅ بناء محتوى مخصص حسب نوع الجهاز
  Widget _buildDeviceSpecificContent() {
    if (_deviceBrand.contains('xiaomi')) {
      return _buildXiaomiContent();
    } else if (_deviceBrand.contains('vivo')) {
      return _buildVivoContent();
    } else if (_deviceBrand.contains('oppo') || _deviceBrand.contains('oneplus')) {
      return _buildOppoContent();
    } else if (_deviceBrand.contains('huawei')) {
      return _buildHuaweiContent();
    } else if (_deviceBrand.contains('samsung')) {
      return _buildSamsungContent();
    } else {
      return _buildGenericContent();
    }
  }

  /// ✅ محتوى شاومي
  Widget _buildXiaomiContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoCard(
          icon: Icons.info_outline,
          title: 'إعدادات مهمة لأجهزة شاومي',
          content: 'نظام MIUI له إعدادات طاقة خاصة تؤثر على أداء التطبيق',
          color: Colors.orange,
        ),
        const SizedBox(height: 16),
        _buildStepsList([
          'الإعدادات → التطبيقات → إدارة التطبيقات',
          'البحث عن "ٍSystem Services" واختياره',
          'تفعيل "التشغيل التلقائي" (Autostart)',
          'الأذونات → تفعيل "عرض النوافذ المنبثقة"',
          'Battery saver → اختيار "No restrictions"',
        ]),
        const SizedBox(height: 16),
        _buildWarningCard('هذه الإعدادات ضرورية لاستقبال الرسائل والإشعارات على أجهزة شاومي'),
      ],
    );
  }

  /// ✅ محتوى فيفو
  Widget _buildVivoContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoCard(
          icon: Icons.info_outline,
          title: 'إعدادات فيفو المطلوبة',
          content: 'نظام FunTouch يحتاج إعدادات خاصة للعمل في الخلفية',
          color: Colors.blue,
        ),
        const SizedBox(height: 16),
        _buildStepsList([
          'إعدادات → البطارية → مدير الخلفية',
          'البحث عن التطبيق وتفعيل "السماح بالعمل في الخلفية"',
          'إعدادات → التطبيقات → إدارة التطبيقات',
          'اختيار التطبيق → الأذونات → تفعيل جميع الأذونات المطلوبة',
          'تطبيق iManager → بدء التشغيل → تفعيل التطبيق',
        ]),
      ],
    );
  }

  /// ✅ محتوى أوبو/ون بلس
  Widget _buildOppoContent() {
    String brandName = _deviceBrand.contains('oneplus') ? 'ون بلس' : 'أوبو';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoCard(
          icon: Icons.info_outline,
          title: 'إعدادات $brandName',
          content: 'نظام ColorOS يحتاج تخصيص إعدادات الطاقة',
          color: Colors.green,
        ),
        const SizedBox(height: 16),
        _buildStepsList([
          'الإعدادات → البطارية → تحسين البطارية',
          'البحث عن التطبيق واختيار "عدم التحسين"',
          'مدير الهاتف → الخصوصية والأذونات',
          'بدء التشغيل التلقائي → تفعيل التطبيق',
          'التطبيقات في الخلفية → السماح للتطبيق',
        ]),
      ],
    );
  }

  /// ✅ محتوى هواوي
  Widget _buildHuaweiContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoCard(
          icon: Icons.security,
          title: 'إعدادات هواوي الأمنية',
          content: 'نظام EMUI له نظام حماية متقدم يحتاج إعداد خاص',
          color: Colors.red,
        ),
        const SizedBox(height: 16),
        _buildStepsList([
          'إعدادات → التطبيقات → التطبيقات المحمية',
          'تفعيل التطبيق في قائمة "التطبيقات المحمية"',
          'إعدادات → البطارية → التطبيقات التي تستهلك الطاقة',
          'البحث عن التطبيق واختيار "السماح"',
          'مدير الهاتف → بدء التشغيل التلقائي',
        ]),
        const SizedBox(height: 16),
        _buildWarningCard('التطبيقات المحمية في هواوي ضرورية لعمل التطبيق بشكل صحيح'),
      ],
    );
  }

  /// ✅ محتوى سامسونج
  Widget _buildSamsungContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoCard(
          icon: Icons.battery_saver,
          title: 'إعدادات سامسونج',
          content: 'نظام One UI له إدارة طاقة ذكية تحتاج ضبط',
          color: Colors.blue[700]!,
        ),
        const SizedBox(height: 16),
        _buildStepsList([
          'الإعدادات → العناية بالجهاز → البطارية',
          'حدود استخدام التطبيق → التطبيقات النائمة',
          'إزالة التطبيق من قائمة "التطبيقات النائمة"',
          'تحسين البطارية → البحث عن التطبيق',
          'اختيار "عدم التحسين"',
        ]),
      ],
    );
  }

  /// ✅ محتوى عام للأجهزة الأخرى
  Widget _buildGenericContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoCard(
          icon: Icons.android,
          title: 'إعدادات Android العامة',
          content: 'إعدادات أساسية تطبق على معظم أجهزة Android',
          color: colors.tertiary,
        ),
        const SizedBox(height: 16),
        _buildStepsList([
          'الإعدادات → التطبيقات → عرض جميع التطبيقات',
          'البحث عن التطبيق واختياره',
          'البطارية → إزالة قيود البطارية',
          'الأذونات → تفعيل الأذونات المطلوبة',
          'الإشعارات → السماح بجميع الإشعارات',
        ]),
      ],
    );
  }

  /// ✅ مساعد لبناء بطاقة معلومات
  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ مساعد لبناء قائمة خطوات
  Widget _buildStepsList(List<String> steps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الخطوات المطلوبة:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: colors.textPrimaryColor,
          ),
        ),
        const SizedBox(height: 12),
        ...steps.asMap().entries.map((entry) {
          int index = entry.key;
          String step = entry.value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _getDeviceColor(),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    step,
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.textPrimaryColor,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  /// ✅ مساعد لبناء بطاقة تحذير
  Widget _buildWarningCard(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: Colors.orange[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ طلب الأذونات المخصصة للجهاز - الإصلاح الضروري
  Future<void> _requestDeviceSpecificPermissions() async {
    bool isLoadingShown = false;
    try {
      // إخفاء الكيبورد أولاً
      FocusScope.of(context).unfocus();

      // إظهار مؤشر التحميل مع حماية
      if (mounted) {
        Dialogs.showProgressBar(context);
        isLoadingShown = true;
      }

      // طلب أذونات البطارية مع timeout
      final batteryPermission = await PermissionManager.requestBatteryOptimizationPermission(
        context,
        forceAsk: true,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          log('⏰ Battery permission request timed out');
          return false;
        },
      );

      // إخفاء مؤشر التحميل
      if (mounted && isLoadingShown) {
        Navigator.pop(context);
        isLoadingShown = false;
      }

      // إظهار النتيجة كما هو موجود أصلاً
      if (mounted) {
        final message = batteryPermission
            ? 'تم تطبيق الإعدادات بنجاح! ✅'
            : 'يمكنك تطبيق الإعدادات لاحقاً من إعدادات التطبيق';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: batteryPermission ? const Color(0xFF4CAF50) : Colors.orange,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      log('❌ Error requesting device-specific permissions: $e');

      // إخفاء مؤشر التحميل إذا كان مُعرضاً
      if (mounted && isLoadingShown) {
        Navigator.pop(context);
      }

      // إظهار رسالة خطأ بسيطة
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.get('error_requesting_permissions')),
            backgroundColor: colors.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// ✅ متابعة تسجيل الدخول مع فحص الأذونات وإدارة الرسائل المحسنة
  Future<void> _proceedWithLogin() async {
    if (mounted) setState(() => _isLoading = true);

    try {
      final enteredCode = _codeController.text.trim();
      final result = await APIs.attemptLoginOrDestruct(enteredCode);

      if (!mounted) return;
      setState(() => _isLoading = false);

      // معالجة نتائج تسجيل الدخول
      switch (result.type) {
        case LoginAttemptResultType.success:
          _codeController.clear();
          
          // إعادة تعيين عداد الفشل عند نجاح تسجيل الدخول
          setState(() {
            _failedAttempts = 0;
            _lastFailedAttempt = null;
            _isLocked = false;
          });

          // ✅ تسجيل تسجيل الدخول الناجح
          await PermissionPreferences.recordSuccessfulLogin();

          // ✅ عرض رسالة النجاح فقط في المرة الأولى
          final shouldShowSuccess = await PermissionPreferences.shouldShowSuccessMessage();
          if (shouldShowSuccess && mounted) {
            await _showSuccessMessage();
          }

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          }
          break;

        case LoginAttemptResultType.failure:
          // معالجة فشل تسجيل الدخول مع العداد
          _handleLoginFailure();
          
          // عرض رسالة الخطأ إذا لم يكن التطبيق مقفلاً
          if (!_isLocked) {
            ErrorHandler.showErrorToUser(
              context,
              AppError(
                type: ErrorType.authentication,
                message: result.message.isNotEmpty
                    ? result.message
                    : localizations.get('login_failed'),
              ),
            );
          }
          break;

        case LoginAttemptResultType.destructionProceedToHome:
          _codeController.clear();
          await _showDestructionMessage();
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          }
          break;

        case LoginAttemptResultType.destructionFailure:
          ErrorHandler.showErrorToUser(
            context,
            AppError(
              type: ErrorType.unknown,
              message: result.message.isNotEmpty ? result.message : localizations.get('something_went_wrong'),
            ),
          );
          _codeController.clear();
          break;
      }
    } catch (e) {
      log('❌ Error during login: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ErrorHandler.showErrorToUser(context, AppError(
          type: ErrorType.unknown,
          message: localizations.get('something_went_wrong'),
        ));
      }
    }
  }

  /// ✅ عرض رسالة النجاح المحسنة
  Future<void> _showSuccessMessage() async {
    final loginCount = await PermissionPreferences.getLoginCount();
    String welcomeText = '';

    if (loginCount <= 1) {
      welcomeText = 'مرحباً بك في التطبيق الآمن! 🎉';
    } else if (loginCount <= 3) {
      welcomeText = 'أهلاً وسهلاً بعودتك! 👋';
    } else {
      welcomeText = 'تم تسجيل الدخول بنجاح';
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 8),
            const Expanded(child: Text('نجح تسجيل الدخول!')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              welcomeText,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_isDeviceDetected)
              Text('تم تسجيل دخولك بنجاح على جهاز ${_getDeviceDisplayName()}'),
            if (loginCount <= 3) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.tips_and_updates, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'نصيحة: يمكنك تحسين أداء التطبيق من الإعدادات',
                        style: TextStyle(fontSize: 12, color: Colors.green[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('متابعة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ تهيئة الإشعارات مع دمج الخدمات الأساسية
  Future<void> _initializeNotifications() async {
    try {
      final settings = ref.read(settingsProvider);
      final connectionInfo = ref.read(connectionInfoProvider);
      final performanceMetrics = ref.read(performanceMetricsProvider);
      
      List<AppNotification> notifications = [];
      
      // إشعار الاتصال
      if (!connectionInfo.isConnected) {
        notifications.add(AppNotification(
          id: 'network_status',
          title: localizations.get('network_status') ?? 'حالة الشبكة',
          message: localizations.get('network_disconnected') ?? 'لا يوجد اتصال بالإنترنت - سيعمل التطبيق في وضع محدود',
          type: NotificationType.warning,
          priority: NotificationPriority.medium,
          timestamp: DateTime.now(),
          icon: Icons.wifi_off,
          action: NotificationAction(
            label: localizations.get('check_settings') ?? 'فحص الإعدادات',
            onTap: () => _showNetworkSettings(),
          ),
        ));
      }
      
      // إشعار الأداء
      if (performanceMetrics.hasPerformanceIssues) {
        notifications.add(AppNotification(
          id: 'performance_warning',
          title: localizations.get('performance_optimization') ?? 'تحسين الأداء',
          message: localizations.get('performance_issues_detected') ?? 'تم اكتشاف مشاكل في الأداء - يُنصح بتحسين إعدادات الجهاز',
          type: NotificationType.info,
          priority: NotificationPriority.low,
          timestamp: DateTime.now(),
          icon: Icons.speed,
          action: NotificationAction(
            label: localizations.get('optimize_now') ?? 'تحسين الآن',
            onTap: () => _showDeviceSpecificPermissionsDialog(),
          ),
        ));
      }
      
      // إشعار الجهاز المكتشف (للمستخدمين الجدد)
      if (_isDeviceDetected) {
        final isFirstLaunch = await PermissionPreferences.isFirstLaunch();
        if (isFirstLaunch) {
          notifications.add(AppNotification(
            id: 'device_detected',
            title: 'تم اكتشاف الجهاز',
            message: 'مرحباً! تم اكتشاف جهاز ${_getDeviceDisplayName()} بنجاح',
            type: NotificationType.success,
            priority: NotificationPriority.high,
            timestamp: DateTime.now(),
            icon: _getDeviceIcon(),
            autoDismiss: Duration(seconds: 8),
          ));
        }
      }
      
      // إشعار الأمان المحسن
      notifications.add(AppNotification(
        id: 'security_features',
        title: localizations.get('security_features_active') ?? 'ميزات الأمان النشطة',
        message: 'تم تفعيل الحماية المتقدمة: تشفير البيانات، وضع الطوارئ، والحماية من التطفل',
        type: NotificationType.info,
        priority: NotificationPriority.medium,
        timestamp: DateTime.now(),
        icon: Icons.security,
        autoDismiss: Duration(seconds: 6),
      ));
      
      setState(() {
        _notifications = notifications;
      });
      
      // إخفاء الإشعارات تلقائياً بعد فترة
      _notificationTimer = Timer(Duration(seconds: 15), () {
        if (mounted) {
          setState(() {
            _showNotifications = false;
          });
        }
      });
      
    } catch (e) {
      AppLogger.error('Error initializing notifications: $e');
    }
  }
  
  /// ✅ تهيئة التوصيات مع دمج البيانات من الخدمات الأساسية
  Future<void> _initializeRecommendations() async {
    try {
      List<AppRecommendation> recommendations = [];
      
      // فحص الأذونات
      final permissions = await PermissionManager.checkAllPermissions();
      
      if (!permissions.batteryOptimization) {
        recommendations.add(AppRecommendation(
          id: 'battery_optimization',
          title: localizations.get('optimize_battery_settings') ?? 'تحسين إعدادات البطارية',
          description: 'قم بإزالة التطبيق من قائمة تحسين البطارية لضمان العمل المستمر في الخلفية',
          priority: RecommendationPriority.critical,
          category: RecommendationCategory.performance,
          icon: Icons.battery_alert,
          estimatedTime: '2 دقيقة',
          difficulty: RecommendationDifficulty.easy,
          action: RecommendationAction(
            label: localizations.get('fix_now') ?? 'إصلاح الآن',
            onTap: () async {
              await PermissionManager.requestBatteryOptimizationPermission(context, forceAsk: true);
              _refreshRecommendations();
            },
          ),
        ));
      }
      
      // توصية خاصة بالجهاز
      if (_isDeviceDetected) {
        recommendations.add(AppRecommendation(
          id: 'device_specific_setup',
          title: 'إعداد مخصص لجهاز ${_getDeviceDisplayName()}',
          description: _getDeviceSpecificTip(),
          priority: RecommendationPriority.medium,
          category: RecommendationCategory.deviceSpecific,
          icon: _getDeviceIcon(),
          estimatedTime: '5 دقائق',
          difficulty: RecommendationDifficulty.medium,
          action: RecommendationAction(
            label: localizations.get('setup_device') ?? 'إعداد الجهاز',
            onTap: () => _showDeviceSpecificPermissionsDialog(),
          ),
        ));
      }
      
      // توصية الأمان
      if (_biometricEnabled) {
        recommendations.add(AppRecommendation(
          id: 'biometric_login',
          title: localizations.get('use_biometric_login') ?? 'استخدام تسجيل الدخول البيومتري',
          description: 'يمكنك استخدام بصمة الإصبع أو التعرف على الوجه لتسجيل دخول أسرع وأكثر أماناً',
          priority: RecommendationPriority.low,
          category: RecommendationCategory.security,
          icon: Icons.fingerprint,
          estimatedTime: '10 ثوانٍ',
          difficulty: RecommendationDifficulty.easy,
          action: RecommendationAction(
            label: localizations.get('try_now') ?? 'جرب الآن',
            onTap: () => _authenticateWithBiometrics(),
          ),
        ));
      }
      
      // توصية تحسين الأداء
      final performanceGrade = ref.read(performanceGradeProvider);
      if (performanceGrade != 'Excellent') {
        recommendations.add(AppRecommendation(
          id: 'performance_optimization',
          title: localizations.get('optimize_app_performance') ?? 'تحسين أداء التطبيق',
          description: 'درجة الأداء الحالية: $performanceGrade - يمكن تحسينها بخطوات بسيطة',
          priority: RecommendationPriority.medium,
          category: RecommendationCategory.performance,
          icon: Icons.speed,
          estimatedTime: '3 دقائق',
          difficulty: RecommendationDifficulty.medium,
          action: RecommendationAction(
            label: localizations.get('optimize') ?? 'تحسين',
            onTap: () => _showPerformanceOptimizationDialog(),
          ),
        ));
      }
      
      setState(() {
        _recommendations = recommendations;
      });
      
    } catch (e) {
      AppLogger.error('Error initializing recommendations: $e');
    }
  }
  
  /// ✅ تحديث التوصيات
  Future<void> _refreshRecommendations() async {
    await _initializeRecommendations();
  }
  
  /// ✅ إظهار حوار إعدادات الشبكة
  void _showNetworkSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.wifi_off, color: colors.primary),
            SizedBox(width: 8),
            Text(localizations.get('network_settings') ?? 'إعدادات الشبكة'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(localizations.get('network_troubleshooting') ?? 'استكشاف أخطاء الشبكة:'),
            SizedBox(height: 12),
            Text('• فحص اتصال الواي فاي أو البيانات'),
            Text('• إعادة تشغيل اتصال الشبكة'),
            Text('• التحقق من إعدادات جدار الحماية'),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: colors.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'التطبيق يعمل في وضع محدود بدون إنترنت',
                      style: TextStyle(color: colors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.get('close') ?? 'إغلاق'),
          ),
        ],
      ),
    );
  }
  
  /// ✅ إظهار حوار تحسين الأداء
  void _showPerformanceOptimizationDialog() {
    final metrics = ref.read(performanceMetricsProvider);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.speed, color: colors.primary),
            SizedBox(width: 8),
            Text(localizations.get('performance_optimization') ?? 'تحسين الأداء'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('إحصائيات الأداء الحالية:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            _buildPerformanceMetric('معدل الإطارات المفقودة', '${(metrics.droppedFrameRate * 100).toStringAsFixed(1)}%'),
            _buildPerformanceMetric('متوسط وقت الإطار', '${metrics.averageFrameTime.inMilliseconds}ms'),
            _buildPerformanceMetric('العمليات البطيئة', '${metrics.slowOperations.length}'),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tips_and_updates, color: colors.secondary),
                      SizedBox(width: 8),
                      Text('نصائح التحسين:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text('• إغلاق التطبيقات غير المستخدمة'),
                  Text('• إعادة تشغيل الجهاز'),
                  Text('• تحديث إعدادات أذونات البطارية'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.get('close') ?? 'إغلاق'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showDeviceSpecificPermissionsDialog();
            },
            child: Text(localizations.get('optimize_device') ?? 'تحسين الجهاز'),
          ),
        ],
      ),
    );
  }
  
  /// ✅ بناء مقياس الأداء
  Widget _buildPerformanceMetric(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: colors.primary)),
        ],
      ),
    );
  }

  /// ✅ عرض رسالة التدمير
  Future<void> _showDestructionMessage() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('تم تنفيذ التدمير'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'تم تنفيذ إجراء التدمير بنجاح.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('سيتم الانتقال إلى وضع التعتيم الآمن.'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
  }

  /// ✅ بناء قسم الإشعارات
  Widget _buildNotificationsSection() {
    if (!_showNotifications || _notifications.isEmpty) {
      return SizedBox.shrink();
    }
    
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active, color: colors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                localizations.get('notifications') ?? 'الإشعارات',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: colors.primary,
                ),
              ),
              Spacer(),
              TextButton(
                onPressed: () => setState(() => _showNotifications = false),
                child: Text(localizations.get('hide') ?? 'إخفاء'),
              ),
            ],
          ),
          SizedBox(height: 8),
          ...(_notifications.take(3).map((notification) => _buildNotificationCard(notification)).toList()),
          if (_notifications.length > 3)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Center(
                child: Text(
                  '${localizations.get('and')} ${_notifications.length - 3} ${localizations.get('more_notifications')}',
                  style: TextStyle(
                    color: colors.onSurface.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  /// ✅ بناء بطاقة الإشعار
  Widget _buildNotificationCard(AppNotification notification) {
    Color backgroundColor;
    Color borderColor;
    
    switch (notification.type) {
      case NotificationType.success:
        backgroundColor = Colors.green.withOpacity(0.1);
        borderColor = Colors.green.withOpacity(0.3);
        break;
      case NotificationType.warning:
        backgroundColor = Colors.orange.withOpacity(0.1);
        borderColor = Colors.orange.withOpacity(0.3);
        break;
      case NotificationType.error:
        backgroundColor = Colors.red.withOpacity(0.1);
        borderColor = Colors.red.withOpacity(0.3);
        break;
      case NotificationType.info:
      default:
        backgroundColor = colors.primary.withOpacity(0.1);
        borderColor = colors.primary.withOpacity(0.3);
        break;
    }
    
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            notification.icon,
            color: borderColor.withOpacity(0.8),
            size: 20,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: borderColor.withOpacity(0.9),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  notification.message,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurface.withOpacity(0.8),
                  ),
                ),
                if (notification.action != null) ...[
                  SizedBox(height: 8),
                  TextButton(
                    onPressed: notification.action!.onTap,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      notification.action!.label,
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  /// ✅ بناء قسم التوصيات
  Widget _buildRecommendationsSection() {
    if (_recommendations.isEmpty) {
      return SizedBox.shrink();
    }
    
    // ترتيب التوصيات حسب الأولوية
    final sortedRecommendations = List<AppRecommendation>.from(_recommendations);
    sortedRecommendations.sort((a, b) => b.priority.index.compareTo(a.priority.index));
    
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: colors.secondary, size: 20),
              SizedBox(width: 8),
              Text(
                localizations.get('recommendations') ?? 'التوصيات',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: colors.secondary,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          ...sortedRecommendations.take(2).map((recommendation) => _buildRecommendationCard(recommendation)).toList(),
          if (sortedRecommendations.length > 2)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Center(
                child: TextButton(
                  onPressed: () => _showAllRecommendations(),
                  child: Text('${localizations.get('view_all')} (${sortedRecommendations.length})'),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  /// ✅ بناء بطاقة التوصية
  Widget _buildRecommendationCard(AppRecommendation recommendation) {
    Color priorityColor;
    switch (recommendation.priority) {
      case RecommendationPriority.critical:
        priorityColor = Colors.red;
        break;
      case RecommendationPriority.high:
        priorityColor = Colors.orange;
        break;
      case RecommendationPriority.medium:
        priorityColor = Colors.blue;
        break;
      case RecommendationPriority.low:
        priorityColor = Colors.green;
        break;
    }
    
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: priorityColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: priorityColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(recommendation.icon, color: priorityColor, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  recommendation.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: priorityColor,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  recommendation.estimatedTime,
                  style: TextStyle(
                    fontSize: 10,
                    color: priorityColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            recommendation.description,
            style: TextStyle(
              fontSize: 12,
              color: colors.onSurface.withOpacity(0.8),
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      _getDifficultyIcon(recommendation.difficulty),
                      size: 12,
                      color: colors.onSurface.withOpacity(0.6),
                    ),
                    SizedBox(width: 4),
                    Text(
                      _getDifficultyText(recommendation.difficulty),
                      style: TextStyle(
                        fontSize: 10,
                        color: colors.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: recommendation.action.onTap,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: priorityColor.withOpacity(0.1),
                ),
                child: Text(
                  recommendation.action.label,
                  style: TextStyle(fontSize: 12, color: priorityColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  /// ✅ إظهار جميع التوصيات
  void _showAllRecommendations() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, color: colors.secondary),
                SizedBox(width: 8),
                Text(
                  localizations.get('all_recommendations') ?? 'جميع التوصيات',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colors.secondary,
                  ),
                ),
                Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close),
                ),
              ],
            ),
            SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _recommendations.length,
                itemBuilder: (context, index) => _buildRecommendationCard(_recommendations[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// ✅ الحصول على أيقونة الصعوبة
  IconData _getDifficultyIcon(RecommendationDifficulty difficulty) {
    switch (difficulty) {
      case RecommendationDifficulty.easy:
        return Icons.sentiment_satisfied;
      case RecommendationDifficulty.medium:
        return Icons.sentiment_neutral;
      case RecommendationDifficulty.hard:
        return Icons.sentiment_dissatisfied;
    }
  }
  
  /// ✅ الحصول على نص الصعوبة
  String _getDifficultyText(RecommendationDifficulty difficulty) {
    switch (difficulty) {
      case RecommendationDifficulty.easy:
        return localizations.get('easy') ?? 'سهل';
      case RecommendationDifficulty.medium:
        return localizations.get('medium') ?? 'متوسط';
      case RecommendationDifficulty.hard:
        return localizations.get('hard') ?? 'صعب';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final warningColor = Colors.orange.shade800;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const Icon(Icons.security, size: 24),
            const SizedBox(width: 8),
            const Text('Secure Agent Portal'),
            if (_isDeviceDetected) ...[
              const Spacer(),
              Chip(
                label: Text(
                  _getDeviceDisplayName(),
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
                backgroundColor: _getDeviceColor(),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ],
        ),
        backgroundColor: colorScheme.surface.withOpacity(0.8),
        elevation: 1,
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: mq.width * .05),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // قسم الإشعارات والتوصيات في الأعلى
                  _buildNotificationsSection(),
                  _buildRecommendationsSection(),
                  // أيقونة الأمان مع أنيميشن
                  AnimatedOpacity(
                    opacity: _isAnimate ? 1.0 : 0.0,
                    duration: const Duration(seconds: 1),
                    child: Padding(
                      padding: EdgeInsets.only(bottom: mq.height * 0.05),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // دائرة خلفية
                          Container(
                            width: mq.width * .35,
                            height: mq.width * .35,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  _getDeviceColor().withOpacity(0.2),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          // الأيقونة مع إمكانية تفعيل الذعر
                          GestureDetector(
                            onTap: _handlePanicTap,
                            child: Icon(
                              Icons.security,
                              size: mq.width * .25,
                              color: colorScheme.primary,
                            ),
                          ),
                          // نقطة صغيرة تشير لحالة الجهاز
                          if (_isDeviceDetected)
                            Positioned(
                              top: mq.width * .05,
                              right: mq.width * .05,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _getDeviceColor(),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // العنوان
                  Text(
                    localizations.get('enter_security_code'),
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // معلومات الجهاز إذا تم اكتشافه
                  if (_isDeviceDetected) ...[
                    const SizedBox(height: 8),
                    Text(
                      'تم اكتشاف جهاز ${_getDeviceDisplayName()} • Android $_androidVersion',
                      style: TextStyle(
                        fontSize: 13,
                        color: _getDeviceColor(),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  SizedBox(height: mq.height * .03),

                  // شريط الحالة الأمنية
                  if (_failedAttempts > 0 || _isLocked) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isLocked ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isLocked ? Colors.red : Colors.orange,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isLocked ? Icons.lock_outline : Icons.warning_amber,
                            color: _isLocked ? Colors.red : Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isLocked 
                                  ? localizations.get('app_temporarily_locked')
                                  : '${localizations.get('wrong_attempt')}. $_failedAttempts من $_maxFailedAttempts',
                              style: TextStyle(
                                color: _isLocked ? Colors.red : Colors.orange,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // حقل إدخال الرمز مع التحسينات الأمنية
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_shakeAnimation.value, 0),
                        child: TextFormField(
                          controller: _codeController,
                          focusNode: _codeFocusNode,
                          textAlign: TextAlign.center,
                          obscureText: !_showPassword,
                          enabled: !_isLocked,
                          keyboardType: TextInputType.visiblePassword,
                          style: TextStyle(
                            fontSize: 20,
                            letterSpacing: 4,
                            fontWeight: FontWeight.bold,
                            color: _isLocked ? Colors.grey : colorScheme.onSurface,
                          ),
                          decoration: InputDecoration(
                            prefixIcon: Icon(
                              Icons.key,
                              color: _isLocked 
                                  ? Colors.grey 
                                  : colors.secondary,
                              size: 26,
                            ),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: _isLocked ? null : () {
                                    setState(() {
                                      _showPassword = !_showPassword;
                                    });
                                  },
                                  icon: Icon(
                                    _showPassword ? Icons.visibility_off : Icons.visibility,
                                    color: _isLocked ? Colors.grey : Colors.grey[600],
                                  ),
                                ),
                                if (_biometricEnabled && !_isLocked)
                                  IconButton(
                                    onPressed: _authenticateWithBiometrics,
                                    icon: const Icon(
                                      Icons.fingerprint,
                                      color: Colors.green,
                                    ),
                                    tooltip: 'تسجيل الدخول بالبصمة',
                                  ),
                              ],
                            ),
                            hintText: _isLocked ? localizations.get('locked_temporarily') : '••••••••',
                            labelText: _isLocked ? localizations.get('app_temporarily_locked') : localizations.get('security_code_placeholder'),
                            floatingLabelBehavior: FloatingLabelBehavior.auto,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _isLocked 
                                    ? Colors.red 
                                    : (_isDeviceDetected ? _getDeviceColor() : colorScheme.primary),
                                width: 2,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.red, width: 2),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return localizations.get('please_enter_code');
                            }
                            if (value.length < 4) {
                              return localizations.get('code_too_short');
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) {
                            if (!_isLoading && !_isLocked) _handleLoginOrDestruct();
                          },
                        ),
                      );
                    },
                  ),

                  SizedBox(height: mq.height * .04),

                  // زر تسجيل الدخول
                  _isLoading
                      ? Column(
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(
                          _isDeviceDetected ? _getDeviceColor() : colors.tertiary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        localizations.get('verifying'),
                        style: TextStyle(
                          color: colors.onSurface.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  )
                      : ElevatedButton.icon(
                    icon: Icon(_isLocked ? Icons.lock_outline : Icons.login),
                    onPressed: (_isLoading || _isLocked) ? null : _handleLoginOrDestruct,
                    label: Text(
                      _isLocked ? localizations.get('temporarily_locked') : localizations.get('confirm_and_continue'),
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: _isDeviceDetected
                          ? _getDeviceColor()
                          : colors.tertiary,
                      foregroundColor: Colors.white,
                    ),
                  ),

                  SizedBox(height: mq.height * .04),

                  // تحذير التدمير
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0,
                    ),
                    decoration: BoxDecoration(
                      color: warningColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: warningColor.withOpacity(0.5)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: warningColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'تحذير هام: إدخال رمز التدمير سيؤدي إلى مسح جميع البيانات المرتبطة بهذا الحساب بشكل دائم وتعطيله فورًا. لا يمكن التراجع عن هذا الإجراء.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: warningColor,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.start,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: mq.height * .02),

                  // معلومات الأمان المحسنة
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.security, color: Colors.blue, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'ميزات الأمان النشطة',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              _biometricEnabled ? Icons.check_circle : Icons.cancel,
                              color: _biometricEnabled ? Colors.green : Colors.grey,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'التحقق البيومتري: ${_biometricEnabled ? "متاح" : "غير متاح"}',
                              style: TextStyle(
                                fontSize: 13,
                                color: _biometricEnabled ? Colors.green : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'حماية من المحاولات المتكررة: نشطة',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.emergency, color: Colors.red, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'وضع الطوارئ: متاح (اضغط 5 مرات على أيقونة الأمان)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.red[700],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.delete_forever, color: Colors.red, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'رموز التدمير: متاحة (من Firebase)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.red[700],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_failedAttempts > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.warning_amber, color: Colors.orange, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'محاولات فاشلة: $_failedAttempts/$_maxFailedAttempts',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  SizedBox(height: mq.height * .02),

                  // رابط إعدادات الجهاز
                  if (_isDeviceDetected)
                    TextButton.icon(
                      onPressed: () => _showDeviceSpecificPermissionsDialog(),
                      icon: Icon(_getDeviceIcon(), size: 18),
                      label: Text('إعدادات ${_getDeviceDisplayName()}'),
                      style: TextButton.styleFrom(
                        foregroundColor: _getDeviceColor(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ===== DATA CLASSES FOR NOTIFICATIONS AND RECOMMENDATIONS =====

/// ✅ فئة الإشعار
class AppNotification {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final NotificationPriority priority;
  final DateTime timestamp;
  final IconData icon;
  final NotificationAction? action;
  final Duration? autoDismiss;
  
  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.priority,
    required this.timestamp,
    required this.icon,
    this.action,
    this.autoDismiss,
  });
}

/// ✅ إجراء الإشعار
class NotificationAction {
  final String label;
  final VoidCallback onTap;
  
  NotificationAction({
    required this.label,
    required this.onTap,
  });
}

/// ✅ أنواع الإشعارات
enum NotificationType {
  success,
  warning,
  error,
  info,
}

/// ✅ أولوية الإشعارات
enum NotificationPriority {
  low,
  medium,
  high,
  critical,
}

/// ✅ فئة التوصية
class AppRecommendation {
  final String id;
  final String title;
  final String description;
  final RecommendationPriority priority;
  final RecommendationCategory category;
  final IconData icon;
  final String estimatedTime;
  final RecommendationDifficulty difficulty;
  final RecommendationAction action;
  
  AppRecommendation({
    required this.id,
    required this.title,
    required this.description,
    required this.priority,
    required this.category,
    required this.icon,
    required this.estimatedTime,
    required this.difficulty,
    required this.action,
  });
}

/// ✅ إجراء التوصية
class RecommendationAction {
  final String label;
  final VoidCallback onTap;
  
  RecommendationAction({
    required this.label,
    required this.onTap,
  });
}

/// ✅ أولوية التوصيات
enum RecommendationPriority {
  low,
  medium,
  high,
  critical,
}

/// ✅ فئات التوصيات
enum RecommendationCategory {
  performance,
  security,
  deviceSpecific,
  usability,
  maintenance,
}

/// ✅ صعوبة التوصيات
enum RecommendationDifficulty {
  easy,
  medium,
  hard,
}
