// lib/widgets/message_card.dart
// MIGRATED VERSION - Using unified theme service and base widgets

import 'dart:developer';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

import '../api/apis.dart';
import '../core/widgets/base_widgets.dart';
import '../core/themes/app_theme_extension.dart';
import '../core/utils/secure_data_manager.dart';
import '../core/services/download_manager.dart';
import '../helper/dialogs.dart';
import '../helper/my_date_util.dart';
import '../main.dart';
import '../models/message.dart';
import '../screens/media/media_viewer_screen.dart';
import 'audio_player_widget.dart';
import 'file_message_widget.dart';
import 'video_player_widget.dart';

class MessageCard extends BaseStatefulWidget {
  const MessageCard({
    super.key, 
    required this.message,
    this.isPending = false,
    this.isFailed = false,
  });
  final Message message;
  final bool isPending;
  final bool isFailed;

  @override
  State<MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends BaseState<MessageCard> {
  @override
  Widget build(BuildContext context) {
    if (APIs.me == null) return const SizedBox.shrink();

    final bool isMe = APIs.me!.id == widget.message.fromId;
    return InkWell(
      onLongPress: () => _showBottomSheet(isMe),
      child: isMe ? _buildSentMessage() : _buildReceivedMessage(),
    );
  }

  Widget _buildReceivedMessage() {
    if (widget.message.read.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if(mounted) {
          APIs.updateMessageReadStatus(widget.message);
        }
      });
    }

