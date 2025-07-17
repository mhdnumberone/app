import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';
import '../themes/app_themes.dart';

/// Unified Settings Manager for app configuration
class SettingsManager {
  static SettingsManager? _instance;
  static SettingsManager get instance => _instance ??= SettingsManager._();
  SettingsManager._();

  SharedPreferences? _prefs;
  final StreamController<AppSettings> _settingsController = StreamController<AppSettings>.broadcast();
  bool _isInitialized = false;
  bool _isInitializing = false;

  // Settings keys
  static const String _themeKey = 'app_theme';
  static const String _languageKey = 'app_language';
  static const String _rtlKey = 'app_rtl';
  static const String _decoyScreenKey = 'decoy_screen_type';
  static const String _selfDestructKey = 'self_destruct_settings';
  static const String _deadManSwitchKey = 'dead_man_switch';
  static const String _securityKey = 'security_settings';
  static const String _chatSecurityKey = 'chat_security';

  AppSettings _currentSettings = AppSettings.defaultSettings();

  /// Initialize settings manager
  Future<void> initialize() async {
    if (_isInitialized || _isInitializing) return; // Prevent multiple initializations
    
    _isInitializing = true;
    
    try {
      // ✅ إرسال القيم الافتراضية فوراً
      _settingsController.add(_currentSettings);
      
      _prefs = await SharedPreferences.getInstance();
      await _loadSettings();
      _isInitialized = true;
      AppLogger.info('Settings Manager initialized successfully');
    } catch (e) {
      AppLogger.error('Failed to initialize Settings Manager: $e');
      // ✅ في حالة الخطأ، أرسل الإعدادات الافتراضية
      _settingsController.add(AppSettings.defaultSettings());
      _isInitialized = true; // Mark as initialized even with defaults
      // Don't rethrow - let the app continue with default settings
    } finally {
      _isInitializing = false;
    }
  }

  /// Get current settings
  AppSettings get currentSettings => _currentSettings;

  /// Get settings stream
  Stream<AppSettings> get settingsStream => _settingsController.stream;

  /// Load settings from storage
  Future<void> _loadSettings() async {
    try {
      final themeIndex = _prefs?.getInt(_themeKey) ?? 0;
      final languageCode = _prefs?.getString(_languageKey) ?? 'ar'; // Default to Arabic
      final decoyScreenIndex = _prefs?.getInt(_decoyScreenKey) ?? 0; // Default to systemUpdate
      
      final selfDestructJson = _prefs?.getString(_selfDestructKey);
      final deadManJson = _prefs?.getString(_deadManSwitchKey);
      final securityJson = _prefs?.getString(_securityKey);
      final chatSecurityJson = _prefs?.getString(_chatSecurityKey);

      final selectedLanguage = AppLanguage.values.firstWhere(
        (lang) => lang.code == languageCode,
        orElse: () => AppLanguage.arabic, // Default to Arabic instead of English
      );

      _currentSettings = AppSettings(
        theme: AppThemeType.values[themeIndex.clamp(0, AppThemeType.values.length - 1)],
        language: selectedLanguage,
        isRtl: selectedLanguage.isRtl, // Use the language's RTL property
        decoyScreenType: DecoyScreenType.values[decoyScreenIndex.clamp(0, DecoyScreenType.values.length - 1)],
        selfDestruct: selfDestructJson != null 
            ? SelfDestructSettings.fromJson(jsonDecode(selfDestructJson))
            : SelfDestructSettings.defaultSettings(),
        deadManSwitch: deadManJson != null
            ? DeadManSwitchSettings.fromJson(jsonDecode(deadManJson))
            : DeadManSwitchSettings.defaultSettings(),
        security: securityJson != null
            ? SecuritySettings.fromJson(jsonDecode(securityJson))
            : SecuritySettings.defaultSettings(),
        chatSecurity: chatSecurityJson != null
            ? ChatSecuritySettings.fromJson(jsonDecode(chatSecurityJson))
            : ChatSecuritySettings.defaultSettings(),
      );

      _settingsController.add(_currentSettings);
    } catch (e) {
      AppLogger.error('Failed to load settings: $e');
    }
  }

