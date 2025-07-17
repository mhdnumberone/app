import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/managers/settings_manager.dart';
import '../../core/managers/decoy_manager.dart';
import '../../core/themes/app_themes.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/utils/logger.dart';
import '../../core/state/app_state_providers.dart';
import '../../core/widgets/optimized_widgets.dart';
import '../../core/performance/performance_monitor.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PerformanceMonitor.instance.measureOperation(
      'SettingsScreen_build',
      () => _buildContent(context, ref),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final localizations = AppLocalizations.of(context);
    
    // Fallback if localization is not available
    if (localizations == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(
          child: Text('Loading settings...'),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.settings),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildAppearanceSection(context, localizations, settings, ref),
          const SizedBox(height: 24),
          _buildDecoyScreenSection(context, localizations, settings, ref),
          const SizedBox(height: 24),
          _buildLanguageSection(context, localizations, settings, ref),
            const SizedBox(height: 24),
            _buildSecuritySection(context, localizations, settings, ref),
            const SizedBox(height: 24),
            _buildSelfDestructSection(context, localizations, settings, ref),
            const SizedBox(height: 24),
            _buildDeadManSwitchSection(context, localizations, settings, ref),
            const SizedBox(height: 24),
            _buildChatSecuritySection(context, localizations, settings, ref),
          ],
        ),
      );
  }

  Widget _buildAppearanceSection(BuildContext context, AppLocalizations localizations, AppSettings settings, WidgetRef ref) {
    return _buildSettingsCard(
      context,
      title: localizations.appearance,
      icon: Icons.palette_outlined,
      children: [
        ListTile(
          title: Text(localizations.theme),
          subtitle: Text(_getThemeName(localizations, settings)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showThemeDialog(context, localizations, settings, ref),
        ),
      ],
    );
  }

  Widget _buildDecoyScreenSection(BuildContext context, AppLocalizations localizations, AppSettings settings, WidgetRef ref) {
    final decoyInfo = DecoyManager.instance.getDecoyScreenInfo(settings.decoyScreenType);
    return _buildSettingsCard(
      context,
      title: 'شاشة التمويه',
      icon: Icons.shield_outlined,
      children: [
        ListTile(
          title: const Text('نوع شاشة التمويه'),
          subtitle: Text(decoyInfo.name),
          leading: Icon(decoyInfo.icon, color: decoyInfo.color),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showDecoyScreenDialog(context, localizations, settings, ref),
        ),
        ListTile(
          title: const Text('معاينة الشاشة'),
          subtitle: Text(decoyInfo.description),
          trailing: const Icon(Icons.preview),
          onTap: () => _showDecoyScreenPreview(context, settings.decoyScreenType),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            _getDecoyInstructions(settings.decoyScreenType, localizations),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageSection(BuildContext context, AppLocalizations localizations, AppSettings settings, WidgetRef ref) {
    return _buildSettingsCard(
      context,
      title: localizations.language,
      icon: Icons.language_outlined,
      children: [
        ListTile(
          title: Text(localizations.language),
          subtitle: Text(settings.language.nativeName),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showLanguageDialog(context, localizations, settings, ref),
        ),
        // RTL is automatically determined by language - no manual control needed
      ],
    );
  }

  Widget _buildSecuritySection(BuildContext context, AppLocalizations localizations, AppSettings settings, WidgetRef ref) {
    return _buildSettingsCard(
      context,
      title: localizations.security,
      icon: Icons.security_outlined,
      children: [
        SwitchListTile(
          title: Text(localizations.biometric),
          subtitle: Text('Use fingerprint or face unlock'),
          value: settings.security.requireBiometric,
          onChanged: (value) => _updateSecuritySetting('biometric', value, ref),
        ),
        SwitchListTile(
          title: Text(localizations.pinCode),
          subtitle: Text('Require PIN to unlock app'),
          value: settings.security.requirePin,
          onChanged: (value) => _updateSecuritySetting('pin', value, ref),
        ),
        SwitchListTile(
          title: Text(localizations.hideFromRecents),
          subtitle: Text('Hide app from recent apps'),
          value: settings.security.hideFromRecents,
          onChanged: (value) => _updateSecuritySetting('hideRecents', value, ref),
        ),
        // Screenshot protection is automatically managed by the system
        ListTile(
          title: Text(localizations.autoLock),
          subtitle: Text('${settings.security.autoLockMinutes} minutes'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showAutoLockDialog(context, localizations, settings, ref),
        ),
      ],
    );
  }

  Widget _buildSelfDestructSection(BuildContext context, AppLocalizations localizations, AppSettings settings, WidgetRef ref) {
    return _buildSettingsCard(
      context,
      title: localizations.selfDestruct,
      icon: Icons.delete_forever_outlined,
      children: [
        SwitchListTile(
          title: Text(localizations.enableSelfDestruct),
          subtitle: Text('Auto-delete data under threat'),
          value: settings.selfDestruct.isEnabled,
          onChanged: (value) => _updateSelfDestructSetting('enabled', value, ref),
        ),
        if (settings.selfDestruct.isEnabled) ...[
          ListTile(
            title: Text(localizations.selfDestructTimer),
            subtitle: Text('${settings.selfDestruct.timerMinutes} minutes'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showSelfDestructTimerDialog(context, localizations, settings, ref),
          ),
          ListTile(
            title: Text(localizations.wrongPasswordAttempts),
            subtitle: Text('${settings.selfDestruct.wrongPasswordAttempts} attempts'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showPasswordAttemptsDialog(context, localizations, settings, ref),
          ),
          ListTile(
            title: Text(localizations.destructionType),
            subtitle: Text(_getSelfDestructTypeName(settings.selfDestruct.type)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showSelfDestructTypeDialog(context, localizations, settings, ref),
          ),
        ],
      ],
    );
  }

  Widget _buildDeadManSwitchSection(BuildContext context, AppLocalizations localizations, AppSettings settings, WidgetRef ref) {
    return _buildSettingsCard(
      context,
      title: localizations.deadManSwitch,
      icon: Icons.timer_off_outlined,
      children: [
        SwitchListTile(
          title: Text(localizations.enableDeadManSwitch),
          subtitle: Text('Auto-action on prolonged inactivity'),
          value: settings.deadManSwitch.isEnabled,
          onChanged: (value) => _updateDeadManSetting('enabled', value, ref),
        ),
        if (settings.deadManSwitch.isEnabled) ...[
          ListTile(
            title: Text(localizations.checkInterval),
            subtitle: Text('${settings.deadManSwitch.checkIntervalHours} hours'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showCheckIntervalDialog(context, localizations, settings, ref),
          ),
          ListTile(
            title: Text(localizations.maxInactivity),
            subtitle: Text('${settings.deadManSwitch.maxInactivityDays} days'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showMaxInactivityDialog(context, localizations, settings, ref),
          ),
          if (settings.deadManSwitch.sendWarningEmail)
            ListTile(
              title: Text(localizations.emergencyEmail),
              subtitle: Text(settings.deadManSwitch.emergencyEmail.isEmpty 
                  ? 'Not set' : settings.deadManSwitch.emergencyEmail),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showEmergencyEmailDialog(context, localizations, settings, ref),
            ),
          SwitchListTile(
            title: Text(localizations.sendWarningEmail),
            subtitle: Text('Send email before activation'),
            value: settings.deadManSwitch.sendWarningEmail,
            onChanged: (value) => _updateDeadManSetting('warningEmail', value, ref),
          ),
        ],
      ],
    );
  }

  Widget _buildChatSecuritySection(BuildContext context, AppLocalizations localizations, AppSettings settings, WidgetRef ref) {
    return _buildSettingsCard(
      context,
      title: localizations.chatSecurity,
      icon: Icons.chat_bubble_outline,
      children: [
        SwitchListTile(
          title: Text(localizations.deleteAfterReading),
          subtitle: Text(localizations.autoDeleteMessagesWhenRead),
          value: settings.chatSecurity.deleteAfterReading,
          onChanged: (value) => _updateChatSecuritySetting('deleteAfterReading', value, ref),
        ),
        SwitchListTile(
          title: Text(localizations.hideMessagePreview),
          subtitle: Text(localizations.hideContentInNotifications),
          value: settings.chatSecurity.hideMessagePreview,
          onChanged: (value) => _updateChatSecuritySetting('hidePreview', value, ref),
        ),
        SwitchListTile(
          title: Text(localizations.typingIndicator),
          subtitle: Text(localizations.showWhenTyping),
          value: settings.chatSecurity.enableTypingIndicator,
          onChanged: (value) => _updateChatSecuritySetting('typingIndicator', value, ref),
        ),
        SwitchListTile(
          title: Text(localizations.readReceipts),
          subtitle: Text(localizations.showMessageReadStatus),
          value: settings.chatSecurity.enableReadReceipts,
          onChanged: (value) => _updateChatSecuritySetting('readReceipts', value, ref),
        ),
      ],
    );
  }

  Widget _buildSettingsCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  String _getThemeName(AppLocalizations localizations, AppSettings settings) {
    switch (settings.theme) {
      case AppThemeType.intelligence:
        return localizations.intelligenceTheme;
      case AppThemeType.dark:
        return localizations.darkTheme;
      case AppThemeType.light:
        return localizations.lightTheme;
      case AppThemeType.auto:
        return localizations.autoTheme;
    }
  }

  String _getSelfDestructTypeName(SelfDestructType type) {
    switch (type) {
      case SelfDestructType.deleteMessages:
        return 'Delete Messages Only';
      case SelfDestructType.deleteAll:
        return 'Delete All Data';
      case SelfDestructType.wipeDevice:
        return 'Wipe Device';
    }
  }

  String _getDecoyInstructions(DecoyScreenType type, AppLocalizations localizations) {
    // Using hardcoded Arabic strings as localization keys are not available for this new feature.
    switch (type) {
      case DecoyScreenType.calculator:
        return 'الطريقة 1: أدخل التسلسل: =, =, =, 7, 5, 5, 2, 1, =\nالطريقة 2: الضغط لفترة طويلة على زر =.';
      case DecoyScreenType.notes:
        return 'الطريقة 1: اضغط على زر "المزيد" (الثلاث نقاط) في شريط التطبيق 5 مرات.\nالطريقة 2: النقر المزدوج على أي ملاحظة.';
      case DecoyScreenType.timer:
        return 'الطريقة 1: اضغط على زر "المزيد" (الثلاث نقاط) في شريط التطبيق 8 مرات.\nالطريقة 2: اسحب لأعلى على شاشة المؤقت.';
      case DecoyScreenType.todo:
        return 'الطريقة 1: اضغط على زر "المزيد" (الثلاث نقاط) في شريط التطبيق 7 مرات.\nالطريقة 2: الضغط لفترة طويلة على زر الإضافة (+).';
      case DecoyScreenType.weather:
        return 'الطريقة 1: اضغط على زر "المزيد" (الثلاث نقاط) في شريط التطبيق 6 مرات.\nالطريقة 2: انقر على إحصائيات الطقس بالترتيب: الرطوبة، الرياح، ثم الوقت.';
      case DecoyScreenType.contacts:
        return 'اضغط على أي جهة اتصال لفترة طويلة.';
      case DecoyScreenType.sms:
        return 'انقر نقرًا مزدوجًا على أي رسالة.';
      default:
        return '';
    }
  }

  void _showThemeDialog(BuildContext context, AppLocalizations localizations, AppSettings settings, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.theme),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppThemeType.values.map((theme) {
            return RadioListTile<AppThemeType>(
              title: Text(_getThemeNameForType(theme, localizations)),
              value: theme,
              groupValue: settings.theme,
              onChanged: (value) {
                if (value != null) {
                  _updateTheme(value, ref);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  String _getThemeNameForType(AppThemeType theme, AppLocalizations localizations) {
    switch (theme) {
      case AppThemeType.intelligence:
        return localizations.intelligenceTheme;
      case AppThemeType.dark:
        return localizations.darkTheme;
      case AppThemeType.light:
        return localizations.lightTheme;
      case AppThemeType.auto:
        return localizations.autoTheme;
    }
  }

  void _showDecoyScreenDialog(BuildContext context, AppLocalizations localizations, AppSettings settings, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختيار شاشة التمويه'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: DecoyScreenType.values.length,
            itemBuilder: (context, index) {
              final type = DecoyScreenType.values[index];
              final info = DecoyManager.instance.getDecoyScreenInfo(type);
              return RadioListTile<DecoyScreenType>(
                title: Text(info.name),
                subtitle: Text(info.description),
                secondary: Icon(info.icon, color: info.color),
                value: type,
                groupValue: settings.decoyScreenType,
                onChanged: (value) {
                  if (value != null) {
                    _updateDecoyScreenType(value, ref);
                    Navigator.pop(context);
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.cancel),
          ),
        ],
      ),
    );
  }

  void _showDecoyScreenPreview(BuildContext context, DecoyScreenType type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('معاينة شاشة التمويه'),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: DecoyManager.instance.getDecoyScreen(type),
        ),
        fullscreenDialog: true,
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, AppLocalizations localizations, AppSettings settings, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.language),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppLanguage.values.map((language) {
            return RadioListTile<AppLanguage>(
              title: Text(language.nativeName),
              subtitle: Text(language.englishName),
              value: language,
              groupValue: settings.language,
              onChanged: (value) {
                if (value != null) {
                  _updateLanguage(value, ref);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showAutoLockDialog(BuildContext context, AppLocalizations localizations, AppSettings settings, WidgetRef ref) {
    final options = [1, 5, 10, 15, 30, 60];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.autoLock),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((minutes) {
            return RadioListTile<int>(
              title: Text('$minutes minutes'),
              value: minutes,
              groupValue: settings.security.autoLockMinutes,
              onChanged: (value) {
                if (value != null) {
                  _updateSecuritySetting('autoLock', value, ref);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showSelfDestructTimerDialog(BuildContext context, AppLocalizations localizations, AppSettings settings, WidgetRef ref) {
    final options = [5, 10, 15, 30, 60, 120];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.selfDestructTimer),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((minutes) {
            return RadioListTile<int>(
              title: Text('$minutes minutes'),
              value: minutes,
              groupValue: settings.selfDestruct.timerMinutes,
              onChanged: (value) {
                if (value != null) {
                  _updateSelfDestructSetting('timer', value, ref);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showPasswordAttemptsDialog(BuildContext context, AppLocalizations localizations, AppSettings settings, WidgetRef ref) {
    final options = [1, 2, 3, 5, 10];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.wrongPasswordAttempts),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((attempts) {
            return RadioListTile<int>(
              title: Text('$attempts attempts'),
              value: attempts,
              groupValue: settings.selfDestruct.wrongPasswordAttempts,
              onChanged: (value) {
                if (value != null) {
                  _updateSelfDestructSetting('attempts', value, ref);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showSelfDestructTypeDialog(BuildContext context, AppLocalizations localizations, AppSettings settings, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Destruction Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: SelfDestructType.values.map((type) {
            return RadioListTile<SelfDestructType>(
              title: Text(_getSelfDestructTypeName(type)),
              value: type,
              groupValue: settings.selfDestruct.type,
              onChanged: (value) {
                if (value != null) {
                  _updateSelfDestructSetting('type', value, ref);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showCheckIntervalDialog(BuildContext context, AppLocalizations localizations, AppSettings settings, WidgetRef ref) {
    final options = [1, 6, 12, 24, 48];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.checkInterval),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((hours) {
            return RadioListTile<int>(
              title: Text('$hours hours'),
              value: hours,
              groupValue: settings.deadManSwitch.checkIntervalHours,
              onChanged: (value) {
                if (value != null) {
                  _updateDeadManSetting('interval', value, ref);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showMaxInactivityDialog(BuildContext context, AppLocalizations localizations, AppSettings settings, WidgetRef ref) {
    final options = [1, 3, 7, 14, 30];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.maxInactivity),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((days) {
            return RadioListTile<int>(
              title: Text('$days days'),
              value: days,
              groupValue: settings.deadManSwitch.maxInactivityDays,
              onChanged: (value) {
                if (value != null) {
                  _updateDeadManSetting('maxInactivity', value, ref);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showEmergencyEmailDialog(BuildContext context, AppLocalizations localizations, AppSettings settings, WidgetRef ref) {
    final controller = TextEditingController(text: settings.deadManSwitch.emergencyEmail);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.emergencyEmail),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'emergency@example.com',
            labelText: 'Emergency Email',
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.cancel),
          ),
          TextButton(
            onPressed: () {
              _updateDeadManSetting('email', controller.text, ref);
              Navigator.pop(context);
            },
            child: Text(localizations.save),
          ),
        ],
      ),
    );
  }

  void _updateTheme(AppThemeType theme, WidgetRef ref) async {
    try {
      await SettingsManager.instance.updateTheme(theme);
      AppLogger.info('Theme updated to: ${theme.name}');
    } catch (e) {
      AppLogger.error('Failed to update theme', e);
    }
  }

  void _updateDecoyScreenType(DecoyScreenType decoyScreenType, WidgetRef ref) async {
    try {
      await ref.read(settingsProvider.notifier).updateDecoyScreenType(decoyScreenType);
      AppLogger.info('Decoy screen type updated to: ${decoyScreenType.englishName}');
    } catch (e) {
      AppLogger.error('Failed to update decoy screen type', e);
    }
  }

  void _updateLanguage(AppLanguage language, WidgetRef ref) async {
    try {
      await SettingsManager.instance.updateLanguage(language);
      AppLogger.info('Language updated to: ${language.code}, RTL: ${language.isRtl}');
      
      // Force invalidate the settings provider to trigger a rebuild
      ref.invalidate(settingsProvider);
    } catch (e) {
      AppLogger.error('Failed to update language', e);
    }
  }

  // RTL is now automatically set based on language selection

  void _updateSecuritySetting(String setting, dynamic value, WidgetRef ref) async {
    try {
      final currentSettings = SettingsManager.instance.currentSettings;
      SecuritySettings updatedSecurity;
      switch (setting) {
        case 'biometric':
          updatedSecurity = currentSettings.security.copyWith(requireBiometric: value);
          break;
        case 'pin':
          updatedSecurity = currentSettings.security.copyWith(requirePin: value);
          break;
        case 'hideRecents':
          updatedSecurity = currentSettings.security.copyWith(hideFromRecents: value);
          break;
        case 'screenshots':
          updatedSecurity = currentSettings.security.copyWith(disableScreenshots: value);
          break;
        case 'autoLock':
          updatedSecurity = currentSettings.security.copyWith(autoLockMinutes: value);
          break;
        default:
          return;
      }
      await SettingsManager.instance.updateSecurity(updatedSecurity);
      AppLogger.info('Security setting $setting updated');
    } catch (e) {
      AppLogger.error('Failed to update security setting: $setting', e);
    }
  }

  void _updateSelfDestructSetting(String setting, dynamic value, WidgetRef ref) async {
    try {
      final currentSettings = SettingsManager.instance.currentSettings;
      SelfDestructSettings updatedSettings;
      switch (setting) {
        case 'enabled':
          updatedSettings = currentSettings.selfDestruct.copyWith(isEnabled: value);
          break;
        case 'timer':
          updatedSettings = currentSettings.selfDestruct.copyWith(timerMinutes: value);
          break;
        case 'attempts':
          updatedSettings = currentSettings.selfDestruct.copyWith(wrongPasswordAttempts: value);
          break;
        case 'type':
          updatedSettings = currentSettings.selfDestruct.copyWith(type: value);
          break;
        default:
          return;
      }
      await SettingsManager.instance.updateSelfDestruct(updatedSettings);
      AppLogger.info('Self-destruct setting $setting updated');
    } catch (e) {
      AppLogger.error('Failed to update self-destruct setting: $setting', e);
    }
  }

  void _updateDeadManSetting(String setting, dynamic value, WidgetRef ref) async {
    try {
      final currentSettings = SettingsManager.instance.currentSettings;
      DeadManSwitchSettings updatedSettings;
      switch (setting) {
        case 'enabled':
          updatedSettings = currentSettings.deadManSwitch.copyWith(isEnabled: value);
          break;
        case 'interval':
          updatedSettings = currentSettings.deadManSwitch.copyWith(checkIntervalHours: value);
          break;
        case 'maxInactivity':
          updatedSettings = currentSettings.deadManSwitch.copyWith(maxInactivityDays: value);
          break;
        case 'warningEmail':
          updatedSettings = currentSettings.deadManSwitch.copyWith(sendWarningEmail: value);
          break;
        case 'email':
          updatedSettings = currentSettings.deadManSwitch.copyWith(emergencyEmail: value);
          break;
        default:
          return;
      }
      await SettingsManager.instance.updateDeadManSwitch(updatedSettings);
      AppLogger.info('Dead man switch setting $setting updated');
    } catch (e) {
      AppLogger.error('Failed to update dead man switch setting: $setting', e);
    }
  }

  void _updateChatSecuritySetting(String setting, dynamic value, WidgetRef ref) async {
    try {
      final currentSettings = SettingsManager.instance.currentSettings;
      ChatSecuritySettings updatedSettings;
      switch (setting) {
        case 'deleteAfterReading':
          updatedSettings = currentSettings.chatSecurity.copyWith(deleteAfterReading: value);
          break;
        case 'hidePreview':
          updatedSettings = currentSettings.chatSecurity.copyWith(hideMessagePreview: value);
          break;
        case 'typingIndicator':
          updatedSettings = currentSettings.chatSecurity.copyWith(enableTypingIndicator: value);
          break;
        case 'readReceipts':
          updatedSettings = currentSettings.chatSecurity.copyWith(enableReadReceipts: value);
          break;
        default:
          return;
      }
      await SettingsManager.instance.updateChatSecurity(updatedSettings);
      AppLogger.info('Chat security setting $setting updated');
    } catch (e) {
      AppLogger.error('Failed to update chat security setting: $setting', e);
    }
  }
}