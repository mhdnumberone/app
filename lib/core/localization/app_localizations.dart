import 'package:flutter/material.dart';
import '../managers/settings_manager.dart';

/// App localization system
class AppLocalizations {
  final Locale locale;
  
  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// Get localized string
  String get(String key) {
    final languageCode = locale.languageCode;
    final result = _localizedStrings[languageCode]?[key] ?? key;
    
    // Debug: Log if we're getting the right language
    if (key == 'app_name') {
      print('AppLocalizations: Using language: $languageCode, key: $key, result: $result');
    }
    
    return result;
  }

  // Common strings
  String get appName => get('app_name');
  String get ok => get('ok');
  String get cancel => get('cancel');
  String get save => get('save');
  String get delete => get('delete');
  String get edit => get('edit');
  String get send => get('send');
  String get back => get('back');
  String get next => get('next');
  String get done => get('done');
  String get error => get('error');
  String get success => get('success');
  String get loading => get('loading');
  String get retry => get('retry');
  String get settings => get('settings');

  // Navigation
  String get home => get('home');
  String get chats => get('chats');
  String get contacts => get('contacts');
  String get profile => get('profile');
  String get about => get('about');

  // Chat
  String get typeMessage => get('type_message');
  String get sendSecureMessage => get('send_secure_message');
  String get online => get('online');
  String get offline => get('offline');
  String get lastSeen => get('last_seen');
  String get typing => get('typing');
  String get messageDeleted => get('message_deleted');
  String get messageEdited => get('message_edited');
  String get clearChat => get('clear_chat');
  String get deleteChat => get('delete_chat');
  String get blockUser => get('block_user');

  // Media
  String get image => get('image');
  String get video => get('video');
  String get audio => get('audio');
  String get file => get('file');
  String get camera => get('camera');
  String get gallery => get('gallery');
  String get pickFile => get('pick_file');
  String get uploadProgress => get('upload_progress');
  String get uploadFailed => get('upload_failed');
  String get uploadCancelled => get('upload_cancelled');

  // Settings
  String get appearance => get('appearance');
  String get language => get('language');
  String get theme => get('theme');
  String get security => get('security');
  String get privacy => get('privacy');
  String get notifications => get('notifications');
  String get storage => get('storage');

  // Themes
  String get intelligenceTheme => get('intelligence_theme');
  String get darkTheme => get('dark_theme');
  String get lightTheme => get('light_theme');
  String get autoTheme => get('auto_theme');

  // Security
  String get selfDestruct => get('self_destruct');
  String get deadManSwitch => get('dead_man_switch');
  String get biometric => get('biometric');
  String get pinCode => get('pin_code');
  String get autoLock => get('auto_lock');
  String get hideFromRecents => get('hide_from_recents');
  String get disableScreenshots => get('disable_screenshots');
  String get incognitoKeyboard => get('incognito_keyboard');

  // Self-destruct
  String get enableSelfDestruct => get('enable_self_destruct');
  String get selfDestructTimer => get('self_destruct_timer');
  String get wrongPasswordAttempts => get('wrong_password_attempts');
  String get deleteMessages => get('delete_messages');
  String get deleteAllData => get('delete_all_data');
  String get wipeDevice => get('wipe_device');

  // Dead man switch
  String get enableDeadManSwitch => get('enable_dead_man_switch');
  String get checkInterval => get('check_interval');
  String get maxInactivity => get('max_inactivity');
  String get emergencyEmail => get('emergency_email');
  String get sendWarningEmail => get('send_warning_email');

  // Permissions
  String get permissionRequired => get('permission_required');
  String get cameraPermission => get('camera_permission');
  String get storagePermission => get('storage_permission');
  String get microphonePermission => get('microphone_permission');
  String get contactsPermission => get('contacts_permission');

  // Errors
  String get networkError => get('network_error');
  String get permissionDenied => get('permission_denied');
  String get uploadError => get('upload_error');
  String get downloadError => get('download_error');
  String get authenticationError => get('authentication_error');

  // Additional UI strings
  String get chatSecurity => get('chat_security');
  String get deleteAfterReading => get('delete_after_reading');
  String get autoDeleteMessagesWhenRead => get('auto_delete_messages_when_read');
  String get hideMessagePreview => get('hide_message_preview');
  String get hideContentInNotifications => get('hide_content_in_notifications');
  String get typingIndicator => get('typing_indicator');
  String get showWhenTyping => get('show_when_typing');
  String get readReceipts => get('read_receipts');
  String get showMessageReadStatus => get('show_message_read_status');
  String get destructionType => get('destruction_type');
  String get importantInformation => get('important_information');
  String get backgroundServicesRequired => get('background_services_required');
  String get batteryOptimizationRequired => get('battery_optimization_required');
  String get appProtectedFromSystemKill => get('app_protected_from_system_kill');
  
  // Missing methods that were causing compilation errors
  String get initializingSystem => get('initializing_system');
  String get systemUpdateInProgress => get('system_update_in_progress');
  String deviceDetected(String deviceName) => get('device_detected').replaceAll('{deviceName}', deviceName);
  String get xiaomiTip => get('xiaomi_tip');
  String get vivoTip => get('vivo_tip');
  String get oppoTip => get('oppo_tip');
  String get huaweiTip => get('huawei_tip');
  String get batteryPermissionRequired => get('battery_permission_required');
  String get batteryPermissionExplanation => get('battery_permission_explanation');
  String get batteryPermissionInstructions => get('battery_permission_instructions');
  String get batteryPermissionWarning => get('battery_permission_warning');
  String get activateNow => get('activate_now');
  String get searchForAgent => get('search_for_agent');
  String get logout => get('logout');
  String get photo => get('photo');
  String get voiceMessage => get('voice_message');
  String get aiWelcome => get('ai_welcome');
  String get askSomething => get('ask_something');
  String get geminiApiKeyRequired => get('gemini_api_key_required');
  String get somethingWentWrong => get('something_went_wrong');
  String get aiAssistant => get('ai_assistant');
  String get askMeAnything => get('ask_me_anything');
  String get joinedOn => get('joined_on');
  String get permissionsSettings => get('permissions_settings');
  String get batteryOptimization => get('battery_optimization');
  String get editMessage => get('edit_message');
  String get enterNewText => get('enter_new_text');
  String get failedToLoadImage => get('failed_to_load_image');
  String get grantStoragePermission => get('grant_storage_permission');
  String get errorRequestingPermissions => get('error_requesting_permissions');

  // Encryption Screen
  String get encryptionTitle => get('encryption_title');
  String get operationMode => get('operation_mode');
  String get coverTextHint => get('cover_text_hint');
  String get passwordHint => get('password_hint');
  String get copiedToClipboard => get('copied_to_clipboard');
  String get copyToClipboard => get('copy_to_clipboard');
  String get outputHint => get('output_hint');
  String get encrypt => get('encrypt');
  String get decrypt => get('decrypt');
  String get hide => get('hide');
  String get reveal => get('reveal');
  String get encryptAndHide => get('encrypt_and_hide');
  String get revealAndDecrypt => get('reveal_and_decrypt');
  String get secretMessage => get('secret_message');
  String get encryptedMessage => get('encrypted_message');
  String get messageToHide => get('message_to_hide');
  String get textWithHiddenMessage => get('text_with_hidden_message');
  String get enterSecretMessage => get('enter_secret_message');
  String get enterEncryptedMessage => get('enter_encrypted_message');
  String get enterMessageToHide => get('enter_message_to_hide');
  String get enterTextWithHiddenMessage => get('enter_text_with_hidden_message');
  String get encryptButton => get('encrypt_button');
  String get decryptButton => get('decrypt_button');
  String get hideButton => get('hide_button');
  String get revealButton => get('reveal_button');
  String get encryptAndHideButton => get('encrypt_and_hide_button');
  String get revealAndDecryptButton => get('reveal_and_decrypt_button');
  String get clear => get('clear');
  String get output => get('output');
  String get clearAll => get('clear_all');
  String get coverText => get('cover_text');
  
  String get password => get('password');
  String get processing => get('processing');
  String get share => get('share');
  String get selected => get('selected');
  String get fileManager => get('file_manager');
  String get selectAll => get('select_all');
  String get search => get('search');
  String get refresh => get('refresh');
  String get newFolder => get('new_folder');
  String get storageInfo => get('storage_info');
  String get permissions => get('permissions');
  String get searchFiles => get('search_files');
  String get loadingFiles => get('loading_files');

  /// Pluralization support
  String plural(String key, int count) {
    final pluralKey = count == 1 ? '${key}_one' : '${key}_other';
    return get(pluralKey).replaceAll('{count}', count.toString());
  }