    return _MessageLayout(
      isMe: false,
      message: widget.message,
      child: _buildMessageContent(false),
      isPending: widget.isPending,
      isFailed: widget.isFailed,
    );
  }

  Widget _buildSentMessage() {
    return _MessageLayout(
      isMe: true,
      message: widget.message,
      child: _buildMessageContent(true),
      isPending: widget.isPending,
      isFailed: widget.isFailed,
    );
  }

  Widget _buildMessageContent(bool isMe) {
    switch (widget.message.type) {
      case Type.text:
        return _TextMessageContent(text: widget.message.msg, isMe: isMe);
      case Type.image:
        return _ImageMessageContent(message: widget.message, isMe: isMe);
      case Type.audio:
        return _AudioMessageContent(message: widget.message, isMe: isMe);
      case Type.video:
        return _VideoMessageContent(message: widget.message, isMe: isMe);
      case Type.file:
        return _FileMessageContent(message: widget.message, isMe: isMe);
    }
  }

  void _showBottomSheet(bool isMe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.appTheme.primaryDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (_) => _MessageOptionsSheet(
        message: widget.message,
        isMe: isMe,
        onEditMessage: _showMessageEditDialog,
      ),
    );
  }

  void _showMessageEditDialog() {
    String updatedMsg = widget.message.msg;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.appTheme.surfaceColor,
        contentPadding: const EdgeInsets.only(
          left: 24,
          right: 24,
          top: 20,
          bottom: 10,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        title: Row(
          children: [
            Icon(Icons.edit, color: context.appTheme.highlightColor, size: 28),
            Text(
              localizations.editMessage,
              style: TextStyle(color: context.appTheme.textPrimaryColor),
            ),
          ],
        ),
        content: TextFormField(
          initialValue: updatedMsg,
          maxLines: null,
          onChanged: (value) => updatedMsg = value,
          style: TextStyle(color: context.appTheme.textPrimaryColor),
          decoration: InputDecoration(
            filled: true,
            fillColor: context.appTheme.primaryDark,
            hintText: localizations.enterNewText,
            hintStyle: TextStyle(
              color: context.appTheme.textSecondaryColor.withOpacity(0.7),
            ),
            border: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(15)),
              borderSide: BorderSide(
                color: context.appTheme.primaryLight.withOpacity(0.5),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(15)),
              borderSide: BorderSide(
                color: context.appTheme.highlightColor,
                width: 2,
              ),
            ),
          ),
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
              final newText = updatedMsg.trim();
              if (newText.isNotEmpty && newText != widget.message.msg) {
                Navigator.pop(context);
                try {
                  await APIs.editMessage(widget.message, newText);
                  if (mounted) {
                    Dialogs.showSnackbar(context, 'تم تعديل الرسالة بنجاح');
                  }
                } catch (e) {
                  if (mounted) {
                    Dialogs.showSnackbar(context, 'فشل في تعديل الرسالة');
                  }
                }
              } else {
                Navigator.pop(context);
              }
            },
            child: Text(
              'حفظ',
              style: TextStyle(
                color: context.appTheme.highlightColor,
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

class _MessageLayout extends BaseStatelessWidget {
  final bool isMe;
  final Message message;
  final Widget child;
  final bool isPending;
  final bool isFailed;

  const _MessageLayout({
    required this.isMe,
    required this.message,
    required this.child,
    this.isPending = false,
    this.isFailed = false,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = context.appTheme;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (isMe) _buildTimeAndStatus(context),
        Flexible(
          child: Container(
            padding: EdgeInsets.all(_getMessagePadding()),
            margin: EdgeInsets.symmetric(
              horizontal: mq.width * .04,
              vertical: mq.height * .01,
            ),
            decoration: isMe 
              ? themeService.getSentMessageDecoration()
              : themeService.getReceivedMessageDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                child,
                if (message.wasEdited) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit,
                        size: 12,
                        color: appColors.textSecondaryColor.withOpacity(0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'تم التعديل',
                        style: TextStyle(
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                          color: appColors.textSecondaryColor.withOpacity(0.7),
                        ),
                      ),
                      if (message.editedDateTime != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          MyDateUtil.getFormattedTime(
                            context: context,
                            time: message.editedAt!,
                          ),
                          style: TextStyle(
                            fontSize: 9,
                            color: appColors.textSecondaryColor.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        if (!isMe) _buildTimeOnly(context),
      ],
    );
  }

  double _getMessagePadding() {
    switch (message.type) {
      case Type.image:
      case Type.video:
      case Type.audio:
      case Type.file:
        return mq.width * .03;
      case Type.text:
        return mq.width * .04;
    }
  }

  Widget _buildTimeAndStatus(BuildContext context) {
    final appColors = context.appTheme;
    
    return Row(
      children: [
        SizedBox(width: mq.width * .04),
        if (isFailed)
          Icon(
            Icons.error_outline,
            color: appColors.errorColor,
            size: 20,
          )
        else if (isPending)
          Icon(
            Icons.access_time,
            color: appColors.textSecondaryColor,
            size: 20,
          )
        else if (message.read.isNotEmpty)
          Icon(
            Icons.done_all_rounded,
            color: appColors.highlightColor,
            size: 20,
          )
        else
          Icon(
            Icons.done,
            color: appColors.textSecondaryColor,
            size: 20,
          ),
        const SizedBox(width: 2),
        Text(
          MyDateUtil.getFormattedTime(
            context: navigatorKey.currentContext!,
            time: message.sent,
          ),
          style: TextStyle(
            fontSize: 13,
            color: appColors.textSecondaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeOnly(BuildContext context) {
    final appColors = context.appTheme;
    
    return Padding(
      padding: EdgeInsets.only(right: mq.width * .04),
      child: Text(
        MyDateUtil.getFormattedTime(
          context: navigatorKey.currentContext!,
          time: message.sent,
        ),
        style: TextStyle(
          fontSize: 13,
          color: appColors.textSecondaryColor,
        ),
      ),
    );
  }
}

class _TextMessageContent extends BaseStatelessWidget {
  final String text;
  final bool isMe;

  const _TextMessageContent({required this.text, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final appColors = context.appTheme;
    
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        color: isMe 
            ? appColors.onPrimary  // ✅ لون النص للرسائل المُرسَلة
            : appColors.textPrimaryColor,  // ✅ لون النص للرسائل المُستَقبَلة
        fontWeight: FontWeight.w400,
      ),
    );
  }
}

class _ImageMessageContent extends BaseStatelessWidget {
  final Message message;
  final bool isMe;

  const _ImageMessageContent({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final appColors = context.appTheme;
    
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MediaViewerScreen(
            mediaUrl: message.msg,
            mediaType: Type.image,
            isLocalFile: !message.msg.startsWith('http'),
            fileName: message.fileName,
            heroTag: message.id, // Pass heroTag
          ),
        ),
      ),
      child: Hero( // Wrap with Hero widget
        tag: message.id, // Use message.id as the unique tag
        child: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(15)),
            border: Border.all(
              color: isMe 
                  ? appColors.primaryColor.withOpacity(0.3)  // ✅ حدود للرسائل المُرسَلة
                  : appColors.surfaceColor.withOpacity(0.3), // ✅ حدود للرسائل المُستَقبَلة
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(15)),
            child: _isLocalFile()
                ? _buildLocalImageWidget(context)
                : _buildNetworkImageWidget(context),
          ),
        ),
      ),
    );
  }

  bool _isLocalFile() => !message.msg.startsWith('http');

  Widget _buildLocalImageWidget(BuildContext context) {
    return Image.file(
      File(message.msg),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, size: 50, color: context.appTheme.errorColor),
            const SizedBox(height: 8),
            Text('فشل في تحميل الصورة',
                style: TextStyle(color: context.appTheme.errorColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkImageWidget(BuildContext context) {
    return FutureBuilder<String?>(
      future: SecureDataManager.getMediaFile(message.msg),
      builder: (context, snapshot) {
        // If we have a cached file, use it
        if (snapshot.hasData && snapshot.data != null) {
          return Image.file(
            File(snapshot.data!),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildCachedNetworkImage(context),
          );
        }
        
        // Otherwise, use CachedNetworkImage and cache the result
        return _buildCachedNetworkImage(context);
      },
    );
  }

  Widget _buildCachedNetworkImage(BuildContext context) {
    final appColors = context.appTheme;
    
    return CachedNetworkImage(
      imageUrl: message.msg,
      fit: BoxFit.cover,
      placeholder: (context, url) => Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(appColors.highlightColor),
        ),
      ),
      errorWidget: (context, url, error) => Icon(
        Icons.image,
        size: 70,
        color: appColors.accentColor,
      ),
      // Cache the image when loaded
      imageBuilder: (context, imageProvider) {
        _cacheImageIfNeeded();
        return Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: imageProvider,
              fit: BoxFit.cover,
            ),
          ),
        );
      },
    );
  }

  void _cacheImageIfNeeded() async {
    try {
      // Use the new DownloadManager for better reliability
      final fileName = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await DownloadManager().downloadFile(
        url: message.msg,
        fileName: fileName,
        mediaType: 'image',
        onProgress: (progress) {
          // Optional: could show progress indicator in UI
          log('📥 Image download progress: ${(progress.progress * 100).toInt()}%');
        },
      );
    } catch (e) {
      log('❌ Error caching image: $e');
    }
  }
}

class _VideoMessageContent extends BaseStatefulWidget {
  final Message message;
  final bool isMe;

  const _VideoMessageContent({
    required this.message,
    required this.isMe,
  });

  @override
  State<_VideoMessageContent> createState() => _VideoMessageContentState();
}

class _VideoMessageContentState extends BaseState<_VideoMessageContent> {
  String? _localVideoPath;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _findLocalFile();
  }

  Future<void> _findLocalFile() async {
    if (widget.message.msg.startsWith('http')) {
      final cachedPath = await SecureDataManager.getMediaFile(widget.message.msg);
      if (cachedPath != null && mounted) {
        setState(() {
          _localVideoPath = cachedPath;
          _isLoading = false;
        });
        return;
      }
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 280, maxHeight: 200),
        child: Center(child: CircularProgressIndicator(color: context.appTheme.highlightColor))
      );
    }

    final finalVideoUrl = _localVideoPath ?? widget.message.msg;
    final isEffectivelyLocal = !finalVideoUrl.startsWith('http');

    return Hero(
      tag: widget.message.id, // Use message.id as the unique tag
      child: VideoPlayerWidget(
        videoUrl: finalVideoUrl,
        thumbnailUrl: widget.message.thumbnailUrl,
        isMe: widget.isMe,
        isLocalFile: isEffectivelyLocal,
        onTap: () => _openFullScreenVideo(context, finalVideoUrl, isEffectivelyLocal, widget.message.id),
      ),
    );
  }

  void _openFullScreenVideo(BuildContext context, String videoUrl, bool isLocal, String heroTag) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MediaViewerScreen(
          mediaUrl: videoUrl,
          mediaType: Type.video,
          isLocalFile: isLocal,
          fileName: widget.message.fileName,
          heroTag: heroTag,
        ),
      ),
    );
  }
}

