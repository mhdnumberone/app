import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../models/chat_user.dart';
import '../../api/apis.dart';
import 'chat_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserListScreen extends StatelessWidget {
  const UserListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations?.get('user_list_title') ?? 'قائمة المستخدمين'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: APIs.getMyUsersId(),
        builder: (context, snapshotMyUsers) {
          if (snapshotMyUsers.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshotMyUsers.hasError) {
            return Center(child: Text(localizations?.get('error_loading_users') ?? 'خطأ في تحميل المستخدمين'));
          }
          final myUserIds = snapshotMyUsers.data?.docs.map((e) => e.id).toList() ?? [];
          if (myUserIds.isEmpty) {
            return Center(child: Text(localizations?.get('no_users_found') ?? 'لا يوجد مستخدمون'));
          }
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: APIs.getAllUsers(myUserIds),
            builder: (context, snapshotAllUsers) {
              if (snapshotAllUsers.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshotAllUsers.hasError) {
                return Center(child: Text(localizations?.get('error_loading_users') ?? 'خطأ في تحميل المستخدمين'));
              }
              final users = snapshotAllUsers.data?.docs
                  .map((e) => ChatUser.fromJson(e.data()))
                  .toList() ?? [];
              if (users.isEmpty) {
                return Center(child: Text(localizations?.get('no_users_found') ?? 'لا يوجد مستخدمون'));
              }
              return ListView.separated(
                itemCount: users.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final user = users[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.primary,
                      child: Text(user.name.isNotEmpty ? user.name[0] : '?'),
                    ),
                    title: Text(user.name),
                    subtitle: Text(user.about),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ChatScreen(user: user)),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
} 