// lib/models/message.dart

class Message {
  Message({
    required this.toId,
    required this.msg,
    required this.read,
    required this.type,
    required this.fromId,
    required this.sent,
    this.fileName,
    this.fileSize,
    this.audioDuration,
    this.videoDuration,
    this.thumbnailUrl,
    this.deletedFor,
    this.isEdited,
    this.editedAt,
    // ✅ إضافة حقول حالة الرفع
    this.uploadCompleted,
    this.uploadFailed,
    this.errorMessage,
  });

  late final String toId;
  late final String msg;
  late final String read;
  late final String fromId;
  late final String sent;
  late final Type type;

  // حقول الملفات المتقدمة
  late final String? fileName;
  late final int? fileSize;
  late final int? audioDuration;
  late final int? videoDuration;
  late final String? thumbnailUrl;

  // حقول نظام الحذف الذكي والتعديل
  late final List<String>? deletedFor;
  late final bool? isEdited;
  late final String? editedAt;

  // ✅ حقول حالة الرفع
  late final bool? uploadCompleted;
  late final bool? uploadFailed;
  late final String? errorMessage;

  // معرف الرسالة الفريد
  String get id => '${fromId}_${sent}';

  // ✅ دوال مساعدة محسنة
  bool isDeletedFor(String userId) => deletedFor?.contains(userId) ?? false;
  bool get wasEdited => isEdited == true;
  bool get isValid => toId.isNotEmpty && fromId.isNotEmpty && sent.isNotEmpty && msg.isNotEmpty;
  int get deletedCount => deletedFor?.length ?? 0;

  // ✅ دوال فحص حالة الرفع
  bool get isUploading => uploadCompleted != true && uploadFailed != true;
  bool get isUploadCompleted => uploadCompleted == true;
  bool get isUploadFailed => uploadFailed == true;

  bool canBeEditedBy(String userId) {
    return fromId == userId && type == Type.text && !isDeletedFor(userId);
  }

  DateTime? get editedDateTime {
    if (editedAt == null) return null;
    try {
      return DateTime.fromMillisecondsSinceEpoch(int.parse(editedAt!));
    } catch (e) {
      return null;
    }
  }

  Message markAsDeletedFor(String userId) {
    final currentDeleted = List<String>.from(deletedFor ?? []);
    if (!currentDeleted.contains(userId)) {
      currentDeleted.add(userId);
    }
    return copyWith(deletedFor: currentDeleted);
  }

  Message editContent(String newMsg) {
    return copyWith(
      msg: newMsg,
      isEdited: true,
      editedAt: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  Message.fromJson(Map<String, dynamic> json) {
    toId = json['toId'].toString();
    msg = json['msg'].toString();
    read = json['read'].toString();
    type = _getTypeFromString(json['type'].toString());
    fromId = json['fromId'].toString();
    sent = json['sent'].toString();
    fileName = json['fileName']?.toString();
    fileSize = json['fileSize'] != null
        ? int.tryParse(json['fileSize'].toString())
        : null;
    audioDuration = json['audioDuration'] != null
        ? int.tryParse(json['audioDuration'].toString())
        : null;
    videoDuration = json['videoDuration'] != null
        ? int.tryParse(json['videoDuration'].toString())
        : null;
    thumbnailUrl = json['thumbnailUrl']?.toString();

    deletedFor = json['deletedFor'] != null
        ? List<String>.from(json['deletedFor'])
        : null;
    isEdited = json['isEdited'] as bool?;
    editedAt = json['editedAt']?.toString();

    // ✅ معالجة حقول الرفع
    uploadCompleted = json['uploadCompleted'] as bool?;
    uploadFailed = json['uploadFailed'] as bool?;
    errorMessage = json['errorMessage']?.toString();
  }

  Type _getTypeFromString(String typeString) {
    switch (typeString) {
      case 'image':
        return Type.image;
      case 'audio':
        return Type.audio;
      case 'video':
        return Type.video;
      case 'file':
        return Type.file;
      default:
        return Type.text;
    }
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['toId'] = toId;
    data['msg'] = msg;
    data['read'] = read;
    data['type'] = type.name;
    data['fromId'] = fromId;
    data['sent'] = sent;
    if (fileName != null) data['fileName'] = fileName;
    if (fileSize != null) data['fileSize'] = fileSize;
    if (audioDuration != null) data['audioDuration'] = audioDuration;
    if (videoDuration != null) data['videoDuration'] = videoDuration;
    if (thumbnailUrl != null) data['thumbnailUrl'] = thumbnailUrl;
    if (deletedFor != null) data['deletedFor'] = deletedFor;
    if (isEdited != null) data['isEdited'] = isEdited;
    if (editedAt != null) data['editedAt'] = editedAt;

    // ✅ إضافة حقول الرفع
    if (uploadCompleted != null) data['uploadCompleted'] = uploadCompleted;
    if (uploadFailed != null) data['uploadFailed'] = uploadFailed;
    if (errorMessage != null) data['errorMessage'] = errorMessage;

    return data;
  }

  Message copyWith({
    String? toId,
    String? msg,
    String? read,
    Type? type,
    String? fromId,
    String? sent,
    String? fileName,
    int? fileSize,
    int? audioDuration,
    int? videoDuration,
    String? thumbnailUrl,
    List<String>? deletedFor,
    bool? isEdited,
    String? editedAt,
    // ✅ إضافة حقول الرفع
    bool? uploadCompleted,
    bool? uploadFailed,
    String? errorMessage,
  }) {
    return Message(
      toId: toId ?? this.toId,
      msg: msg ?? this.msg,
      read: read ?? this.read,
      type: type ?? this.type,
      fromId: fromId ?? this.fromId,
      sent: sent ?? this.sent,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      audioDuration: audioDuration ?? this.audioDuration,
      videoDuration: videoDuration ?? this.videoDuration,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      deletedFor: deletedFor ?? this.deletedFor,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      uploadCompleted: uploadCompleted ?? this.uploadCompleted,
      uploadFailed: uploadFailed ?? this.uploadFailed,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  String toString() {
    return 'Message(id: $id, type: ${type.name}, from: $fromId, to: $toId, edited: $wasEdited)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

enum Type { text, image, audio, video, file }

class AiMessage {
  String msg;
  final MessageType msgType;
  AiMessage({required this.msg, required this.msgType});
}

enum MessageType { user, bot }
