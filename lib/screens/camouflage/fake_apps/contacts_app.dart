import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../../../core/widgets/base_widgets.dart';
import '../../../core/error/error_handler.dart';
import '../../../core/utils/permission_manager.dart';
import '../../../core/themes/app_theme_extension.dart';
import '../../../core/localization/app_localizations.dart';
import '../../auth/login_screen.dart';

class ContactsApp extends BaseStatefulWidget {
  const ContactsApp({super.key});

  @override
  State<ContactsApp> createState() => _ContactsAppState();
}

class _ContactsAppState extends BaseState<ContactsApp> {
  List<Contact> _contacts = [];
  List<Contact> _filteredContacts = [];
  bool _isLoading = true;
  String _error = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _requestContactsPermission();
    _searchController.addListener(_filterContacts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _requestContactsPermission() async {
    try {
      if (await FlutterContacts.requestPermission()) {
        await _fetchContacts();
      } else {
        final errorMessage = ErrorHandler.createUserError(
          'permission_denied',
          localizations.get('contacts_permission_denied')
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

  Future<void> _fetchContacts() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });

      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: true,
      );

      // Sort contacts alphabetically
      contacts.sort((a, b) => a.displayName.compareTo(b.displayName));

      setState(() {
        _contacts = contacts;
        _filteredContacts = contacts;
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

  void _filterContacts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredContacts = _contacts;
      } else {
        _filteredContacts = _contacts.where((contact) {
          final name = contact.displayName.toLowerCase();
          final phone = contact.phones.isNotEmpty 
              ? contact.phones.first.number?.toLowerCase() ?? ''
              : '';
          return name.contains(query) || phone.contains(query);
        }).toList();
      }
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _filteredContacts = _contacts;
      }
    });
  }

  void _showAddContactDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.get('add_contact')),
        content: Text(localizations.get('add_contact_description')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.get('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _createNewContact();
            },
            child: Text(localizations.get('create')),
          ),
        ],
      ),
    );
  }

  Future<void> _createNewContact() async {
    try {
      final contact = Contact()
        ..name.first = 'New'
        ..name.last = 'Contact'
        ..phones = [Phone('1234567890')];
      
      await contact.insert();
      await _fetchContacts();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.get('contact_created')),
            backgroundColor: context.appTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorToUser(context, ErrorHandler.handleApiError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appTheme;
    return Scaffold(
      appBar: _isSearching ? _buildSearchAppBar(appColors) : _buildNormalAppBar(appColors),
      backgroundColor: appColors.backgroundColor,
      body: _buildBody(appColors),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddContactDialog,
        backgroundColor: appColors.primaryColor,
        child: Icon(Icons.add, color: appColors.onPrimaryColor),
      ),
    );
  }

  PreferredSizeWidget _buildNormalAppBar(AppThemeExtension appColors) {
    return AppBar(
      title: Text(
        localizations.get('contacts'),
        style: TextStyle(color: appColors.textPrimaryColor),
      ),
      backgroundColor: appColors.surfaceColor,
      elevation: 0,
      actions: [
        IconButton(
          icon: Icon(Icons.search, color: appColors.textPrimaryColor),
          onPressed: _toggleSearch,
        ),
        IconButton(
          icon: Icon(Icons.refresh, color: appColors.textPrimaryColor),
          onPressed: _fetchContacts,
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
          hintText: localizations.get('search_contacts'),
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

  Widget _buildBody(AppThemeExtension appColors) {
    if (_isLoading) {
      return BaseLoadingWidget(
        message: localizations.get('loading_contacts'),
      );
    }

    if (_error.isNotEmpty) {
      return _buildErrorState(appColors);
    }

    if (_filteredContacts.isEmpty) {
      return _buildEmptyState(appColors);
    }

    return _buildContactsList(appColors);
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
              onPressed: _fetchContacts,
              child: Text(localizations.get('retry')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppThemeExtension appColors) {
    return Center(
      child: BaseCardWidget(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.contact_page_outlined,
              size: 64,
              color: appColors.textSecondaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty
                  ? localizations.get('no_contacts_found')
                  : localizations.get('no_contacts'),
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
                  : localizations.get('add_contact_to_start'),
              textAlign: TextAlign.center,
              style: TextStyle(color: appColors.textSecondaryColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactsList(AppThemeExtension appColors) {
    return ListView.builder(
      itemCount: _filteredContacts.length,
      itemBuilder: (context, index) {
        final contact = _filteredContacts[index];
        return _buildContactItem(contact, appColors);
      },
    );
  }

  Widget _buildContactItem(Contact contact, AppThemeExtension appColors) {
    return BaseCardWidget(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      onTap: () => _showContactDetails(contact, appColors),
      child: ListTile(
        leading: _buildContactAvatar(contact, appColors),
        title: Text(
          contact.displayName.isNotEmpty ? contact.displayName : localizations.get('unknown_contact'),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: appColors.textPrimaryColor,
          ),
        ),
        subtitle: _buildContactSubtitle(contact, appColors),
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

  Widget _buildContactAvatar(Contact contact, AppThemeExtension appColors) {
    if (contact.photo != null && contact.photo!.isNotEmpty) {
      return CircleAvatar(
        backgroundImage: MemoryImage(contact.photo!),
        backgroundColor: appColors.primaryColor,
      );
    }

    final initial = contact.displayName.isNotEmpty 
        ? contact.displayName[0].toUpperCase() 
        : '?';
    
    return CircleAvatar(
      backgroundColor: appColors.primaryColor,
      child: Text(
        initial,
        style: TextStyle(
          color: appColors.onPrimaryColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget? _buildContactSubtitle(Contact contact, AppThemeExtension appColors) {
    final phones = contact.phones;
    final emails = contact.emails;
    
    if (phones.isNotEmpty) {
      return Text(
        phones.first.number ?? localizations.get('no_phone'),
        style: TextStyle(color: appColors.textSecondaryColor),
      );
    } else if (emails.isNotEmpty) {
      return Text(
        emails.first.address,
        style: TextStyle(color: appColors.textSecondaryColor),
      );
    }
    
    return Text(
      localizations.get('no_contact_info'),
      style: TextStyle(color: appColors.textSecondaryColor),
    );
  }

  void _showContactDetails(Contact contact, AppThemeExtension appColors) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildContactDetailsSheet(contact, appColors),
    );
  }

  Widget _buildContactDetailsSheet(Contact contact, AppThemeExtension appColors) {
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
          
          // Contact avatar and name
          _buildContactAvatar(contact, appColors),
          const SizedBox(height: 16),
          Text(
            contact.displayName.isNotEmpty ? contact.displayName : localizations.get('unknown_contact'),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: appColors.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 20),
          
          // Contact details
          if (contact.phones.isNotEmpty) ...[
            _buildDetailSection(
              localizations.get('phone_numbers'),
              contact.phones.map((phone) => phone.number ?? '').toList(),
              Icons.phone,
              appColors,
            ),
            const SizedBox(height: 16),
          ],
          
          if (contact.emails.isNotEmpty) ...[
            _buildDetailSection(
              localizations.get('email_addresses'),
              contact.emails.map((email) => email.address).toList(),
              Icons.email,
              appColors,
            ),
            const SizedBox(height: 16),
          ],
          
          if (contact.addresses.isNotEmpty) ...[
            _buildDetailSection(
              localizations.get('addresses'),
              contact.addresses.map((addr) => addr.address).toList(),
              Icons.location_on,
              appColors,
            ),
            const SizedBox(height: 16),
          ],
          
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.get('close')),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<String> items, IconData icon, AppThemeExtension appColors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: appColors.primaryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: appColors.textPrimaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(left: 28, bottom: 4),
          child: Text(
            item,
            style: TextStyle(color: appColors.textSecondaryColor),
          ),
        )),
      ],
    );
  }
}