  /// Save settings to storage
  Future<void> _saveSettings() async {
    try {
      if (_prefs == null) {
        AppLogger.warning('SharedPreferences not initialized, attempting to initialize...');
        _prefs = await SharedPreferences.getInstance();
      }
      
      // Use a local copy to avoid race conditions with concurrent updates
      final settingsToSave = _currentSettings;
      
      await _prefs!.setInt(_themeKey, settingsToSave.theme.index);
      await _prefs!.setString(_languageKey, settingsToSave.language.code);
      await _prefs!.setBool(_rtlKey, settingsToSave.isRtl);
      await _prefs!.setInt(_decoyScreenKey, settingsToSave.decoyScreenType.index);
      await _prefs!.setString(_selfDestructKey, jsonEncode(settingsToSave.selfDestruct.toJson()));
      await _prefs!.setString(_deadManSwitchKey, jsonEncode(settingsToSave.deadManSwitch.toJson()));
      await _prefs!.setString(_securityKey, jsonEncode(settingsToSave.security.toJson()));
      await _prefs!.setString(_chatSecurityKey, jsonEncode(settingsToSave.chatSecurity.toJson()));
      
      // Always broadcast the updated settings
      if (!_settingsController.isClosed) {
        _settingsController.add(_currentSettings);
      }
      AppLogger.info('Settings saved successfully - DecoyScreen: ${settingsToSave.decoyScreenType.englishName}');
    } catch (e) {
      AppLogger.error('Failed to save settings: $e');
      // Still broadcast the current settings to UI even if save failed
      if (!_settingsController.isClosed) {
        _settingsController.add(_currentSettings);
      }
      rethrow;
    }
  }

  /// Update theme
  Future<void> updateTheme(AppThemeType theme) async {
    _currentSettings = _currentSettings.copyWith(theme: theme);
    await _saveSettings();
  }

  /// Update language
  Future<void> updateLanguage(AppLanguage language) async {
    // Create the new state
    final newSettings = _currentSettings.copyWith(
      language: language,
      isRtl: language.isRtl,
    );

    // 1. Immediately update the in-memory state
    _currentSettings = newSettings;

    // 2. Immediately push the new state to the stream to ensure the UI updates instantly
    if (!_settingsController.isClosed) {
      _settingsController.add(newSettings);
    }

    // 3. Asynchronously save the settings to persistent storage
    try {
      if (_prefs != null) {
        await _prefs!.setString(_languageKey, newSettings.language.code);
        await _prefs!.setBool(_rtlKey, newSettings.isRtl);
      }
      AppLogger.info('Language and RTL settings saved successfully');
    } catch (e) {
      AppLogger.error('Failed to save language settings: $e');
      // Optional: Revert the change if saving fails, though it's often better
      // to leave the UI state as is and retry saving later.
    }
  }

  /// Update RTL setting
  Future<void> updateRtl(bool isRtl) async {
    _currentSettings = _currentSettings.copyWith(isRtl: isRtl);
    await _saveSettings();
  }

  /// Update self-destruct settings
  Future<void> updateSelfDestruct(SelfDestructSettings settings) async {
    _currentSettings = _currentSettings.copyWith(selfDestruct: settings);
    await _saveSettings();
  }

  /// Update dead man switch settings
  Future<void> updateDeadManSwitch(DeadManSwitchSettings settings) async {
    _currentSettings = _currentSettings.copyWith(deadManSwitch: settings);
    await _saveSettings();
  }

  /// Update security settings
  Future<void> updateSecurity(SecuritySettings settings) async {
    _currentSettings = _currentSettings.copyWith(security: settings);
    await _saveSettings();
  }

  /// Update chat security settings
  Future<void> updateChatSecurity(ChatSecuritySettings settings) async {
    _currentSettings = _currentSettings.copyWith(chatSecurity: settings);
    await _saveSettings();
  }

  /// Update decoy screen type
  Future<void> updateDecoyScreenType(DecoyScreenType decoyScreenType) async {
    _currentSettings = _currentSettings.copyWith(decoyScreenType: decoyScreenType);
    await _saveSettings();
  }

  /// Reset all settings to default
  Future<void> resetToDefaults() async {
    _currentSettings = AppSettings.defaultSettings();
    await _saveSettings();
  }

  void dispose() {
    if (!_settingsController.isClosed) {
      _settingsController.close();
    }
  }
}

/// Main app settings class
class AppSettings {
  final AppThemeType theme;
  final AppLanguage language;
  final bool isRtl;
  final DecoyScreenType decoyScreenType;
  final SelfDestructSettings selfDestruct;
  final DeadManSwitchSettings deadManSwitch;
  final SecuritySettings security;
  final ChatSecuritySettings chatSecurity;

  const AppSettings({
    required this.theme,
    required this.language,
    required this.isRtl,
    required this.decoyScreenType,
    required this.selfDestruct,
    required this.deadManSwitch,
    required this.security,
    required this.chatSecurity,
  });

