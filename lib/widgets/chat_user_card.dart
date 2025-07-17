// lib/widgets/chat_user_card.dart
// MIGRATED VERSION - Using unified theme service and base widgets

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/apis.dart';
import '../core/widgets/base_widgets.dart';
import '../core/themes/app_theme_extension.dart';
import '../core/performance/performance_monitor.dart';
import '../helper/my_date_util.dart';
import '../main.dart';
import '../models/chat_user.dart';
import '../models/message.dart';
import '../screens/chat/chat_screen.dart';
import '../core/navigation/smooth_page_transition.dart';
import 'dialogs/profile_dialog.dart';
import 'profile_image.dart';

// Provider for last message
final lastMessageProvider = StreamProvider.family<Message?, ChatUser>((ref, user) {
  final stream = APIs.getLastMessage(user);
  if (stream == null) {
    return Stream.value(null);
  }
  return stream.map((snapshot) {
    if (snapshot.docs.isEmpty) return null;
    return Message.fromJson(snapshot.docs.first.data());
  });
});

class ChatUserCard extends ConsumerWidget {
  final ChatUser user;
  const ChatUserCard({super.key, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ChatUserCardContent(user: user);
  }
}

class _ChatUserCardContent extends BaseStatelessWidget {
  final ChatUser user;
  
  const _ChatUserCardContent({required this.user});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final lastMessageAsync = ref.watch(lastMessageProvider(user));
        final appColors = Theme.of(context).colorScheme;

        return BaseCardWidget(
          onTap: () {
            Navigator.push(
              context,
              ChatPageTransition(
                child: ChatScreen(user: user),
                heroTag: 'chat_${user.id}',
              ),
            );
          },
          child: lastMessageAsync.when(
            data: (message) => _buildListTile(context, appColors, message),
            loading: () => _buildListTile(context, appColors, null),
            error: (error, stack) => _buildListTile(context, appColors, null),
          ),
        );
      },
    );
  }

  Widget _buildListTile(
    BuildContext context,
    ColorScheme appColors,
    Message? message,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero, // Remove default padding since BaseCardWidget handles it
      leading: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => ProfileDialog(user: user),
          );
        },
        child: ProfileImage(
          size: mq.height * .055,
          url: user.image,
        ),
      ),
      title: Text(
        user.name,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).extension<AppThemeExtension>()!.textPrimaryColor,
        ),
      ),
      subtitle: Text(
        message != null
            ? _getLastMessagePreview(context, message)
            : user.about,
        maxLines: 1,
        style: TextStyle(
          fontSize: 14,
          color: Theme.of(context).extension<AppThemeExtension>()!.textSecondaryColor,
        ),
      ),
      trailing: message == null
          ? null
          : message.read.isEmpty && message.fromId != APIs.me?.id
              ? Container(
                  width: 15,
                  height: 15,
                  decoration: BoxDecoration(
                    color: Theme.of(context).extension<AppThemeExtension>()!.errorColor, // Using errorColor for unread indicator
                    shape: BoxShape.circle,
                  ),
                )
              : Text(
                  MyDateUtil.getLastMessageTime(
                    context: context,
                    time: message.sent,
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).extension<AppThemeExtension>()!.textSecondaryColor.withOpacity(0.8),
                  ),
                ),
    );
  }

  // Helper function to get message preview
  String _getLastMessagePreview(BuildContext context, Message message) {
    final localizations = this.localizations(context);
    
    switch (message.type) {
      case Type.text:
        return message.msg;
      case Type.image:
        return localizations.photo;
      case Type.video:
        return localizations.video;
      case Type.audio:
        return localizations.voiceMessage;
      case Type.file:
        return localizations.file;
    }
  }
}