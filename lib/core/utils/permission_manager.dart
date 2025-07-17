// lib/core/utils/permission_manager.dart

import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import 'permission_preferences.dart';

/// ✅ مدير الأذونات المحسن مع أفضل الممارسات الحديثة
class PermissionManager {
  // ✅ Method channels مع error handling
  static const MethodChannel _batteryChannel = MethodChannel('com.example.mictest/battery');

  // ✅ Constants
  static const int _maxRetryAttempts = 3;
  static const int _minHoursBetweenRequests = 6;

  /// ✅ فحص جميع الأذونات المطلوبة - جديد ومحسن
  static Future<PermissionCheckResult> checkAllPermissions() async {
    try {
      log('🔍 Checking all permissions...');

      final batteryOptimization = await checkBatteryOptimization();
      final backgroundPermission = await PermissionPreferences.isBackgroundPermissionGranted();

      // ✅ تحديث الحالة إذا تغيرت الأذونات خارجياً
      if (batteryOptimization != backgroundPermission) {
        log('📝 Permission status mismatch detected, updating...');
        await PermissionPreferences.setBackgroundPermissionGranted(batteryOptimization);
      }

      final result = PermissionCheckResult(
        batteryOptimization: batteryOptimization,
        backgroundPermission: batteryOptimization, // تحديث لتطابق الحالة الفعلية
        allGranted: batteryOptimization,
      );

      log('📊 Permission check result: ${result.toString()}');
      return result;
    } catch (e) {
      log('❌ Error checking all permissions: $e');
      return PermissionCheckResult(
        batteryOptimization: false,
        backgroundPermission: false,
        allGranted: false,
      );
    }
  }

  /// ✅ طلب صلاحية البطارية مع فحص الحالة المحسن
  static Future<bool> requestBatteryOptimizationPermission(
      BuildContext context, {
        bool forceAsk = false,
        bool showEducationalContent = true,
      }) async {
    try {
      log('🔋 Starting battery optimization permission request...');

      // ✅ 1. فحص الحالة الحالية أولاً - التحديث الأهم
      final currentPermissions = await checkAllPermissions();
      if (currentPermissions.allGranted && !forceAsk) {
        log('✅ All permissions already granted, no need to ask');
        return true;
      }

      // 2. فحص إذا كان المستخدم رفض نهائياً
      if (!forceAsk) {
        final hasOptedOut = await PermissionPreferences.hasUserOptedOutPermanently();
        if (hasOptedOut) {
          log('🚫 User has permanently opted out');
          return false;
        }
      }

      // 3. فحص التوقيت المناسب للطلب
      if (!forceAsk && !await _isGoodTimeToAsk()) {
        log('⏰ Not a good time to ask for permissions');
        return false;
      }

      // 4. عرض المحتوى التعليمي إذا كان مطلوب
      if (showEducationalContent && !forceAsk) {
        final userWantsToLearn = await _showEducationalContent(context);
        if (!userWantsToLearn) {
          await PermissionPreferences.incrementPermissionDismissedCount();
          return false;
        }
      }

      // 5. عرض طلب الصلاحية
      final userAccepted = await _showBatteryPermissionDialog(context);
      if (!userAccepted) {
        await PermissionPreferences.incrementPermissionDismissedCount();
        return false;
      }

      // 6. تسجيل أن الصلاحية تم طلبها
      await PermissionPreferences.markBatteryPermissionAsked();

      // 7. محاولة تفعيل الصلاحية
      final permissionGranted = await _attemptBatteryPermissionGrant(context);

      // 8. تحديث الحالة في التفضيلات
      await PermissionPreferences.setBackgroundPermissionGranted(permissionGranted);

      return permissionGranted;
    } catch (e) {
      log('❌ Error in battery optimization permission request: $e');
      return false;
    }
  }