  factory AppSettings.defaultSettings() {
    return AppSettings(
      theme: AppThemeType.intelligence,
      language: AppLanguage.arabic,
      isRtl: true,
      decoyScreenType: DecoyScreenType.systemUpdate,
      selfDestruct: SelfDestructSettings.defaultSettings(),
      deadManSwitch: DeadManSwitchSettings.defaultSettings(),
      security: SecuritySettings.defaultSettings(),
      chatSecurity: ChatSecuritySettings.defaultSettings(),
    );
  }

  AppSettings copyWith({
    AppThemeType? theme,
    AppLanguage? language,
    bool? isRtl,
    DecoyScreenType? decoyScreenType,
    SelfDestructSettings? selfDestruct,
    DeadManSwitchSettings? deadManSwitch,
    SecuritySettings? security,
    ChatSecuritySettings? chatSecurity,
  }) {
    return AppSettings(
      theme: theme ?? this.theme,
      language: language ?? this.language,
      isRtl: isRtl ?? this.isRtl,
      decoyScreenType: decoyScreenType ?? this.decoyScreenType,
      selfDestruct: selfDestruct ?? this.selfDestruct,
      deadManSwitch: deadManSwitch ?? this.deadManSwitch,
      security: security ?? this.security,
      chatSecurity: chatSecurity ?? this.chatSecurity,
    );
  }
}

// AppThemeType is defined in app_themes.dart

/// Supported languages
enum AppLanguage {
  english('en', 'English', 'English', false),
  arabic('ar', 'العربية', 'Arabic', true);

  const AppLanguage(this.code, this.nativeName, this.englishName, this.isRtl);
  final String code;
  final String nativeName;
  final String englishName;
  final bool isRtl;
}

/// Self-destruct security settings
class SelfDestructSettings {
  final bool isEnabled;
  final SelfDestructType type;
  final int timerMinutes;
  final int wrongPasswordAttempts;
  final bool deleteOnUninstall;
  final bool deleteOnFactoryReset;
  final List<SelfDestructTrigger> triggers;

  const SelfDestructSettings({
    required this.isEnabled,
    required this.type,
    required this.timerMinutes,
    required this.wrongPasswordAttempts,
    required this.deleteOnUninstall,
    required this.deleteOnFactoryReset,
    required this.triggers,
  });

  factory SelfDestructSettings.defaultSettings() {
    return const SelfDestructSettings(
      isEnabled: false,
      type: SelfDestructType.deleteMessages,
      timerMinutes: 60,
      wrongPasswordAttempts: 3,
      deleteOnUninstall: true,
      deleteOnFactoryReset: true,
      triggers: [SelfDestructTrigger.wrongPassword, SelfDestructTrigger.uninstall],
    );
  }

  factory SelfDestructSettings.fromJson(Map<String, dynamic> json) {
    return SelfDestructSettings(
      isEnabled: json['isEnabled'] ?? false,
      type: SelfDestructType.values[json['type'] ?? 0],
      timerMinutes: json['timerMinutes'] ?? 60,
      wrongPasswordAttempts: json['wrongPasswordAttempts'] ?? 3,
      deleteOnUninstall: json['deleteOnUninstall'] ?? true,
      deleteOnFactoryReset: json['deleteOnFactoryReset'] ?? true,
      triggers: (json['triggers'] as List?)
          ?.map((e) => SelfDestructTrigger.values[e])
          .toList() ?? [SelfDestructTrigger.wrongPassword],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isEnabled': isEnabled,
      'type': type.index,
      'timerMinutes': timerMinutes,
      'wrongPasswordAttempts': wrongPasswordAttempts,
      'deleteOnUninstall': deleteOnUninstall,
      'deleteOnFactoryReset': deleteOnFactoryReset,
      'triggers': triggers.map((e) => e.index).toList(),
    };
  }

  SelfDestructSettings copyWith({
    bool? isEnabled,
    SelfDestructType? type,
    int? timerMinutes,
    int? wrongPasswordAttempts,
    bool? deleteOnUninstall,
    bool? deleteOnFactoryReset,
    List<SelfDestructTrigger>? triggers,
  }) {
    return SelfDestructSettings(
      isEnabled: isEnabled ?? this.isEnabled,
      type: type ?? this.type,
      timerMinutes: timerMinutes ?? this.timerMinutes,
      wrongPasswordAttempts: wrongPasswordAttempts ?? this.wrongPasswordAttempts,
      deleteOnUninstall: deleteOnUninstall ?? this.deleteOnUninstall,
      deleteOnFactoryReset: deleteOnFactoryReset ?? this.deleteOnFactoryReset,
      triggers: triggers ?? this.triggers,
    );
  }
}