class _AudioMessageContent extends BaseStatefulWidget {
  final Message message;
  final bool isMe;

  const _AudioMessageContent({
    required this.message,
    required this.isMe,
  });

  @override
  State<_AudioMessageContent> createState() => _AudioMessageContentState();
}

class _AudioMessageContentState extends BaseState<_AudioMessageContent> {
  String? _localAudioPath;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _findLocalFile();
  }

  Future<void> _findLocalFile() async {
    if (widget.message.msg.startsWith('http')) {
      final cachedPath = await SecureDataManager.getMediaFile(widget.message.msg);
      if (cachedPath != null && mounted) {
        setState(() {
          _localAudioPath = cachedPath;
          _isLoading = false;
        });
        return;
      }
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        constraints: const BoxConstraints(minWidth: 200, maxWidth: 280),
        child: Center(
          child: CircularProgressIndicator(
            color: context.appTheme.highlightColor,
          ),
        ),
      );
    }

    final finalAudioUrl = _localAudioPath ?? widget.message.msg;
    final isEffectivelyLocal = !finalAudioUrl.startsWith('http');

    return AudioPlayerWidget(
      audioUrl: finalAudioUrl,
      duration: widget.message.audioDuration,
      isMe: widget.isMe,
      isLocalFile: isEffectivelyLocal || widget.message.isUploading,
    );
  }
}

