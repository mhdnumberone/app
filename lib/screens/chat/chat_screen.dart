// lib/screens/chat_screen.dart

import 'dart:developer';
import 'dart:io';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../../api/apis.dart';
import '../../core/cache/message_cache_manager.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/themes/app_theme_extension.dart';
import '../../core/widgets/base_widgets.dart';
import '../../core/managers/settings_manager.dart';
import '../../helper/dialogs.dart';
import '../../helper/my_date_util.dart';
import '../../main.dart';
import '../../models/chat_user.dart';
import '../../models/message.dart';
import '../../widgets/audio_recorder_widget.dart';
import '../../widgets/message_card.dart';
import '../../widgets/profile_image.dart';
import '../profile/view_profile_screen.dart';
import '../../core/error/error_handler.dart';

class ChatScreen extends BaseStatefulWidget {
  final ChatUser user;
  const ChatScreen({super.key, required this.user});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends BaseState<ChatScreen> {
  List<Message> _list = [];
  List<Message> _previousMessageList = []; // ✅ لتجنب إعادة المعالجة غير الضرورية
  final _textController = TextEditingController();
  final _inputFocusNode = FocusNode();

  // ✅ ValueNotifiers محسنة - لمنع إعادة بناء الصفحة كاملة
  final ValueNotifier<bool> _showEmojiNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _isUploadingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _isRecordingAudioNotifier = ValueNotifier(false);
  final ValueNotifier<List<Message>> _pendingMessagesNotifier = ValueNotifier([]); // ✅ استخدام ValueNotifier بدلاً من setState
  final ValueNotifier<bool> _isLoadingCacheNotifier = ValueNotifier(false); // ✅ حالة تحميل الكاش

  // ✅ متغيرات النظام
  int _androidSdkVersion = 0;
  bool _hasCacheLoaded = false; // ✅ لتتبع ما إذا تم تحميل الكاش

  @override
  void initState() {
    super.initState();
    _setupFocusListener();
    _initializeAndroidVersion();
    _checkBasicPermissions();
    _loadCachedMessages(); // ✅ تحميل الرسائل المخزنة محلياً
  }

  @override
  void dispose() {
    _textController.dispose();
    _inputFocusNode.dispose();
    _showEmojiNotifier.dispose();
    _isUploadingNotifier.dispose();
    _isRecordingAudioNotifier.dispose();
    _pendingMessagesNotifier.dispose();
    _isLoadingCacheNotifier.dispose();
    super.dispose();
  }

  void _setupFocusListener() {
    _inputFocusNode.addListener(() {
      if (_inputFocusNode.hasFocus && _showEmojiNotifier.value) {
        _showEmojiNotifier.value = false;
      }
    });
  }

  // ✅ تحميل الرسائل المخزنة محلياً للعرض الفوري
  Future<void> _loadCachedMessages() async {
    if (_hasCacheLoaded) return;
    
    _isLoadingCacheNotifier.value = true;
    
    try {
      final cachedMessages = await MessageCacheManager.getCachedMessages(widget.user.id);
      if (cachedMessages != null && cachedMessages.isNotEmpty && mounted) {
        _list = cachedMessages;
        _previousMessageList = List.from(cachedMessages);
        _hasCacheLoaded = true;
        log('Loaded ${cachedMessages.length} cached messages for user ${widget.user.id}');
      }
    } catch (e) {
      log('Error loading cached messages: $e');
    } finally {
      if (mounted) {
        _isLoadingCacheNotifier.value = false;
      }
    }
  }

  // ✅ مقارنة الرسائل لتجنب إعادة المعالجة غير الضرورية
  bool _messagesAreEqual(List<Message> newMessages, List<Message> previousMessages) {
    if (newMessages.length != previousMessages.length) return false;
    
    for (int i = 0; i < newMessages.length; i++) {
      final newMsg = newMessages[i];
      final prevMsg = previousMessages[i];
      
      if (newMsg.id != prevMsg.id || 
          newMsg.msg != prevMsg.msg || 
          newMsg.read != prevMsg.read ||
          newMsg.sent != prevMsg.sent) {
        return false;
      }
    }
    
    return true;
  }

  // ✅ إزالة الرسائل المعلقة التي تم تأكيدها - مع دعم تطابق الملفات المحسن
  void _removePendingMessages() {
    final currentPendingMessages = _pendingMessagesNotifier.value;
    final now = DateTime.now().millisecondsSinceEpoch;
    final initialCount = currentPendingMessages.length;
    
    final updatedPendingMessages = currentPendingMessages.where((pending) {
      // Fallback: إذا بقيت الرسالة المؤقتة أكثر من دقيقة ولم يتم تأكيدها، احذفها تلقائيًا
      final sentTime = int.tryParse(pending.sent) ?? 0;
      if (now - sentTime > 60000) {
        log('[PENDING TIMEOUT] Removing expired pending message: ${pending.msg}');
        return false;
      }
      
      // التطابق الذكي مع الرسائل المؤكدة
      final hasMatch = _list.any((confirmed) => _areMessagesEquivalent(pending, confirmed));
      if (hasMatch) {
        log('[PENDING MATCHED] Removing matched pending message: ${pending.msg}');
        return false;
      }
      
      return true; // keep pending message
    }).toList();
    
    if (updatedPendingMessages.length != currentPendingMessages.length) {
      final removedCount = currentPendingMessages.length - updatedPendingMessages.length;
      log('[PENDING CLEANUP] Removed $removedCount pending messages (${initialCount} -> ${updatedPendingMessages.length})');
      _pendingMessagesNotifier.value = updatedPendingMessages;
    }
  }
  
  // ✅ فحص تطابق الرسائل مع دعم الملفات والوسائط بشكل ذكي
  bool _areMessagesEquivalent(Message pending, Message confirmed) {
    if (pending.fromId != confirmed.fromId) return false;
    if (pending.type != confirmed.type) return false;
    // فارق زمني أوسع (15 ثانية)
    final timeDiff = (int.parse(confirmed.sent) - int.parse(pending.sent)).abs();
    if (timeDiff > 15000) return false;
    
    // للملفات/الصور/الفيديو/الصوت: تطابق اسم الملف المحسن
    if (pending.type == Type.file || pending.type == Type.image || pending.type == Type.video || pending.type == Type.audio) {
      return _areFileMessagesEquivalent(pending, confirmed);
    }
    
    // للرسائل النصية: تطابق المحتوى
    final isTextMatch = pending.msg == confirmed.msg;
    if (!isTextMatch) {
      log('[TEXT MATCH FAIL] pending: ${pending.msg}, confirmed: ${confirmed.msg}');
    }
    return isTextMatch;
  }
  
  // ✅ فحص تطابق الملفات المحسن مع دعم مسارات مختلفة
  bool _areFileMessagesEquivalent(Message pending, Message confirmed) {
    // 1. فحص حجم الملف أولاً (الأكثر موثوقية)
    if (pending.fileSize != null && confirmed.fileSize != null && 
        pending.fileSize! > 0 && confirmed.fileSize! > 0) {
      final sizeDiff = (pending.fileSize! - confirmed.fileSize!).abs();
      if (sizeDiff > 2000) { // سماحية 2KB
        log('[FILE SIZE MISMATCH] pending: ${pending.fileSize}, confirmed: ${confirmed.fileSize}');
        return false;
      }
    }
    
    // 2. استخراج أسماء الملفات
    final pendingFileName = _extractCleanFileName(pending.msg);
    final confirmedFileName = _extractCleanFileName(confirmed.msg);
    
    // 3. مقارنة مُحسّنة لأسماء الملفات
    final isFileNameMatch = _doFileNamesMatch(pendingFileName, confirmedFileName);
    
    if (!isFileNameMatch) {
      log('[FILE NAME MISMATCH] pending: "$pendingFileName", confirmed: "$confirmedFileName"');
      log('[ORIGINAL PATHS] pending: "${pending.msg}", confirmed: "${confirmed.msg}"');
    }
    
    return isFileNameMatch;
  }
  
  // ✅ استخراج اسم الملف النظيف من أي مسار
  String _extractCleanFileName(String path) {
    try {
      // استخراج اسم الملف من المسار
      String fileName = path.split('/').last;
      
      // إزالة أي باراميتر بعد ؟ في URL
      if (fileName.contains('?')) {
        fileName = fileName.split('?').first;
      }
      
      // إزالة أي رقم timestamp في البداية (مثل 1234567890_file.pdf)
      if (fileName.contains('_')) {
        final parts = fileName.split('_');
        if (parts.length > 1 && int.tryParse(parts[0]) != null) {
          fileName = parts.skip(1).join('_');
        }
      }
      
      return fileName.toLowerCase().trim();
    } catch (e) {
      return path.toLowerCase().trim();
    }
  }
  
  // ✅ مقارنة أسماء الملفات مع دعم حالات مختلفة
  bool _doFileNamesMatch(String fileName1, String fileName2) {
    // 1. مقارنة مباشرة
    if (fileName1 == fileName2) return true;
    
    // 2. إزالة الامتداد والمقارنة
    final name1WithoutExt = fileName1.contains('.') ? fileName1.split('.').first : fileName1;
    final name2WithoutExt = fileName2.contains('.') ? fileName2.split('.').first : fileName2;
    
    if (name1WithoutExt == name2WithoutExt) return true;
    
    // 3. فحص إذا كان أحدهما يحتوي على الآخر (للملفات المُعاد تسميتها)
    if (name1WithoutExt.contains(name2WithoutExt) || name2WithoutExt.contains(name1WithoutExt)) {
      return true;
    }
    
    // 4. إزالة أي timestamp إضافي وإعادة المقارنة
    final cleanName1 = _removeTimestampFromName(name1WithoutExt);
    final cleanName2 = _removeTimestampFromName(name2WithoutExt);
    
    return cleanName1 == cleanName2;
  }
  
  // ✅ إزالة أي timestamp من اسم الملف
  String _removeTimestampFromName(String name) {
    // إزالة أي رقم في البداية أو النهاية
    String cleaned = name.replaceAll(RegExp(r'^\d+_'), '').replaceAll(RegExp(r'_\d+$'), '');
    
    // إزالة أي تاريخ/وقت بصيغة مختلفة
    cleaned = cleaned.replaceAll(RegExp(r'\d{4}-\d{2}-\d{2}'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\d{2}-\d{2}-\d{4}'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\d{8,}'), ''); // أي رقم طويل
    
    // تنظيف النتيجة
    cleaned = cleaned.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
    
    return cleaned.trim();
  }

  // ✅ توحيد اسم الملف للمقارنة (محسن) - محفوظ للتوافق مع الخلف
  String _normalizeFileName(String fileName) {
    return _extractCleanFileName(fileName);
  }

  // ✅ استخراج اسم الملف بذكاء (محسن) - محفوظ للتوافق مع الخلف
  String _smartExtractFileName(String path) {
    return _extractCleanFileName(path);
  }
  
  // دالة مساعدة لاستخراج اسم الملف من المسار
  String _extractFileName(String path) {
    try {
      return path.split('/').last;
    } catch (e) {
      return path;
    }
  }

  // ✅ إنشاء رسالة فورية للعرض مع timestamp فريد
  Message _createOptimisticMessage(String content, Type type, {String? fileName, int? fileSize}) {
    String effectiveFileName = fileName ?? _extractFileName(content);
    if (effectiveFileName.isEmpty && content.isNotEmpty) {
      effectiveFileName = content.split('/').last; // Fallback to last segment of path
    }

    return Message(
      msg: content,
      toId: widget.user.id,
      read: '',
      type: type,
      sent: DateTime.now().millisecondsSinceEpoch.toString(),
      fromId: APIs.me!.id,
      fileName: effectiveFileName.isEmpty ? null : effectiveFileName,
      fileSize: fileSize,
    );
  }

  // ✅ تحديد إصدار Android للتعامل مع الصلاحيات المناسبة - بدون setState
  Future<void> _initializeAndroidVersion() async {
    if (Platform.isAndroid) {
      try {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        _androidSdkVersion = androidInfo.version.sdkInt;
        log('Android SDK Version: $_androidSdkVersion');
      } catch (e) {
        log('Error getting Android version: $e');
        _androidSdkVersion = 30; // fallback to Android 11
      }
    }
  }

  // ✅ فحص الصلاحيات الأساسية
  Future<void> _checkBasicPermissions() async {
    if (!Platform.isAndroid) return;
    try {
      await Permission.microphone.status;
      await Permission.camera.status;
    } catch (e) {
      log('Error checking basic permissions: $e');
    }
  }

  // ✅ ====== نظام الصلاحيات المتقدم لجميع إصدارات Android ======

  /// طلب صلاحيات التخزين حسب إصدار Android
  Future<bool> _requestStoragePermissions() async {
    if (!Platform.isAndroid) return true;
    try {
      log('🔍 Checking storage permissions for Android SDK $_androidSdkVersion');
      
      // Android 13+ (API 33+): صلاحيات الوسائط المحددة
      if (_androidSdkVersion >= 33) {
        log('📱 Android 13+ detected, requesting granular media permissions');
        
        // Check current status first
        final imageStatus = await Permission.photos.status;
        final videoStatus = await Permission.videos.status;
        final audioStatus = await Permission.audio.status;
        
        log('Current permissions - Photos: $imageStatus, Videos: $videoStatus, Audio: $audioStatus');
        
        // Request permissions if not granted
        Map<Permission, PermissionStatus> permissions = {};
        
        if (!imageStatus.isGranted) {
          permissions[Permission.photos] = await Permission.photos.request();
        } else {
          permissions[Permission.photos] = imageStatus;
        }
        
        if (!videoStatus.isGranted) {
          permissions[Permission.videos] = await Permission.videos.request();
        } else {
          permissions[Permission.videos] = videoStatus;
        }
        
        if (!audioStatus.isGranted) {
          permissions[Permission.audio] = await Permission.audio.request();
        } else {
          permissions[Permission.audio] = audioStatus;
        }

        log('Final permissions - Photos: ${permissions[Permission.photos]}, Videos: ${permissions[Permission.videos]}, Audio: ${permissions[Permission.audio]}');

        // For image picker, we specifically need photos permission
        final hasPhotoAccess = permissions[Permission.photos]?.isGranted ?? false;
        
        if (!hasPhotoAccess) {
          log('❌ Photos permission not granted, showing dialog');
          await _showMedia13PermissionDialog();
        }
        
        return hasPhotoAccess;
      }
      // Android 11-12 (API 30-32): MANAGE_EXTERNAL_STORAGE
      else if (_androidSdkVersion >= 30) {
        log('📱 Android 11-12 detected, checking MANAGE_EXTERNAL_STORAGE');
        final manageStorage = await Permission.manageExternalStorage.status;
        log('Current MANAGE_EXTERNAL_STORAGE status: $manageStorage');
        
        if (manageStorage.isGranted) {
          return true;
        }

        // طلب MANAGE_EXTERNAL_STORAGE
        final result = await Permission.manageExternalStorage.request();
        log('MANAGE_EXTERNAL_STORAGE request result: $result');
        
        if (result.isGranted) {
          return true;
        } else if (result.isPermanentlyDenied) {
          await _showManageStorageDialog();
          return false;
        }

        return false;
      }
      // Android 10 وأقل (API 29-): صلاحيات التخزين التقليدية
      else {
        log('📱 Android 10 or lower detected, using legacy storage permission');
        final storagePermission = await Permission.storage.request();
        log('Storage permission result: $storagePermission');
        
        if (storagePermission.isPermanentlyDenied) {
          await _showStoragePermissionDialog();
          return false;
        }

        return storagePermission.isGranted;
      }
    } catch (e) {
      log('❌ Error requesting storage permissions: $e');
      return false;
    }
  }

  /// طلب صلاحية الكاميرا
  Future<bool> _requestCameraPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final permission = await Permission.camera.request();
      if (permission.isGranted) {
        return true;
      } else if (permission.isPermanentlyDenied) {
        await _showCameraPermissionDialog();
        return false;
      }

      return false;
    } catch (e) {
      log('Error requesting camera permission: $e');
      return false;
    }
  }

  /// طلب صلاحية الميكروفون
  Future<bool> _requestMicrophonePermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final permission = await Permission.microphone.request();
      if (permission.isGranted) {
        return true;
      } else if (permission.isPermanentlyDenied) {
        await _showMicrophonePermissionDialog();
        return false;
      }

      return false;
    } catch (e) {
      log('Error requesting microphone permission: $e');
      return false;
    }
  }

  /// طلب صلاحيات شاملة للملفات والفيديو
  Future<bool> _requestFileAndVideoPermissions() async {
    if (!Platform.isAndroid) return true;
    try {
      // Android 13+: صلاحيات محددة للوسائط
      if (_androidSdkVersion >= 33) {
        final permissions = await [
          Permission.photos,
          Permission.videos,
          Permission.audio,
        ].request();

        bool hasAnyPermission = permissions.values.any((status) => status.isGranted);
        if (!hasAnyPermission) {
          await _showMedia13PermissionDialog();
        }

        return hasAnyPermission;
      }
      // Android 11+: MANAGE_EXTERNAL_STORAGE مطلوب
      else if (_androidSdkVersion >= 30) {
        final manageStorage = await Permission.manageExternalStorage.status;
        if (manageStorage.isGranted) return true;

        final result = await Permission.manageExternalStorage.request();
        if (result.isPermanentlyDenied) {
          await _showManageStorageDialog();
          return false;
        }

        return result.isGranted;
      }
      // Android 10 وأقل
      else {
        return await _requestStoragePermissions();
      }
    } catch (e) {
      log('Error requesting file and video permissions: $e');
      return false;
    }
  }

  // ✅ ====== حوارات الصلاحيات المخصصة ======

  Future<void> _showManageStorageDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.folder_open, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('صلاحية إدارة الملفات'),
          ],
        ),
        content: const Text(
          'للتمكن من إرسال واستقبال الملفات والفيديوهات، يحتاج التطبيق إلى صلاحية "إدارة جميع الملفات".\n\n'
              'في الصفحة التالية:\n'
              '1. ابحث عن هذا التطبيق\n'
              '2. فعّل "السماح بإدارة جميع الملفات"',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            icon: const Icon(Icons.settings, size: 18),
            label: const Text('فتح الإعدادات'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showMedia13PermissionDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.perm_media, color: Colors.blue, size: 28),
            SizedBox(width: 8),
            Text('صلاحيات الوسائط'),
          ],
        ),
        content: const Text(
          'لإرسال الصور والفيديوهات والملفات الصوتية، يحتاج التطبيق إلى صلاحيات الوصول للوسائط.\n\n'
              'يرجى منح الصلاحيات المطلوبة من إعدادات التطبيق.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            icon: const Icon(Icons.settings, size: 18),
            label: const Text('فتح الإعدادات'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showStoragePermissionDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.storage, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('صلاحية التخزين'),
          ],
        ),
        content: const Text(
          'لإرسال واستقبال الملفات، يحتاج التطبيق إلى صلاحية الوصول للتخزين.\n\n'
              'يرجى منح الصلاحية من إعدادات التطبيق.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            icon: const Icon(Icons.settings, size: 18),
            label: const Text('فتح الإعدادات'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCameraPermissionDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.camera_alt, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('صلاحية الكاميرا'),
          ],
        ),
        content: const Text(
          'لالتقاط الصور، يحتاج التطبيق إلى صلاحية الكاميرا.\n\n'
              'يرجى منح الصلاحية من إعدادات التطبيق.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            icon: const Icon(Icons.settings, size: 18),
            label: const Text('فتح الإعدادات'),
          ),
        ],
      ),
    );
  }

  Future<void> _showMicrophonePermissionDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.mic, color: Colors.purple, size: 28),
            SizedBox(width: 8),
            Text('صلاحية الميكروفون'),
          ],
        ),
        content: const Text(
          'لتسجيل الرسائل الصوتية، يحتاج التطبيق إلى صلاحية الميكروفون.\n\n'
              'يرجى منح الصلاحية من إعدادات التطبيق.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            icon: const Icon(Icons.settings, size: 18),
            label: const Text('فتح الإعدادات'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleScreenTap,
      child: PopScope(
        canPop: !_isRecordingAudioNotifier.value,
        onPopInvoked: _handleBackPress,
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            flexibleSpace: _buildAppBar(),
            elevation: 1,
          ),
          backgroundColor: context.appTheme.surfaceColor.withValues(alpha: 0.98),
          body: SafeArea(
            child: Column(
              children: [
                // ✅ مؤشر التقدم المحسن مع فلترة المحادثة
                _EnhancedUploadIndicator(
                  isUploadingNotifier: _isUploadingNotifier,
                  user: widget.user,
                ),
                Expanded(child: _buildMessagesList()),
                _InputArea(
                  isRecordingNotifier: _isRecordingAudioNotifier,
                  textController: _textController,
                  inputFocusNode: _inputFocusNode,
                  showEmojiNotifier: _showEmojiNotifier,
                  user: widget.user,
                  messagesList: _list,
                  onAudioRecordComplete: _handleAudioRecordComplete,
                  onShowAttachment: _showAttachmentSheet,
                  onUploadingChanged: (value) => _isUploadingNotifier.value = value,
                  onRequestMicrophonePermission: _requestMicrophonePermission,
                  onSendMessage: (messageText) => _sendMessage(messageText),
                ),
                _EmojiSection(
                  showEmojiNotifier: _showEmojiNotifier,
                  textController: _textController,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleScreenTap() {
    FocusScope.of(context).unfocus();
    _showEmojiNotifier.value = false;
  }

  void _handleBackPress(bool didPop) {
    _showEmojiNotifier.value = false;
  }

  void _sendMessage(String messageText) {
    if (messageText.isNotEmpty) {
      // Clear input immediately for better UX
      _textController.clear();

      // Send message immediately without Future.microtask delay
      _sendMessageAsync(messageText);
    }
  }

  Future<void> _sendMessageAsync(String messageText) async {
    // ✅ 1. إنشاء رسالة فورية
    final optimisticMessage = _createOptimisticMessage(messageText, Type.text);
    
    // ✅ 2. إضافة الرسالة فوراً للعرض باستخدام ValueNotifier
    final currentPendingMessages = _pendingMessagesNotifier.value;
    _pendingMessagesNotifier.value = [optimisticMessage, ...currentPendingMessages];
    
    // ✅ 3. إرسال الرسالة في الخلفية
    try {
      if (_list.isEmpty) {
        await APIs.sendFirstMessage(widget.user, messageText, Type.text);
      } else {
        await APIs.sendMessage(widget.user, messageText, Type.text);
      }
      
      // ✅ 4. إضافة الرسالة للكاش بعد الإرسال الناجح
      MessageCacheManager.addMessageToCache(widget.user.id, optimisticMessage);
      
    } catch (e) {
      // ✅ 5. في حالة الفشل، تحديث حالة الرسالة باستخدام ValueNotifier
      final currentMessages = _pendingMessagesNotifier.value;
      final index = currentMessages.indexWhere((msg) => msg.id == optimisticMessage.id);
      if (index != -1) {
        final updatedMessages = List<Message>.from(currentMessages);
        updatedMessages[index] = Message(
          msg: messageText,
          toId: widget.user.id,
          read: 'failed', // ✅ تحديد حالة الفشل
          type: Type.text,
          sent: optimisticMessage.sent,
          fromId: APIs.me!.id,
        );
        _pendingMessagesNotifier.value = updatedMessages;
      }
      log('Error sending message: $e');
    }
  }

  // ✅ تحديث لاستخدام getAllMessagesFiltered بدلاً من getAllMessages مع تحسين الأداء
  Widget _buildMessagesList() {
    return StreamBuilder(
      // ✅ استخدام الدالة المفلترة الجديدة مباشرة بدون ValueListenableBuilder
      stream: APIs.getAllMessagesFiltered(widget.user),
      builder: (context, snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.waiting:
          case ConnectionState.none:
            return const SizedBox.shrink();
          case ConnectionState.active:
          case ConnectionState.done:
            final data = snapshot.data?.docs;
            final newMessageList = data?.map((e) => Message.fromJson(e.data())).toList() ?? [];
            
            // ✅ تجنب إعادة المعالجة إذا لم تتغير الرسائل
            if (_messagesAreEqual(newMessageList, _previousMessageList)) {
              return ValueListenableBuilder<List<Message>>(
                valueListenable: _pendingMessagesNotifier,
                builder: (context, pendingMessages, child) {
                  final allMessages = [...pendingMessages, ..._list];
                  return allMessages.isNotEmpty
                      ? _MessagesList(messages: allMessages)
                      : const _EmptyState();
                },
              );
            }
            
            // ✅ تحديث القائمة فقط إذا تغيرت
            _list = newMessageList;
            _previousMessageList = List.from(newMessageList);
            
            // ✅ حفظ الرسائل الجديدة في الكاش
            if (newMessageList.isNotEmpty) {
              MessageCacheManager.cacheMessages(widget.user.id, newMessageList);
            }
            
            // ✅ إزالة الرسائل المعلقة التي تم تأكيدها
            _removePendingMessages();
            
            // ✅ استخدام ValueListenableBuilder للرسائل المعلقة
            return ValueListenableBuilder<List<Message>>(
              valueListenable: _pendingMessagesNotifier,
              builder: (context, pendingMessages, child) {
                final allMessages = [...pendingMessages, ..._list];

                return allMessages.isNotEmpty
                    ? _MessagesList(messages: allMessages)
                    : const _EmptyState();
              },
            );
        }
      },
    );
  }

  Widget _buildAppBar() {
    final appBarForegroundColor = Theme.of(context).appBarTheme.foregroundColor ??
        context.appTheme.textPrimaryColor;

    return SafeArea(
      child: StreamBuilder(
        stream: APIs.getUserInfo(widget.user),
        builder: (context, snapshot) {
          final data = snapshot.data?.docs;
          final list = data?.map((e) => ChatUser.fromJson(e.data())).toList() ?? [];
          final displayUser = list.isNotEmpty ? list[0] : widget.user;

          // ✅ تحديث: إضافة خيارات المحادثة
          return _AppBarContent(
            user: displayUser,
            originalUser: widget.user,
            foregroundColor: appBarForegroundColor,
            onClearChat: _showClearChatDialog,
            onDeleteChat: _showDeleteChatDialog,
          );
        },
      ),
    );
  }

  Future<void> _handleAudioRecordComplete(String audioPath, int duration) async {
    if (!mounted) return;
    _isRecordingAudioNotifier.value = false;

    // ✅ 1. إنشاء رسالة فورية للتسجيل الصوتي
    final optimisticMessage = _createOptimisticMessage(audioPath, Type.audio);
    
    // ✅ 2. إضافة الرسالة فوراً للعرض باستخدام ValueNotifier
    final currentPendingMessages = _pendingMessagesNotifier.value;
    _pendingMessagesNotifier.value = [optimisticMessage, ...currentPendingMessages];

    try {
      await APIs.sendChatAudio(widget.user, File(audioPath), duration);
    } catch (e) {
      log("Error sending audio: $e");
      if (mounted) {
        Dialogs.showSnackbar(context, 'فشل إرسال التسجيل الصوتي.');
      }
    }
  }

  // ✅ عرض قائمة المرفقات مع فحص الصلاحيات المحسن
  Future<void> _showAttachmentSheet() async {
    FocusScope.of(context).unfocus();
    _showEmojiNotifier.value = false;

    if (mounted) {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        builder: (_) => _AttachmentBottomSheet(
          user: widget.user,
          onUploadingChanged: (value) => _isUploadingNotifier.value = value,
          onRequestStoragePermissions: _requestStoragePermissions,
          onRequestFileAndVideoPermissions: _requestFileAndVideoPermissions,
          onRequestCameraPermission: _requestCameraPermission,
          onOptimisticMessageAdd: (message) {
            final currentPendingMessages = _pendingMessagesNotifier.value;
            _pendingMessagesNotifier.value = [message, ...currentPendingMessages];
          },
          onCreateOptimisticMessage: _createOptimisticMessage,
        ),
      );
    }
  }

  // ✅ إضافة حوار مسح الرسائل
  void _showClearChatDialog(BuildContext dialogContext) {
    showDialog(
      context: dialogContext,
      builder: (context) => AlertDialog(
        backgroundColor: context.appTheme.surfaceColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        title: Row(
          children: [
            Icon(Icons.clear_all, color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            Text(
              'مسح الرسائل',
              style: TextStyle(color: context.appTheme.textPrimaryColor),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'هل تريد مسح جميع الرسائل في المحادثة مع ${widget.user.name}؟',
              style: TextStyle(
                color: context.appTheme.textPrimaryColor,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ستختفي جميع الرسائل من محادثتك فقط ولن يتأثر الطرف الآخر',
                      style: TextStyle(
                        color: context.appTheme.textSecondaryColor,
                        fontSize: 13,
                      ),
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
            child: Text(
              'إلغاء',
              style: TextStyle(color: context.appTheme.accentColor, fontSize: 16),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await APIs.clearChatForMe(widget.user.id);
                if (mounted) {
                  Dialogs.showSnackbar(context, 'تم مسح جميع الرسائل من محادثتك');
                }
              } catch (e) {
                log('Error clearing chat: $e');
                if (mounted) {
                  Dialogs.showSnackbar(context, 'فشل في مسح الرسائل');
                }
              }
            },
            child: Text(
              'مسح',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ إضافة حوار حذف المحادثة
  void _showDeleteChatDialog(BuildContext dialogContext) {
    showDialog(
      context: dialogContext,
      builder: (context) => AlertDialog(
        backgroundColor: context.appTheme.surfaceColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            Text(
              'حذف المحادثة',
              style: TextStyle(color: context.appTheme.textPrimaryColor),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'هل تريد حذف المحادثة مع ${widget.user.name}؟',
              style: TextStyle(
                color: context.appTheme.textPrimaryColor,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.red.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ستختفي المحادثة من قائمتك فقط ولن تتأثر للطرف الآخر',
                      style: TextStyle(
                        color: context.appTheme.textSecondaryColor,
                        fontSize: 13,
                      ),
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
            child: Text(
              'إلغاء',
              style: TextStyle(color: context.appTheme.accentColor, fontSize: 16),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // إغلاق الحوار

              try {
                await APIs.deleteChatForMe(widget.user.id);
                if (mounted) {
                  Navigator.pop(context); // العودة للشاشة الرئيسية
                  Dialogs.showSnackbar(context, 'تم حذف المحادثة من قائمتك');
                }
              } catch (e) {
                log('Error deleting chat: $e');
                if (mounted) {
                  Dialogs.showSnackbar(context, 'فشل في حذف المحادثة');
                }
              }
            },
            child: Text(
              'حذف',
              style: TextStyle(
                color: Colors.red,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ✅ مؤشر التحميل المحسن مع فلترة حسب المحادثة
class _EnhancedUploadIndicator extends BaseStatelessWidget {
  final ValueNotifier<bool> isUploadingNotifier;
  final ChatUser user;

  const _EnhancedUploadIndicator({
    required this.isUploadingNotifier,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, UploadProgress>>(
      valueListenable: APIs.uploadProgressNotifier,
      builder: (context, progressMap, child) {
        // ✅ فلترة العمليات للمحادثة الحالية فقط
        final currentConversationId = APIs.getConversationID(user.id);
        if (currentConversationId == null) {
          return const SizedBox.shrink();
        }

        final relevantProgress = progressMap.values
            .where((progress) =>
        progress.conversationId == currentConversationId &&
            progress.status != UploadStatus.completed &&
            progress.status != UploadStatus.cancelled &&
            !progress.isExpired
        )
            .toList();

        // ✅ إخفاء المؤشر إذا لم توجد عمليات للمحادثة الحالية
        if (relevantProgress.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: context.appTheme.surfaceColor.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: relevantProgress.map((progress) {
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _getUploadMessage(progress.status, progress.fileName),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: context.appTheme.onSurface.withValues(alpha: 0.8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              '${(progress.progress * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 12,
                                color: _getStatusColor(context, progress.status),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildActionButton(progress),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: progress.progress,
                        backgroundColor: Colors.grey.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation(
                          _getStatusColor(context, progress.status),
                        ),
                        minHeight: 3,
                      ),
                    ),
                    if (progress.status == UploadStatus.failed && progress.errorMessage != null)
                      _buildErrorMessage(progress.errorMessage!),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildActionButton(UploadProgress progress) {
    switch (progress.status) {
      case UploadStatus.uploading:
        return InkWell(
          onTap: () => APIs.cancelUpload(progress.messageId),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(4),
            child: const Icon(
              Icons.close,
              size: 16,
              color: Colors.red,
            ),
          ),
        );
      case UploadStatus.failed:
        if (progress.canRetry) {
          return InkWell(
            onTap: () => APIs.retryUpload(progress.messageId),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(4),
              child: const Icon(
                Icons.refresh,
                size: 16,
                color: Colors.orange,
              ),
            ),
          );
        }
        break;
      case UploadStatus.retrying:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(Colors.orange),
          ),
        );
      default:
        break;
    }
    return const SizedBox(width: 16);
  }

  Widget _buildErrorMessage(String errorMessage) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 12,
            color: Colors.red.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              errorMessage,
              style: TextStyle(
                fontSize: 10,
                color: Colors.red.withValues(alpha: 0.8),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ رسائل حالة الرفع المحسنة
  String _getUploadMessage(UploadStatus status, String? fileName) {
    final displayName = fileName ?? 'ملف';
    switch (status) {
      case UploadStatus.pending:
        return 'جاري التحضير...';
      case UploadStatus.uploading:
        return 'رفع $displayName...';
      case UploadStatus.retrying:
        return 'إعادة المحاولة...';
      case UploadStatus.completed:
        return 'تم الرفع بنجاح ✓';
      case UploadStatus.failed:
        return 'فشل في رفع $displayName';
      case UploadStatus.cancelled:
        return 'تم الإلغاء';
    }
  }

  // ✅ ألوان حالة الرفع المحسنة
  Color _getStatusColor(BuildContext context, UploadStatus status) {
    switch (status) {
      case UploadStatus.pending:
      case UploadStatus.uploading:
        return context.appTheme.highlightColor;
      case UploadStatus.retrying:
        return Colors.orange;
      case UploadStatus.completed:
        return Colors.green;
      case UploadStatus.failed:
        return Colors.red;
      case UploadStatus.cancelled:
        return Colors.grey;
    }
  }
}

// ✅ باقي المكونات محسنة مع عدم التكرار

class _MessagesList extends BaseStatefulWidget {
  final List<Message> messages;

  const _MessagesList({super.key, required this.messages});

  @override
  State<_MessagesList> createState() => _MessagesListState();
}

class _MessagesListState extends BaseState<_MessagesList> {
  final ScrollController _scrollController = ScrollController();
  List<Message> _previousMessages = [];

  @override
  void initState() {
    super.initState();
    _previousMessages = List.from(widget.messages);
  }

  @override
  void didUpdateWidget(_MessagesList oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Check if new messages were added
    if (widget.messages.length > _previousMessages.length) {
      // Auto-scroll to bottom when new messages arrive
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0, // Because reverse: true, 0 is the bottom
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
    
    _previousMessages = List.from(widget.messages);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      itemCount: widget.messages.length,
      padding: EdgeInsets.only(top: mq.height * .01, bottom: 4),
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final message = widget.messages[index];
        final isPending = message.id.startsWith('pending_');
        final isFailed = message.read == 'failed';
        
        return RepaintBoundary(
          child: MessageCard(
            key: ValueKey(message.id), // ✅ استخدام ID أفضل للمفاتيح
            message: message,
            isPending: isPending,
            isFailed: isFailed,
          ),
        );
      },
    );
  }
}

class _EmptyState extends BaseStatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'بدء محادثة آمنة 💬',
        style: TextStyle(
          fontSize: 20,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

// ✅ تحديث _AppBarContent لإضافة خيارات المحادثة
class _AppBarContent extends BaseStatelessWidget {
  final ChatUser user;
  final ChatUser originalUser;
  final Color foregroundColor;
  final Function(BuildContext) onClearChat;
  final Function(BuildContext) onDeleteChat;

  const _AppBarContent({
    required this.user,
    required this.originalUser,
    required this.foregroundColor,
    required this.onClearChat,
    required this.onDeleteChat,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: foregroundColor,
              size: 24,
            ),
          ),
          // معلومات المستخدم (قابلة للنقر لعرض الملف الشخصي)
          Expanded(
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ViewProfileScreen(user: originalUser),
                ),
              ),
              child: Row(
                children: [
                  ProfileImage(size: mq.height * .045, url: user.image),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: TextStyle(
                            fontSize: 16,
                            color: foregroundColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.isOnline
                              ? 'متصل الآن'
                              : MyDateUtil.getLastActiveTime(
                            context: context,
                            lastActive: user.lastActive,
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: foregroundColor.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ✅ إضافة قائمة خيارات المحادثة
          PopupMenuButton<String>(
            onSelected: (value) {
              try {
                debugPrint('[PopupMenuButton] onSelected: $value');
                _handleMenuSelection(context, value);
              } catch (e, s) {
                debugPrint('PopupMenuButton onSelected error: $e\n$s');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('حدث خطأ أثناء تنفيذ الخيار. يرجى إعادة المحاولة.')),
                  );
                }
              }
            },
            itemBuilder: (context) {
              try {
                debugPrint('[PopupMenuButton] itemBuilder invoked');
                // تحقق من أن المتغيرات الأساسية ليست null
                if (user == null || originalUser == null || foregroundColor == null) {
                  return [
                    const PopupMenuItem(
                      value: 'error',
                      child: Text('حدث خطأ في القائمة'),
                    ),
                  ];
                }
                return [
                  const PopupMenuItem(
                    value: 'clear_chat',
                    child: Row(
                      children: [
                        Icon(Icons.clear_all, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Text('مسح الرسائل'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete_chat',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text('حذف المحادثة', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ];
              } catch (e, s) {
                debugPrint('PopupMenuButton itemBuilder error: $e\n$s');
                return [
                  const PopupMenuItem(
                    value: 'error',
                    child: Text('حدث خطأ في القائمة'),
                  ),
                ];
              }
            },
            icon: Icon(Icons.more_vert, color: foregroundColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ معالجة اختيارات القائمة
  void _handleMenuSelection(BuildContext context, String value) {
    switch (value) {
      case 'clear_chat':
        onClearChat(context);
        break;
      case 'delete_chat':
        onDeleteChat(context);
        break;
    }
  }
}

class _InputArea extends BaseStatelessWidget {
  final ValueNotifier<bool> isRecordingNotifier;
  final TextEditingController textController;
  final FocusNode inputFocusNode;
  final ValueNotifier<bool> showEmojiNotifier;
  final ChatUser user;
  final List<Message> messagesList;
  final Function(String, int) onAudioRecordComplete;
  final VoidCallback onShowAttachment;
  final Function(bool) onUploadingChanged;
  final Future<bool> Function() onRequestMicrophonePermission;
  final void Function(String) onSendMessage;

  const _InputArea({
    required this.isRecordingNotifier,
    required this.textController,
    required this.inputFocusNode,
    required this.showEmojiNotifier,
    required this.user,
    required this.messagesList,
    required this.onAudioRecordComplete,
    required this.onShowAttachment,
    required this.onUploadingChanged,
    required this.onRequestMicrophonePermission,
    required this.onSendMessage,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: isRecordingNotifier,
      builder: (context, child) {
        return isRecordingNotifier.value
            ? AudioRecorderWidget(
          onRecordComplete: onAudioRecordComplete,
          onCancel: () => isRecordingNotifier.value = false,
        )
            : _ChatInput(
          textController: textController,
          inputFocusNode: inputFocusNode,
          showEmojiNotifier: showEmojiNotifier,
          isRecordingNotifier: isRecordingNotifier,
          user: user,
          messagesList: messagesList,
          onShowAttachment: onShowAttachment,
          onRequestMicrophonePermission: onRequestMicrophonePermission,
          onSendMessage: onSendMessage,
        );
      },
    );
  }
}

class _ChatInput extends BaseStatelessWidget {
  final TextEditingController textController;
  final FocusNode inputFocusNode;
  final ValueNotifier<bool> showEmojiNotifier;
  final ValueNotifier<bool> isRecordingNotifier;
  final ChatUser user;
  final List<Message> messagesList;
  final VoidCallback onShowAttachment;
  final Future<bool> Function() onRequestMicrophonePermission;
  final void Function(String) onSendMessage;

  const _ChatInput({
    required this.textController,
    required this.inputFocusNode,
    required this.showEmojiNotifier,
    required this.isRecordingNotifier,
    required this.user,
    required this.messagesList,
    required this.onShowAttachment,
    required this.onRequestMicrophonePermission,
    required this.onSendMessage,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: mq.height * .01,
        horizontal: mq.width * .025,
      ),
      child: Row(
        children: [
          Expanded(
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Row(
                children: [
                  _EmojiToggleButton(showEmojiNotifier: showEmojiNotifier),
                  Expanded(
                    child: TextField(
                      controller: textController,
                      focusNode: inputFocusNode,
                      keyboardType: TextInputType.multiline,
                      maxLines: null,
                      minLines: 1,
                      onTap: () => showEmojiNotifier.value = false,
                      decoration: InputDecoration(
                        hintText: 'رسالة آمنة...',
                        hintStyle: TextStyle(
                          color: context.appTheme.onSurface.withValues(alpha: 0.5),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onShowAttachment,
                    icon: Icon(
                      Icons.attach_file_rounded,
                      color: context.appTheme.secondary,
                      size: 26,
                    ),
                  ),
                  SizedBox(width: mq.width * .01),
                ],
              ),
            ),
          ),
          SizedBox(width: mq.width * .015),
          _SendButton(
            textController: textController,
            isRecordingNotifier: isRecordingNotifier,
            user: user,
            onRequestMicrophonePermission: onRequestMicrophonePermission,
            onSendMessage: onSendMessage,
          ),
        ],
      ),
    );
  }
}

class _EmojiToggleButton extends BaseStatelessWidget {
  final ValueNotifier<bool> showEmojiNotifier;

  const _EmojiToggleButton({required this.showEmojiNotifier});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: showEmojiNotifier,
      builder: (context, child) {
        return IconButton(
          onPressed: () {
            FocusScope.of(context).unfocus();
            showEmojiNotifier.value = !showEmojiNotifier.value;
          },
          icon: Icon(
            showEmojiNotifier.value ? Icons.keyboard : Icons.emoji_emotions_outlined,
            color: context.appTheme.secondary,
            size: 26,
          ),
        );
      },
    );
  }
}

class _SendButton extends BaseStatelessWidget {
  final TextEditingController textController;
  final ValueNotifier<bool> isRecordingNotifier;
  final ChatUser user;
  final Future<bool> Function() onRequestMicrophonePermission;
  final void Function(String) onSendMessage;

  const _SendButton({
    required this.textController,
    required this.isRecordingNotifier,
    required this.user,
    required this.onRequestMicrophonePermission,
    required this.onSendMessage,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: textController,
      builder: (context, textValue, child) {
        final bool isTextEmpty = textValue.text.trim().isEmpty;

        return FloatingActionButton(
          mini: true,
          backgroundColor: context.appTheme.highlightColor,
          onPressed: () => isTextEmpty ? _startRecording(context) : onSendMessage(textController.text.trim()),
          child: Icon(
            isTextEmpty ? Icons.mic : Icons.send,
            color: context.appTheme.primaryDark,
            size: 20,
          ),
        );
      },
    );
  }

  // ✅ بدء التسجيل مع فحص الصلاحية المحسن
  Future<void> _startRecording(BuildContext context) async {
    final hasPermission = await onRequestMicrophonePermission();
    if (hasPermission) {
      isRecordingNotifier.value = true;
    }
  }
}

class _EmojiSection extends BaseStatelessWidget {
  final ValueNotifier<bool> showEmojiNotifier;
  final TextEditingController textController;

  const _EmojiSection({
    required this.showEmojiNotifier,
    required this.textController,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: showEmojiNotifier,
      builder: (context, child) {
        return showEmojiNotifier.value
            ? SizedBox(
          height: mq.height * .35,
          child: EmojiPicker(
            textEditingController: textController,
            config: Config(
              height: mq.height * .35,
              checkPlatformCompatibility: true,
              emojiViewConfig: EmojiViewConfig(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                buttonMode: ButtonMode.MATERIAL,
                columns: 8,
                emojiSizeMax: 28 * (Platform.isIOS ? 1.20 : 1.0),
              ),
              skinToneConfig: const SkinToneConfig(),
              categoryViewConfig: CategoryViewConfig(
                initCategory: Category.RECENT,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                indicatorColor: context.appTheme.highlightColor,
                iconColorSelected: context.appTheme.highlightColor,
                iconColor: Theme.of(context).colorScheme.secondary,
                dividerColor: Theme.of(context).dividerColor,
              ),
              bottomActionBarConfig: const BottomActionBarConfig(enabled: false),
              searchViewConfig: SearchViewConfig(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                buttonIconColor: context.appTheme.secondary,
                hintText: 'البحث عن إيموجي...',
              ),
            ),
          ),
        )
            : const SizedBox.shrink();
      },
    );
  }
}

// ✅ قائمة المرفقات المحسنة بتصميم WhatsApp
class _AttachmentBottomSheet extends BaseStatelessWidget {
  final ChatUser user;
  final Function(bool) onUploadingChanged;
  final Future<bool> Function() onRequestStoragePermissions;
  final Future<bool> Function() onRequestFileAndVideoPermissions;
  final Future<bool> Function() onRequestCameraPermission;
  final Function(Message) onOptimisticMessageAdd;
  final Message Function(String, Type, {String? fileName, int? fileSize}) onCreateOptimisticMessage;

  const _AttachmentBottomSheet({
    required this.user,
    required this.onUploadingChanged,
    required this.onRequestStoragePermissions,
    required this.onRequestFileAndVideoPermissions,
    required this.onRequestCameraPermission,
    required this.onOptimisticMessageAdd,
    required this.onCreateOptimisticMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.attachment,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'إرسال مرفق آمن',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: context.appTheme.textPrimaryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Attachment options grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _WhatsAppAttachmentOption(
                        icon: Icons.photo_library_rounded,
                        label: 'الاستوديو',
                        color: const Color(0xFF8B5CF6),
                        onTap: () => _handleImagePicker(context, ImageSource.gallery),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _WhatsAppAttachmentOption(
                        icon: Icons.camera_alt_rounded,
                        label: 'الكاميرا',
                        color: const Color(0xFFEF4444),
                        onTap: () => _handleImagePicker(context, ImageSource.camera),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _WhatsAppAttachmentOption(
                        icon: Icons.videocam_rounded,
                        label: 'فيديو',
                        color: const Color(0xFF10B981),
                        onTap: () => _handleVideoPicker(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _WhatsAppAttachmentOption(
                        icon: Icons.description_rounded,
                        label: 'ملف',
                        color: const Color(0xFF3B82F6),
                        onTap: () => _handleFilePicker(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
        ],
      ),
    );
  }

  // ✅ معالجة اختيار الصور مع نظام الأخطاء الموحد
  Future<void> _handleImagePicker(BuildContext context, ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    try {
      // فحص صلاحية الكاميرا أولاً
      if (source == ImageSource.camera) {
        final hasCameraPermission = await onRequestCameraPermission();
        if (!hasCameraPermission) {
          final error = ErrorHandler.handleFileError('Permission denied for camera');
          if (context.mounted) {
            ErrorHandler.showErrorToUser(context, error);
          }
          return;
        }
      }
      // فحص صلاحيات التخزين للصور
      final hasStoragePermission = await onRequestStoragePermissions();
      if (!hasStoragePermission) {
        final error = ErrorHandler.handleFileError('Permission denied for photos');
        if (context.mounted) {
          ErrorHandler.showErrorToUser(context, error);
        }
        return;
      }
      if (source == ImageSource.gallery) {
        try {
          final List<XFile> images = await picker.pickMultiImage(
            imageQuality: 70,
            maxWidth: 1920,
            maxHeight: 1920,
          );
          if (images.isNotEmpty && context.mounted) {
            Navigator.pop(context); // Close attachment sheet
            if (images.length == 1) {
              await _uploadSingleFile(File(images.first.path), APIs.sendChatImage, Type.image);
            } else {
              await _uploadFilesSequentially(
                images.map((img) => File(img.path)).toList(),
                APIs.sendChatImage,
              );
            }
          } else if (context.mounted) {
            final error = ErrorHandler.createUserError('no_image_selected', 'لم يتم اختيار أي صورة');
            ErrorHandler.showErrorToUser(context, error);
          }
        } catch (multiImageError) {
          // Fallback to single image picker
          try {
            final XFile? image = await picker.pickImage(
              source: ImageSource.gallery,
              imageQuality: 70,
              maxWidth: 1920,
              maxHeight: 1920,
            );
            if (image != null && context.mounted) {
              Navigator.pop(context); // Close attachment sheet
              await _uploadSingleFile(File(image.path), APIs.sendChatImage, Type.image);
            } else if (context.mounted) {
              final error = ErrorHandler.createUserError('no_image_selected', 'لم يتم اختيار أي صورة');
              ErrorHandler.showErrorToUser(context, error);
            }
          } catch (singleImageError) {
            final error = ErrorHandler.handleFileError(singleImageError);
            if (context.mounted) {
              ErrorHandler.showErrorToUser(context, error);
            }
          }
        }
      } else {
        // Camera source
        final XFile? image = await picker.pickImage(
          source: source,
          imageQuality: 70,
          maxWidth: 1920,
          maxHeight: 1920,
        );
        if (image != null && context.mounted) {
          Navigator.pop(context); // Close attachment sheet
          await _uploadSingleFile(File(image.path), APIs.sendChatImage, Type.image);
        } else if (context.mounted) {
          final error = ErrorHandler.createUserError('no_image_captured', 'لم يتم التقاط أي صورة');
          ErrorHandler.showErrorToUser(context, error);
        }
      }
    } catch (e, s) {
      log('Error in image picker: $e\n$s');
      final error = ErrorHandler.handleFileError(e);
      if (context.mounted) {
        ErrorHandler.showErrorToUser(context, error);
      }
    }
  }

  // ✅ معالجة اختيار الفيديو مع فحص الصلاحيات المتقدم
  Future<void> _handleVideoPicker(BuildContext context) async {
    try {
      // فحص صلاحيات الملفات والفيديو المتقدمة
      final hasPermission = await onRequestFileAndVideoPermissions();
      if (!hasPermission) {
        return;
      }

      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
      if (video != null && context.mounted) {
        Navigator.pop(context);
        await _uploadSingleFile(File(video.path), APIs.sendChatVideo, Type.video);
      }
    } catch (e) {
      log('Error picking video: $e');
      if (context.mounted) {
        Dialogs.showSnackbar(context, 'فشل في اختيار الفيديو');
      }
    }
  }

  // ✅ معالجة اختيار الملفات مع نظام الأخطاء الموحد
  Future<void> _handleFilePicker(BuildContext context) async {
    try {
      final hasPermission = await onRequestFileAndVideoPermissions();
      if (!hasPermission) {
        final error = ErrorHandler.handleFileError('Permission denied for file');
        if (context.mounted) {
          ErrorHandler.showErrorToUser(context, error);
        }
        return;
      }
      final FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null && context.mounted) {
        Navigator.pop(context);
        final file = result.files.single;
        final optimisticMessage = onCreateOptimisticMessage(
          file.path!,
          Type.file,
          fileName: file.name,
          fileSize: file.size,
        );
        onOptimisticMessageAdd(optimisticMessage);
        onUploadingChanged(true);
        try {
          await APIs.sendChatFile(user, File(file.path!), file.name, file.size ?? 0);
        } finally {
          onUploadingChanged(false);
        }
      } else if (context.mounted) {
        final error = ErrorHandler.createUserError('no_file_selected', 'لم يتم اختيار أي ملف');
        ErrorHandler.showErrorToUser(context, error);
      }
    } catch (e, s) {
      log('Error picking file: $e\n$s');
      final error = ErrorHandler.handleFileError(e);
      if (context.mounted) {
        ErrorHandler.showErrorToUser(context, error);
      }
    }
  }

  // ✅ رفع ملف واحد مع معالجة الأخطاء والعرض الفوري
  Future<void> _uploadSingleFile(
      File file,
      Future<void> Function(ChatUser, File) uploadFunction,
      Type messageType,
      ) async {
    // ✅ 1. إنشاء رسالة فورية للملف
    final optimisticMessage = onCreateOptimisticMessage(file.path, messageType);
    
    // ✅ 2. إضافة الرسالة فوراً للعرض
    onOptimisticMessageAdd(optimisticMessage);
    
    // ✅ 3. رفع الملف في الخلفية
    onUploadingChanged(true);
    try {
      await uploadFunction(user, file);
    } catch (e) {
      log('Error uploading single file: $e');
      if (navigatorKey.currentContext != null) {
        Dialogs.showSnackbar(
          navigatorKey.currentContext!,
          'فشل في رفع الملف: ${file.path.split('/').last}',
        );
      }
    } finally {
      onUploadingChanged(false);
    }
  }

  // ✅ رفع عدة ملفات بالتتابع مع عدم التكرار
  Future<void> _uploadFilesSequentially(
      List<File> files,
      Future<void> Function(ChatUser, File) uploadFunction,
      ) async {
    onUploadingChanged(true);

    try {
      for (int i = 0; i < files.length; i++) {
        final file = files[i];

        try {
          // رفع كل ملف على حدة
          await uploadFunction(user, file);

          // انتظار قصير بين الملفات لتجنب التحميل الزائد
          if (i < files.length - 1) {
            await Future.delayed(const Duration(milliseconds: 500));
          }

        } catch (e) {
          log('Error uploading file ${file.path.split('/').last}: $e');
          if (navigatorKey.currentContext != null) {
            Dialogs.showSnackbar(
              navigatorKey.currentContext!,
              'فشل في رفع الملف: ${file.path.split('/').last}',
            );
          }
        }
      }
    } catch (e) {
      log('Error uploading files: $e');
      if (navigatorKey.currentContext != null) {
        Dialogs.showSnackbar(
          navigatorKey.currentContext!,
          'حدث خطأ أثناء رفع الملفات',
        );
      }
    } finally {
      onUploadingChanged(false);
    }
  }
}

class _WhatsAppAttachmentOption extends BaseStatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _WhatsAppAttachmentOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.withOpacity(0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: context.appTheme.textPrimaryColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
