// lib/api/apis.dart

import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/agent_identity.dart';
import '../models/chat_user.dart';
import '../models/message.dart';
import 'notification_access_token.dart';
import '../core/utils/secure_data_manager.dart'; // ✅ إضافة استيراد مدير البيانات الآمن

// ✅ Enums محسنة
enum LoginAttemptResultType {
  success,
  failure,
  destructionProceedToHome,
  destructionFailure
}

enum OperationResult { success, failure, networkError, permissionDenied }

// ✅ حالات الرفع المحسنة مع إعادة المحاولة
enum UploadStatus {
  pending,
  uploading,
  completed,
  failed,
  retrying,
  cancelled
}

// ✅ نماذج النتائج المحسنة
class LoginAttemptResult {
  final LoginAttemptResultType type;
  final String message;
  final AgentIdentity? agent;
  final AgentIdentity? ghostAgent;

  const LoginAttemptResult._(this.type, this.message, {this.agent, this.ghostAgent});

  factory LoginAttemptResult.success(AgentIdentity agent, String message) =>
      LoginAttemptResult._(LoginAttemptResultType.success, message, agent: agent);

  factory LoginAttemptResult.failure(String message) =>
      LoginAttemptResult._(LoginAttemptResultType.failure, message);

  factory LoginAttemptResult.destructionProceedToHome(
      AgentIdentity destroyedAgentIdentity, String message) =>
      LoginAttemptResult._(
          LoginAttemptResultType.destructionProceedToHome, message,
          ghostAgent: destroyedAgentIdentity);

  factory LoginAttemptResult.destructionFailure(String message) =>
      LoginAttemptResult._(LoginAttemptResultType.destructionFailure, message);

  bool get isSuccess => type == LoginAttemptResultType.success;
  bool get isFailure => type == LoginAttemptResultType.failure;
  bool get isDestruction => type == LoginAttemptResultType.destructionProceedToHome;
}

class AgentAuthResult {
  final bool isSuccess;
  final String message;
  final AgentIdentity? agent;

  const AgentAuthResult._(this.isSuccess, this.message, this.agent);

  factory AgentAuthResult.success(AgentIdentity agent) =>
      AgentAuthResult._(true, 'تم تسجيل الدخول بنجاح', agent);

  factory AgentAuthResult.failure(String message) =>
      AgentAuthResult._(false, message, null);
}

// ✅ نموذج تتبع رفع الملفات المحسن مع معرف المحادثة
class UploadProgress {
  final String messageId;
  final double progress;
  final UploadStatus status;
  final String? errorMessage;
  final int retryCount;
  final DateTime createdAt;
  final String? fileName;
  final File? originalFile;
  final String? conversationId;

  const UploadProgress({
    required this.messageId,
    required this.progress,
    required this.status,
    this.errorMessage,
    this.retryCount = 0,
    required this.createdAt,
    this.fileName,
    this.originalFile,
    this.conversationId,
  });

  UploadProgress copyWith({
    double? progress,
    UploadStatus? status,
    String? errorMessage,
    int? retryCount,
    String? fileName,
    File? originalFile,
    String? conversationId,
  }) =>
      UploadProgress(
        messageId: messageId,
        progress: progress ?? this.progress,
        status: status ?? this.status,
        errorMessage: errorMessage ?? this.errorMessage,
        retryCount: retryCount ?? this.retryCount,
        createdAt: createdAt,
        fileName: fileName ?? this.fileName,
        originalFile: originalFile ?? this.originalFile,
        conversationId: conversationId ?? this.conversationId,
      );

  // ✅ فحص إذا كان الرفع قديم (أكثر من 10 دقائق)
  bool get isExpired {
    return DateTime.now().difference(createdAt).inMinutes > 10;
  }

  // ✅ فحص إذا كان يمكن إعادة المحاولة
  bool get canRetry {
    return status == UploadStatus.failed && retryCount < 3 && originalFile != null;
  }
}

// ✅ Main APIs Class - محسن مع أحدث الممارسات
class APIs {
  // ✅ Singleton Pattern للوصول العام
  static final APIs _instance = APIs._internal();
  factory APIs() => _instance;
  APIs._internal();

  // ✅ Firebase Services
  static FirebaseAuth get auth => FirebaseAuth.instance;
  static FirebaseFirestore get firestore => FirebaseFirestore.instance;
  static FirebaseStorage get storage => FirebaseStorage.instance;
  static FirebaseMessaging get fMessaging => FirebaseMessaging.instance;

  // ✅ User State Management
  static ChatUser? me;
  static AgentIdentity? currentAgent;
  static User? get user => auth.currentUser;

  // ✅ Upload Progress Tracking - ValueNotifier للتتبع المباشر
  static final ValueNotifier<Map<String, UploadProgress>> uploadProgressNotifier =
  ValueNotifier({});

  // ✅ خريطة مهام الرفع النشطة للإلغاء
  static final Map<String, UploadTask> _activeUploadTasks = {};

  // ✅ Timer للتنظيف الدوري
  static Timer? _cleanupTimer;

  // ✅ إشعار تحديث المحادثات للواجهة
  static final ValueNotifier<int> chatUpdatesNotifier = ValueNotifier<int>(0);