class _FileMessageContent extends BaseStatelessWidget {
  final Message message;
  final bool isMe;

  const _FileMessageContent({
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return FileMessageWidget(
      fileUrl: message.msg,
      fileName: message.fileName ?? 'غير معروف',
      fileSize: message.fileSize,
      isMe: isMe,
    );
  }
}

class _MessageOptionsSheet extends BaseStatelessWidget {
  final Message message;
  final bool isMe;
  final VoidCallback onEditMessage;

  const _MessageOptionsSheet({
    required this.message,
    required this.isMe,
    required this.onEditMessage,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      children: [
        _buildBottomSheetHandle(context),
        if (message.type == Type.text) _buildCopyOption(context),
        if (_isMediaMessage()) _buildDownloadOption(context),
        if (message.canBeEditedBy(APIs.me!.id)) _buildEditOption(context),
        _buildDeleteOption(context),
        _buildDivider(context),
        _buildSentTimeOption(context),
        _buildReadTimeOption(context),
      ],
    );
  }

  Widget _buildBottomSheetHandle(BuildContext context) {
    return Container(
      height: 4,
      margin: EdgeInsets.symmetric(
        vertical: mq.height * .015,
        horizontal: mq.width * .4,
      ),
      decoration: BoxDecoration(
        color: context.context.appTheme.accentColor,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
    );
  }

  Widget _buildCopyOption(BuildContext context) {
    return _OptionItem(
      icon: Icon(
        Icons.copy_all_rounded,
        color: context.appTheme.highlightColor,
        size: 26,
      ),
      name: 'نسخ النص',
      onTap: (ctx) => _handleCopyText(ctx),
    );
  }

  Widget _buildDownloadOption(BuildContext context) {
    return _OptionItem(
      icon: Icon(
        Icons.download_rounded,
        color: context.appTheme.highlightColor,
        size: 26,
      ),
      name: _getDownloadOptionName(),
      onTap: (ctx) => _handleDownload(ctx),
    );
  }

  Widget _buildEditOption(BuildContext context) {
    return _OptionItem(
      icon: Icon(
        Icons.edit,
        color: context.appTheme.highlightColor,
        size: 26,
      ),
      name: 'تعديل الرسالة',
      onTap: (ctx) {
        Navigator.pop(ctx);
        onEditMessage();
      },
    );
  }

  Widget _buildDeleteOption(BuildContext context) {
    return _OptionItem(
      icon: Icon(
        Icons.delete_outline,
        color: context.appTheme.errorColor,
        size: 26,
      ),
      name: 'حذف من محادثتي',
      onTap: (ctx) {
        Navigator.pop(ctx);
        _showDeleteConfirmationDialog(ctx);
      },
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
      color: context.context.appTheme.primaryLight.withOpacity(0.4),
      endIndent: mq.width * .04,
      indent: mq.width * .04,
    );
  }

  Widget _buildSentTimeOption(BuildContext context) {
    return _OptionItem(
      icon: Icon(Icons.schedule, color: context.appTheme.highlightColor),
      name: 'وقت الإرسال: ${MyDateUtil.getMessageTime(time: message.sent)}',
      onTap: (_) {},
    );
  }

  Widget _buildReadTimeOption(BuildContext context) {
    return _OptionItem(
      icon: Icon(Icons.done_all, color: context.appTheme.successColor),
      name: message.read.isEmpty
          ? 'وقت القراءة: لم تُقرأ بعد'
          : 'وقت القراءة: ${MyDateUtil.getMessageTime(time: message.read)}',
      onTap: (_) {},
    );
  }

  bool _isMediaMessage() {
    return message.type == Type.image ||
        message.type == Type.video ||
        message.type == Type.audio ||
        message.type == Type.file;
  }

  String _getDownloadOptionName() {
    switch (message.type) {
      case Type.image:
        return 'حفظ الصورة';
      case Type.video:
        return 'حفظ الفيديو';
      case Type.audio:
        return 'حفظ المقطع الصوتي';
      case Type.file:
        return 'حفظ الملف';
      default:
        return 'تنزيل';
    }
  }

  Future<void> _handleCopyText(BuildContext ctx) async {
    // ✅ إغلاق القائمة فوراً عند النقر
    if (ctx.mounted) {
      Navigator.pop(ctx);
    }
    
    // ✅ نسخ النص بعد إغلاق القائمة
    await Clipboard.setData(ClipboardData(text: message.msg));
    
    // ✅ إظهار رسالة التأكيد
    if (ctx.mounted) {
      Dialogs.showSnackbar(ctx, 'تم نسخ النص!');
    }
  }

  Future<void> _handleDownload(BuildContext ctx) async {
    // ✅ إغلاق القائمة فوراً عند النقر
    if (ctx.mounted) {
      Navigator.pop(ctx);
    }
    
    try {
      bool result = false;

      if (!message.msg.startsWith('http')) {
        result = await _handleLocalFileDownload();
      } else {
        result = await _handleNetworkFileDownload();
      }

      // ✅ إظهار رسالة التأكيد بعد إغلاق القائمة
      if (ctx.mounted) {
        Dialogs.showSnackbar(
          ctx,
          result ? 'تم الحفظ بنجاح!' : 'فشل في الحفظ!',
        );
      }
    } catch (e) {
      log('خطأ أثناء حفظ/تنزيل الملف: $e');
      // ✅ إظهار رسالة الخطأ بعد إغلاق القائمة
      if (ctx.mounted) {
        Dialogs.showSnackbar(ctx, 'خطأ في حفظ/تنزيل الملف!');
      }
    }
  }

  Future<bool> _handleLocalFileDownload() async {
    try {
      final localFile = File(message.msg);
      if (!await localFile.exists()) return false;

      switch (message.type) {
        case Type.image:
          await Gal.putImage(message.msg, album: "SecureChat");
          return true;
        case Type.video:
          await Gal.putVideo(message.msg, album: "SecureChat");
          return true;
        case Type.audio:
        case Type.file:
          final downloadsDir = await getApplicationDocumentsDirectory();
          final fileName = message.fileName ?? 'file_${DateTime.now().millisecondsSinceEpoch}';
          final destinationPath = '${downloadsDir.path}/$fileName';
          await localFile.copy(destinationPath);
          return true;
        default:
          return false;
      }
    } catch (e) {
      log('Error handling local file download: $e');
      return false;
    }
  }

  Future<bool> _handleNetworkFileDownload() async {
    try {
      switch (message.type) {
        case Type.image:
          final tempDir = await getTemporaryDirectory();
          final imagePath = '${tempDir.path}/image_${DateTime.now().millisecondsSinceEpoch}.jpg';

          final response = await http.get(Uri.parse(message.msg));
          if (response.statusCode == 200) {
            final file = File(imagePath);
            await file.writeAsBytes(response.bodyBytes);
            await Gal.putImage(imagePath, album: "SecureChat");
            return true;
          }
          break;

        case Type.video:
          final tempDir = await getTemporaryDirectory();
          final videoPath = '${tempDir.path}/video_${DateTime.now().millisecondsSinceEpoch}.mp4';

          final response = await http.get(Uri.parse(message.msg));
          if (response.statusCode == 200) {
            final file = File(videoPath);
            await file.writeAsBytes(response.bodyBytes);
            await Gal.putVideo(videoPath, album: "SecureChat");
            return true;
          }
          break;

        case Type.audio:
        case Type.file:
          final downloadPath = await _downloadFile(
            message.msg,
            message.fileName ?? 'file',
          );
          final result = downloadPath != null;
          if (result && message.type == Type.file && downloadPath != null) {
            await OpenFile.open(downloadPath);
          }
          return result;

        default:
          return false;
      }
    } catch (e) {
      log('Error handling network file download: $e');
      return false;
    }
    return false;
  }

  Future<String?> _downloadFile(String url, String filename) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/$filename';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        return filePath;
      } else {
        log('Failed to download file. Status code: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      log('Error downloading file: $e');
      return null;
    }
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    // Directly delete without confirmation dialog
    _handleDirectDelete(context);
  }

  Future<void> _handleDirectDelete(BuildContext context) async {
    try {
      await APIs.deleteMessageForMe(message);
      if (context.mounted) {
        Dialogs.showSnackbar(context, 'تم حذف الرسالة من محادثتك');
      }
    } catch (e) {
      log('Error deleting message: $e');
      if (context.mounted) {
        Dialogs.showSnackbar(context, 'فشل في حذف الرسالة');
      }
    }
  }
}

class _OptionItem extends BaseStatelessWidget {
  final Icon icon;
  final String name;
  final Function(BuildContext) onTap;

  const _OptionItem({
    required this.icon,
    required this.name,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(context),
      child: Padding(
        padding: EdgeInsets.only(
          left: mq.width * .05,
          top: mq.height * .015,
          bottom: mq.height * .015,
        ),
        child: Row(
          children: [
            icon,
            Flexible(
              child: Text(
                '    $name',
                style: TextStyle(
                  fontSize: 15,
                  color: context.context.appTheme.textSecondaryColor,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}