  /// Parametrized strings
  String param(String key, Map<String, String> params) {
    String result = get(key);
    params.forEach((key, value) {
      result = result.replaceAll('{$key}', value);
    });
    return result;
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    final supported = ['en', 'ar'].contains(locale.languageCode);
    print('AppLocalizations isSupported: ${locale.languageCode} -> $supported');
    return supported;
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    print('AppLocalizations load: Loading locale ${locale.languageCode}');
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => true;
}

/// Localized strings database
const Map<String, Map<String, String>> _localizedStrings = {
  'en': {
    // Common
    'app_name': 'SecureChat',
    'ok': 'OK',
    'cancel': 'Cancel',
    'save': 'Save',
    'delete': 'Delete',
    'edit': 'Edit',
    'send': 'Send',
    'back': 'Back',
    'next': 'Next',
    'done': 'Done',
    'error': 'Error',
    'success': 'Success',
    'loading': 'Loading...',
    'retry': 'Retry',
    'settings': 'Settings',

    // Navigation
    'home': 'Home',
    'chats': 'Chats',
    'contacts': 'Contacts',
    'profile': 'Profile',
    'about': 'About',

    // Chat
    'type_message': 'Type a message...',
    'send_secure_message': 'Secure message...',
    'online': 'Online',
    'offline': 'Offline',
    'last_seen': 'Last seen',
    'typing': 'typing...',
    'message_deleted': 'Message deleted',
    'message_edited': 'edited',
    'clear_chat': 'Clear Messages',
    'delete_chat': 'Delete Chat',
    'block_user': 'Block User',

    // Media
    'image': 'Image',
    'video': 'Video',
    'audio': 'Audio',
    'file': 'File',
    'camera': 'Camera',
    'gallery': 'Gallery',
    'pick_file': 'Pick File',
    'upload_progress': 'Uploading...',
    'upload_failed': 'Upload failed',
    'upload_cancelled': 'Upload cancelled',

    // Settings
    'appearance': 'Appearance',
    'language': 'Language',
    'theme': 'Theme',
    'security': 'Security',
    'privacy': 'Privacy',
    'notifications': 'Notifications',
    'storage': 'Storage',

    // Themes
    'intelligence_theme': 'Intelligence Dark',
    'dark_theme': 'Pure Dark',
    'light_theme': 'Light',
    'auto_theme': 'Auto',

    // Security
    'self_destruct': 'Self-Destruct',
    'dead_man_switch': 'Dead Man\'s Switch',
    'biometric': 'Biometric Lock',
    'pin_code': 'PIN Code',
    'auto_lock': 'Auto Lock',
    'hide_from_recents': 'Hide from Recents',
    'disable_screenshots': 'Disable Screenshots',
    'incognito_keyboard': 'Incognito Keyboard',

    // Self-destruct
    'enable_self_destruct': 'Enable Self-Destruct',
    'self_destruct_timer': 'Timer (minutes)',
    'wrong_password_attempts': 'Wrong password attempts',
    'delete_messages': 'Delete Messages Only',
    'delete_all_data': 'Delete All Data',
    'wipe_device': 'Wipe Device',

    // Dead man switch
    'enable_dead_man_switch': 'Enable Dead Man\'s Switch',
    'check_interval': 'Check Interval (hours)',
    'max_inactivity': 'Max Inactivity (days)',
    'emergency_email': 'Emergency Email',
    'send_warning_email': 'Send Warning Email',

    // Permissions
    'permission_required': 'Permission Required',
    'camera_permission': 'Camera permission is required to take photos',
    'storage_permission': 'Storage permission is required to access files',
    'microphone_permission': 'Microphone permission is required for voice messages',
    'contacts_permission': 'Contacts permission is required to find friends',

    // Errors
    'network_error': 'Network connection error',
    'permission_denied': 'Permission denied',
    'upload_error': 'Upload failed',
    'download_error': 'Download failed',
    'authentication_error': 'Authentication failed',
    
    // Login
    'login_success': 'Login successful',
    'login_failed': 'Login failed',
    'enter_security_code': 'Enter security code to continue',
    'security_code_placeholder': 'Security code / Destruction code',
    'security_code_label': 'Security Code',
    'invalid_code': 'Invalid code',
    'code_too_short': 'Code must be at least 4 characters',
    'please_enter_code': 'Please enter the code',
    'confirm_and_continue': 'Confirm and Continue',
    'app_temporarily_locked': 'App temporarily locked',
    'wrong_attempt': 'Wrong attempt',
    'attempts_remaining': 'attempts remaining',
    'temporarily_locked': 'Temporarily locked',
    'verifying': 'Verifying...',
    'first_time_welcome': 'Welcome! 👋',
    'welcome_to_secure_app': 'Welcome to the secure app!',
    'you_can_start_now': '✅ You can start now',
    'help_with_settings_later': '⚙️ We\'ll help you with settings later',
    'data_safe_protected': '🔒 Your data is safe and protected',
    'understood_lets_start': 'Got it, let\'s start!',
    'successful_login': 'Successful login',
    'welcome_back': 'Welcome back! 👋',
    'continue_button': 'Continue',
    'destruction_executed': 'Destruction executed',
    'destruction_executed_successfully': 'Destruction procedure executed successfully.',
    'switching_to_safe_mode': 'Switching to safe darkening mode.',
    'security_features_active': 'Active Security Features',
    'biometric_verification': 'Biometric verification',
    'available': 'Available',
    'not_available': 'Not available',
    'repeated_attempts_protection': 'Repeated attempts protection: Active',
    'emergency_mode': 'Emergency mode',
    'emergency_mode_available': 'Available (tap 5 times on security icon)',
    'destruction_codes': 'Destruction codes',
    'destruction_codes_available': 'Available (from Firebase)',
    'failed_attempts': 'Failed attempts',
    'locked_temporarily': 'Locked temporarily',
    
    // Additional UI text
    'chat_security': 'Chat Security',
    'delete_after_reading': 'Delete After Reading',
    'auto_delete_messages_when_read': 'Auto-delete messages when read',
    'hide_message_preview': 'Hide Message Preview',
    'hide_content_in_notifications': 'Hide content in notifications',
    'typing_indicator': 'Typing Indicator',
    'show_when_typing': 'Show when typing',
    'read_receipts': 'Read Receipts',
    'show_message_read_status': 'Show message read status',
    'destruction_type': 'Destruction Type',
    'important_information': 'Important Information',
    'background_services_required': 'Background services are required for the app to function properly and cannot be disabled. It is recommended to enable battery optimization to ensure the system does not stop the app.',
    'battery_optimization_required': 'Required for proper app functionality',
    'app_protected_from_system_kill': 'App protected from system termination',
    'initializing_system': 'Initializing system...', 
    'system_update_in_progress': 'System Update in Progress',
    'device_detected': 'Device detected: {deviceName}',
    'xiaomi_tip': 'For Xiaomi devices: We may need to enable "Autostart" for best performance.',
    'vivo_tip': 'For Vivo devices: We will help you enable background operation.',
    'oppo_tip': 'For Oppo/OnePlus devices: We may need to adjust power management settings.',
    'huawei_tip': 'For Huawei devices: Adding the app to protected apps is very important.',
    'battery_permission_required': 'Battery optimization permission is required.',
    'battery_permission_explanation': 'To ensure continuous operation and timely notifications, please disable battery optimization for this app.',
    'battery_permission_instructions': 'Go to App Info > Battery > Optimize battery usage > All apps > Disable optimization for this app.',
    'battery_permission_warning': 'Without this permission, the app may not function correctly in the background.',
    'activate_now': 'Activate Now',
    'search_for_agent': 'Search for agent...', 
    'logout': 'Logout',
    'photo': 'Photo',
    'voice_message': 'Voice Message',
    'ai_welcome': 'Hello! I am your AI assistant. How can I help you today?',
    'ask_something': 'Please ask something!',
    'gemini_api_key_required': 'Gemini API Key is required to use AI features.',
    'something_went_wrong': 'Something went wrong',
    'ai_assistant': 'AI Assistant',
    'ask_me_anything': 'Ask me anything...', 
    'joined_on': 'Joined On',
    'permissions_settings': 'Permissions Settings',
    'battery_optimization': 'Battery Optimization',
    'edit_message': 'Edit Message',
    'enter_new_text': 'Enter new text',
    'failed_to_load_image': 'Failed to load image',
    'grant_storage_permission': 'Grant Storage Permission',
    'error_requesting_permissions': 'Error requesting permissions',
    'unknown': 'Unknown',
    'days_ago': '{count} days ago',
    'hours_ago': '{count} hours ago',
    'minutes_ago': '{count} minutes ago',
    'just_now': 'Just now',

    // Profile Screen
    'emergency_destruction_code': 'Emergency Destruction Code',
    'destruction_code_description': 'Use this code in login screen for emergency data destruction',
    'copy_to_clipboard': 'Copy to clipboard',
    'destruction_warning': 'DANGER: This code will permanently destroy ALL data!',
    'destruction_warning_detail': 'Use only in emergency situations. This action cannot be undone.',
    'destruction_code_not_available': 'Emergency Destruction Code Not Available',
    'retry_loading_code': 'Retry Loading Code',
    'destruction_code_load_error': 'Your emergency destruction code could not be loaded. This may be due to:',
    'network_connectivity_issues': 'Network connectivity issues',
    'agent_configuration_problems': 'Agent configuration problems',
    'administrator_restrictions': 'Administrator restrictions',
    'contact_administrator': 'Try refreshing the data or contact your administrator for assistance.',
    'manual_data_destruction': 'Manual Data Destruction',
    'manual_destruction_description': 'Immediately destroy all user data from this device. This cannot be undone.',
    'destroy_user_data': 'Destroy User Data',
    'code_copied_to_clipboard': 'Code "{code}" copied to clipboard',
    'processing_destruction': 'Processing destruction...',
    'user_data_destroyed': 'User data destroyed successfully',
    'confirm_destruction': 'Confirm Destruction',
    'destruction_confirmation_text': 'This will permanently destroy all user data for:',
    'name': 'Name',
    'email': 'Email',
    'id': 'ID',
    'action_cannot_be_undone': 'This action cannot be undone. Are you sure?',
    'destroy': 'Destroy',

    // Enhanced About Screen - Intelligence Character
    'intelligence_character_name': 'Agent Cipher',
    'intelligence_character_title': 'Your Security Guide',
    'character_welcome_message': 'Welcome to the secure communication platform. I\'m here to guide you through our advanced security features and help you understand how to use this application safely.',
    
    // About Screen Content
    'what_is_app': 'What is SecureChat?',
    'app_description': 'SecureChat is an advanced, military-grade secure communication platform designed exclusively for authorized agents and security personnel.',
    'secure_platform': 'Secure Platform',
    'secure_platform_desc': 'Built with end-to-end encryption and zero-knowledge architecture',
    'agent_network': 'Agent Network',
    'agent_network_desc': 'Connect only with verified agents using unique security codes',
    
    // Encryption Screen
    'encryption_and_hiding': 'Encryption & Steganography',
    'simple_encryption': 'Simple Encryption',
    'advanced_encryption': 'Advanced Encryption',
    'advanced_mode_enabled': 'Advanced mode enabled',
    'simple_mode_enabled': 'Simple mode enabled',
    'advanced_options': 'Advanced Options',
    'enable_partitioning': 'Enable Data Partitioning',
    'partitioning_description': 'Splits large data for better security',
    'encrypt_and_hide_message': 'Encrypt & Hide Message',
    'encryption_section_hint': 'Enter your secret message and cover text. The secret will be hidden within the cover text.',
    'secret_message': 'Secret Message',
    'enter_secret_message': 'Enter your secret message here',
    'cover_text': 'Cover Text',
    'enter_cover_text': 'Enter cover text here',
    'password': 'Password',
    'enter_password': 'Enter password',
    'password_required': 'Password is required',
    'password_too_short': 'Password is too short',
    'processing': 'Processing...',
    'encrypt_and_hide': 'Encrypt & Hide',
    'hidden_message': 'Hidden Message',
    'share': 'Share',
    'decrypt_and_reveal_message': 'Decrypt & Reveal Message',
    'decryption_section_hint': 'Paste text containing a hidden message to extract the secret.',
    'text_to_reveal': 'Text to Reveal',
    'paste_text_with_hidden_message': 'Paste text with hidden message',
    'decryption_password': 'Decryption Password',
    'enter_decryption_password': 'Enter decryption password',
    'decrypt_and_reveal': 'Decrypt & Reveal',
    'revealed_secret_message': 'Revealed Secret Message',
    'clear_all': 'Clear All',
    'secret_message_empty': 'Please enter secret message',
    'cover_text_empty': 'Please enter cover text',
    'hidden_text_empty': 'Please enter hidden text',
    'message_encrypted_success': 'Message encrypted successfully',
    'message_revealed_success': 'Secret message revealed successfully',
    'no_secret_found': 'No secret message found',
    'copied': 'Copied',
    'share_not_implemented': 'Share feature not available',
    'message_saved': 'Message saved',
    'save_failed': 'Failed to save message',
    'encryption_failed': 'Encryption failed',
    'decryption_failed': 'Decryption failed',
    'privacy_first': 'Privacy First',
    'privacy_first_desc': 'Your data is never stored on our servers or accessible to third parties',
    
    // Main Features
    'main_features': 'Main Features',
    'secure_messaging': 'Secure Messaging',
    'secure_messaging_desc': 'End-to-end encrypted messages with perfect forward secrecy',
    'file_sharing': 'File Sharing',
    'file_sharing_desc': 'Share documents, images, and files with military-grade encryption',
    'voice_messages': 'Voice Messages',
    'voice_messages_desc': 'Encrypted voice recordings with automatic deletion options',
    'auto_deletion': 'Auto Deletion',
    'auto_deletion_desc': 'Messages automatically delete after reading for maximum security',
    
    // How to Use
    'how_to_use': 'How to Use the Application',
    'usage_guide_intro': 'This comprehensive guide will help you get started with secure communications in just a few steps.',
    'step_1_title': 'Enter Your Agent Code',
    'step_1_desc': 'Use your unique secret code provided by your administrator to access the platform. This code establishes your secure identity.',
    'step_2_title': 'Add Other Agents',
    'step_2_desc': 'Connect with other verified agents by entering their secure agent codes. Each connection is encrypted independently.',
    'step_3_title': 'Start Secure Communication',
    'step_3_desc': 'Send encrypted messages, files, and voice recordings with military-grade security. All content is protected end-to-end.',
    'step_4_title': 'Configure Security Settings',
    'step_4_desc': 'Customize auto-lock timers, destruction codes, and advanced security features to match your operational requirements.',
    'step_5_title': 'Verify Security Status',
    'step_5_desc': 'Regularly check security indicators and ensure all features are properly configured for your security environment.',
    
    // Security Features
    'end_to_end_encryption': 'End-to-End Encryption',
    'encryption_description': 'All communications are encrypted using AES-256 with perfect forward secrecy',
    'screenshot_protection': 'Screenshot Protection',
    'screenshot_description': 'Prevents screenshots and screen recording to protect sensitive information',
    'auto_lock_description': 'Automatically locks the application after a period of inactivity',
    'military_grade': 'Military Grade',
    'active': 'Active',
    'configurable': 'Configurable',
    
    // Security Features
    'security_features': 'Security Features',
    
    // Advanced Security
    'advanced_security': 'Advanced Security Features',
    'advanced_warning_title': 'Advanced Features Warning',
    'advanced_warning_desc': 'The following features are designed for high-security environments and should only be configured by authorized personnel.',
    'dead_man_switch_desc': 'Automatically triggers security actions if no activity is detected for a specified period',
    'stealth_mode': 'Stealth Mode',
    'stealth_mode_desc': 'Hides the application from recent apps and system notifications',
    'secure_memory': 'Secure Memory',
    'secure_memory_desc': 'Prevents sensitive data from being written to device storage or swap files',
    
    // Destruction System
    'destruction_system': 'Emergency Destruction System',
    'critical_warning': 'Critical Security Feature',
    'destruction_system_warning': 'This system allows for immediate and permanent deletion of data in emergency situations. Use extreme caution when configuring these features.',
    'level_1_messages': 'Level 1: Message Deletion',
    'level_1_desc': 'Deletes all messages and conversation history while preserving application settings',
    'level_2_data': 'Level 2: Data Deletion',
    'level_2_desc': 'Deletes all application data including contacts, settings, and cached files',
    'level_3_complete': 'Level 3: Complete Destruction',
    'level_3_desc': 'Triggers device-wide security protocols and may affect other applications',
    
    // Security Tips
    'security_tips': 'Security Tips & Best Practices',
    'tip_1_title': 'Protect Your Access Codes',
    'tip_1_desc': 'Never share your agent code or destruction code with anyone. These codes provide complete access to your secure communications.',
    'tip_2_title': 'Always Log Out When Finished',
    'tip_2_desc': 'Ensure you properly log out of the application when not in use, especially on shared or public devices.',
    'tip_3_title': 'Keep the Application Updated',
    'tip_3_desc': 'Regularly update the application to receive the latest security patches and improvements.',
    'tip_4_title': 'Use Secure Networks Only',
    'tip_4_desc': 'Only use the application on trusted networks. Avoid public Wi-Fi for sensitive communications.',
    'critical': 'Critical',
    'important': 'Important',
    'recommended': 'Recommended',
    'essential': 'Essential',
    
    // Architecture
    'app_architecture': 'Application Architecture',
    'zero_knowledge': 'Zero-Knowledge Architecture',
    'zero_knowledge_desc': 'The server never has access to your private keys or unencrypted messages. All encryption happens on your device.',
    'e2e_encryption': 'End-to-End Encryption',
    'e2e_encryption_desc': 'Messages are encrypted on your device and can only be decrypted by the intended recipient using AES-256 encryption.',
    'local_storage': 'Local Data Storage',
    'local_storage_desc': 'All sensitive data is stored locally on your device with advanced encryption. No personal data is sent to our servers.',
    'secure_transport': 'Secure Transport Layer',
    'secure_transport_desc': 'All network communications use TLS 1.3 with certificate pinning to prevent man-in-the-middle attacks.',
    
    // Security Tips Enhancements
    'security_tips_intro': 'Following these security best practices will help keep your communications safe and secure.',
    'tip_5_title': 'Monitor Network Connections',
    'tip_5_desc': 'Be aware of your network environment and avoid using the app on compromised or monitored networks.',
    
    // App Info
    'app_info': 'Application Information',
    'version_info': 'Version 2.0.0 - Enhanced Security Edition',
    'secure_by_design': 'Secure by Design',
    'copyright_info': '© 2024 SecureChat Platform. All rights reserved.',
    
    // UI Controls
    'show_advanced': 'Show Advanced Features',
    'hide_advanced': 'Hide Advanced Features',
    
    // Contacts App
    'search_contacts': 'Search contacts...',
    'loading_contacts': 'Loading contacts...',
    'contacts_permission_denied': 'Permission to access contacts was denied.',
    'no_contacts_found': 'No contacts found',
    'no_contacts': 'No contacts available',
    'try_different_search': 'Try a different search term',
    'add_contact_to_start': 'Add contacts to get started',
    'add_contact': 'Add Contact',
    'add_contact_description': 'This will create a new contact with sample data.',
    'create': 'Create',
    'contact_created': 'Contact created successfully',
    'unknown_contact': 'Unknown Contact',
    'no_phone': 'No phone number',
    'no_contact_info': 'No contact information',
    'phone_numbers': 'Phone Numbers',
    'email_addresses': 'Email Addresses',
    'addresses': 'Addresses',
    'close': 'Close',
    
    // Secure File Management
    'secure_file_management': 'Secure File Management',
    'secure_file_management_desc': 'Permanent file deletion with recovery prevention',
    'secure_file_management_section': 'Secure File Management',
    'file_management_intro': 'Advanced file management system with secure permanent deletion that prevents file recovery.',
    'dod_secure_deletion': 'DoD 5220.22-M Secure Deletion',
    'dod_secure_deletion_desc': 'Uses US Department of Defense standard for permanent file deletion preventing recovery even with advanced recovery tools.',
    'multi_pass_overwriting': 'Multi-Pass Overwriting',
    'multi_pass_overwriting_desc': 'Overwrites data 7 times with different patterns (zeros, ones, random) to ensure complete deletion.',
    'filename_obfuscation': 'Filename Obfuscation',
    'filename_obfuscation_desc': 'Renames file multiple times with random names before deletion to remove any trace of the original file.',
    'deletion_verification': 'Deletion Verification',
    'deletion_verification_desc': 'Verifies successful deletion completion and ensures no file remnants exist in the system.',
    'organized_interface': 'Organized Interface',
    'organized_interface_desc': 'Four dedicated tabs: All Files, Audio Files, Search, and Security with bulk selection capabilities.',
    'military_standard': 'Military Standard',
    '7_passes': '7 Passes',
    'advanced': 'Advanced',
    'automatic': 'Automatic',
    'user_friendly': 'User Friendly',
    
    // Steganography & Encryption Features
    'steganography_encryption': 'Steganography & Encryption',
    'steganography_encryption_desc': 'Hide messages within ordinary text invisibly',
    'encryption_steganography_section': 'Encryption & Steganography',
    'encryption_intro': 'Advanced technology for hiding secret messages within ordinary text so they appear completely natural.',
    'simple_steganography': 'Simple Steganography',
    'simple_steganography_desc': 'Uses Caesar cipher with invisible Unicode characters to hide messages within ordinary text without any visible signs.',
    'advanced_steganography': 'Advanced Steganography',
    'advanced_steganography_desc': 'Uses AES-256-CBC encryption with PBKDF2 and data partitioning for maximum protection with sophisticated hiding.',
    'invisible_hiding': 'Invisible Hiding',
    'invisible_hiding_desc': 'Uses 4 different types of invisible characters with 2-bit encoding for better efficiency and more sophisticated hiding.',
    'auto_detection': 'Auto Detection',
    'auto_detection_desc': 'Automatically attempts different decryption methods and provides clear error messages with user guidance.',
    'caesar_encryption': 'Caesar Encryption',
    'invisible_unicode': 'Invisible Unicode Characters',
    'natural_distribution': 'Natural Text Distribution',
    'aes_256_encryption': 'AES-256-CBC Encryption',
    'pbkdf2_key_derivation': 'PBKDF2 Key Derivation',
    'data_partitioning': 'Data Partitioning',
    '100k_iterations': '100,000 Iterations',
    '4_invisible_chars': '4 Invisible Characters',
    '2bit_encoding': '2-bit Encoding',
    'base64_compression': 'Base64 Compression',
    'smart_distribution': 'Smart Distribution',
    'multiple_methods': 'Multiple Methods',
    'clear_error_messages': 'Clear Error Messages',
    'user_guidance': 'User Guidance',
    'security_validation': 'Security Validation',
    
    // Security Tips for New Features
    'file_management_tip': 'File Management Tip',
    'file_management_tip_desc': 'Use secure deletion for sensitive files. Remember that secure deletion cannot be undone, so ensure you have backups of important files.',
    'encryption_tip': 'Encryption & Hiding Tip',
    'encryption_tip_desc': 'For best hiding results, use cover text longer than the secret message. Use advanced mode with strong password for maximum protection.',

    // SMS App
    'messages': 'Messages',
    'search_messages': 'Search messages',
    'loading_messages': 'Loading messages...',
    'sms_permission_denied': 'SMS permission denied',
    'no_messages_found': 'No messages found',
    'no_messages': 'No messages',
    'compose_message': 'Compose Message',
    'all_messages': 'All',
    'inbox': 'Inbox',
    'sent': 'Sent',
    'received': 'Received',
    'unknown_sender': 'Unknown Sender',
    'yesterday': 'Yesterday',
    'unknown_time': 'Unknown time',
    'no_content': 'No content',
    'start_conversation': 'Start a conversation',
    'compose_message_description': 'This will open a compose dialog for demonstration.',
    'compose': 'Compose',
    'message_compose_simulation': 'Message compose simulation',

    // Encryption Screen
    'encryption_title': 'Encryption & Steganography',
    'operation_mode': 'Operation Mode',
    'cover_text_hint': 'Enter cover text to hide message in...',
    'password_hint': 'Enter encryption password...',
    'copied_to_clipboard': 'Copied to clipboard',
    'output_hint': 'Output will appear here...',
    'encrypt': 'Encrypt',
    'decrypt': 'Decrypt',
    'hide': 'Hide',
    'reveal': 'Reveal',
    'reveal_and_decrypt': 'Reveal & Decrypt',
    'encrypted_message': 'Encrypted Message',
    'message_to_hide': 'Message to Hide',
    'text_with_hidden_message': 'Text with Hidden Message',
    'enter_encrypted_message': 'Enter encrypted message...',
    'enter_message_to_hide': 'Enter message to hide...',
    'enter_text_with_hidden_message': 'Enter text with hidden message...',
    'encrypt_button': 'Encrypt',
    'decrypt_button': 'Decrypt',
    'hide_button': 'Hide',
    'reveal_button': 'Reveal',
    'encrypt_and_hide_button': 'Encrypt & Hide',
    'reveal_and_decrypt_button': 'Reveal & Decrypt',
    'clear': 'Clear',
    'output': 'Output',
    'password': 'Password',
    'processing': 'Processing...',
    'share': 'Share',
    'selected': 'selected',
    'file_manager': 'File Manager',
    'select_all': 'Select All',
    'search': 'Search',
    'refresh': 'Refresh',
    'new_folder': 'New Folder',
    'storage_info': 'Storage Info',
    'permissions': 'Permissions',
    'search_files': 'Search files...',
    'loading_files': 'Loading files...',
  },
  'ar': {
    // Common
    'app_name': 'محادثة آمنة',
    'ok': 'موافق',
    'cancel': 'إلغاء',
    'save': 'حفظ',
    'delete': 'حذف',
    'edit': 'تعديل',
    'send': 'إرسال',
    'back': 'رجوع',
    'next': 'التالي',
    'done': 'تم',
    'error': 'خطأ',
    'success': 'نجح',
    'loading': 'جاري التحميل...', 
    'retry': 'إعادة المحاولة',
    'settings': 'الإعدادات',

    // Navigation
    'home': 'الرئيسية',
    'chats': 'المحادثات',
    'contacts': 'جهات الاتصال',
    'profile': 'الملف الشخصي',
    'about': 'حول',

    // Chat
    'type_message': 'اكتب رسالة...', 
    'send_secure_message': 'رسالة آمنة...', 
    'online': 'متصل',
    'offline': 'غير متصل',
    'last_seen': 'آخر ظهور',
    'typing': 'يكتب...', 
    'message_deleted': 'تم حذف الرسالة',
    'message_edited': 'معدلة',
    'clear_chat': 'مسح الرسائل',
    'delete_chat': 'حذف المحادثة',
    'block_user': 'حظر المستخدم',

    // Media
    'image': 'صورة',
    'video': 'فيديو',
    'audio': 'صوت',
    'file': 'ملف',
    'camera': 'كاميرا',
    'gallery': 'معرض الصور',
    'pick_file': 'اختيار ملف',
    'upload_progress': 'جاري الرفع...', 
    'upload_failed': 'فشل الرفع',
    'upload_cancelled': 'تم إلغاء الرفع',

    // Settings
    'appearance': 'المظهر',
    'language': 'اللغة',
    'theme': 'المظهر',
    'security': 'الأمان',
    'privacy': 'الخصوصية',
    'notifications': 'الإشعارات',
    'storage': 'التخزين',

    // Themes
    'intelligence_theme': 'المظهر الاستخباراتي',
    'dark_theme': 'مظهر داكن',
    'light_theme': 'مظهر فاتح',
    'auto_theme': 'تلقائي',

    // Security
    'self_destruct': 'التدمير الذاتي',
    'dead_man_switch': 'مفتاح الرجل الميت',
    'biometric': 'القفل البيومتري',
    'pin_code': 'رمز PIN',
    'auto_lock': 'القفل التلقائي',
    'hide_from_recents': 'إخفاء من التطبيقات الحديثة',
    'disable_screenshots': 'منع لقطات الشاشة',
    'incognito_keyboard': 'لوحة مفاتيح متخفية',

    // Self-destruct
    'enable_self_destruct': 'تفعيل التدمير الذاتي',
    'self_destruct_timer': 'المؤقت (بالدقائق)',
    'wrong_password_attempts': 'محاولات كلمة المرور الخاطئة',
    'delete_messages': 'حذف الرسائل فقط',
    'delete_all_data': 'حذف جميع البيانات',
    'wipe_device': 'مسح الجهاز',

    // Dead man switch
    'enable_dead_man_switch': 'تفعيل مفتاح الرجل الميت',
    'check_interval': 'فترة الفحص (بالساعات)',
    'max_inactivity': 'أقصى فترة عدم نشاط (بالأيام)',
    'emergency_email': 'البريد الإلكتروني للطوارئ',
    'send_warning_email': 'إرسال بريد تحذيري',

    // Permissions
    'permission_required': 'صلاحية مطلوبة',
    'camera_permission': 'صلاحية الكاميرا مطلوبة لالتقاط الصور',
    'storage_permission': 'صلاحية التخزين مطلوبة للوصول للملفات',
    'microphone_permission': 'صلاحية الميكروفون مطلوبة للرسائل الصوتية',
    'contacts_permission': 'صلاحية جهات الاتصال مطلوبة للعثور على الأصدقاء',

    // Errors
    'network_error': 'خطأ في الاتصال بالشبكة',
    'permission_denied': 'تم رفض الصلاحية',
    'upload_error': 'فشل في الرفع',
    'download_error': 'فشل في التحميل',
    'authentication_error': 'فشل في المصادقة',
    
    // Login
    'login_success': 'تم تسجيل الدخول بنجاح',
    'login_failed': 'فشل تسجيل الدخول',
    'enter_security_code': 'أدخل الرمز السري للمتابعة',
    'security_code_placeholder': 'الرمز السري / رمز التدمير',
    'security_code_label': 'الرمز السري',
    'invalid_code': 'رمز غير صحيح',
    'code_too_short': 'يجب أن يكون الرمز 4 أحرف على الأقل',
    'please_enter_code': 'يرجى إدخال الرمز',
    'confirm_and_continue': 'تأكيد ومتابعة',
    'app_temporarily_locked': 'التطبيق مقفل مؤقتاً',
    'wrong_attempt': 'محاولة خاطئة',
    'attempts_remaining': 'محاولات متبقية',
    'temporarily_locked': 'مقفل مؤقتاً',
    'verifying': 'جاري التحقق...',
    'first_time_welcome': 'مرحباً بك! 👋',
    'welcome_to_secure_app': 'مرحباً بك في التطبيق الآمن!',
    'you_can_start_now': '✅ يمكنك البدء الآن',
    'help_with_settings_later': '⚙️ سنساعدك في الإعدادات لاحقاً',
    'data_safe_protected': '🔒 بياناتك آمنة ومحمية',
    'understood_lets_start': 'فهمت، هيا نبدأ!',
    'successful_login': 'نجح تسجيل الدخول!',
    'welcome_back': 'أهلاً وسهلاً بعودتك! 👋',
    'continue_button': 'متابعة',
    'destruction_executed': 'تم تنفيذ التدمير',
    'destruction_executed_successfully': 'تم تنفيذ إجراء التدمير بنجاح.',
    'switching_to_safe_mode': 'سيتم الانتقال إلى وضع التعتيم الآمن.',
    'security_features_active': 'ميزات الأمان النشطة',
    'biometric_verification': 'التحقق البيومتري',
    'available': 'متاح',
    'not_available': 'غير متاح',
    'repeated_attempts_protection': 'حماية من المحاولات المتكررة: نشطة',
    'emergency_mode': 'وضع الطوارئ',
    'emergency_mode_available': 'متاح (اضغط 5 مرات على أيقونة الأمان)',
    'destruction_codes': 'رموز التدمير',
    'destruction_codes_available': 'متاحة (من Firebase)',
    'failed_attempts': 'محاولات فاشلة',
    'locked_temporarily': 'مقفل مؤقتاً',
    
    // Additional UI text
    'chat_security': 'أمان المحادثة',
    'delete_after_reading': 'حذف بعد القراءة',
    'auto_delete_messages_when_read': 'حذف الرسائل تلقائيًا عند قراءتها',
    'hide_message_preview': 'إخفاء معاينة الرسالة',
    'hide_content_in_notifications': 'إخفاء المحتوى في الإشعارات',
    'typing_indicator': 'مؤشر الكتابة',
    'show_when_typing': 'إظهار عند الكتابة',
    'read_receipts': 'إيصالات القراءة',
    'show_message_read_status': 'إظهار حالة قراءة الرسالة',
    'destruction_type': 'نوع التدمير',
    'important_information': 'معلومات مهمة',
    'background_services_required': 'الخدمات الخلفية مطلوبة لعمل التطبيق بشكل صحيح ولا يمكن إيقافها. يُنصح بتفعيل تحسين البطارية لضمان عدم إيقاف النظام للتطبيق.',
    'battery_optimization_required': 'مطلوب للعمل الصحيح للتطبيق',
    'app_protected_from_system_kill': 'التطبيق محمي من إيقاف النظام',
    'initializing_system': 'جاري تهيئة النظام...', 
    'system_update_in_progress': 'تحديث النظام قيد التقدم',
    'device_detected': 'تم اكتشاف جهاز: {deviceName}',
    'xiaomi_tip': 'لأجهزة شاومي: قد نحتاج لتفعيل "التشغيل التلقائي" للحصول على أفضل أداء.',
    'vivo_tip': 'لأجهزة فيفو: سنساعدك في تفعيل العمل في الخلفية.',
    'oppo_tip': 'لأجهزة أوبو/ون بلس: قد نحتاج لتعديل إعدادات إدارة الطاقة.',
    'huawei_tip': 'لأجهزة هواوي: إضافة التطبيق للتطبيقات المحمية مهم جداً.',
    'battery_permission_required': 'صلاحية تحسين البطارية مطلوبة.',
    'battery_permission_explanation': 'لضمان التشغيل المستمر والإشعارات في الوقت المناسب، يرجى تعطيل تحسين البطارية لهذا التطبيق.',
    'battery_permission_instructions': 'انتقل إلى معلومات التطبيق > البطارية > تحسين استخدام البطارية > جميع التطبيقات > تعطيل التحسين لهذا التطبيق.',
    'battery_permission_warning': 'بدون هذه الصلاحية، قد لا يعمل التطبيق بشكل صحيح في الخلفية.',
    'activate_now': 'تفعيل الآن',
    'search_for_agent': 'البحث عن وكيل...', 
    'logout': 'تسجيل الخروج',
    'photo': 'صورة',
    'voice_message': 'رسالة صوتية',
    'ai_welcome': 'مرحباً! أنا مساعدك الذكي. كيف يمكنني مساعدتك اليوم؟',
    'ask_something': 'الرجاء طرح سؤال!',
    'gemini_api_key_required': 'مفتاح API الخاص بـ Gemini مطلوب لاستخدام ميزات الذكاء الاصطناعي.',
    'something_went_wrong': 'حدث خطأ ما',
    'ai_assistant': 'مساعد الذكاء الاصطناعي',
    'ask_me_anything': 'اسألني أي شيء...', 
    'joined_on': 'انضم في',
    'permissions_settings': 'إعدادات الصلاحيات',
    'battery_optimization': 'تحسين البطارية',
    'edit_message': 'تعديل الرسالة',
    'enter_new_text': 'أدخل نصًا جديدًا',
    'failed_to_load_image': 'فشل تحميل الصورة',
    'grant_storage_permission': 'منح صلاحية التخزين',
    'error_requesting_permissions': 'خطأ في طلب الصلاحيات',
    'unknown': 'غير معروف',
    'days_ago': 'منذ {count} يوم',
    'hours_ago': 'منذ {count} ساعة',
    'minutes_ago': 'منذ {count} دقيقة',
    'just_now': 'الآن',

    // Profile Screen
    'emergency_destruction_code': 'رمز التدمير الطارئ',
    'destruction_code_description': 'استخدم هذا الرمز في شاشة تسجيل الدخول لتدمير البيانات الطارئ',
    'copy_to_clipboard': 'نسخ إلى الحافظة',
    'destruction_warning': 'خطر: هذا الرمز سيدمر جميع البيانات نهائياً!',
    'destruction_warning_detail': 'استخدم فقط في حالات الطوارئ. لا يمكن التراجع عن هذا الإجراء.',
    'destruction_code_not_available': 'رمز التدمير الطارئ غير متاح',
    'retry_loading_code': 'إعادة تحميل الرمز',
    'destruction_code_load_error': 'تعذر تحميل رمز التدمير الطارئ. قد يكون هذا بسبب:',
    'network_connectivity_issues': 'مشاكل في الاتصال بالشبكة',
    'agent_configuration_problems': 'مشاكل في إعداد الوكيل',
    'administrator_restrictions': 'قيود المدير',
    'contact_administrator': 'حاول إعادة تحديث البيانات أو اتصل بالمدير للمساعدة.',
    'manual_data_destruction': 'تدمير البيانات يدوياً',
    'manual_destruction_description': 'دمر جميع بيانات المستخدم من هذا الجهاز فوراً. لا يمكن التراجع عن هذا.',
    'destroy_user_data': 'تدمير بيانات المستخدم',
    'code_copied_to_clipboard': 'تم نسخ الرمز "{code}" إلى الحافظة',
    'processing_destruction': 'معالجة التدمير...',
    'user_data_destroyed': 'تم تدمير بيانات المستخدم بنجاح',
    'confirm_destruction': 'تأكيد التدمير',
    'destruction_confirmation_text': 'سيتم تدمير جميع بيانات المستخدم نهائياً لـ:',
    'name': 'الاسم',
    'email': 'البريد الإلكتروني',
    'id': 'المعرف',
    'action_cannot_be_undone': 'لا يمكن التراجع عن هذا الإجراء. هل أنت متأكد؟',
    'destroy': 'تدمير',

    // Enhanced About Screen - Intelligence Character
    'intelligence_character_name': 'العميل سايفر',
    'intelligence_character_title': 'دليلك الأمني',
    'character_welcome_message': 'مرحباً بك في منصة التواصل الآمن. أنا هنا لأرشدك عبر ميزات الأمان المتقدمة ولمساعدتك في فهم كيفية استخدام هذا التطبيق بأمان.',
    
    // About Screen Content
    'what_is_app': 'ما هو تطبيق المحادثة الآمنة؟',
    'app_description': 'المحادثة الآمنة هي منصة تواصل آمنة متقدمة بمواصفات عسكرية مصممة حصرياً للوكلاء المعتمدين وأفراد الأمن.',
    'secure_platform': 'منصة آمنة',
    'secure_platform_desc': 'مبنية بتشفير من النهاية إلى النهاية وبنية عدم المعرفة',
    'agent_network': 'شبكة الوكلاء',
    'agent_network_desc': 'اتصل فقط مع الوكلاء المعتمدين باستخدام رموز أمان فريدة',
    
    // Encryption Screen
    'encryption_and_hiding': 'التشفير والإخفاء',
    'simple_encryption': 'تشفير بسيط',
    'advanced_encryption': 'تشفير متقدم',
    'advanced_mode_enabled': 'تم تفعيل الوضع المتقدم',
    'simple_mode_enabled': 'تم تفعيل الوضع البسيط',
    'advanced_options': 'خيارات متقدمة',
    'enable_partitioning': 'تفعيل تقسيم البيانات',
    'partitioning_description': 'يقسم البيانات الكبيرة لأمان أفضل',
    'encrypt_and_hide_message': 'تشفير وإخفاء رسالة',
    'encryption_section_hint': 'اكتب الرسالة السرية التي تريد تشفيرها، ثم اكتب نص غطاء عادي. سيتم إخفاء الرسالة السرية داخل نص الغطاء.',
    'secret_message': 'الرسالة السرية',
    'enter_secret_message': 'اكتب الرسالة السرية هنا',
    'cover_text': 'نص الغطاء',
    'enter_cover_text': 'اكتب نص الغطاء هنا',
    'password': 'كلمة المرور',
    'enter_password': 'ادخل كلمة المرور',
    'password_required': 'كلمة المرور مطلوبة',
    'password_too_short': 'كلمة المرور قصيرة جداً',
    'processing': 'جاري المعالجة...',
    'encrypt_and_hide': 'تشفير وإخفاء',
    'hidden_message': 'النص المخفي',
    'share': 'مشاركة',
    'decrypt_and_reveal_message': 'فك التشفير واستخراج الرسالة',
    'decryption_section_hint': 'الصق أي نص يحتوي على رسالة سرية مخفية، وسيتم استخراج الرسالة السرية فقط.',
    'text_to_reveal': 'النص المراد كشفه',
    'paste_text_with_hidden_message': 'الصق النص الذي يحتوي على الرسالة السرية',
    'decryption_password': 'كلمة مرور فك التشفير',
    'enter_decryption_password': 'ادخل كلمة مرور فك التشفير',
    'decrypt_and_reveal': 'فك التشفير واستخراج',
    'revealed_secret_message': 'الرسالة السرية المستخرجة',
    'clear_all': 'مسح الكل',
    'secret_message_empty': 'يرجى إدخال الرسالة السرية',
    'cover_text_empty': 'يرجى إدخال نص الغطاء',
    'hidden_text_empty': 'يرجى إدخال النص المخفي',
    'message_encrypted_success': 'تم تشفير الرسالة وإخفاؤها بنجاح',
    'message_revealed_success': 'تم استخراج الرسالة السرية بنجاح',
    'no_secret_found': 'لم يتم العثور على رسالة سرية',
    'copied': 'تم النسخ',
    'share_not_implemented': 'ميزة المشاركة غير متاحة حالياً',
    'message_saved': 'تم حفظ الرسالة',
    'save_failed': 'فشل في حفظ الرسالة',
    'encryption_failed': 'فشل في التشفير',
    'decryption_failed': 'فشل في فك التشفير',
    
    'privacy_first': 'الخصوصية أولاً',
    'privacy_first_desc': 'بياناتك لا تُخزن مطلقاً على خوادمنا أو يمكن الوصول إليها من قبل أطراف ثالثة',
    
    // Main Features
    'main_features': 'الميزات الرئيسية',
    'secure_messaging': 'المراسلة الآمنة',
    'secure_messaging_desc': 'رسائل مشفرة من النهاية إلى النهاية مع السرية التامة المستقبلية',
    'file_sharing': 'مشاركة الملفات',
    'file_sharing_desc': 'شارك المستندات والصور والملفات بتشفير عسكري الدرجة',
    'voice_messages': 'الرسائل الصوتية',
    'voice_messages_desc': 'تسجيلات صوتية مشفرة مع خيارات الحذف التلقائي',
    'auto_deletion': 'الحذف التلقائي',
    'auto_deletion_desc': 'الرسائل تُحذف تلقائياً بعد القراءة لأقصى حماية',
    
    // How to Use
    'how_to_use': 'كيفية استخدام التطبيق',
    'usage_guide_intro': 'سيساعدك هذا الدليل الشامل في البدء بالاتصالات الآمنة في خطوات قليلة فقط.',
    'step_1_title': 'أدخل رمز الوكيل الخاص بك',
    'step_1_desc': 'استخدم رمزك السري الفريد المقدم من المدير للوصول إلى المنصة. هذا الرمز يؤسس هويتك الآمنة.',
    'step_2_title': 'أضف وكلاء آخرين',
    'step_2_desc': 'اتصل مع وكلاء معتمدين آخرين بإدخال رموز الوكلاء الآمنة. كل اتصال مشفر بشكل مستقل.',
    'step_3_title': 'ابدأ التواصل الآمن',
    'step_3_desc': 'أرسل رسائل مشفرة وملفات وتسجيلات صوتية بأمان عسكري الدرجة. جميع المحتوى محمي من النهاية إلى النهاية.',
    'step_4_title': 'قم بضبط إعدادات الأمان',
    'step_4_desc': 'خصص مؤقتات القفل التلقائي ورموز التدمير والميزات الأمنية المتقدمة لتناسب متطلباتك التشغيلية.',
    'step_5_title': 'تحقق من حالة الأمان',
    'step_5_desc': 'افحص بانتظام مؤشرات الأمان وتأكد من تكوين جميع الميزات بشكل صحيح لبيئتك الأمنية.',
    
    // Security Features
    'end_to_end_encryption': 'التشفير من النهاية إلى النهاية',
    'encryption_description': 'جميع الاتصالات مشفرة باستخدام AES-256 مع السرية التامة المستقبلية',
    'screenshot_protection': 'حماية لقطة الشاشة',
    'screenshot_description': 'يمنع لقطات الشاشة وتسجيل الشاشة لحماية المعلومات الحساسة',
    'auto_lock_description': 'يقفل التطبيق تلقائياً بعد فترة من عدم النشاط',
    'military_grade': 'درجة عسكرية',
    'active': 'نشط',
    'configurable': 'قابل للتخصيص',
    
    // Security Features
    'security_features': 'ميزات الأمان',
    
    // Advanced Security
    'advanced_security': 'ميزات الأمان المتقدمة',
    'advanced_warning_title': 'تحذير الميزات المتقدمة',
    'advanced_warning_desc': 'الميزات التالية مصممة لبيئات عالية الأمان ويجب تكوينها فقط من قبل الأشخاص المعتمدين.',
    'dead_man_switch_desc': 'يؤدي تلقائياً إجراءات أمنية إذا لم يتم اكتشاف نشاط لفترة محددة',
    'stealth_mode': 'الوضع الخفي',
    'stealth_mode_desc': 'يخفي التطبيق من التطبيقات الحديثة وإشعارات النظام',
    'secure_memory': 'الذاكرة الآمنة',
    'secure_memory_desc': 'يمنع كتابة البيانات الحساسة في تخزين الجهاز أو ملفات التبديل',
    
    // Destruction System
    'destruction_system': 'نظام التدمير الطارئ',
    'critical_warning': 'ميزة أمنية حرجة',
    'destruction_system_warning': 'يسمح هذا النظام بالحذف الفوري والدائم للبيانات في حالات الطوارئ. استخدم حذراً شديداً عند تكوين هذه الميزات.',
    'level_1_messages': 'المستوى 1: حذف الرسائل',
    'level_1_desc': 'يحذف جميع الرسائل وتاريخ المحادثة مع الاحتفاظ بإعدادات التطبيق',
    'level_2_data': 'المستوى 2: حذف البيانات',
    'level_2_desc': 'يحذف جميع بيانات التطبيق بما في ذلك جهات الاتصال والإعدادات والملفات المؤقتة',
    'level_3_complete': 'المستوى 3: التدمير الكامل',
    'level_3_desc': 'يؤدي بروتوكولات أمنية على مستوى الجهاز وقد يؤثر على تطبيقات أخرى',
    
    // Security Tips
    'security_tips': 'نصائح الأمان وأفضل الممارسات',
    'tip_1_title': 'احم رموز الوصول الخاصة بك',
    'tip_1_desc': 'لا تشارك مطلقاً رمز الوكيل أو رمز التدمير مع أي شخص. هذه الرموز توفر وصولاً كاملاً لاتصالاتك الآمنة.',
    'tip_2_title': 'اخرج دائماً عند الانتهاء',
    'tip_2_desc': 'تأكد من تسجيل الخروج من التطبيق بشكل صحيح عند عدم الاستخدام، خاصة على الأجهزة المشتركة أو العامة.',
    'tip_3_title': 'حافظ على التطبيق محدثاً',
    'tip_3_desc': 'قم بتحديث التطبيق بانتظام لتلقي أحدث تصحيحات الأمان والتحسينات.',
    'tip_4_title': 'استخدم الشبكات الآمنة فقط',
    'tip_4_desc': 'استخدم التطبيق فقط على الشبكات الموثوقة. تجنب شبكات Wi-Fi العامة للاتصالات الحساسة.',
    'critical': 'حرج',
    'important': 'مهم',
    'recommended': 'موصى به',
    'essential': 'أساسي',
    
    // Architecture
    'app_architecture': 'هيكل التطبيق',
    'zero_knowledge': 'بنية عدم المعرفة',
    'zero_knowledge_desc': 'الخادم لا يحصل مطلقاً على مفاتيحك الخاصة أو رسائلك غير المشفرة. جميع عمليات التشفير تحدث على جهازك.',
    'e2e_encryption': 'التشفير من النهاية إلى النهاية',
    'e2e_encryption_desc': 'الرسائل مشفرة على جهازك ولا يمكن فك تشفيرها إلا من قبل المستقبل المقصود باستخدام تشفير AES-256.',
    'local_storage': 'التخزين المحلي للبيانات',
    'local_storage_desc': 'جميع البيانات الحساسة مخزنة محلياً على جهازك مع تشفير متقدم. لا يتم إرسال بيانات شخصية لخوادمنا.',
    'secure_transport': 'طبقة النقل الآمنة',
    'secure_transport_desc': 'جميع اتصالات الشبكة تستخدم TLS 1.3 مع تثبيت الشهادات لمنع هجمات الوسطاء.',
    
    // Security Tips Enhancements
    'security_tips_intro': 'اتباع أفضل ممارسات الأمان هذه سيساعد في الحفاظ على أمان اتصالاتك.',
    'tip_5_title': 'مراقبة اتصالات الشبكة',
    'tip_5_desc': 'كن على دراية ببيئة الشبكة الخاصة بك وتجنب استخدام التطبيق على الشبكات المخترقة أو المراقبة.',
    
    // App Info
    'app_info': 'معلومات التطبيق',
    'version_info': 'الإصدار 2.0.0 - إصدار الأمان المحسن',
    'secure_by_design': 'آمن بالتصميم',
    'copyright_info': '© 2024 منصة المحادثة الآمنة. جميع الحقوق محفوظة.',
    
    // UI Controls
    'show_advanced': 'إظهار الميزات المتقدمة',
    'hide_advanced': 'إخفاء الميزات المتقدمة',
    
    // Contacts App
    'search_contacts': 'البحث في جهات الاتصال...',
    'loading_contacts': 'تحميل جهات الاتصال...',
    'contacts_permission_denied': 'تم رفض إذن الوصول إلى جهات الاتصال.',
    'no_contacts_found': 'لم يتم العثور على جهات اتصال',
    'no_contacts': 'لا توجد جهات اتصال متاحة',
    'try_different_search': 'جرب مصطلح بحث مختلف',
    'add_contact_to_start': 'أضف جهات اتصال للبدء',
    'add_contact': 'إضافة جهة اتصال',
    'add_contact_description': 'سيتم إنشاء جهة اتصال جديدة ببيانات تجريبية.',
    'create': 'إنشاء',
    'contact_created': 'تم إنشاء جهة الاتصال بنجاح',
    'unknown_contact': 'جهة اتصال غير معروفة',
    'no_phone': 'لا يوجد رقم هاتف',
    'no_contact_info': 'لا توجد معلومات اتصال',
    'phone_numbers': 'أرقام الهاتف',
    'email_addresses': 'عناوين البريد الإلكتروني',
    'addresses': 'العناوين',
    'close': 'إغلاق',
    
    // Secure File Management
    'secure_file_management': 'إدارة الملفات الآمنة',
    'secure_file_management_desc': 'حذف دائم للملفات مع منع الاسترداد',
    'secure_file_management_section': 'إدارة الملفات الآمنة',
    'file_management_intro': 'نظام إدارة الملفات المتقدم مع حذف آمن ودائم يمنع استرداد الملفات المحذوفة.',
    'dod_secure_deletion': 'الحذف الآمن DoD 5220.22-M',
    'dod_secure_deletion_desc': 'يستخدم معيار وزارة الدفاع الأمريكية لحذف الملفات بشكل دائم ومنع استردادها حتى باستخدام أدوات الاسترداد المتقدمة.',
    'multi_pass_overwriting': 'إعادة الكتابة متعددة المرات',
    'multi_pass_overwriting_desc': 'يعيد كتابة البيانات 7 مرات بأنماط مختلفة (أصفار، آحاد، عشوائي) لضمان الحذف الكامل.',
    'filename_obfuscation': 'تشويش أسماء الملفات',
    'filename_obfuscation_desc': 'يغير اسم الملف عدة مرات بأسماء عشوائية قبل الحذف لإزالة أي أثر للملف الأصلي.',
    'deletion_verification': 'التحقق من الحذف',
    'deletion_verification_desc': 'يتحقق من إتمام عملية الحذف بنجاح ويضمن عدم وجود أي بقايا للملف في النظام.',
    'organized_interface': 'واجهة منظمة',
    'organized_interface_desc': 'أربعة تبويبات مخصصة: جميع الملفات، الملفات الصوتية، البحث، والأمان مع إمكانية التحديد المتعدد.',
    'military_standard': 'معيار عسكري',
    '7_passes': '7 مرات',
    'advanced': 'متقدم',
    'automatic': 'تلقائي',
    'user_friendly': 'سهل الاستخدام',
    
    // Steganography & Encryption Features
    'steganography_encryption': 'التشفير والإخفاء',
    'steganography_encryption_desc': 'إخفاء الرسائل داخل النصوص العادية',
    'encryption_steganography_section': 'التشفير والإخفاء (Steganography)',
    'encryption_intro': 'تقنية متقدمة لإخفاء الرسائل السرية داخل النصوص العادية بحيث تبدو طبيعية تماماً.',
    'simple_steganography': 'الإخفاء البسيط',
    'simple_steganography_desc': 'يستخدم تشفير Caesar مع أحرف Unicode غير مرئية لإخفاء الرسائل داخل النصوص العادية دون أي علامات واضحة.',
    'advanced_steganography': 'الإخفاء المتقدم',
    'advanced_steganography_desc': 'يستخدم تشفير AES-256-CBC مع PBKDF2 وتقسيم البيانات لحماية قصوى مع إخفاء متطور.',
    'invisible_hiding': 'الإخفاء غير المرئي',
    'invisible_hiding_desc': 'يستخدم 4 أنواع مختلفة من الأحرف غير المرئية مع ترميز 2-bit لكفاءة أفضل وإخفاء أكثر تطوراً.',
    'auto_detection': 'الكشف التلقائي',
    'auto_detection_desc': 'يحاول فك التشفير بالطرق المختلفة تلقائياً ويعطي رسائل خطأ واضحة مع إرشادات للمستخدم.',
    'caesar_encryption': 'تشفير Caesar',
    'invisible_unicode': 'أحرف Unicode غير مرئية',
    'natural_distribution': 'توزيع طبيعي في النص',
    'aes_256_encryption': 'تشفير AES-256-CBC',
    'pbkdf2_key_derivation': 'اشتقاق المفاتيح PBKDF2',
    'data_partitioning': 'تقسيم البيانات',
    '100k_iterations': '100,000 تكرار',
    '4_invisible_chars': '4 أحرف غير مرئية',
    '2bit_encoding': 'ترميز 2-bit',
    'base64_compression': 'ضغط Base64',
    'smart_distribution': 'توزيع ذكي',
    'multiple_methods': 'طرق متعددة',
    'clear_error_messages': 'رسائل خطأ واضحة',
    'user_guidance': 'إرشادات للمستخدم',
    'security_validation': 'التحقق الأمني',
    
    // Security Tips for New Features
    'file_management_tip': 'نصيحة إدارة الملفات',
    'file_management_tip_desc': 'استخدم الحذف الآمن للملفات الحساسة. تذكر أن الحذف الآمن لا يمكن التراجع عنه، فتأكد من عمل نسخ احتياطية للملفات المهمة.',
    'encryption_tip': 'نصيحة التشفير والإخفاء',
    'encryption_tip_desc': 'للحصول على أفضل إخفاء، استخدم نص غطاء أطول من الرسالة السرية. استخدم الوضع المتقدم مع كلمة مرور قوية للحماية القصوى.',
    
    // SMS App
    'messages': 'الرسائل',
    'search_messages': 'البحث في الرسائل',
    'loading_messages': 'تحميل الرسائل...',
    'sms_permission_denied': 'تم رفض إذن الرسائل النصية',
    'no_messages_found': 'لم يتم العثور على رسائل',
    'no_messages': 'لا توجد رسائل',
    'compose_message': 'كتابة رسالة',
    'all_messages': 'الكل',
    'inbox': 'الواردة',
    'sent': 'المرسلة',
    'received': 'مستلمة',
    'unknown_sender': 'مرسل غير معروف',
    'yesterday': 'الأمس',
    'unknown_time': 'وقت غير معروف',
    'no_content': 'لا يوجد محتوى',
    'start_conversation': 'ابدأ محادثة',
    'compose_message_description': 'سيتم فتح نافذة الكتابة للعرض التوضيحي.',
    'compose': 'كتابة',
    'message_compose_simulation': 'محاكاة كتابة الرسالة',

    // Encryption Screen
    'encryption_title': 'التشفير والإخفاء',
    'operation_mode': 'نمط العملية',
    'cover_text_hint': 'أدخل نص الغطاء لإخفاء الرسالة فيه...',
    'password_hint': 'أدخل كلمة مرور التشفير...',
    'copied_to_clipboard': 'تم النسخ إلى الحافظة',
    'copy_to_clipboard': 'نسخ إلى الحافظة',
    'output_hint': 'سيظهر الناتج هنا...',
    'encrypt': 'تشفير',
    'decrypt': 'فك التشفير',
    'hide': 'إخفاء',
    'reveal': 'كشف',
    'reveal_and_decrypt': 'كشف وفك التشفير',
    'encrypted_message': 'الرسالة المشفرة',
    'message_to_hide': 'الرسالة المراد إخفاؤها',
    'text_with_hidden_message': 'النص مع الرسالة المخفية',
    'enter_encrypted_message': 'أدخل الرسالة المشفرة...',
    'enter_message_to_hide': 'أدخل الرسالة المراد إخفاؤها...',
    'enter_text_with_hidden_message': 'أدخل النص مع الرسالة المخفية...',
    'encrypt_button': 'تشفير',
    'decrypt_button': 'فك التشفير',
    'hide_button': 'إخفاء',
    'reveal_button': 'كشف',
    'encrypt_and_hide_button': 'تشفير وإخفاء',
    'reveal_and_decrypt_button': 'كشف وفك التشفير',
    'clear': 'مسح',
    'output': 'الناتج',
    'password': 'كلمة المرور',
    'processing': 'جاري المعالجة...',
    'share': 'مشاركة',
    'selected': 'محدد',
    'file_manager': 'مدير الملفات',
    'select_all': 'تحديد الكل',
    'search': 'بحث',
    'refresh': 'تحديث',
    'new_folder': 'مجلد جديد',
    'storage_info': 'معلومات التخزين',
    'permissions': 'الصلاحيات',
    'search_files': 'البحث في الملفات...',
    'loading_files': 'تحميل الملفات...',
  },
};