  // ✅ Constants
  static const String _projectID = 'the-conduit-app';
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);
  static const Duration _operationTimeout = Duration(minutes: 2);

  // ==================== CORE UTILITIES ====================

  /// ✅ تشغيل العمليات مع إعادة المحاولة والتحكم في الأخطاء
  static Future<T?> executeWithRetry<T>(
      Future<T> Function() operation,
      String operationName, {
        int maxRetries = _maxRetries,
        Duration delay = _retryDelay,
        Duration timeout = _operationTimeout,
      }) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final result = await operation().timeout(timeout);
        return result;
      } catch (e) {
        log('$operationName failed (attempt $attempt/$maxRetries): $e');
        if (attempt == maxRetries) {
          log('$operationName failed after $maxRetries attempts');
          return null;
        }
        await Future.delayed(delay * attempt);
      }
    }
    return null;
  }

  /// ✅ التحقق من صلاحية الجلسة
  static bool get isValidSession =>
      me != null &&
          currentAgent != null &&
          currentAgent!.isActive &&
          me!.id.isNotEmpty;

  /// ✅ سجل إلغاء العملية مع تفاصيل الجلسة
  static String _logAbort(String functionName) {
    final sessionInfo = me != null ? "User: ${me!.id}" : "No user session";
    final agentInfo = currentAgent != null
        ? "Agent: ${currentAgent!.agentCode} (Active: ${currentAgent!.isActive})"
        : "No agent session";
    return "$functionName aborted - $sessionInfo, $agentInfo";
  }

  /// ✅ تهيئة الجلسة مع تنظيف تتبع الرفع القديم
  static Future<void> initializeSession() async {
    // مسح أي تتبع قديم عند بدء الجلسة
    clearAllUploadProgress();

    // بدء التنظيف الدوري
    startPeriodicCleanup();

    log('✅ Session initialized - upload tracking cleared');
  }

  /// ✅ تهيئة APIs مع مدير البيانات الآمن - دالة جديدة
  static Future<void> initializeAPIs() async {
    try {
      // تهيئة مدير البيانات الآمن
      await SecureDataManager.initialize();
      log('✅ SecureDataManager initialized');

      // تهيئة الجلسة العادية
      await initializeSession();

      // تنظيف دوري للملفات القديمة
      await SecureDataManager.cleanOldFiles();

      log('✅ APIs initialized with secure data manager');
    } catch (e) {
      log('❌ Error initializing APIs: $e');
    }
  }

  /// ✅ الحصول على معرف الجهاز المحسن
  static Future<String> getDeviceId() async {
    final result = await executeWithRetry(() async {
      try {
        final deviceInfo = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          return androidInfo.id;
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          return iosInfo.identifierForVendor ?? 'unknown-ios';
        }
        return 'unknown-platform';
      } catch (e) {
        log('Error getting device ID: $e');
        return 'error-getting-device-id';
      }
    }, 'getDeviceId');
    return result ?? 'fallback-device-id';
  }

  // ==================== UPLOAD PROGRESS MANAGEMENT ====================

  /// ✅ بدء التنظيف الدوري لتتبع الرفع
  static void startPeriodicCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _cleanupExpiredUploads();
    });
    log('Started periodic upload cleanup');
  }

  /// ✅ إيقاف التنظيف الدوري
  static void stopPeriodicCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    log('Stopped periodic upload cleanup');
  }

  /// ✅ تنظيف رفوعات منتهية الصلاحية
  static void _cleanupExpiredUploads() {
    final currentMap = Map<String, UploadProgress>.from(uploadProgressNotifier.value);
    final initialCount = currentMap.length;

    currentMap.removeWhere((messageId, progress) {
      final shouldRemove = progress.isExpired ||
          (progress.status == UploadStatus.completed &&
              DateTime.now().difference(progress.createdAt).inMinutes > 2);

      if (shouldRemove) {
        _activeUploadTasks.remove(messageId);
      }

      return shouldRemove;
    });

    if (currentMap.length < initialCount) {
      uploadProgressNotifier.value = currentMap;
      final removedCount = initialCount - currentMap.length;
      log('🧹 Cleaned up $removedCount expired/completed upload progress entries');
    }
  }

  /// ✅ تنظيف قوي للرفوعات المنتهية
  static void forceCleanupUploads() {
    final currentMap = Map<String, UploadProgress>.from(uploadProgressNotifier.value);
    final initialCount = currentMap.length;

    // إزالة جميع الرفوعات المكتملة أو المنتهية الصلاحية
    currentMap.removeWhere((messageId, progress) {
      final shouldRemove = progress.status == UploadStatus.completed ||
          progress.isExpired ||
          DateTime.now().difference(progress.createdAt).inMinutes > 1;

      if (shouldRemove) {
        _activeUploadTasks.remove(messageId);
      }

      return shouldRemove;
    });

    if (currentMap.length < initialCount) {
      uploadProgressNotifier.value = currentMap;
      final removedCount = initialCount - currentMap.length;
      log('🧹 Force cleaned $removedCount upload progress entries');
    }
  }

  /// ✅ إضافة تتبع رفع مع معرف المحادثة
  static void _addUploadProgress(String messageId, UploadProgress progress) {
    final currentMap = Map<String, UploadProgress>.from(uploadProgressNotifier.value);
    currentMap[messageId] = progress;
    uploadProgressNotifier.value = currentMap;
    log('Added upload progress for message: $messageId in conversation: ${progress.conversationId}');
  }

  /// ✅ تحديث تقدم الرفع
  static void _updateUploadProgress(String messageId, {
    double? progress,
    UploadStatus? status,
    String? errorMessage,
    int? retryCount,
  }) {
    final currentMap = Map<String, UploadProgress>.from(uploadProgressNotifier.value);
    final existing = currentMap[messageId];
    if (existing != null) {
      currentMap[messageId] = existing.copyWith(
        progress: progress,
        status: status,
        errorMessage: errorMessage,
        retryCount: retryCount,
      );
      uploadProgressNotifier.value = currentMap;
      log('Updated upload progress for message: $messageId (${status ?? 'progress update'})');
    }
  }

  /// ✅ إزالة تتبع الرفع المحسنة مع التحقق
  static void removeUploadProgress(String messageId, {Duration? delay}) {
    if (delay != null && delay.inSeconds > 0) {
      Future.delayed(delay, () {
        _removeUploadProgressImmediate(messageId);
      });
    } else {
      _removeUploadProgressImmediate(messageId);
    }
  }

  /// ✅ إزالة فورية محسنة مع تسجيل مفصل
  static void _removeUploadProgressImmediate(String messageId) {
    final currentMap = Map<String, UploadProgress>.from(uploadProgressNotifier.value);
    final removedProgress = currentMap.remove(messageId);

    if (removedProgress != null) {
      uploadProgressNotifier.value = currentMap;
      log('✅ Upload progress removed for message: $messageId (Status: ${removedProgress.status})');

      // التأكد من إزالة المهمة النشطة
      final activeTask = _activeUploadTasks.remove(messageId);
      if (activeTask != null) {
        log('✅ Active upload task removed for message: $messageId');
      }
    } else {
      log('⚠️ No upload progress found to remove for message: $messageId');
    }
  }

  /// ✅ التحقق من حالة رفع رسالة معينة
  static UploadProgress? getUploadProgress(String messageId) {
    return uploadProgressNotifier.value[messageId];
  }

  /// ✅ التحقق إذا كانت الرسالة قيد الرفع
  static bool isMessageUploading(String messageId) {
    final progress = getUploadProgress(messageId);
    return progress != null &&
        (progress.status == UploadStatus.uploading ||
            progress.status == UploadStatus.pending ||
            progress.status == UploadStatus.retrying);
  }

  /// ✅ إلغاء رفع
  static Future<void> cancelUpload(String messageId) async {
    final uploadTask = _activeUploadTasks[messageId];
    if (uploadTask != null) {
      try {
        await uploadTask.cancel();
        log('Upload cancelled for message: $messageId');
      } catch (e) {
        log('Error cancelling upload for message $messageId: $e');
      }
    }

    _updateUploadProgress(messageId, status: UploadStatus.cancelled);
    removeUploadProgress(messageId, delay: const Duration(seconds: 2));
  }

  /// ✅ مسح جميع تتبعات الرفع
  static void clearAllUploadProgress() {
    // إلغاء جميع المهام النشطة
    for (final uploadTask in _activeUploadTasks.values) {
      uploadTask.cancel().catchError((e) => log('Error cancelling upload: $e'));
    }

    _activeUploadTasks.clear();
    uploadProgressNotifier.value = {};
    log('Cleared all upload progress');
  }

  /// ✅ إعادة المحاولة للرفع الفاشل
  static Future<void> retryUpload(String messageId) async {
    final progress = getUploadProgress(messageId);
    // لا تحاول إعادة الرفع إذا لم يكن فشل فعلي، أو تجاوزت المحاولات، أو تم الرفع
    if (progress == null ||
        !progress.canRetry ||
        progress.status == UploadStatus.completed ||
        progress.status == UploadStatus.uploading ||
        progress.status == UploadStatus.pending ||
        progress.status == UploadStatus.cancelled) {
      log('Cannot retry upload for message: $messageId (status: ${progress?.status})');
      return;
    }

    try {
      _updateUploadProgress(messageId,
          status: UploadStatus.retrying,
          retryCount: progress.retryCount + 1);

      final originalFile = progress.originalFile;
      if (originalFile == null) {
        throw Exception('Original file not found for retry');
      }

      // إعادة رفع الملف حسب النوع
      final docRef = firestore
          .collection('chats/${progress.conversationId}/messages/')
          .doc(messageId);

      // تحديد نوع الملف وإعادة الرفع
      final extension = originalFile.path.toLowerCase().split('.').last;

      if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension)) {
        await _uploadImageInBackground(originalFile, docRef,
            ChatUser(id: '', name: '', email: '', about: '', image: '',
                createdAt: '', isOnline: false, lastActive: '', pushToken: ''),
            messageId);
      } else if (['mp4', 'mov', 'avi', 'mkv'].contains(extension)) {
        await _uploadVideoInBackground(originalFile, docRef,
            ChatUser(id: '', name: '', email: '', about: '', image: '',
                createdAt: '', isOnline: false, lastActive: '', pushToken: ''),
            messageId);
      } else if (['m4a', 'aac', 'mp3', 'wav'].contains(extension)) {
        await _uploadAudioInBackground(originalFile, docRef,
            ChatUser(id: '', name: '', email: '', about: '', image: '',
                createdAt: '', isOnline: false, lastActive: '', pushToken: ''),
            messageId);
      }
    } catch (e) {
      log('Error retrying upload: $e');
      _updateUploadProgress(messageId,
          status: UploadStatus.failed,
          errorMessage: e.toString());
    }
  }

  // ==================== SOFT DELETE & EDIT SYSTEM ====================

  /// ✅ حذف رسالة للمستخدم الحالي فقط (Soft Delete) - مُصلح
  static Future<bool> deleteMessageForMe(Message message) async {
    if (!isValidSession) {
      log(_logAbort("deleteMessageForMe"));
      return false;
    }

    final conversationId = getConversationID(
        message.toId == me!.id ? message.fromId : message.toId
    );
    if (conversationId == null) return false;

    try {
      await executeWithRetry(() async {
        final messageRef = firestore
            .collection('chats/$conversationId/messages/')
            .doc(message.sent);

        // الحصول على الرسالة الحالية
        final currentDoc = await messageRef.get();
        if (!currentDoc.exists)  return null;

        final currentMessage = Message.fromJson(currentDoc.data()!);

        // إضافة المستخدم الحالي إلى قائمة المحذوفين
        final updatedDeletedFor = List<String>.from(currentMessage.deletedFor ?? []);
        if (!updatedDeletedFor.contains(me!.id)) {
          updatedDeletedFor.add(me!.id);
        }

        // تحديث الرسالة في قاعدة البيانات
        await messageRef.update({
          'deletedFor': updatedDeletedFor,
          'deletedAt': FieldValue.serverTimestamp(),
        });

        log('✅ Message soft deleted for user: ${me!.id}');
        return true;
      }, 'deleteMessageForMe');

      // ✅ إشعار المستمعين بالتحديث الفوري
      chatUpdatesNotifier.value++;
      return true;
    } catch (e) {
      log('❌ Error soft deleting message: $e');
      return false;
    }
  }

  /// ✅ مسح جميع رسائل المحادثة (حذف محلي)
  static Future<bool> clearChatForMe(String otherUserId) async {
    if (!isValidSession) {
      log(_logAbort("clearChatForMe"));
      return false;
    }

    final conversationId = getConversationID(otherUserId);
    if (conversationId == null) return false;

    try {
      final result = await executeWithRetry(() async {
        // الحصول على جميع رسائل المحادثة
        final messagesSnapshot = await firestore
            .collection('chats/$conversationId/messages/')
            .get();

        // تحديث كل رسالة بإضافة المستخدم الحالي لقائمة المحذوفين
        final batch = firestore.batch();
        for (final doc in messagesSnapshot.docs) {
          final data = doc.data();
          final deletedFor = List<String>.from(data['deletedFor'] ?? []);
          if (!deletedFor.contains(me!.id)) {
            deletedFor.add(me!.id);
            batch.update(doc.reference, {
              'deletedFor': deletedFor,
              'deletedAt': FieldValue.serverTimestamp(),
            });
          }
        }

        await batch.commit();
        log('✅ All messages marked as deleted for user: ${me!.id}');
        return true;
      }, 'clearChatForMe');

      return result ?? false;
    } catch (e) {
      log('❌ Error clearing chat: $e');
      return false;
    }
  }

  /// ✅ تعديل رسالة نصية
  static Future<void> editMessage(Message message, String newText) async {
    if (!isValidSession || message.fromId != me!.id || message.type != Type.text) {
      log("${_logAbort("editMessage")} or invalid message type/owner");
      return;
    }

    final conversationId = getConversationID(message.toId);
    if (conversationId == null) return;

    await executeWithRetry(() async {
      await firestore
          .collection('chats/$conversationId/messages/')
          .doc(message.sent)
          .update({
        'msg': newText,
        'isEdited': true,
        'editedAt': DateTime.now().millisecondsSinceEpoch.toString(),
      });
    }, 'editMessage');
  }

  /// ✅ الحصول على الرسائل مع فلترة المحذوفة - مُصلح
  static Stream<QuerySnapshot<Map<String, dynamic>>>? getAllMessagesFiltered(ChatUser chatUser) {
    if (me == null || chatUser.id.isEmpty) {
      log("getAllMessagesFiltered: Invalid parameters");
      return Stream.empty();
    }

    final conversationId = getConversationID(chatUser.id);
    if (conversationId == null) return Stream.empty();

    return firestore
        .collection('chats/$conversationId/messages/')
        .orderBy('sent', descending: true)
        .snapshots()
        .map((snapshot) {
      // فلترة الرسائل المحذوفة للمستخدم الحالي
      final filteredDocs = snapshot.docs.where((doc) {
        final data = doc.data();
        final deletedFor = List<String>.from(data['deletedFor'] ?? []);
        return !deletedFor.contains(me!.id);
      }).toList();

      return _createFilteredSnapshot(filteredDocs, snapshot.metadata);
    });
  }

  /// ✅ مساعد لإنشاء QuerySnapshot مفلتر
  static QuerySnapshot<Map<String, dynamic>> _createFilteredSnapshot(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      SnapshotMetadata metadata,
      ) {
    return _FilteredQuerySnapshot(docs, metadata);
  }

  /// ✅ حذف المحادثة المحسن مع تحديث فوري للواجهة - مُصلح
  static Future<bool> deleteChatForMe(String otherUserId) async {
    if (!isValidSession) {
      log(_logAbort("deleteChatForMe"));
      return false;
    }

    try {
      final result = await executeWithRetry(() async {
        // حذف المحادثة من my_users
        await firestore
            .collection('users')
            .doc(me!.id)
            .collection('my_users')
            .doc(otherUserId)
            .delete();

        log('✅ Chat deleted for user: ${me!.id}');
        return true;
      }, 'deleteChatForMe');

      if (result == true) {
        // ✅ إشعار المستمعين بالتحديث الفوري
        chatUpdatesNotifier.value++;
        return true;
      }
      return false;
    } catch (e) {
      log('❌ Error deleting chat: $e');
      return false;
    }
  }

  // ==================== AUTHENTICATION ====================

  /// ✅ محاولة تسجيل الدخول أو التدمير المحسنة
  static Future<LoginAttemptResult> attemptLoginOrDestruct(String enteredCode) async {
    final deviceId = await getDeviceId();
    currentAgent = null;
    me = null;

    // فحص كود التدمير أولاً
    try {
      final querySnapshot = await firestore
          .collection('agent_identities')
          .where('destructionCode', isEqualTo: enteredCode)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final agentToDestructDoc = querySnapshot.docs.first;
        final AgentIdentity originalAgentIdentity =
        AgentIdentity.fromFirestore(agentToDestructDoc);

        if (originalAgentIdentity.destructionCode == enteredCode &&
            originalAgentIdentity.destructionCode != null &&
            originalAgentIdentity.destructionCode!.isNotEmpty) {
          log('Destruction code matched for agent: ${originalAgentIdentity.agentCode}');
          await _performDestruction(originalAgentIdentity);
          currentAgent = originalAgentIdentity.copyWith(
              isActive: false,
              deviceId: null,
              destructionCode: null,
              displayName: "تمت المغادرة",
              metadata: {}
          );

          await createDummyUserFromAgent();
          return LoginAttemptResult.destructionProceedToHome(
              currentAgent!, 'تم الانتقال لوضع التعتيم.');
        }
      }
    } catch (e) {
      log('Error checking destruction code "$enteredCode": $e');
    }

    // محاولة تسجيل الدخول العادي
    log('Code "$enteredCode" not a destruction trigger. Attempting normal login.');
    final authResult = await _authenticateAgentLogic(enteredCode, deviceId);
    if (authResult.isSuccess && authResult.agent != null) {
      return LoginAttemptResult.success(authResult.agent!, authResult.message);
    } else {
      currentAgent = null;
      me = null;
      return LoginAttemptResult.failure(authResult.message);
    }
  }

  /// ✅ منطق المصادقة المحسن
  static Future<AgentAuthResult> _authenticateAgentLogic(
      String agentCode, String currentDeviceId) async {
    try {
      final agentDoc = await firestore
          .collection('agent_identities')
          .doc(agentCode)
          .get();

      if (!agentDoc.exists) {
        return AgentAuthResult.failure('رمز الوكيل غير موجود');
      }

      final agent = AgentIdentity.fromFirestore(agentDoc);

      if (!agent.isActive) {
        return AgentAuthResult.failure('الحساب معطل أو تم تدميره');
      }

      // التحقق من ربط الجهاز
      if (agent.deviceBindingRequired) {
        final String? storedDeviceId = agent.deviceId;
        if (storedDeviceId == null || storedDeviceId.isEmpty) {
          log("Agent $agentCode binding to new device: $currentDeviceId");
          await _bindDeviceToAgent(agentCode, currentDeviceId);
        } else if (storedDeviceId != currentDeviceId) {
          log("Login denied for agent $agentCode from device $currentDeviceId");
          return AgentAuthResult.failure(
              'لا يمكنك الدخول بهذا الرمز، الحساب مرتبط بجهاز آخر.');
        }
      }

      await _updateLastLogin(agentCode, currentDeviceId);

      // جلب الوكيل المحدث
      final updatedAgentDoc = await firestore
          .collection('agent_identities')
          .doc(agentCode)
          .get();
      final updatedAgent = AgentIdentity.fromFirestore(updatedAgentDoc);

      // تعيين الجلسة النشطة
      currentAgent = updatedAgent;
      await createDummyUserFromAgent();
      await getFirebaseMessagingToken();

      // بدء التنظيف الدوري
      startPeriodicCleanup();

      return AgentAuthResult.success(updatedAgent);
    } catch (e) {
      log("Error in _authenticateAgentLogic for $agentCode: $e");
      currentAgent = null;
      me = null;
      return AgentAuthResult.failure('خطأ في الاتصال أثناء محاولة التوثيق.');
    }
  }

  /// ✅ ربط الجهاز بالوكيل
  static Future<void> _bindDeviceToAgent(String agentCode, String deviceId) async {
    await executeWithRetry(() async {
      await firestore.collection('agent_identities').doc(agentCode).update({
        'deviceId': deviceId,
        'lastLoginDeviceId': deviceId,
      });
    }, '_bindDeviceToAgent');
  }

  /// ✅ تحديث آخر تسجيل دخول
  static Future<void> _updateLastLogin(String agentCode, String deviceId) async {
    await executeWithRetry(() async {
      await firestore.collection('agent_identities').doc(agentCode).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
        'lastLoginDeviceId': deviceId,
      });
    }, '_updateLastLogin');
  }

  // ==================== DESTRUCTION & CLEANUP ====================

  /// ✅ تنفيذ عملية التدمير المحسنة
  static Future<void> _performDestruction(AgentIdentity agentToDestruct) async {
    final agentCode = agentToDestruct.agentCode;
    final chatUserId = 'agent_$agentCode';

    try {
      log('Performing server-side data manipulation for agent: $agentCode');

      // تعطيل الوكيل في قاعدة البيانات
      await firestore.collection('agent_identities').doc(agentCode).update({
        'isActive': false,
        'deviceId': null,
        'lastLoginDeviceId': null,
        'destructionCode': FieldValue.delete(),
        'displayName': 'وكيل معطّل',
        'metadata': FieldValue.delete(),
      });

      // حذف ملف المستخدم
      final userDocRef = firestore.collection('users').doc(chatUserId);
      final userDocSnapshot = await userDocRef.get();
      if (userDocSnapshot.exists) {
        final String? imageUrl = userDocSnapshot.data()?['image'];

        // حذف صورة الملف الشخصي
        if (imageUrl != null && imageUrl.isNotEmpty) {
          try {
            await storage.refFromURL(imageUrl).delete();
            log("Deleted profile picture for $chatUserId");
          } catch (e) {
            log("Error deleting profile pic: $e");
          }
        }

        await userDocRef.delete();
        log("ChatUser profile for $chatUserId deleted");
      }
    } catch (e) {
      log('Error during server-side data manipulation: $e');
    }

    await _clearLocalData();
  }

  /// ✅ مسح البيانات المحلية المحسن مع SecureDataManager
  static Future<void> _clearLocalData() async {
    await executeWithRetry(() async {
      try {
        // ✅ مسح cache الصور المؤقت فقط
        await CachedNetworkImage.evictFromCache('');
        log('Cached network images evicted');

        // ✅ مسح الملفات الأمنية والمؤقتة فقط (نحافظ على الوسائط)
        await SecureDataManager.clearSecureDataOnly();
        log('✅ Secure data cleared while preserving media cache');

        // مسح تتبع الرفع
        clearAllUploadProgress();

      } catch (e) {
        log('Error during secure data clearing: $e');
      }
    }, '_clearLocalData');
  }

  /// ✅ مسح محتويات المجلد
  static Future<void> _clearDirectory(Directory directory) async {
    try {
      final entities = directory.listSync();
      for (final entity in entities) {
        if (entity is File) {
          await entity.delete();
        } else if (entity is Directory) {
          await entity.delete(recursive: true);
        }
      }
    } catch (e) {
      log("Error clearing directory ${directory.path}: $e");
    }
  }

  // ==================== SESSION MANAGEMENT ====================

  /// ✅ التحقق من صحة الجلسة المخزنة
  static Future<bool> validateStoredSession() async {
    log('Validating stored session - no session persistence implemented');
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getKeys().isNotEmpty) {
      await prefs.clear();
      log("Cleared existing SharedPreferences during validation");
    }

    currentAgent = null;
    me = null;
    return false;
  }

  /// ✅ تسجيل الخروج المحسن مع SecureDataManager
  static Future<void> signOut() async {
    log('Signing out...');
    if (isValidSession) {
      try {
        await updateActiveStatus(false);
      } catch (e) {
        log("Error updating active status during sign out: $e");
      }
    }

    // إيقاف التنظيف الدوري
    stopPeriodicCleanup();

    // ✅ مسح البيانات الآمنة فقط (الحفاظ على الوسائط)
    await _clearLocalData();

    currentAgent = null;
    me = null;
    log('Sign out complete - media cache preserved');
  }

  /// ✅ إنشاء مستخدم وهمي من الوكيل
  static Future<void> createDummyUserFromAgent() async {
    if (currentAgent == null) {
      log("Cannot create dummy user, currentAgent is null");
      me = null;
      return;
    }

    me = ChatUser(
      id: 'agent_${currentAgent!.agentCode}',
      name: currentAgent!.isActive
          ? currentAgent!.displayName
          : 'مستخدم غير معروف',
      email: '${currentAgent!.agentCode}@agents.local',
      about: currentAgent!.isActive ? "أهلاً!" : "غير متوفر",
      image: currentAgent!.isActive
          ? (currentAgent!.metadata?['image_url'] ?? '')
          : '',
      createdAt: DateTime.now().millisecondsSinceEpoch.toString(),
      isOnline: currentAgent!.isActive,
      lastActive: currentAgent!.isActive
          ? DateTime.now().millisecondsSinceEpoch.toString()
          : '',
      pushToken: '',
    );

    if (currentAgent!.isActive) {
      await createUserIfNotExists();
    }
  }

  /// ✅ إنشاء المستخدم إذا لم يكن موجوداً
  static Future<void> createUserIfNotExists() async {
    if (!isValidSession) {
      log("Skipping createUserIfNotExists - invalid session");
      return;
    }

    final userDoc = await firestore.collection('users').doc(me!.id).get();
    if (!userDoc.exists) {
      await firestore.collection('users').doc(me!.id).set(me!.toJson());
      log("Created ChatUser profile for ${me!.id}");
    } else {
      log("ChatUser profile for ${me!.id} already exists");
      // تحديث البيانات الأساسية
      await firestore.collection('users').doc(me!.id).update({
        'name': me!.name,
        'image': me!.image,
      });
    }
  }

  // ==================== MESSAGING TOKEN ====================

  /// ✅ الحصول على رمز Firebase Messaging
  static Future<void> getFirebaseMessagingToken() async {
    if (!isValidSession) {
      log("Skipping FCM token retrieval - invalid session");
      return;
    }

    try {
      await fMessaging.requestPermission();
      final String? token = await fMessaging.getToken();
      if (token != null) {
        me!.pushToken = token;
        log('Push Token acquired for user ${me!.id}');
        await firestore.collection('users').doc(me!.id).update({
          'push_token': token
        });
      } else {
        log('FCM token is null');
        me!.pushToken = '';
      }
    } catch (e) {
      log("Error getting FCM token: $e");
      me!.pushToken = '';
    }
  }

  // ==================== MESSAGING ====================

  /// ✅ إرسال الإشعارات المحسن
  static Future<void> sendPushNotification(ChatUser chatUser, String msg) async {
    if (!isValidSession || chatUser.pushToken.isEmpty) {
      log(_logAbort("sendPushNotification"));
      return;
    }

    await executeWithRetry(() async {
      final body = {
        "message": {
          "token": chatUser.pushToken,
          "notification": {
            "title": me!.name,
            "body": msg,
          },
        }
      };

      final bearerToken = await NotificationAccessToken.getToken;
      if (bearerToken == null) {
        throw Exception("Bearer token is null");
      }

      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/v1/projects/$_projectID/messages:send'),
        headers: {
          HttpHeaders.contentTypeHeader: 'application/json',
          HttpHeaders.authorizationHeader: 'Bearer $bearerToken'
        },
        body: jsonEncode(body),
      );

      log('Push Notification Response: ${response.statusCode}');
      if (response.statusCode != 200) {
        throw Exception('Failed to send notification: ${response.body}');
      }
    }, 'sendPushNotification');
  }

  /// ✅ إرسال الرسالة الأولى
  static Future<void> sendFirstMessage(ChatUser chatUser, String msg, Type type) async {
    if (!isValidSession) {
      log(_logAbort("sendFirstMessage"));
      return;
    }

    final otherUserDoc = await firestore.collection('users').doc(chatUser.id).get();
    if (!otherUserDoc.exists) {
      log("sendFirstMessage: Other user ${chatUser.id} does not exist");
      return;
    }

    await firestore
        .collection('users')
        .doc(chatUser.id)
        .collection('my_users')
        .doc(me!.id)
        .set({});
    await sendMessage(chatUser, msg, type);
  }

  /// ✅ إرسال رسالة عادية
  static Future<void> sendMessage(ChatUser chatUser, String msg, Type type) async {
    if (!isValidSession) {
      log(_logAbort("sendMessage"));
      return;
    }

    final time = DateTime.now().millisecondsSinceEpoch.toString();
    final conversationId = getConversationID(chatUser.id);
    if (conversationId == null) return;

    final message = Message(
      toId: chatUser.id,
      msg: msg,
      read: '',
      type: type,
      fromId: me!.id,
      sent: time,
    );

    final ref = firestore.collection('chats/$conversationId/messages/');
    await ref.doc(time).set(message.toJson());
    await sendPushNotification(chatUser, _getNotificationMessage(type, msg));
  }

  // ==================== INSTANT MEDIA SENDING ====================

  /// ✅ إرسال صوت مع العرض المباشر والحفظ في Cache المحمي
  static Future<void> sendChatAudio(ChatUser chatUser, File audioFile, int duration) async {
    if (!isValidSession) {
      log(_logAbort("sendChatAudio"));
      return;
    }

    final conversationId = getConversationID(chatUser.id);
    if (conversationId == null) return;

    final time = DateTime.now().millisecondsSinceEpoch.toString();
    final fileName = audioFile.path.split('/').last;

    // ✅ إنشاء رسالة محلية للعرض الفوري
    final localMessage = Message(
      toId: chatUser.id,
      msg: audioFile.path, // المسار المحلي
      read: '',
      type: Type.audio,
      fromId: me!.id,
      sent: time,
      audioDuration: duration,
      fileName: fileName,
    );

    // ✅ إضافة الرسالة محلياً أولاً للعرض الفوري
    final docRef = firestore.collection('chats/$conversationId/messages/').doc(time);
    await docRef.set(localMessage.toJson());

    // ✅ إضافة تتبع الرفع مع معرف المحادثة والملف الأصلي
    _addUploadProgress(time, UploadProgress(
      messageId: time,
      progress: 0.0,
      status: UploadStatus.pending,
      createdAt: DateTime.now(),
      fileName: fileName,
      originalFile: audioFile,
      conversationId: conversationId,
    ));

    // ✅ رفع الملف في الخلفية
    _uploadAudioInBackground(audioFile, docRef, chatUser, time);
  }

  /// ✅ رفع الصوت في الخلفية مع حفظ في Cache محمي
  static Future<void> _uploadAudioInBackground(
      File audioFile,
      DocumentReference docRef,
      ChatUser chatUser,
      String messageId) async {

    UploadTask? uploadTask;

    try {
      _updateUploadProgress(messageId, status: UploadStatus.uploading);

      final ext = audioFile.path.split('.').last;
      final ref = storage.ref().child('audio/${docRef.id}.$ext');

      uploadTask = ref.putFile(audioFile, SettableMetadata(contentType: 'audio/$ext'));
      _activeUploadTasks[messageId] = uploadTask;

      // تتبع التقدم
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (snapshot.state == TaskState.running) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          _updateUploadProgress(messageId, progress: progress);
        }
      });

      // انتظار اكتمال الرفع
      final taskSnapshot = await uploadTask;

      if (taskSnapshot.state == TaskState.success) {
        final downloadUrl = await ref.getDownloadURL();

        // ✅ حفظ الملف في cache محمي قبل تحديث الرسالة
        final audioBytes = await audioFile.readAsBytes();
        await SecureDataManager.saveMediaFile(audioBytes, audioFile.path.split('/').last, downloadUrl);

        // تحديث الرسالة بالرابط الجديد
        await docRef.update({'msg': downloadUrl});

        // تحديث حالة الإكمال
        _updateUploadProgress(messageId,
            progress: 1.0,
            status: UploadStatus.completed);

        // ✅ إزالة التتبع فوراً بدلاً من التأخير
        removeUploadProgress(messageId);

        // إرسال الإشعار
        await sendPushNotification(chatUser, _getNotificationMessage(Type.audio, ''));

        log('✅ Audio upload completed and cached: $messageId');
      }

    } catch (e) {
      log('❌ Error uploading audio: $e');

      _updateUploadProgress(messageId,
          status: UploadStatus.failed,
          errorMessage: e.toString());

      // إزالة التتبع بعد 5 ثوانٍ للسماح برؤية الخطأ
      removeUploadProgress(messageId, delay: const Duration(seconds: 5));

      // الاحتفاظ بالرسالة مع علامة فشل الرفع
      await docRef.update({'uploadFailed': true, 'msg': audioFile.path});

    } finally {
      // ✅ التأكد من إزالة المهمة من المهام النشطة
      _activeUploadTasks.remove(messageId);

      // ✅ إلغاء المهمة إذا كانت لا تزال نشطة
      if (uploadTask != null) {
        try {
          await uploadTask.cancel();
        } catch (e) {
          // تجاهل أخطاء الإلغاء
        }
      }
    }
  }

  /// ✅ إرسال فيديو مع العرض المباشر والحفظ في Cache المحمي
  static Future<void> sendChatVideo(ChatUser chatUser, File videoFile,
      {String? thumbnailUrl}) async {
    if (!isValidSession) {
      log(_logAbort("sendChatVideo"));
      return;
    }

    final conversationId = getConversationID(chatUser.id);
    if (conversationId == null) return;

    final time = DateTime.now().millisecondsSinceEpoch.toString();
    final fileName = videoFile.path.split('/').last;

    // ✅ إنشاء رسالة محلية للعرض الفوري
    final localMessage = Message(
      toId: chatUser.id,
      msg: videoFile.path, // المسار المحلي
      read: '',
      type: Type.video,
      fromId: me!.id,
      sent: time,
      fileName: fileName,
      thumbnailUrl: thumbnailUrl,
    );

    // ✅ إضافة الرسالة محلياً أولاً
    final docRef = firestore.collection('chats/$conversationId/messages/').doc(time);
    await docRef.set(localMessage.toJson());

    // ✅ تتبع الرفع مع معرف المحادثة والملف الأصلي
    _addUploadProgress(time, UploadProgress(
      messageId: time,
      progress: 0.0,
      status: UploadStatus.pending,
      createdAt: DateTime.now(),
      fileName: fileName,
      originalFile: videoFile,
      conversationId: conversationId,
    ));

    // ✅ رفع الملف في الخلفية
    _uploadVideoInBackground(videoFile, docRef, chatUser, time);
  }

  /// ✅ رفع الفيديو في الخلفية مع حفظ في Cache محمي
  static Future<void> _uploadVideoInBackground(
      File videoFile,
      DocumentReference docRef,
      ChatUser chatUser,
      String messageId) async {

    UploadTask? uploadTask;

    try {
      _updateUploadProgress(messageId, status: UploadStatus.uploading);

      final ext = videoFile.path.split('.').last;
      final ref = storage.ref().child('videos/${docRef.id}.$ext');

      uploadTask = ref.putFile(videoFile, SettableMetadata(contentType: 'video/$ext'));
      _activeUploadTasks[messageId] = uploadTask;

      // تتبع التقدم
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (snapshot.state == TaskState.running) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          _updateUploadProgress(messageId, progress: progress);
        }
      });

      // انتظار اكتمال الرفع
      final taskSnapshot = await uploadTask;

      if (taskSnapshot.state == TaskState.success) {
        final downloadUrl = await ref.getDownloadURL();

        // ✅ حفظ الملف في cache محمي قبل تحديث الرسالة
        final videoBytes = await videoFile.readAsBytes();
        await SecureDataManager.saveMediaFile(videoBytes, videoFile.path.split('/').last, downloadUrl);

        // تحديث الرسالة بالرابط النهائي
        await docRef.update({'msg': downloadUrl});

        // تحديث حالة الإكمال
        _updateUploadProgress(messageId,
            progress: 1.0,
            status: UploadStatus.completed);

        // ✅ إزالة التتبع فوراً
        removeUploadProgress(messageId);

        // إرسال الإشعار
        await sendPushNotification(chatUser, _getNotificationMessage(Type.video, ''));

        log('✅ Video upload completed and cached: $messageId');
      }

    } catch (e) {
      log('❌ Error uploading video: $e');

      _updateUploadProgress(messageId,
          status: UploadStatus.failed,
          errorMessage: e.toString());

      // إزالة التتبع بعد 5 ثوانٍ للسماح برؤية الخطأ
      removeUploadProgress(messageId, delay: const Duration(seconds: 5));

      // الاحتفاظ بالرسالة مع علامة فشل الرفع
      await docRef.update({'uploadFailed': true, 'msg': videoFile.path});

    } finally {
      // ✅ التأكد من إزالة المهمة من المهام النشطة
      _activeUploadTasks.remove(messageId);

      // ✅ إلغاء المهمة إذا كانت لا تزال نشطة
      if (uploadTask != null) {
        try {
          await uploadTask.cancel();
        } catch (e) {
          // تجاهل أخطاء الإلغاء
        }
      }
    }
  }

  /// ✅ إرسال صورة محسن مع العرض الفوري وحفظ في Cache محمي
  static Future<void> sendChatImage(ChatUser chatUser, File file) async {
    if (!isValidSession) {
      log(_logAbort("sendChatImage"));
      return;
    }

    final conversationId = getConversationID(chatUser.id);
    if (conversationId == null) return;

    final time = DateTime.now().millisecondsSinceEpoch.toString();
    final fileName = file.path.split('/').last;

    // ✅ إنشاء رسالة محلية للعرض الفوري
    final localMessage = Message(
      toId: chatUser.id,
      msg: file.path, // المسار المحلي للعرض الفوري
      read: '',
      type: Type.image,
      fromId: me!.id,
      sent: time,
      fileName: fileName,
    );

    // ✅ إضافة الرسالة محلياً أولاً للعرض الفوري
    final docRef = firestore.collection('chats/$conversationId/messages/').doc(time);
    await docRef.set(localMessage.toJson());

    // ✅ إضافة تتبع الرفع
    _addUploadProgress(time, UploadProgress(
      messageId: time,
      progress: 0.0,
      status: UploadStatus.pending,
      createdAt: DateTime.now(),
      fileName: fileName,
      originalFile: file,
      conversationId: conversationId,
    ));

    // ✅ رفع الصورة في الخلفية
    _uploadImageInBackground(file, docRef, chatUser, time);
  }

  /// ✅ رفع الصورة في الخلفية مع حفظ في Cache محمي
  static Future<void> _uploadImageInBackground(
      File imageFile,
      DocumentReference docRef,
      ChatUser chatUser,
      String messageId) async {

    UploadTask? uploadTask;

    try {
      _updateUploadProgress(messageId, status: UploadStatus.uploading);

      final ext = imageFile.path.split('.').last;
      final ref = storage.ref().child('images/${docRef.id}.$ext');

      uploadTask = ref.putFile(imageFile, SettableMetadata(contentType: 'image/$ext'));
      _activeUploadTasks[messageId] = uploadTask;

      // تتبع التقدم
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (snapshot.state == TaskState.running) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          _updateUploadProgress(messageId, progress: progress);
        }
      });

      // انتظار اكتمال الرفع
      final taskSnapshot = await uploadTask;

      if (taskSnapshot.state == TaskState.success) {
        final downloadUrl = await ref.getDownloadURL();

        // ✅ حفظ الملف في cache محمي قبل تحديث الرسالة
        final imageBytes = await imageFile.readAsBytes();
        await SecureDataManager.saveMediaFile(imageBytes, imageFile.path.split('/').last, downloadUrl);

        // تحديث الرسالة بالرابط النهائي
        await docRef.update({'msg': downloadUrl});

        // تحديث حالة الإكمال
        _updateUploadProgress(messageId,
            progress: 1.0,
            status: UploadStatus.completed);

        // ✅ إزالة التتبع فوراً
        removeUploadProgress(messageId);

        // إرسال الإشعار
        await sendPushNotification(chatUser, _getNotificationMessage(Type.image, ''));

        log('✅ Image upload completed and cached: $messageId');
      }

    } catch (e) {
      log('❌ Error uploading image: $e');

      _updateUploadProgress(messageId,
          status: UploadStatus.failed,
          errorMessage: e.toString());

      // إزالة التتبع بعد 5 ثوانٍ للسماح برؤية الخطأ
      removeUploadProgress(messageId, delay: const Duration(seconds: 5));

      // الاحتفاظ بالرسالة مع علامة فشل الرفع
      await docRef.update({'uploadFailed': true, 'msg': imageFile.path});

    } finally {
      // ✅ التأكد من إزالة المهمة من المهام النشطة
      _activeUploadTasks.remove(messageId);

      // ✅ إلغاء المهمة إذا كانت لا تزال نشطة
      if (uploadTask != null) {
        try {
          await uploadTask.cancel();
        } catch (e) {
          // تجاهل أخطاء الإلغاء
        }
      }
    }
  }

  /// ✅ إرسال ملف محسن
  static Future<void> sendChatFile(
      ChatUser chatUser, File file, String fileName, int? fileSize) async {
    if (!isValidSession) {
      log(_logAbort("sendChatFile"));
      return;
    }

    final conversationId = getConversationID(chatUser.id);
    if (conversationId == null) return;

    await executeWithRetry(() async {
      final ext = file.path.split('.').last;
      final ref = storage.ref().child(
          'files/$conversationId/${DateTime.now().millisecondsSinceEpoch}_$fileName');

      await ref.putFile(file, SettableMetadata(contentType: 'application/$ext'));
      final fileUrl = await ref.getDownloadURL();

      final time = DateTime.now().millisecondsSinceEpoch.toString();
      final message = Message(
        toId: chatUser.id,
        msg: fileUrl,
        read: '',
        type: Type.file,
        fromId: me!.id,
        sent: time,
        fileName: fileName,
        fileSize: fileSize,
      );

      await firestore
          .collection('chats/$conversationId/messages/')
          .doc(time)
          .set(message.toJson());

      await sendPushNotification(chatUser, _getNotificationMessage(Type.file, fileName));
    }, 'sendChatFile');
  }

  // ==================== MESSAGE OPERATIONS ====================

  /// ✅ تحديث حالة قراءة الرسالة
  static Future<void> updateMessageReadStatus(Message message) async {
    if (me == null || message.fromId.isEmpty || message.toId != me!.id) {
      log("updateMessageReadStatus: Invalid parameters");
      return;
    }

    final conversationId = getConversationID(message.fromId);
    if (conversationId == null) return;

    await executeWithRetry(() async {
      await firestore
          .collection('chats/$conversationId/messages/')
          .doc(message.sent)
          .update({'read': DateTime.now().millisecondsSinceEpoch.toString()});
    }, 'updateMessageReadStatus');
  }

  /// ✅ حذف رسالة (فعلي - للمالك فقط)
  static Future<void> deleteMessage(Message message) async {
    if (!isValidSession || message.fromId != me!.id) {
      log("${_logAbort("deleteMessage")} or not message owner");
      return;
    }

    final conversationId = getConversationID(message.toId);
    if (conversationId == null) return;

    await executeWithRetry(() async {
      // حذف الرسالة من Firestore
      await firestore
          .collection('chats/$conversationId/messages/')
          .doc(message.sent)
          .delete();

      // حذف الملف المرتبط من Storage
      if (_isMediaMessage(message.type) && message.msg.startsWith('https://')) {
        try {
          await storage.refFromURL(message.msg).delete();
          log("Deleted ${message.type.name} from storage: ${message.msg}");
        } catch (e) {
          log("Error deleting ${message.type.name} from storage: $e");
        }
      }

      // إلغاء تتبع الرفع إذا كان موجوداً
      removeUploadProgress(message.sent);
    }, 'deleteMessage');
  }

  /// ✅ تحديث رسالة (قديم - استخدم editMessage بدلاً منه)
  static Future<void> updateMessage(Message message, String updatedMsg) async {
    if (!isValidSession || message.fromId != me!.id) {
      log("${_logAbort("updateMessage")} or not message owner");
      return;
    }

    final conversationId = getConversationID(message.toId);
    if (conversationId == null) return;

    await executeWithRetry(() async {
      await firestore
          .collection('chats/$conversationId/messages/')
          .doc(message.sent)
          .update({'msg': updatedMsg});
    }, 'updateMessage');
  }

  // ==================== USER MANAGEMENT ====================

  /// ✅ التحقق من وجود المستخدم
  static Future<bool> userExists() async {
    if (!isValidSession) {
      log(_logAbort("userExists"));
      return false;
    }

    final result = await executeWithRetry(() async {
      return (await firestore.collection('users').doc(me!.id).get()).exists;
    }, 'userExists');
    return result ?? false;
  }

  /// ✅ الحصول على معلومات المستخدم الحالي
  static Future<void> getSelfInfo() async {
    if (!isValidSession) {
      log(_logAbort("getSelfInfo"));
      return;
    }

    await executeWithRetry(() async {
      // تحديث معلومات الوكيل مع التأكد من جلب جميع البيانات
      final agentDoc = await firestore
          .collection('agent_identities')
          .doc(currentAgent!.agentCode)
          .get();
      if (agentDoc.exists) {
        final newAgentData = AgentIdentity.fromFirestore(agentDoc);
        currentAgent = newAgentData;
        log('✅ Agent data refreshed - AgentCode: ${newAgentData.agentCode}, DestructionCode: ${newAgentData.destructionCode}, IsActive: ${newAgentData.isActive}');
      } else {
        log('❌ Agent document does not exist for code: ${currentAgent!.agentCode}');
      }

      // تحديث معلومات المستخدم
      final userDoc = await firestore.collection('users').doc(me!.id).get();
      if (userDoc.exists) {
        me = ChatUser.fromJson(userDoc.data()!);
        log('✅ User data refreshed - UserID: ${me!.id}');
      } else {
        log('❌ User document does not exist for ID: ${me!.id}');
      }
    }, 'getSelfInfo');
  }

  /// ✅ إضافة مستخدم للدردشة
  static Future<bool> addChatUser(String agentCodeToAdd) async {
    if (!isValidSession) {
      log(_logAbort("addChatUser"));
      return false;
    }

    if (currentAgent!.agentCode == agentCodeToAdd) {
      log('addChatUser: Cannot add self');
      return false;
    }

    final result = await executeWithRetry(() async {
      final agentDoc = await firestore
          .collection('agent_identities')
          .doc(agentCodeToAdd)
          .get();
      if (!agentDoc.exists) {
        log('addChatUser: Agent $agentCodeToAdd not found');
        return false;
      }

      final agentToAdd = AgentIdentity.fromFirestore(agentDoc);
      if (!agentToAdd.isActive) {
        log('addChatUser: Agent $agentCodeToAdd is not active');
        return false;
      }

      final chatUserIdToAdd = 'agent_$agentCodeToAdd';
      await firestore
          .collection('users')
          .doc(me!.id)
          .collection('my_users')
          .doc(chatUserIdToAdd)
          .set({});
      log('addChatUser: Added $chatUserIdToAdd to my_users');
      return true;
    }, 'addChatUser');
    return result ?? false;
  }

  /// ✅ تحديث معلومات المستخدم
  static Future<void> updateUserInfo() async {
    if (!isValidSession) {
      log(_logAbort("updateUserInfo"));
      return;
    }

    await executeWithRetry(() async {
      await firestore.collection('users').doc(me!.id).update({
        'name': me!.name,
        'about': me!.about,
      });
    }, 'updateUserInfo');
  }

  /// ✅ تحديث صورة الملف الشخصي
  static Future<void> updateProfilePicture(File file) async {
    if (!isValidSession) {
      log(_logAbort("updateProfilePicture"));
      return;
    }

    await executeWithRetry(() async {
      final ext = file.path.split('.').last;
      final ref = storage.ref().child('profile_pictures/${me!.id}.$ext');
      await ref.putFile(file, SettableMetadata(contentType: 'image/$ext'));
      me!.image = await ref.getDownloadURL();
      await firestore.collection('users').doc(me!.id).update({'image': me!.image});
    }, 'updateProfilePicture');
  }

  /// ✅ تحديث حالة النشاط
  static Future<void> updateActiveStatus(bool isOnline) async {
    if (!isValidSession) {
      log(_logAbort("updateActiveStatus"));
      return;
    }

    await executeWithRetry(() async {
      await firestore.collection('users').doc(me!.id).update({
        'is_online': isOnline,
        'last_active': DateTime.now().millisecondsSinceEpoch.toString(),
      });
    }, 'updateActiveStatus');
  }

  // ==================== STREAMS & QUERIES ====================

  /// ✅ الحصول على قائمة معرفات المستخدمين
  static Stream<QuerySnapshot<Map<String, dynamic>>>? getMyUsersId() {
    if (!isValidSession) {
      log(_logAbort("getMyUsersId"));
      return Stream.empty();
    }

    return firestore
        .collection('users')
        .doc(me!.id)
        .collection('my_users')
        .snapshots();
  }

  /// ✅ الحصول على جميع المستخدمين
  static Stream<QuerySnapshot<Map<String, dynamic>>> getAllUsers(List<String> userIds) {
    if (!isValidSession || userIds.isEmpty) {
      log(_logAbort("getAllUsers"));
      return Stream.empty();
    }

    return firestore
        .collection('users')
        .where('id', whereIn: userIds)
        .snapshots();
  }

  /// ✅ الحصول على معلومات مستخدم محدد
  static Stream<QuerySnapshot<Map<String, dynamic>>> getUserInfo(ChatUser chatUser) {
    return firestore
        .collection('users')
        .where('id', isEqualTo: chatUser.id)
        .snapshots();
  }

  /// ✅ الحصول على جميع الرسائل (العادي - بدون فلترة)
  static Stream<QuerySnapshot<Map<String, dynamic>>>? getAllMessages(ChatUser chatUser) {
    if (me == null || chatUser.id.isEmpty) {
      log("getAllMessages: Invalid parameters");
      return Stream.empty();
    }

    final conversationId = getConversationID(chatUser.id);
    if (conversationId == null) return Stream.empty();

    return firestore
        .collection('chats/$conversationId/messages/')
        .orderBy('sent', descending: true)
        .snapshots();
  }

  /// ✅ الحصول على آخر رسالة
  static Stream<QuerySnapshot<Map<String, dynamic>>>? getLastMessage(ChatUser chatUser) {
    if (me == null || chatUser.id.isEmpty) {
      log("getLastMessage: Invalid parameters");
      return Stream.empty();
    }

    final conversationId = getConversationID(chatUser.id);
    if (conversationId == null) return Stream.empty();

    return firestore
        .collection('chats/$conversationId/messages/')
        .orderBy('sent', descending: true)
        .limit(1)
        .snapshots();
  }

  // ==================== UTILITY FUNCTIONS ====================

  /// ✅ الحصول على معرف المحادثة
  static String? getConversationID(String otherUserId) {
    if (me == null || otherUserId.isEmpty) {
      log("getConversationID: Invalid parameters");
      return null;
    }

    return me!.id.hashCode <= otherUserId.hashCode
        ? '${me!.id}_$otherUserId'
        : '${otherUserId}_${me!.id}';
  }

  /// ✅ الحصول على رسالة الإشعار
  static String _getNotificationMessage(Type type, String msgContent) {
    switch (type) {
      case Type.text:
        return msgContent;
      case Type.image:
        return 'تم إرسال صورة';
      case Type.video:
        return 'تم إرسال فيديو';
      case Type.audio:
        return 'تم إرسال مقطع صوتي';
      case Type.file:
        return 'تم إرسال ملف';
    }
  }

  /// ✅ التحقق من نوع الوسائط
  static bool _isMediaMessage(Type type) {
    return type == Type.image ||
        type == Type.video ||
        type == Type.audio ||
        type == Type.file;
  }
}

/// ✅ فئة مساعدة لإنشاء QuerySnapshot مفلتر
class _FilteredQuerySnapshot extends QuerySnapshot<Map<String, dynamic>> {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs;
  final SnapshotMetadata _metadata;

  _FilteredQuerySnapshot(this._docs, this._metadata);

  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => _docs;

  @override
  List<DocumentChange<Map<String, dynamic>>> get docChanges => [];

  @override
  SnapshotMetadata get metadata => _metadata;

  @override
  int get size => _docs.length;
}

/// ✅ Extension للـ firstOrNull
extension FirstOrNullExtension<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) {
      return iterator.current;
    }
    return null;
  }
}
