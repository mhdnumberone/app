
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import '../../../core/widgets/base_widgets.dart';
import '../../../core/error/error_handler.dart';
import '../../../core/utils/permission_manager.dart';
import '../../../core/themes/app_theme_extension.dart';
import '../../../core/localization/app_localizations.dart';
import '../../auth/login_screen.dart';

class SmsApp extends BaseStatefulWidget {
  const SmsApp({super.key});

  @override
  State<SmsApp> createState() => _SmsAppState();
}

class _SmsAppState extends BaseState<SmsApp> {
  final SmsQuery _query = SmsQuery();
  List<SmsMessage> _messages = [];
  bool _isLoading = true;
  String _error = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _selectedFilter = 'all'; // all, inbox, sent
  String? _selectedAddress; // العنوان (الرقم) المحدد للمحادثة

  @override
  void initState() {
    super.initState();
    _requestSmsPermission();
    _searchController.addListener(_filterMessages);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _requestSmsPermission() async {
    try {
      final status = await Permission.sms.request();
      if (status.isGranted) {
        await _fetchSms();
      } else {
        final errorMessage = ErrorHandler.createUserError(
          'permission_denied',
          localizations.get('sms_permission_denied'),
        );
        setState(() {
          _isLoading = false;
          _error = errorMessage.userMessage;
        });
      }
    } catch (e) {
      final errorMessage = ErrorHandler.handleApiError(e);
      setState(() {
        _isLoading = false;
        _error = errorMessage.userMessage;
      });
    }
  }

  Future<void> _fetchSms() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });
      final messages = await _query.getAllSms;
      messages.sort((a, b) => (b.date ?? DateTime.now()).compareTo(a.date ?? DateTime.now()));
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
    } catch (e) {
      final errorMessage = ErrorHandler.handleApiError(e);
      setState(() {
        _isLoading = false;
        _error = errorMessage.userMessage;
      });
    }
  }

  void _filterMessages() {
    setState(() {}); // إعادة بناء الواجهة فقط لأن الفلترة تتم ديناميكياً
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
      }
    });
  }

  void _changeFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
  }

  void _showComposeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.get('compose_message')),
        content: Text(localizations.get('compose_message_description')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.get('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _simulateNewMessage();
            },
            child: Text(localizations.get('compose')),
          ),
        ],
      ),
    );
  }

  void _simulateNewMessage() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.get('message_compose_simulation')),
          backgroundColor: context.appTheme.primaryColor,
        ),
      );
    }
  }

  // --- منطق المحادثات ---
  List<String> get _allAddresses {
    final addresses = _messages.map((m) => m.address ?? '').where((a) => a.isNotEmpty).toSet().toList();
    addresses.sort();
    return addresses;
  }

  List<SmsMessage> _messagesForAddress(String address) {
    return _messages.where((m) => (m.address ?? '') == address).toList();
  }

  SmsMessage? _lastMessageForAddress(String address) {
    final msgs = _messagesForAddress(address);
    if (msgs.isEmpty) return null;
    msgs.sort((a, b) => (b.date ?? DateTime.now()).compareTo(a.date ?? DateTime.now()));
    return msgs.first;
  }

  List<SmsMessage> get _filteredConversationMessages {
    if (_selectedAddress == null) return [];
    var msgs = _messagesForAddress(_selectedAddress!);
    // فلترة حسب البحث
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      msgs = msgs.where((message) {
        final body = message.body?.toLowerCase() ?? '';
        return body.contains(query);
      }).toList();
    }
    // فلترة حسب النوع
    switch (_selectedFilter) {
      case 'inbox':
        msgs = msgs.where((msg) => msg.kind == SmsMessageKind.received).toList();
        break;
      case 'sent':
        msgs = msgs.where((msg) => msg.kind == SmsMessageKind.sent).toList();
        break;
      default:
        break;
    }
    return msgs;
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appTheme;
    return Scaffold(
      appBar: _isSearching ? _buildSearchAppBar(appColors) : _buildNormalAppBar(appColors),
      backgroundColor: appColors.backgroundColor,
      body: _isLoading
          ? BaseLoadingWidget(message: localizations.get('loading_messages'))
          : _error.isNotEmpty
              ? _buildErrorState(appColors)
              : _selectedAddress == null
                  ? _buildConversationsList(appColors)
                  : _buildConversationView(appColors),
      floatingActionButton: FloatingActionButton(
        onPressed: _showComposeDialog,
        backgroundColor: appColors.primaryColor,
        child: Icon(Icons.message, color: appColors.onPrimaryColor),
      ),
    );
  }

  PreferredSizeWidget _buildNormalAppBar(AppThemeExtension appColors) {
    return AppBar(
      title: Text(
        _selectedAddress == null
            ? localizations.get('messages')
            : (_selectedAddress ?? localizations.get('unknown_sender')),
        style: TextStyle(color: appColors.textPrimaryColor),
      ),
      backgroundColor: appColors.surfaceColor,
      elevation: 0,
      leading: _selectedAddress != null
          ? IconButton(
              icon: Icon(Icons.arrow_back, color: appColors.textPrimaryColor),
              onPressed: () => setState(() => _selectedAddress = null),
            )
          : null,
      actions: [
        IconButton(
          icon: Icon(Icons.search, color: appColors.textPrimaryColor),
          onPressed: _toggleSearch,
        ),
        IconButton(
          icon: Icon(Icons.refresh, color: appColors.textPrimaryColor),
          onPressed: _fetchSms,
        ),
      ],
    );
  }

  PreferredSizeWidget _buildSearchAppBar(AppThemeExtension appColors) {
    return AppBar(
      backgroundColor: appColors.surfaceColor,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: appColors.textPrimaryColor),
        onPressed: _toggleSearch,
      ),
      title: TextField(
        controller: _searchController,
        autofocus: true,
        style: TextStyle(color: appColors.textPrimaryColor),
        decoration: InputDecoration(
          hintText: localizations.get('search_messages'),
          hintStyle: TextStyle(color: appColors.textSecondaryColor),
          border: InputBorder.none,
        ),
      ),
      actions: [
        if (_searchController.text.isNotEmpty)
          IconButton(
            icon: Icon(Icons.clear, color: appColors.textPrimaryColor),
            onPressed: () => _searchController.clear(),
          ),
      ],
    );
  }

  Widget _buildErrorState(AppThemeExtension appColors) {
    return Center(
      child: BaseCardWidget(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: appColors.errorColor,
            ),
            const SizedBox(height: 16),
            Text(
              localizations.get('error'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: appColors.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error,
              textAlign: TextAlign.center,
              style: TextStyle(color: appColors.textSecondaryColor),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchSms,
              child: Text(localizations.get('retry')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationsList(AppThemeExtension appColors) {
    final addresses = _allAddresses;
    if (addresses.isEmpty) {
      return _buildEmptyState(appColors);
    }
    return ListView.builder(
      itemCount: addresses.length,
      itemBuilder: (context, index) {
        final address = addresses[index];
        final lastMsg = _lastMessageForAddress(address);
        return BaseCardWidget(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          onTap: () => setState(() => _selectedAddress = address),
          child: ListTile(
            leading: _buildMessageAvatar(lastMsg, lastMsg?.kind == SmsMessageKind.received, appColors),
            title: Text(
              address.isNotEmpty ? address : localizations.get('unknown_sender'),
              style: TextStyle(fontWeight: FontWeight.w600, color: appColors.textPrimaryColor),
            ),
            subtitle: Text(
              lastMsg?.body ?? localizations.get('no_content'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: appColors.textSecondaryColor),
            ),
            trailing: Text(
              _formatMessageTime(lastMsg?.date),
              style: TextStyle(fontSize: 12, color: appColors.textSecondaryColor),
            ),
            onLongPress: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildConversationView(AppThemeExtension appColors) {
    final msgs = _filteredConversationMessages;
    if (msgs.isEmpty) {
      return _buildEmptyState(appColors);
    }
    return Column(
      children: [
        _buildFilterTabs(appColors),
        Expanded(
          child: ListView.builder(
            itemCount: msgs.length,
            itemBuilder: (context, index) {
              final message = msgs[index];
              return _buildMessageItem(message, appColors);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(AppThemeExtension appColors) {
    return Center(
      child: BaseCardWidget(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.message_outlined,
              size: 64,
              color: appColors.textSecondaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty
                  ? localizations.get('no_messages_found')
                  : localizations.get('no_messages'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: appColors.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isNotEmpty
                  ? localizations.get('try_different_search')
                  : localizations.get('start_conversation'),
              textAlign: TextAlign.center,
              style: TextStyle(color: appColors.textSecondaryColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTabs(AppThemeExtension appColors) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: appColors.surfaceColor,
        border: Border(
          bottom: BorderSide(
            color: appColors.textSecondaryColor.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          _buildFilterTab('all', localizations.get('all_messages'), appColors),
          _buildFilterTab('inbox', localizations.get('inbox'), appColors),
          _buildFilterTab('sent', localizations.get('sent'), appColors),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String filter, String label, AppThemeExtension appColors) {
    final isSelected = _selectedFilter == filter;
    return Expanded(
      child: GestureDetector(
        onTap: () => _changeFilter(filter),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? appColors.primaryColor : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? appColors.primaryColor : appColors.textSecondaryColor,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageItem(SmsMessage message, AppThemeExtension appColors) {
    final isReceived = message.kind == SmsMessageKind.received;
    return BaseCardWidget(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      onTap: () => _showMessageDetails(message, appColors),
      child: ListTile(
        leading: _buildMessageAvatar(message, isReceived, appColors),
        title: Row(
          children: [
            Expanded(
              child: Text(
                message.sender ?? localizations.get('unknown_sender'),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: appColors.textPrimaryColor,
                ),
              ),
            ),
            Text(
              _formatMessageTime(message.date),
              style: TextStyle(
                fontSize: 12,
                color: appColors.textSecondaryColor,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              message.body ?? localizations.get('no_content'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: appColors.textSecondaryColor),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  isReceived ? Icons.call_received : Icons.call_made,
                  size: 12,
                  color: isReceived ? appColors.successColor : appColors.primaryColor,
                ),
                const SizedBox(width: 4),
                Text(
                  isReceived ? localizations.get('received') : localizations.get('sent'),
                  style: TextStyle(
                    fontSize: 10,
                    color: isReceived ? appColors.successColor : appColors.primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: appColors.textSecondaryColor,
        ),
        onLongPress: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        },
      ),
    );
  }

  Widget _buildMessageAvatar(SmsMessage? message, bool isReceived, AppThemeExtension appColors) {
    final sender = message?.sender ?? '';
    final initial = sender.isNotEmpty ? sender[0].toUpperCase() : '?';
    return CircleAvatar(
      backgroundColor: isReceived ? appColors.successColor : appColors.primaryColor,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatMessageTime(DateTime? date) {
    if (date == null) return localizations.get('unknown_time');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);
    if (messageDate == today) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return localizations.get('yesterday');
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _showMessageDetails(SmsMessage message, AppThemeExtension appColors) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildMessageDetailsSheet(message, appColors),
    );
  }

  Widget _buildMessageDetailsSheet(SmsMessage message, AppThemeExtension appColors) {
    final isReceived = message.kind == SmsMessageKind.received;
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: appColors.textSecondaryColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          // Message header
          Row(
            children: [
              _buildMessageAvatar(message, isReceived, appColors),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.sender ?? localizations.get('unknown_sender'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: appColors.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${isReceived ? localizations.get('received') : localizations.get('sent')} • ${_formatMessageTime(message.date)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: appColors.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Message content
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isReceived 
                  ? appColors.surfaceColor 
                  : appColors.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: appColors.textSecondaryColor.withOpacity(0.2),
              ),
            ),
            child: Text(
              message.body ?? localizations.get('no_content'),
              style: TextStyle(
                fontSize: 16,
                color: appColors.textPrimaryColor,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.get('close')),
          ),
        ],
      ),
    );
  }
}