  /// ✅ فحص التوقيت المناسب للطلب
  static Future<bool> _isGoodTimeToAsk() async {
    try {
      // المستخدمين الجدد - السماح بالطلب
      final isRecentlyInstalled = await PermissionPreferences.isRecentlyInstalled();
      if (isRecentlyInstalled) {
        log('👋 Recently installed user, allowing permission request');
        return true;
      }

      // فحص آخر مرة تم الطلب
      final lastRequest = await PermissionPreferences.getLastPermissionRequestDate();
      if (lastRequest != null) {
        final hoursSinceLastRequest = DateTime.now().difference(lastRequest).inHours;
        if (hoursSinceLastRequest < _minHoursBetweenRequests) {
          log('⏰ Too soon since last request ($hoursSinceLastRequest hours)');
          return false;
        }
      }

      // فحص عدد مرات التجاهل
      final dismissedCount = await PermissionPreferences.getPermissionDismissedCount();
      if (dismissedCount >= 3) {
        log('🚫 Too many dismissals ($dismissedCount)');
        return false;
      }

      return true;
    } catch (e) {
      log('❌ Error checking timing: $e');
      return false;
    }
  }

  /// ✅ عرض محتوى تعليمي للمستخدم
  static Future<bool> _showEducationalContent(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.school, color: Colors.blue, size: 24),
            SizedBox(width: 8),
            Text('تحسين أداء التطبيق'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'لماذا نحتاج هذا الإذن؟',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text('• الحفاظ على الاتصال الآمن'),
              const Text('• استقبال الرسائل فوراً'),
              const Text('• منع توقف الخدمات الأمنية'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.eco, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'لن يؤثر على عمر البطارية بشكل ملحوظ',
                        style: TextStyle(color: Colors.green, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ليس الآن'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('فهمت، متابعة'),
          ),
        ],
      ),
    ) ?? false;
  }

  /// ✅ حوار طلب الصلاحية محسن
  static Future<bool> _showBatteryPermissionDialog(BuildContext context) async {
    final dismissedCount = await PermissionPreferences.getPermissionDismissedCount();
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.battery_charging_full,
              color: dismissedCount > 1 ? Colors.orange : Colors.green,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Expanded(child: Text('تحسين البطارية')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (dismissedCount == 0) ...[
              const Text(
                'لضمان أفضل أداء، يرجى السماح للتطبيق بالعمل في الخلفية.',
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 12),
              const Text('سنقوم بفتح إعدادات النظام لك.'),
            ] else if (dismissedCount == 1) ...[
              const Text(
                'لاحظنا أن بعض الميزات قد لا تعمل بشكل مثالي.',
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 8),
              const Text('هل تود تفعيل التحسينات الآن؟'),
            ] else ...[
              const Text(
                'هذا آخر تذكير 😊',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('يمكنك تفعيل هذا لاحقاً من إعدادات التطبيق.'),
            ],
            if (dismissedCount >= 2) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showPermanentOptOutDialog(context),
                      child: const Text(
                        'عدم السؤال مرة أخرى',
                        style: TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(dismissedCount >= 2 ? 'لاحقاً' : 'ليس الآن'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('موافق'),
          ),
        ],
      ),
    ) ?? false;
  }

  /// ✅ حوار الرفض النهائي
  static Future<void> _showPermanentOptOutDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.block, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('تأكيد الرفض'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'هل أنت متأكد من عدم رغبتك في تفعيل تحسينات البطارية؟',
              style: TextStyle(fontSize: 15),
            ),
            SizedBox(height: 12),
            Text(
              'يمكنك تغيير رأيك لاحقاً من إعدادات التطبيق.',
              style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('نعم، لا أريد'),
          ),
        ],
      ),
    ) ?? false;

    if (confirmed) {
      await PermissionPreferences.markUserOptedOutPermanently();
      if (context.mounted) {
        Navigator.pop(context, false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم حفظ اختيارك. يمكنك تغييره من الإعدادات لاحقاً.'),
            action: SnackBarAction(
              label: 'الإعدادات',
              onPressed: () => AppSettings.openAppSettings(),
            ),
          ),
        );
      }
    }
  }

  /// ✅ محاولة منح صلاحية البطارية مع retry logic
  static Future<bool> _attemptBatteryPermissionGrant(BuildContext context) async {
    try {
      final shouldProceed = await _showSettingsGuidanceDialog(context);
      if (!shouldProceed) return false;

      await _openBatterySettings();

      // فحص بسيط واحد بدلاً من التكرار المعقد
      await Future.delayed(const Duration(seconds: 3));
      final isGranted = await checkBatteryOptimization();

      return isGranted;
    } catch (e) {
      log('❌ Error attempting battery permission grant: $e');
      return false;
    }
  }


  /// ✅ حوار إرشادات الإعدادات
  static Future<bool> _showSettingsGuidanceDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.settings, color: Colors.blue, size: 24),
            SizedBox(width: 8),
            Text('خطوات بسيطة'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'سنفتح إعدادات النظام لك. يرجى اتباع الخطوات:',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildStep('1', 'ابحث عن "MicTest" في القائمة'),
            _buildStep('2', 'اختر "عدم التحسين" أو "غير محدود"'),
            _buildStep('3', 'ارجع للتطبيق'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.blue, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'إذا لم تجد التطبيق، ابحث في "جميع التطبيقات"',
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('فتح الإعدادات'),
          ),
        ],
      ),
    ) ?? false;
  }

  /// ✅ مساعد لبناء خطوات الإرشاد
  static Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  /// ✅ عرض رسالة بسيطة للمستخدمين الجدد
  static void showGentlePermissionInfo(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'لأفضل أداء، يمكنك تفعيل تحسينات البطارية لاحقاً',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'تفعيل الآن',
          textColor: Colors.white,
          onPressed: () {
            requestBatteryOptimizationPermission(context, forceAsk: true);
          },
        ),
      ),
    );
  }

  /// ✅ فحص حالة صلاحية البطارية مع fallback
  static Future<bool> checkBatteryOptimization() async {
    try {
      // المحاولة الأولى عبر platform channel
      final result = await _batteryChannel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      log('🔋 Battery optimization check (platform): $result');
      return result == true;
    } catch (e) {
      log('❌ Platform channel failed: $e');
      // Fallback إلى permission_handler
      try {
        final permission = Permission.ignoreBatteryOptimizations;
        final status = await permission.status;
        final isGranted = status.isGranted;
        log('🔋 Battery optimization check (permission_handler): $isGranted');
        return isGranted;
      } catch (e2) {
        log('❌ Permission handler also failed: $e2');
        return false;
      }
    }
  }

  /// ✅ فتح إعدادات البطارية مع fallback
  static Future<void> _openBatterySettings() async {
    try {
      // المحاولة الأولى عبر platform channel
      await _batteryChannel.invokeMethod('requestIgnoreBatteryOptimizations');
      log('✅ Opened battery settings via platform channel');
    } catch (e) {
      log('❌ Platform channel failed, using fallback: $e');
      // Fallback إلى app_settings
      try {
        await AppSettings.openAppSettings(type: AppSettingsType.batteryOptimization);
        log('✅ Opened battery settings via app_settings');
      } catch (e2) {
        log('❌ App settings also failed: $e2');
        // Final fallback
        await AppSettings.openAppSettings();
      }
    }
  }

  /// ✅ طلب أذونات التخزين (للتوافق مع الملفات الأخرى)
  static Future<bool> requestStoragePermission(BuildContext context) async {
    try {
      if (Platform.isAndroid) {
        // Android 13+ specific permissions
        if (await _isAndroid13OrHigher()) {
          final permissions = [Permission.photos, Permission.videos, Permission.audio];
          final results = await permissions.request();
          return results.values.any((status) => status.isGranted);
        } else {
          // Older Android versions
          final status = await Permission.storage.request();
          return status.isGranted;
        }
      }
      return true; // iOS doesn't need explicit storage permission
    } catch (e) {
      log('❌ Error requesting storage permission: $e');
      return false;
    }
  }

  static Future<bool> _isAndroid13OrHigher() async {
    try {
      if (!Platform.isAndroid) return false;
      // يمكن إضافة فحص دقيق لإصدار Android هنا
      return true; // لتبسيط المثال
    } catch (e) {
      return false;
    }
  }

  /// ✅ عرض حالة جميع الأذونات (مفيد للـ debugging)
  static Future<void> showPermissionsStatusDialog(BuildContext context) async {
    try {
      final permissionsResult = await checkAllPermissions();
      final debugInfo = await PermissionPreferences.getDebugInfo();

      if (!context.mounted) return;

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('حالة الأذونات'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusItem('تحسين البطارية', permissionsResult.batteryOptimization),
                _buildStatusItem('العمل في الخلفية', permissionsResult.backgroundPermission),
                const Divider(),
                const Text('معلومات إضافية:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...debugInfo.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('${entry.key}: ${entry.value}', style: const TextStyle(fontSize: 12)),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
            if (!permissionsResult.allGranted)
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  requestBatteryOptimizationPermission(context, forceAsk: true);
                },
                child: const Text('تفعيل'),
              ),
          ],
        ),
      );
    } catch (e) {
      log('❌ Error showing permissions status: $e');
    }
  }

  static Widget _buildStatusItem(String title, bool isGranted) {
    return Row(
      children: [
        Icon(
          isGranted ? Icons.check_circle : Icons.cancel,
          color: isGranted ? Colors.green : Colors.red,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(title),
        const Spacer(),
        Text(
          isGranted ? 'مُفعّل' : 'غير مُفعّل',
          style: TextStyle(
            color: isGranted ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// ✅ فحص شامل وتحديث حالة الأذونات - جديد
  static Future<bool> refreshPermissionsStatus() async {
    try {
      log('🔄 Refreshing permissions status...');

      final currentBatteryStatus = await checkBatteryOptimization();
      await PermissionPreferences.setBackgroundPermissionGranted(currentBatteryStatus);

      log('✅ Permission status refreshed: $currentBatteryStatus');
      return currentBatteryStatus;
    } catch (e) {
      log('❌ Error refreshing permissions status: $e');
      return false;
    }
  }

  /// ✅ فحص سريع للأذونات بدون حوارات - جديد
  static Future<bool> hasAllRequiredPermissions() async {
    try {
      final permissions = await checkAllPermissions();
      return permissions.allGranted;
    } catch (e) {
      log('❌ Error checking required permissions: $e');
      return false;
    }
  }

  /// ✅ إعادة تعيين حالة الأذونات في حالة الأخطاء - جديد
  static Future<void> resetPermissionsState() async {
    try {
      log('🔄 Resetting permissions state...');
      await PermissionPreferences.setBackgroundPermissionGranted(false);
      log('✅ Permissions state reset completed');
    } catch (e) {
      log('❌ Error resetting permissions state: $e');
    }
  }
}

/// ✅ فئة لتنظيم نتائج فحص الأذونات - محسنة
class PermissionCheckResult {
  final bool batteryOptimization;
  final bool backgroundPermission;
  final bool allGranted;

  const PermissionCheckResult({
    required this.batteryOptimization,
    required this.backgroundPermission,
    required this.allGranted,
  });

  @override
  String toString() {
    return 'PermissionCheckResult(battery: $batteryOptimization, background: $backgroundPermission, all: $allGranted)';
  }

  /// ✅ تحويل إلى Map للتسجيل
  Map<String, dynamic> toMap() {
    return {
      'batteryOptimization': batteryOptimization,
      'backgroundPermission': backgroundPermission,
      'allGranted': allGranted,
    };
  }

  /// ✅ فحص إذا كانت هناك أذونات ناقصة
  bool get hasMissingPermissions => !allGranted;

  /// ✅ قائمة الأذونات الناقصة
  List<String> get missingPermissions {
    final missing = <String>[];
    if (!batteryOptimization) missing.add('تحسين البطارية');
    if (!backgroundPermission) missing.add('العمل في الخلفية');
    return missing;
  }
}
