// lib/helper/my_date_util.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // ✅ إضافة للتنسيق المتقدم

// ✅ فئة محسنة لتنسيق التواريخ - تطبيق استخباراتي متقدم
class MyDateUtil {
  // ✅ المنطقة الزمنية المحلية
  static const String _arabicLocale = 'ar_SA';

  // ✅ منسقات التاريخ المعرفة مسبقاً
  static final DateFormat _timeFormat = DateFormat('HH:mm', _arabicLocale);
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy', _arabicLocale);
  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm', _arabicLocale);

  // ============== الدوال الأساسية الموجودة - محسنة ==============

  /// ✅ تنسيق الوقت المحسن مع دعم أفضل للأخطاء
  static String getFormattedTime({
    required BuildContext context,
    required String time,
  }) {
    try {
      final timestamp = int.tryParse(time);
      if (timestamp == null) return '--:--';

      final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return TimeOfDay.fromDateTime(date).format(context);
    } catch (e) {
      debugPrint('Error formatting time: $e');
      return '--:--';
    }
  }

  /// ✅ وقت الرسالة المحسن مع تفاصيل أكثر
  static String getMessageTime({required String time}) {
    try {
      final timestamp = int.tryParse(time);
      if (timestamp == null) return '--:--';

      final DateTime sent = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final DateTime now = DateTime.now();

      // نفس اليوم
      if (isSameDay(sent, now)) {
        return _timeFormat.format(sent);
      }

      // أمس
      if (isSameDay(sent, now.subtract(const Duration(days: 1)))) {
        return 'أمس ${_timeFormat.format(sent)}';
      }

      // نفس الأسبوع
      final daysDifference = now.difference(sent).inDays;
      if (daysDifference < 7) {
        return '${_getArabicWeekday(sent.weekday)} ${_timeFormat.format(sent)}';
      }

      // نفس السنة
      if (sent.year == now.year) {
        return '${sent.day}/${sent.month} ${_timeFormat.format(sent)}';
      }

      // سنة مختلفة
      return _dateTimeFormat.format(sent);
    } catch (e) {
      debugPrint('Error getting message time: $e');
      return '--:--';
    }
  }

  /// ✅ وقت آخر رسالة المحسن
  static String getLastMessageTime({
    required BuildContext context,
    required String time,
  }) {
    try {
      final timestamp = int.tryParse(time);
      if (timestamp == null) return '--:--';

      final DateTime sent = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final DateTime now = DateTime.now();

      if (isSameDay(sent, now)) {
        return TimeOfDay.fromDateTime(sent).format(context);
      }

      if (isSameDay(sent, now.subtract(const Duration(days: 1)))) {
        return 'أمس';
      }

      return '${sent.day}/${sent.month}';
    } catch (e) {
      debugPrint('Error getting last message time: $e');
      return '--:--';
    }
  }

  /// ✅ آخر نشاط محسن مع دقة أكبر
  static String getLastActiveTime({
    required BuildContext context,
    required String lastActive,
  }) {
    try {
      final timestamp = int.tryParse(lastActive);
      if (timestamp == null || timestamp == -1) return 'غير متاح';

      final DateTime time = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final DateTime now = DateTime.now();
      final difference = now.difference(time);

      // أقل من دقيقة
      if (difference.inSeconds < 60) {
        return 'الآن';
      }

      // أقل من ساعة
      if (difference.inMinutes < 60) {
        final minutes = difference.inMinutes;
        return 'منذ $minutes ${_getPluralForm(minutes, 'دقيقة', 'دقيقتين', 'دقائق')}';
      }

      // أقل من يوم
      if (difference.inHours < 24) {
        final hours = difference.inHours;
        return 'منذ $hours ${_getPluralForm(hours, 'ساعة', 'ساعتين', 'ساعات')}';
      }

      // أقل من أسبوع
      if (difference.inDays < 7) {
        final days = difference.inDays;
        return 'منذ $days ${_getPluralForm(days, 'يوم', 'يومين', 'أيام')}';
      }

      // أكثر من أسبوع
      if (isSameDay(time, now.subtract(const Duration(days: 1)))) {
        return 'آخر ظهور: أمس ${TimeOfDay.fromDateTime(time).format(context)}';
      }

      return 'آخر ظهور: ${_getArabicWeekday(time.weekday)} ${TimeOfDay.fromDateTime(time).format(context)}';
    } catch (e) {
      debugPrint('Error getting last active time: $e');
      return 'غير متاح';
    }
  }

  // ============== دوال جديدة للميزات المتقدمة ==============

  /// ✅ دالة جديدة لعرض وقت التعديل
  static String getEditedTime({
    required BuildContext context,
    required String editedAt,
  }) {
    try {
      final timestamp = int.tryParse(editedAt);
      if (timestamp == null) return '';

      final DateTime edited = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final DateTime now = DateTime.now();

      if (isSameDay(edited, now)) {
        return 'تم التعديل ${TimeOfDay.fromDateTime(edited).format(context)}';
      }

      if (isSameDay(edited, now.subtract(const Duration(days: 1)))) {
        return 'تم التعديل أمس ${TimeOfDay.fromDateTime(edited).format(context)}';
      }

      return 'تم التعديل ${edited.day}/${edited.month} ${TimeOfDay.fromDateTime(edited).format(context)}';
    } catch (e) {
      debugPrint('Error getting edited time: $e');
      return '';
    }
  }