enum SelfDestructType {
  deleteMessages,
  deleteAll,
  wipeDevice
}

enum SelfDestructTrigger {
  wrongPassword,
  timeout,
  uninstall,
  factoryReset,
  simCardChange,
  rootDetection
}

/// Dead man's switch settings
class DeadManSwitchSettings {
  final bool isEnabled;
  final int checkIntervalHours;
  final int maxInactivityDays;
  final bool sendWarningEmail;
  final String emergencyEmail;
  final DeadManAction action;

  const DeadManSwitchSettings({
    required this.isEnabled,
    required this.checkIntervalHours,
    required this.maxInactivityDays,
    required this.sendWarningEmail,
    required this.emergencyEmail,
    required this.action,
  });

  factory DeadManSwitchSettings.defaultSettings() {
    return const DeadManSwitchSettings(
      isEnabled: false,
      checkIntervalHours: 24,
      maxInactivityDays: 7,
      sendWarningEmail: true,
      emergencyEmail: '',
      action: DeadManAction.deleteMessages,
    );
  }

  factory DeadManSwitchSettings.fromJson(Map<String, dynamic> json) {
    return DeadManSwitchSettings(
      isEnabled: json['isEnabled'] ?? false,
      checkIntervalHours: json['checkIntervalHours'] ?? 24,
      maxInactivityDays: json['maxInactivityDays'] ?? 7,
      sendWarningEmail: json['sendWarningEmail'] ?? true,
      emergencyEmail: json['emergencyEmail'] ?? '',
      action: DeadManAction.values[json['action'] ?? 0],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isEnabled': isEnabled,
      'checkIntervalHours': checkIntervalHours,
      'maxInactivityDays': maxInactivityDays,
      'sendWarningEmail': sendWarningEmail,
      'emergencyEmail': emergencyEmail,
      'action': action.index,
    };
  }

  DeadManSwitchSettings copyWith({
    bool? isEnabled,
    int? checkIntervalHours,
    int? maxInactivityDays,
    bool? sendWarningEmail,
    String? emergencyEmail,
    DeadManAction? action,
  }) {
    return DeadManSwitchSettings(
      isEnabled: isEnabled ?? this.isEnabled,
      checkIntervalHours: checkIntervalHours ?? this.checkIntervalHours,
      maxInactivityDays: maxInactivityDays ?? this.maxInactivityDays,
      sendWarningEmail: sendWarningEmail ?? this.sendWarningEmail,
      emergencyEmail: emergencyEmail ?? this.emergencyEmail,
      action: action ?? this.action,
    );
  }
}

enum DeadManAction {
  deleteMessages,
  deleteAll,
  sendEmergencyMessage,
  lockApp
}

/// Decoy screen types
enum DecoyScreenType {
  systemUpdate('System Update', 'Fake system update screen', 'تحديث النظام'),
  calculator('Calculator', 'Calculator application', 'الآلة الحاسبة'),
  notes('Notes', 'Notes application', 'المذكرات'),
  weather('Weather', 'Weather application', 'الطقس'),
  todo('Todo', 'Todo list application', 'قائمة المهام'),
  timer('Timer', 'Timer application', 'الموقت'),
  contacts('Contacts', 'Contacts application', 'جهات الاتصال'),
  sms('SMS', 'SMS application', 'الرسائل');

  const DecoyScreenType(this.englishName, this.description, this.arabicName);
  final String englishName;
  final String description;
  final String arabicName;
}

/// General security settings
class SecuritySettings {
  final bool requireBiometric;
  final bool requirePin;
  final String pinHash;
  final bool hideFromRecents;
  final bool disableScreenshots;
  final bool enableIncognitoKeyboard;
  final int autoLockMinutes;

  const SecuritySettings({
    required this.requireBiometric,
    required this.requirePin,
    required this.pinHash,
    required this.hideFromRecents,
    required this.disableScreenshots,
    required this.enableIncognitoKeyboard,
    required this.autoLockMinutes,
  });

  factory SecuritySettings.defaultSettings() {
    return const SecuritySettings(
      requireBiometric: false,
      requirePin: false,
      pinHash: '',
      hideFromRecents: true,
      disableScreenshots: true,
      enableIncognitoKeyboard: true,
      autoLockMinutes: 5,
    );
  }

