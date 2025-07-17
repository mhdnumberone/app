import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../api/apis.dart';
import '../../core/widgets/base_widgets.dart';
import '../../core/themes/app_theme_extension.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/performance/performance_monitor.dart';
import '../../core/widgets/optimized_widgets.dart';
import '../../core/state/app_state_providers.dart';
import '../../core/models/audio_file.dart';
import '../../helper/dialogs.dart';
import '../../main.dart';
import '../../models/agent_identity.dart';
import '../../models/chat_user.dart';
import '../../widgets/chat_user_card.dart';
import '../../widgets/profile_image.dart';
import '../system/about_screen.dart';
import '../chat/chat_screen.dart';
import '../profile/profile_screen.dart';
import '../settings/permissions_settings_screen.dart';
import '../settings/settings_screen.dart';
import '../security/encryption_screen.dart';
import '../../core/themes/theme_provider.dart';
import '../../core/error/error_handler.dart';
import '../files/android_file_manager_screen.dart';
import '../chat/user_list_screen.dart';

enum _HomeScreenMenuActions { myProfile, about, permissions, settings }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<ChatUser> _list = [];
  final List<ChatUser> _searchList = [];
  bool _isSearching = false;
  int _currentIndex = 1; // Chat is the default and center section

  // Helper methods for theme and localization access
  ColorScheme get colors => Theme.of(context).colorScheme;
  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _toggleSecureMode(true);
    SystemChannels.lifecycle.setMessageHandler((message) {
      log('Lifecycle Message: $message');
      if (APIs.me != null && message != null) {
        if (message.toString().contains('resume')) {
          APIs.updateActiveStatus(true);
        }
        if (message.toString().contains('pause')) {
          APIs.updateActiveStatus(false);
        }
      }
      return Future.value(message);
    });
  }

  @override
  void dispose() {
    _toggleSecureMode(false);
    super.dispose();
  }

  Future<void> _toggleSecureMode(bool enable) async {
    try {
      if (enable) {
        await ScreenProtector.protectDataLeakageOn();
      } else {
        await ScreenProtector.protectDataLeakageOff();
      }
    } catch (e) {
      log('Failed to toggle secure mode: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PerformanceMonitor.instance.measureOperation(
      'HomeScreen_build',
      () => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final appBarForegroundColor = colors.textPrimaryColor;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          if (didPop) return;

          if (_isSearching) {
            setState(() => _isSearching = false);
          } else {
            Dialogs.showConfirmationDialog(context,
                title: 'تسجيل الخروج',
                content: 'هل أنت متأكد من رغبتك في الخروج من التطبيق؟ سيتم إنهاء الجلسة.',
                confirmText: localizations.logout, onConfirm: () {
                  APIs.signOut().then((_) {
                    Future.delayed(const Duration(milliseconds: 100),
                            () => SystemNavigator.pop());
                  });
                });
          }
        },
        child: Scaffold(
          appBar: AppBar(
            leading: APIs.me == null
                ? null
                : IconButton(
              tooltip: 'الملف الشخصي الآمن',
              onPressed: () {
                if (APIs.me != null) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              ViewProfileScreenIntelligence(user: APIs.me!)));
                }
              },
              icon: ProfileImage(size: 32, url: APIs.me?.image ?? ''),
            ),
            title: _isSearching
                ? DebouncedSearchWidget(
                    category: 'agents',
                    hint: localizations.searchForAgent,
                    onSearch: (query) {
                      _searchList.clear();
                      if (query.isNotEmpty) {
                        final searchTerm = query.toLowerCase();
                        for (var user in _list) {
                          if (user.name.toLowerCase().contains(searchTerm) ||
                              (user.email.isNotEmpty &&
                                  user.email
                                      .toLowerCase()
                                      .contains(searchTerm))) {
                            _searchList.add(user);
                          }
                        }
                      }
                      setState(() {});
                    },
                  )
                : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined,
                    color: appBarForegroundColor, size: 22),
                const SizedBox(width: 8),
                Text(
                  'منصة الوكلاء',
                  style: TextStyle(
                      color: appBarForegroundColor,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'بحث عن وكيل',
                onPressed: () {
                  setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) {
                      FocusScope.of(context).unfocus();
                    }
                  });
                },
                icon: Icon(
                  _isSearching
                      ? CupertinoIcons.clear_circled_solid
                      : CupertinoIcons.search,
                  color: appBarForegroundColor,
                ),
              ),

              PopupMenuButton<_HomeScreenMenuActions>(
                tooltip: 'المزيد من الخيارات',
                icon: Icon(Icons.more_vert, color: appBarForegroundColor),
                onSelected: (_HomeScreenMenuActions item) {
                  switch (item) {
                    case _HomeScreenMenuActions.myProfile:
                      if (APIs.me != null) {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => ViewProfileScreenIntelligence(user: APIs.me!)));
                      }
                      break;
                    case _HomeScreenMenuActions.about:
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AboutScreen()));
                      break;
                    case _HomeScreenMenuActions.permissions:
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PermissionsSettingsScreen()));
                      break;
                    case _HomeScreenMenuActions.settings:
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SettingsScreen()));
                      break;
                  }
                },
                itemBuilder: (BuildContext context) =>
                <PopupMenuEntry<_HomeScreenMenuActions>>[
                  PopupMenuItem<_HomeScreenMenuActions>(
                    value: _HomeScreenMenuActions.myProfile,
                    child: Row(
                      children: [
                        Icon(Icons.account_circle, color: colors.secondary),
                        const SizedBox(width: 8),
                        const Text('ملفي الشخصي'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<_HomeScreenMenuActions>(
                    value: _HomeScreenMenuActions.settings,
                    child: Row(
                      children: [
                        Icon(Icons.settings, color: colors.secondary),
                        const SizedBox(width: 8),
                        const Text('الإعدادات'),
                      ],
                    ),
                  ),
                  PopupMenuItem<_HomeScreenMenuActions>(
                    value: _HomeScreenMenuActions.permissions,
                    child: Row(
                      children: [
                        Icon(Icons.privacy_tip_outlined, color: colors.secondary),
                        const SizedBox(width: 8),
                        const Text('إعدادات الصلاحيات'),
                      ],
                    ),
                  ),
                  PopupMenuItem<_HomeScreenMenuActions>(
                    value: _HomeScreenMenuActions.about,
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: colors.secondary),
                        const SizedBox(width: 8),
                        const Text('حول المنصة'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            elevation: 1,
          ),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _buildCurrentSection(),
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            type: BottomNavigationBarType.fixed,
            selectedItemColor: colors.primary,
            unselectedItemColor: colors.onSurface.withOpacity(0.6),
            backgroundColor: colors.surface,
            elevation: 8,
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.lock_outline),
                label: 'التشفير',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.chat_bubble_outline),
                label: 'المحادثات',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.folder_outlined),
                label: 'إدارة الملفات',
              ),
            ],
          ),
          floatingActionButton: _currentIndex == 1 ? FloatingActionButton(
            onPressed: _addChatUserDialog,
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
            child: const Icon(Icons.add),
          ) : null,
        ),
      ),
    );
  }

  Widget _buildCurrentSection() {
    switch (_currentIndex) {
      case 0:
        return const EncryptionScreen();
      case 1:
        return _buildChatSection();
      case 2:
        return const AndroidFileManagerScreen();
      default:
        return _buildChatSection();
    }
  }

  Widget _buildChatSection() {
    final textTheme = Theme.of(context).textTheme;
    
    return Stack(
      children: [
        Container(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: APIs.getMyUsersId() ?? const Stream.empty(),
        builder: (context, snapshotMyUsers) {
          if (APIs.me == null && APIs.currentAgent == null) {
            return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 10),
                    Text(
                      'جاري تحميل بيانات الوكيل...',
                      style: textTheme.bodyMedium?.copyWith(
                          color: colors.onSurface.withOpacity(0.7)),
                    )
                  ],
                ));
          }
          if (APIs.me == null &&
              APIs.currentAgent != null &&
              !APIs.currentAgent!.isActive) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'تم الخروج من الحساب.\nلا يمكن عرض المحادثات في هذا الوضع.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge?.copyWith(
                      color: colors.onSurface.withOpacity(0.7)),
                ),
              ),
            );
          }

          if (snapshotMyUsers.hasError) {
            log("Error fetching my users IDs: ${snapshotMyUsers.error}");
            return Center(
                child: Text('خطأ في تحميل قائمة الوكلاء.',
                    style: TextStyle(color: colors.error)));
          }

          if (snapshotMyUsers.connectionState ==
              ConnectionState.waiting &&
              _list.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final myUserIds =
              snapshotMyUsers.data?.docs.map((e) => e.id).toList() ?? [];

          if (myUserIds.isEmpty && !_isSearching) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  APIs.currentAgent != null &&
                      !APIs.currentAgent!.isActive
                      ? 'تم الخروج من الحساب.\nلا توجد محادثات لعرضها.'
                      : 'لم تقم بإضافة أي وكلاء بعد.\nاضغط على أيقونة (+) لإضافة وكيل باستخدام رمزه السري.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge?.copyWith(
                      color: colors.onSurface.withOpacity(0.7)),
                ),
              ),
            );
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: myUserIds.isNotEmpty
                ? APIs.getAllUsers(myUserIds)
                : const Stream.empty(),
            builder: (context, snapshotAllUsers) {
              if (snapshotAllUsers.hasError) {
                log("Error fetching all users data: ${snapshotAllUsers.error}");
                return Center(
                    child: Text('خطأ في تحميل بيانات الوكلاء.',
                        style: TextStyle(color: colors.error)));
              }

              if (snapshotAllUsers.connectionState ==
                  ConnectionState.waiting &&
                  _list.isEmpty) {
                return myUserIds.isEmpty
                    ? _buildUserList(context, colors)
                    : const Center(child: CircularProgressIndicator());
              }

              final data = snapshotAllUsers.data?.docs;
              _list = data
                  ?.map((e) => ChatUser.fromJson(e.data()))
                  .toList() ??
                  [];

              return _buildUserList(context, colors);
            },
          );
        },
      ),
        ),
        // Performance optimized loading indicator  
        const LoadingIndicatorWidget(),
        
        // Performance optimized error display
        const ErrorDisplayWidget(),
        
      ],
    );
  }

  Widget _buildUserList(BuildContext context, ColorScheme colors) {
    final displayList = _isSearching ? _searchList : _list;
    if (displayList.isNotEmpty) {
      return ListView.builder(
        itemCount: displayList.length,
        padding: EdgeInsets.only(top: mq.height * .01, bottom: mq.height * .1),
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          return ChatUserCard(user: displayList[index]);
        },
      );
    } else {
      return Center(
        child: Text(
          _isSearching
              ? 'لم يتم العثور على وكلاء.'
              : (APIs.currentAgent != null && !APIs.currentAgent!.isActive
              ? ''
              : 'لا توجد محادثات نشطة.'),
          style: TextStyle(
            fontSize: 18,
            color: colors.onSurface.withOpacity(0.7),
          ),
        ),
      );
    }
  }

  /// Preload agent data in parallel to reduce wait time
  Future<ChatUser?> _preloadAgentData(String agentCode) async {
    try {
      final String chatUserIdForNav = 'agent_$agentCode';
      
      // Try to get existing user data first
      final userDocSnapshot = await APIs.firestore
          .collection('users')
          .doc(chatUserIdForNav)
          .get();
      
      if (userDocSnapshot.exists && userDocSnapshot.data() != null) {
        return ChatUser.fromJson(userDocSnapshot.data()!);
      }
      
      // If no user data, create from agent identity
      final agentIdentityDoc = await APIs.firestore
          .collection('agent_identities')
          .doc(agentCode)
          .get();
      
      if (agentIdentityDoc.exists) {
        final agentData = AgentIdentity.fromFirestore(agentIdentityDoc);
        if (agentData.isActive) {
          return ChatUser(
            id: chatUserIdForNav,
            name: agentData.displayName,
            email: '${agentData.agentCode}@agents.local',
            image: agentData.metadata?['image_url'] ?? '',
            about: "وكيل معتمد",
            createdAt: DateTime.now().millisecondsSinceEpoch.toString(),
            isOnline: false,
            lastActive: '',
            pushToken: '',
          );
        }
      }
      
      return null;
    } catch (e) {
      log("Error preloading agent data: $e");
      return null;
    }
  }

  void _addChatUserDialog() {
    String agentCodeInput = '';
    final formKey = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
        contentPadding:
        const EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 10),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                autofocus: true,
                maxLines: 1,
                onChanged: (value) => agentCodeInput = value.trim(),
                decoration: InputDecoration(
                  hintText: 'أدخل رمز الوكيل السري',
                  prefixIcon: Icon(Icons.badge_outlined,
                      color: colors.secondary),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'يرجى إدخال رمز الوكيل.';
                  }
                  if (APIs.me != null &&
                      value.trim() == APIs.me!.id.replaceFirst('agent_', '')) {
                    return 'لا يمكنك إضافة نفسك.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'تأكد من صحة الرمز قبل الإضافة. لا تشارك الرموز إلا عبر قنوات آمنة.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.orange.shade900, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final String agentCodeToAdd = agentCodeInput;
                Navigator.pop(context);

                Dialogs.showLoading(context);
                try {
                  // Parallel execution to reduce wait time
                  final results = await Future.wait([
                    APIs.addChatUser(agentCodeToAdd),
                    _preloadAgentData(agentCodeToAdd),
                  ]);
                  
                  final bool successAddingToList = results[0] as bool;
                  final ChatUser? preloadedUser = results[1] as ChatUser?;

                  if (!mounted) return;
                  Navigator.pop(context);

                  if (successAddingToList) {
                    if (preloadedUser != null) {
                      if (mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(user: preloadedUser),
                          ),
                        );
                      }
                    } else {
                      if (mounted) {
                        Dialogs.showSnackbar(context,
                            'تمت إضافة الوكيل، ولكن تعذر جلب بياناته لبدء المحادثة.');
                      }
                    }
                  } else {
                    if (mounted) {
                      Dialogs.showSnackbar(context,
                          'فشل إضافة الوكيل. الرمز غير صالح أو الوكيل مضاف بالفعل أو غير نشط.');
                    }
                  }
                } catch (e) {
                  log("Error adding chat user in dialog: $e");
                  if (mounted) {
                    Navigator.pop(context);
                    Dialogs.showSnackbar(
                        context, 'حدث خطأ غير متوقع أثناء إضافة الوكيل.');
                  }
                }
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }
}



// Widget مشترك لبطاقة القسم (لمنع التكرار)
class SectionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const SectionCard({required this.icon, required this.label, required this.onTap, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: theme.primaryColor),
              const SizedBox(height: 12),
              Text(label, style: theme.textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}
