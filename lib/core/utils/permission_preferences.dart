// lib/core/utils/permission_preferences.dart

import 'dart:developer';
import 'package:shared_preferences/shared_preferences.dart';

/// ✅ مدير تفضيلات الأذونات المحسن مع أفضل الممارسات الحديثة
class PermissionPreferences {
  // ✅ Constants مع naming convention محسن
  static const String _batteryPermissionAsked = 'battery_permission_asked';
  static const String _firstLaunch = 'first_launch';
  static const String _installDate = 'install_date';
  static const String _permissionDismissedCount = 'permission_dismissed_count';
  static const String _lastPermissionRequestDate = 'last_permission_request_date';
  static const String _userOptedOutPermanently = 'user_opted_out_permanently';
  static const String _backgroundPermissionGranted = 'background_permission_granted';

  // ✅ إضافة متغيرات للرسائل الترحيبية
  static const String _firstLoginWelcomeShown = 'first_login_welcome_shown';
  static const String _successLoginMessageShown = 'success_login_message_shown';
  static const String _lastSuccessfulLogin = 'last_successful_login';
  static const String _loginCount = 'login_count';

  // ✅ Cache للـ SharedPreferences instance
  static SharedPreferences? _prefs;

  /// ✅ Initialize SharedPreferences مع error handling
  static Future<SharedPreferences> _getPrefs() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      return _prefs!;
    } catch (e) {
      log('❌ Error initializing SharedPreferences: $e');
      return await SharedPreferences.getInstance();
    }
  }

  /// ✅ فحص ما إذا كان هذا أول تشغيل
  static Future<bool> isFirstLaunch() async {
    try {
      // ✅ الحل: نعتبره أول تشغيل فقط إذا كان عدد مرات تسجيل الدخول صفراً.
      // هذا أكثر موثوقية من الاعتماد على علامة منفصلة.
      final loginCount = await getLoginCount();
      final isFirst = loginCount == 0;
      log('🔍 First launch check (based on login count: $loginCount): $isFirst');
      return isFirst;
    } catch (e) {
      log('❌ Error checking first launch: $e');
      return true;
    }
  }
  /// ✅ تسجيل أن التطبيق تم تشغيله مع atomic operations
  static Future<bool> markFirstLaunchComplete() async {
    try {
      final prefs = await _getPrefs();
      final results = await Future.wait([
        prefs.setBool(_firstLaunch, false),
        _setInstallDateIfNotExists(prefs),
      ]);
      final success = results.every((result) => result);
      log(success ? '✅ First launch marked complete' : '❌ Failed to mark first launch complete');
      return success;
    } catch (e) {
      log('❌ Error marking first launch complete: $e');
      return false;
    }
  }

  /// ✅ Helper method لتسجيل تاريخ التثبيت
  static Future<bool> _setInstallDateIfNotExists(SharedPreferences prefs) async {
    try {
      if (!prefs.containsKey(_installDate)) {
        final installTime = DateTime.now().millisecondsSinceEpoch;
        final success = await prefs.setInt(_installDate, installTime);
        log('📅 Install date set: ${DateTime.fromMillisecondsSinceEpoch(installTime)}');
        return success;
      }
      return true;
    } catch (e) {
      log('❌ Error setting install date: $e');
      return false;
    }
  }

  /// ✅ فحص ما إذا كان تم طلب صلاحية البطارية من قبل
  static Future<bool> wasBatteryPermissionAsked() async {
    try {
      final prefs = await _getPrefs();
      final wasAsked = prefs.getBool(_batteryPermissionAsked) ?? false;
      log('🔍 Battery permission was asked before: $wasAsked');
      return wasAsked;
    } catch (e) {
      log('❌ Error checking battery permission history: $e');
      return false;
    }
  }

  /// ✅ تسجيل أن صلاحية البطارية تم طلبها مع timestamp
  static Future<bool> markBatteryPermissionAsked() async {
    try {
      final prefs = await _getPrefs();
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final results = await Future.wait([
        prefs.setBool(_batteryPermissionAsked, true),
        prefs.setInt(_lastPermissionRequestDate, currentTime),
      ]);
      final success = results.every((result) => result);
      log(success ? '✅ Battery permission request marked' : '❌ Failed to mark battery permission request');
      return success;
    } catch (e) {
      log('❌ Error marking battery permission as asked: $e');
      return false;
    }
  }

  /// ✅ عدد مرات تجاهل المستخدم لطلب الصلاحية مع validation
  static Future<int> getPermissionDismissedCount() async {
    try {
      final prefs = await _getPrefs();
      final count = prefs.getInt(_permissionDismissedCount) ?? 0;
      final validatedCount = count.clamp(0, 10);
      if (count != validatedCount) {
        log('⚠️ Invalid dismissed count ($count), corrected to $validatedCount');
        await prefs.setInt(_permissionDismissedCount, validatedCount);
      }
      return validatedCount;
    } catch (e) {
      log('❌ Error getting permission dismissed count: $e');
      return 0;
    }
  }

  /// ✅ زيادة عدد مرات التجاهل مع safety checks
  static Future<bool> incrementPermissionDismissedCount() async {
    try {
      final currentCount = await getPermissionDismissedCount();
      final newCount = (currentCount + 1).clamp(0, 10);
      final prefs = await _getPrefs();
      final success = await prefs.setInt(_permissionDismissedCount, newCount);
      log(success
          ? '📊 Permission dismissed count: $currentCount → $newCount'
          : '❌ Failed to increment dismissed count');
      return success;
    } catch (e) {
      log('❌ Error incrementing permission dismissed count: $e');
      return false;
    }
  }

  /// ✅ فحص ما إذا كان التطبيق مثبت حديثاً مع time validation
  static Future<bool> isRecentlyInstalled({int hoursThreshold = 24}) async {
    try {
      final prefs = await _getPrefs();
      final installDate = prefs.getInt(_installDate);
      if (installDate == null) {
        log('⚠️ No install date found, assuming recently installed');
        return true;
      }

      final installTime = DateTime.fromMillisecondsSinceEpoch(installDate);
      final now = DateTime.now();
      final hoursSinceInstall = now.difference(installTime).inHours;

      if (hoursSinceInstall < 0) {
        log('⚠️ Invalid install date (future), correcting...');
        await prefs.setInt(_installDate, now.millisecondsSinceEpoch);
        return true;
      }

      final isRecent = hoursSinceInstall < hoursThreshold;
      log('📅 Hours since install: $hoursSinceInstall, Is recent: $isRecent');
      return isRecent;
    } catch (e) {
      log('❌ Error checking if recently installed: $e');
      return true;
    }
  }

  /// ✅ فحص متى تم طلب الأذونات آخر مرة
  static Future<DateTime?> getLastPermissionRequestDate() async {
    try {
      final prefs = await _getPrefs();
      final timestamp = prefs.getInt(_lastPermissionRequestDate);
      if (timestamp != null) {
        final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
        log('📅 Last permission request: $date');
        return date;
      }
      return null;
    } catch (e) {
      log('❌ Error getting last permission request date: $e');
      return null;
    }
  }

  /// ✅ فحص إذا كان المستخدم رفض الأذونات نهائياً
  static Future<bool> hasUserOptedOutPermanently() async {
    try {
      final prefs = await _getPrefs();
      final optedOut = prefs.getBool(_userOptedOutPermanently) ?? false;
      log('🚫 User opted out permanently: $optedOut');
      return optedOut;
    } catch (e) {
      log('❌ Error checking permanent opt-out status: $e');
      return false;
    }
  }

  /// ✅ تسجيل أن المستخدم رفض الأذونات نهائياً
  static Future<bool> markUserOptedOutPermanently() async {
    try {
      final prefs = await _getPrefs();
      final success = await prefs.setBool(_userOptedOutPermanently, true);
      log(success ? '🚫 User marked as permanently opted out' : '❌ Failed to mark permanent opt-out');
      return success;
    } catch (e) {
      log('❌ Error marking permanent opt-out: $e');
      return false;
    }
  }

  /// ✅ تسجيل حالة أذونات الخلفية
  static Future<bool> setBackgroundPermissionGranted(bool granted) async {
    try {
      final prefs = await _getPrefs();
      final success = await prefs.setBool(_backgroundPermissionGranted, granted);
      log(success
          ? '🔧 Background permission status: $granted'
          : '❌ Failed to set background permission status');
      return success;
    } catch (e) {
      log('❌ Error setting background permission status: $e');
      return false;
    }
  }

  /// ✅ فحص حالة أذونات الخلفية
  static Future<bool> isBackgroundPermissionGranted() async {
    try {
      final prefs = await _getPrefs();
      final granted = prefs.getBool(_backgroundPermissionGranted) ?? false;
      log('🔍 Background permission granted: $granted');
      return granted;
    } catch (e) {
      log('❌ Error checking background permission status: $e');
      return false;
    }
  }

  /// ✅ فحص إذا كان المستخدم يحتاج تذكير بالأذونات
  static Future<bool> shouldRemindAboutPermissions() async {
    try {
      // لا نذكر إذا رفض المستخدم نهائياً
      final hasOptedOut = await hasUserOptedOutPermanently();
      if (hasOptedOut) return false;

      // لا نذكر إذا تم منح الأذونات بالفعل
      final isGranted = await isBackgroundPermissionGranted();
      if (isGranted) return false;

      // لا نذكر إذا تم التجاهل أكثر من 3 مرات
      final dismissedCount = await getPermissionDismissedCount();
      if (dismissedCount >= 3) return false;

      // لا نذكر إذا كان أقل من يوم واحد من آخر طلب
      final lastRequest = await getLastPermissionRequestDate();
      if (lastRequest != null) {
        final hoursSinceLastRequest = DateTime.now().difference(lastRequest).inHours;
        if (hoursSinceLastRequest < 24) return false;
      }

      log('✅ Should remind about permissions');
      return true;
    } catch (e) {
      log('❌ Error checking if should remind about permissions: $e');
      return false;
    }
  }

  // ✅ إدارة رسائل تسجيل الدخول

  /// ✅ فحص إذا تم عرض رسالة الترحيب الأولى
  static Future<bool> wasFirstLoginWelcomeShown() async {
    try {
      final prefs = await _getPrefs();
      final shown = prefs.getBool(_firstLoginWelcomeShown) ?? false;
      log('🔍 First login welcome shown: $shown');
      return shown;
    } catch (e) {
      log('❌ Error checking first login welcome status: $e');
      return false;
    }
  }

  /// ✅ تسجيل أن رسالة الترحيب الأولى تم عرضها
  static Future<bool> markFirstLoginWelcomeShown() async {
    try {
      final prefs = await _getPrefs();
      final success = await prefs.setBool(_firstLoginWelcomeShown, true);
      log(success ? '✅ First login welcome marked as shown' : '❌ Failed to mark first login welcome');
      return success;
    } catch (e) {
      log('❌ Error marking first login welcome: $e');
      return false;
    }
  }

  /// ✅ فحص إذا يجب عرض رسالة النجاح (فقط في المرة الأولى)
  static Future<bool> shouldShowSuccessMessage() async {
    try {
      final prefs = await _getPrefs();
      final loginCount = prefs.getInt(_loginCount) ?? 0;

      // عرض الرسالة فقط في المرة الأولى
      final shouldShow = loginCount == 0;
      log('🔍 Should show success message (first login only): $shouldShow (login count: $loginCount)');
      return shouldShow;
    } catch (e) {
      log('❌ Error checking if should show success message: $e');
      return false;
    }
  }

  /// ✅ تسجيل تسجيل دخول ناجح
  static Future<bool> recordSuccessfulLogin() async {
    try {
      final prefs = await _getPrefs();
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final currentCount = prefs.getInt(_loginCount) ?? 0;

      final results = await Future.wait([
        prefs.setInt(_lastSuccessfulLogin, currentTime),
        prefs.setInt(_loginCount, currentCount + 1),
      ]);

      final success = results.every((result) => result);
      log(success
          ? '✅ Successful login recorded (count: ${currentCount + 1})'
          : '❌ Failed to record successful login');
      return success;
    } catch (e) {
      log('❌ Error recording successful login: $e');
      return false;
    }
  }

  /// ✅ الحصول على عدد مرات تسجيل الدخول
  static Future<int> getLoginCount() async {
    try {
      final prefs = await _getPrefs();
      final count = prefs.getInt(_loginCount) ?? 0;
      return count;
    } catch (e) {
      log('❌ Error getting login count: $e');
      return 0;
    }
  }

  /// ✅ إعادة تعيين جميع التفضيلات مع confirmation
  static Future<bool> resetAllPreferences({bool keepInstallDate = true}) async {
    try {
      final prefs = await _getPrefs();
      if (keepInstallDate) {
        final installDate = prefs.getInt(_installDate);
        final clearSuccess = await prefs.clear();
        if (!clearSuccess) return false;
        if (installDate != null) {
          await prefs.setInt(_installDate, installDate);
        }
      } else {
        final clearSuccess = await prefs.clear();
        if (!clearSuccess) return false;
      }

      _prefs = null;
      log('🔄 All preferences reset successfully');
      return true;
    } catch (e) {
      log('❌ Error resetting preferences: $e');
      return false;
    }
  }

  /// ✅ إحصائيات شاملة للـ debugging
  static Future<Map<String, dynamic>> getDebugInfo() async {
    try {
      final info = <String, dynamic>{};
      info['firstLaunch'] = await isFirstLaunch();
      info['batteryPermissionAsked'] = await wasBatteryPermissionAsked();
      info['permissionDismissedCount'] = await getPermissionDismissedCount();
      info['isRecentlyInstalled'] = await isRecentlyInstalled();
      info['lastPermissionRequest'] = await getLastPermissionRequestDate();
      info['userOptedOutPermanently'] = await hasUserOptedOutPermanently();
      info['backgroundPermissionGranted'] = await isBackgroundPermissionGranted();
      info['shouldRemindAboutPermissions'] = await shouldRemindAboutPermissions();
      info['firstLoginWelcomeShown'] = await wasFirstLoginWelcomeShown();
      info['shouldShowSuccessMessage'] = await shouldShowSuccessMessage();
      info['loginCount'] = await getLoginCount();

      final prefs = await _getPrefs();
      final installDate = prefs.getInt(_installDate);
      if (installDate != null) {
        info['installDate'] = DateTime.fromMillisecondsSinceEpoch(installDate);
        info['daysSinceInstall'] = DateTime.now().difference(
            DateTime.fromMillisecondsSinceEpoch(installDate)
        ).inDays;
      }

      log('📊 Debug info: $info');
      return info;
    } catch (e) {
      log('❌ Error getting debug info: $e');
      return {'error': e.toString()};
    }
  }

  /// ✅ Validation و cleanup للبيانات التالفة
  static Future<bool> validateAndCleanup() async {
    try {
      final prefs = await _getPrefs();
      bool needsCleanup = false;

      // فحص تاريخ التثبيت
      final installDate = prefs.getInt(_installDate);
      if (installDate != null) {
        final installTime = DateTime.fromMillisecondsSinceEpoch(installDate);
        if (installTime.isAfter(DateTime.now())) {
          log('⚠️ Invalid install date (future), removing...');
          await prefs.remove(_installDate);
          needsCleanup = true;
        }
      }

      // فحص عدد التجاهل
      final dismissedCount = prefs.getInt(_permissionDismissedCount) ?? 0;
      if (dismissedCount < 0 || dismissedCount > 10) {
        log('⚠️ Invalid dismissed count ($dismissedCount), resetting...');
        await prefs.setInt(_permissionDismissedCount, 0);
        needsCleanup = true;
      }

      // فحص تاريخ آخر طلب
      final lastRequestDate = prefs.getInt(_lastPermissionRequestDate);
      if (lastRequestDate != null) {
        final lastRequest = DateTime.fromMillisecondsSinceEpoch(lastRequestDate);
        if (lastRequest.isAfter(DateTime.now())) {
          log('⚠️ Invalid last request date (future), removing...');
          await prefs.remove(_lastPermissionRequestDate);
          needsCleanup = true;
        }
      }

      // فحص تاريخ آخر تسجيل دخول
      final lastLogin = prefs.getInt(_lastSuccessfulLogin);
      if (lastLogin != null) {
        final lastLoginDate = DateTime.fromMillisecondsSinceEpoch(lastLogin);
        if (lastLoginDate.isAfter(DateTime.now())) {
          log('⚠️ Invalid last login date (future), removing...');
          await prefs.remove(_lastSuccessfulLogin);
          needsCleanup = true;
        }
      }

      log(needsCleanup ? '🧹 Cleanup completed' : '✅ Data validation passed');
      return true;
    } catch (e) {
      log('❌ Error during validation and cleanup: $e');
      return false;
    }
  }
}