  factory SecuritySettings.fromJson(Map<String, dynamic> json) {
    return SecuritySettings(
      requireBiometric: json['requireBiometric'] ?? false,
      requirePin: json['requirePin'] ?? false,
      pinHash: json['pinHash'] ?? '',
      hideFromRecents: json['hideFromRecents'] ?? true,
      disableScreenshots: json['disableScreenshots'] ?? true,
      enableIncognitoKeyboard: json['enableIncognitoKeyboard'] ?? true,
      autoLockMinutes: json['autoLockMinutes'] ?? 5,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'requireBiometric': requireBiometric,
      'requirePin': requirePin,
      'pinHash': pinHash,
      'hideFromRecents': hideFromRecents,
      'disableScreenshots': disableScreenshots,
      'enableIncognitoKeyboard': enableIncognitoKeyboard,
      'autoLockMinutes': autoLockMinutes,
    };
  }

  SecuritySettings copyWith({
    bool? requireBiometric,
    bool? requirePin,
    String? pinHash,
    bool? hideFromRecents,
    bool? disableScreenshots,
    bool? enableIncognitoKeyboard,
    int? autoLockMinutes,
  }) {
    return SecuritySettings(
      requireBiometric: requireBiometric ?? this.requireBiometric,
      requirePin: requirePin ?? this.requirePin,
      pinHash: pinHash ?? this.pinHash,
      hideFromRecents: hideFromRecents ?? this.hideFromRecents,
      disableScreenshots: disableScreenshots ?? this.disableScreenshots,
      enableIncognitoKeyboard: enableIncognitoKeyboard ?? this.enableIncognitoKeyboard,
      autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
    );
  }
}

/// Chat-specific security settings
class ChatSecuritySettings {
  final bool deleteAfterReading;
  final int deleteAfterHours;
  final bool requireBiometricForChat;
  final bool hideMessagePreview;
  final bool enableTypingIndicator;
  final bool enableReadReceipts;
  final bool enableOnlineStatus;

  const ChatSecuritySettings({
    required this.deleteAfterReading,
    required this.deleteAfterHours,
    required this.requireBiometricForChat,
    required this.hideMessagePreview,
    required this.enableTypingIndicator,
    required this.enableReadReceipts,
    required this.enableOnlineStatus,
  });

  factory ChatSecuritySettings.defaultSettings() {
    return const ChatSecuritySettings(
      deleteAfterReading: false,
      deleteAfterHours: 24,
      requireBiometricForChat: false,
      hideMessagePreview: true,
      enableTypingIndicator: true,
      enableReadReceipts: true,
      enableOnlineStatus: true,
    );
  }

  factory ChatSecuritySettings.fromJson(Map<String, dynamic> json) {
    return ChatSecuritySettings(
      deleteAfterReading: json['deleteAfterReading'] ?? false,
      deleteAfterHours: json['deleteAfterHours'] ?? 24,
      requireBiometricForChat: json['requireBiometricForChat'] ?? false,
      hideMessagePreview: json['hideMessagePreview'] ?? true,
      enableTypingIndicator: json['enableTypingIndicator'] ?? true,
      enableReadReceipts: json['enableReadReceipts'] ?? true,
      enableOnlineStatus: json['enableOnlineStatus'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deleteAfterReading': deleteAfterReading,
      'deleteAfterHours': deleteAfterHours,
      'requireBiometricForChat': requireBiometricForChat,
      'hideMessagePreview': hideMessagePreview,
      'enableTypingIndicator': enableTypingIndicator,
      'enableReadReceipts': enableReadReceipts,
      'enableOnlineStatus': enableOnlineStatus,
    };
  }

  ChatSecuritySettings copyWith({
    bool? deleteAfterReading,
    int? deleteAfterHours,
    bool? requireBiometricForChat,
    bool? hideMessagePreview,
    bool? enableTypingIndicator,
    bool? enableReadReceipts,
    bool? enableOnlineStatus,
  }) {
    return ChatSecuritySettings(
      deleteAfterReading: deleteAfterReading ?? this.deleteAfterReading,
      deleteAfterHours: deleteAfterHours ?? this.deleteAfterHours,
      requireBiometricForChat: requireBiometricForChat ?? this.requireBiometricForChat,
      hideMessagePreview: hideMessagePreview ?? this.hideMessagePreview,
      enableTypingIndicator: enableTypingIndicator ?? this.enableTypingIndicator,
      enableReadReceipts: enableReadReceipts ?? this.enableReadReceipts,
      enableOnlineStatus: enableOnlineStatus ?? this.enableOnlineStatus,
    );
  }
}