  /// ✅ دالة لحساب الفترة بين تاريخين
  static String getTimeDifference(String startTime, String endTime) {
    try {
      final start = DateTime.fromMillisecondsSinceEpoch(int.parse(startTime));
      final end = DateTime.fromMillisecondsSinceEpoch(int.parse(endTime));
      final difference = end.difference(start);

      if (difference.inDays > 0) {
        return '${difference.inDays} ${_getPluralForm(difference.inDays, 'يوم', 'يومين', 'أيام')}';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} ${_getPluralForm(difference.inHours, 'ساعة', 'ساعتين', 'ساعات')}';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} ${_getPluralForm(difference.inMinutes, 'دقيقة', 'دقيقتين', 'دقائق')}';
      } else {
        return 'أقل من دقيقة';
      }
    } catch (e) {
      debugPrint('Error calculating time difference: $e');
      return 'غير محدد';
    }
  }

  /// ✅ دالة للتحقق من صحة التاريخ
  static bool isValidTimestamp(String timestamp) {
    try {
      final parsed = int.tryParse(timestamp);
      if (parsed == null) return false;

      final date = DateTime.fromMillisecondsSinceEpoch(parsed);
      final now = DateTime.now();

      // التحقق من أن التاريخ ليس في المستقبل البعيد أو الماضي البعيد
      return date.isAfter(DateTime(2020)) && date.isBefore(now.add(const Duration(days: 1)));
    } catch (e) {
      return false;
    }
  }

  /// ✅ دالة لتنسيق مدة الصوت/الفيديو
  static String formatMediaDuration(int? durationInSeconds) {
    if (durationInSeconds == null || durationInSeconds <= 0) {
      return '00:00';
    }

    final minutes = durationInSeconds ~/ 60;
    final seconds = durationInSeconds % 60;

    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return '${hours.toString().padLeft(2, '0')}:${remainingMinutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// ✅ دالة لتنسيق حجم الملف مع التاريخ
  static String getFileInfoString({
    required String timestamp,
    int? fileSize,
    String? fileName,
  }) {
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp));
      final dateStr = _dateFormat.format(date);

      String info = dateStr;

      if (fileSize != null && fileSize > 0) {
        info += ' • ${_formatFileSize(fileSize)}';
      }

      if (fileName != null && fileName.isNotEmpty) {
        final extension = fileName.split('.').last.toUpperCase();
        info += ' • $extension';
      }

      return info;
    } catch (e) {
      return 'معلومات غير متاحة';
    }
  }

  // ============== دوال مساعدة خاصة ==============

  /// ✅ التحقق من نفس اليوم
  static bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  /// ✅ الحصول على اسم اليوم بالعربية
  static String _getArabicWeekday(int weekday) {
    switch (weekday) {
      case 1: return 'الاثنين';
      case 2: return 'الثلاثاء';
      case 3: return 'الأربعاء';
      case 4: return 'الخميس';
      case 5: return 'الجمعة';
      case 6: return 'السبت';
      case 7: return 'الأحد';
      default: return '';
    }
  }

  /// ✅ الحصول على اسم الشهر بالعربية
  static String _getArabicMonth(int month) {
    switch (month) {
      case 1: return 'يناير';
      case 2: return 'فبراير';
      case 3: return 'مارس';
      case 4: return 'أبريل';
      case 5: return 'مايو';
      case 6: return 'يونيو';
      case 7: return 'يوليو';
      case 8: return 'أغسطس';
      case 9: return 'سبتمبر';
      case 10: return 'أكتوبر';
      case 11: return 'نوفمبر';
      case 12: return 'ديسمبر';
      default: return '';
    }
  }

  /// ✅ تحديد صيغة الجمع العربية
  static String _getPluralForm(int count, String singular, String dual, String plural) {
    if (count == 1) return singular;
    if (count == 2) return dual;
    return plural;
  }

  /// ✅ تنسيق حجم الملف
  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes بايت';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} كيلوبايت';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} ميجابايت';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} جيجابايت';
  }

  /// ✅ الحصول على التوقيت النسبي الذكي
  static String getSmartTime(String timestamp) {
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp));
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inSeconds < 30) return 'الآن';
      if (difference.inMinutes < 1) return 'منذ لحظات';
      if (difference.inMinutes < 60) return 'منذ ${difference.inMinutes} د';
      if (difference.inHours < 24) return 'منذ ${difference.inHours} س';
      if (difference.inDays == 1) return 'أمس';
      if (difference.inDays < 7) return 'منذ ${difference.inDays} أيام';

      return _dateFormat.format(date);
    } catch (e) {
      return '--';
    }
  }

  /// ✅ تحويل Timestamp إلى نص قابل للقراءة
  static String timestampToReadable(String timestamp) {
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp));
      return _dateTimeFormat.format(date);
    } catch (e) {
      return 'تاريخ غير صحيح';
    }
  }

  /// ✅ الحصول على تاريخ اليوم كـ timestamp
  static String getTodayTimestamp() {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    return startOfDay.millisecondsSinceEpoch.toString();
  }

  /// ✅ التحقق من أن التاريخ هو اليوم
  static bool isToday(String timestamp) {
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp));
      return isSameDay(date, DateTime.now());
    } catch (e) {
      return false;
    }
  }
}
