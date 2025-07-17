import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../managers/settings_manager.dart';
import '../utils/logger.dart';

/// Dead Man's Switch implementation for automatic data protection
class DeadManSwitch {
  static DeadManSwitch? _instance;
  static DeadManSwitch get instance => _instance ??= DeadManSwitch._();
  DeadManSwitch._();

  Timer? _checkTimer;
  SharedPreferences? _prefs;
  
  static const String _lastCheckKey = 'dead_man_last_check';
  static const String _lastActivityKey = 'dead_man_last_activity';
  static const String _warningEmailSentKey = 'dead_man_warning_sent';
  
  /// Initialize dead man's switch
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _updateLastActivity();
      _setupPeriodicCheck();
      AppLogger.info('Dead Man Switch initialized');
    } catch (e) {
      AppLogger.error('Failed to initialize Dead Man Switch', e);
    }
  }

  /// Setup periodic check timer
  void _setupPeriodicCheck() {
    final settings = SettingsManager.instance.currentSettings;
    if (!settings.deadManSwitch.isEnabled) {
      _checkTimer?.cancel();
      return;
    }

    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(
      Duration(hours: settings.deadManSwitch.checkIntervalHours),
      (_) => _performCheck(),
    );
    
    AppLogger.info('Dead Man Switch periodic check setup for every ${settings.deadManSwitch.checkIntervalHours} hours');
  }

  /// Update last activity timestamp
  Future<void> updateActivity() async {
    try {
      await _updateLastActivity();
      await _clearWarningEmailFlag();
    } catch (e) {
      AppLogger.error('Failed to update Dead Man Switch activity', e);
    }
  }

  /// Update last activity timestamp
  Future<void> _updateLastActivity() async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _prefs?.setInt(_lastActivityKey, now);
      AppLogger.debug('Dead Man Switch activity updated');
    } catch (e) {
      AppLogger.error('Failed to update last activity', e);
    }
  }

  /// Perform periodic check
  Future<void> _performCheck() async {
    try {
      final settings = SettingsManager.instance.currentSettings;
      if (!settings.deadManSwitch.isEnabled) return;

      final lastActivity = await _getLastActivity();
      final now = DateTime.now();
      final daysSinceActivity = now.difference(lastActivity).inDays;
      
      AppLogger.info('Dead Man Switch check: $daysSinceActivity days since last activity');

      if (daysSinceActivity >= settings.deadManSwitch.maxInactivityDays) {
        // Maximum inactivity reached - trigger action
        await _triggerDeadManAction();
      } else if (daysSinceActivity >= (settings.deadManSwitch.maxInactivityDays - 1)) {
        // Send warning email if close to trigger
        await _sendWarningEmailIfNeeded();
      }

      await _updateLastCheck();
    } catch (e) {
      AppLogger.error('Dead Man Switch check failed', e);
    }
  }

  /// Get last activity timestamp
  Future<DateTime> _getLastActivity() async {
    try {
      final timestamp = _prefs?.getInt(_lastActivityKey) ?? DateTime.now().millisecondsSinceEpoch;
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } catch (e) {
      AppLogger.error('Failed to get last activity', e);
      return DateTime.now();
    }
  }

  /// Update last check timestamp
  Future<void> _updateLastCheck() async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _prefs?.setInt(_lastCheckKey, now);
    } catch (e) {
      AppLogger.error('Failed to update last check', e);
    }
  }

  /// Send warning email if needed
  Future<void> _sendWarningEmailIfNeeded() async {
    try {
      final settings = SettingsManager.instance.currentSettings;
      if (!settings.deadManSwitch.sendWarningEmail || 
          settings.deadManSwitch.emergencyEmail.isEmpty) {
        return;
      }

      final warningEmailSent = _prefs?.getBool(_warningEmailSentKey) ?? false;
      if (warningEmailSent) {
        return; // Warning already sent
      }

      await _sendWarningEmail();
      await _prefs?.setBool(_warningEmailSentKey, true);
      AppLogger.info('Dead Man Switch warning email sent');
    } catch (e) {
      AppLogger.error('Failed to send warning email', e);
    }
  }

  /// Send warning email
  Future<void> _sendWarningEmail() async {
    try {
      final settings = SettingsManager.instance.currentSettings;
      final email = settings.deadManSwitch.emergencyEmail;
      
      if (email.isEmpty) return;

      // Prepare email content
      final subject = 'Dead Man Switch Warning - SecureChat';
      final body = '''
Dear User,

This is an automated warning from your SecureChat Dead Man's Switch.

Your account has been inactive for ${settings.deadManSwitch.maxInactivityDays - 1} days.
If you do not respond within 24 hours, the following action will be taken:
${_getActionDescription(settings.deadManSwitch.action)}

To prevent this action:
1. Open the SecureChat app
2. Perform any activity (send a message, check settings, etc.)

This will reset the inactivity timer.

Best regards,
SecureChat Security System
''';

      // Send email using your preferred email service
      await _sendEmailViaService(email, subject, body);
      
    } catch (e) {
      AppLogger.error('Failed to send warning email', e);
    }
  }

  /// Send email via service (implement with your preferred email service)
  Future<void> _sendEmailViaService(String email, String subject, String body) async {
    try {
      // TODO: Configure email service credentials through secure environment variables
      // or app settings instead of hardcoding them here
      
      // Get email service configuration from secure storage or environment
      final emailServiceUrl = await _getEmailServiceUrl();
      final apiKey = await _getEmailServiceApiKey();
      final fromEmail = await _getFromEmailAddress();
      
      if (emailServiceUrl == null || apiKey == null || fromEmail == null) {
        AppLogger.warning('Email service not configured - logging email content instead');
        AppLogger.warning('EMAIL TO SEND:\nTo: $email\nSubject: $subject\nBody: $body');
        return;
      }

      final response = await http.post(
        Uri.parse(emailServiceUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'to': email,
          'subject': subject,
          'text': body,
          'from': fromEmail,
        }),
      );

      if (response.statusCode == 200) {
        AppLogger.info('Warning email sent successfully to $email');
      } else {
        AppLogger.error('Failed to send email: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.error('Email service error', e);
      // Fallback: log the email content for manual processing
      AppLogger.warning('EMAIL TO SEND:\nTo: $email\nSubject: $subject\nBody: $body');
    }
  }

  /// Get email service URL from secure configuration
  Future<String?> _getEmailServiceUrl() async {
    try {
      // TODO: Implement secure configuration retrieval
      // This should come from environment variables or secure app settings
      return _prefs?.getString('email_service_url');
    } catch (e) {
      AppLogger.error('Failed to get email service URL', e);
      return null;
    }
  }

  /// Get email service API key from secure configuration
  Future<String?> _getEmailServiceApiKey() async {
    try {
      // TODO: Implement secure credential retrieval
      // This should come from encrypted storage or secure keychain
      return _prefs?.getString('email_service_api_key');
    } catch (e) {
      AppLogger.error('Failed to get email service API key', e);
      return null;
    }
  }

  /// Get from email address from secure configuration
  Future<String?> _getFromEmailAddress() async {
    try {
      // TODO: Implement secure configuration retrieval
      return _prefs?.getString('from_email_address') ?? 'security@securechat.app';
    } catch (e) {
      AppLogger.error('Failed to get from email address', e);
      return 'security@securechat.app';
    }
  }

  /// Clear warning email flag
  Future<void> _clearWarningEmailFlag() async {
    try {
      await _prefs?.setBool(_warningEmailSentKey, false);
    } catch (e) {
      AppLogger.error('Failed to clear warning email flag', e);
    }
  }

  /// Trigger dead man action
  Future<void> _triggerDeadManAction() async {
    try {
      final settings = SettingsManager.instance.currentSettings;
      AppLogger.warning('Dead Man Switch triggered: ${settings.deadManSwitch.action}');

      switch (settings.deadManSwitch.action) {
        case DeadManAction.deleteMessages:
          await _deleteMessages();
          break;
        case DeadManAction.deleteAll:
          await _deleteAllData();
          break;
        case DeadManAction.sendEmergencyMessage:
          await _sendEmergencyAlert();
          break;
        case DeadManAction.lockApp:
          await _lockApp();
          break;
      }

      // Send notification email about action taken
      await _sendActionTakenEmail();
      
    } catch (e) {
      AppLogger.error('Failed to execute dead man action', e);
    }
  }

  /// Delete messages
  Future<void> _deleteMessages() async {
    try {
      // Implement message deletion logic
      AppLogger.info('Dead Man Switch: Deleting messages');
      // You would implement the actual message deletion here
    } catch (e) {
      AppLogger.error('Failed to delete messages', e);
    }
  }

  /// Delete all app data
  Future<void> _deleteAllData() async {
    try {
      AppLogger.info('Dead Man Switch: Deleting all data');
      
      // Clear SharedPreferences
      await _prefs?.clear();
      
      // Clear app cache and data directories
      if (Platform.isAndroid || Platform.isIOS) {
        // This would require platform-specific implementation
        AppLogger.info('App data deletion initiated');
      }
    } catch (e) {
      AppLogger.error('Failed to delete all data', e);
    }
  }

  /// Send emergency alert
  Future<void> _sendEmergencyAlert() async {
    try {
      final settings = SettingsManager.instance.currentSettings;
      if (settings.deadManSwitch.emergencyEmail.isNotEmpty) {
        await _sendEmailViaService(
          settings.deadManSwitch.emergencyEmail,
          'EMERGENCY: Dead Man Switch Triggered',
          'This is an emergency alert. The Dead Man Switch has been triggered due to prolonged inactivity.',
        );
      }
      AppLogger.info('Emergency alert sent');
    } catch (e) {
      AppLogger.error('Failed to send emergency alert', e);
    }
  }

  /// Lock the app
  Future<void> _lockApp() async {
    try {
      // Set app as locked in preferences
      await _prefs?.setBool('app_locked_by_dead_man_switch', true);
      
      AppLogger.warning('App locked by Dead Man Switch');
    } catch (e) {
      AppLogger.error('Failed to lock app: $e');
    }
  }

  /// Send action taken email
  Future<void> _sendActionTakenEmail() async {
    try {
      final settings = SettingsManager.instance.currentSettings;
      if (settings.deadManSwitch.emergencyEmail.isEmpty) return;

      final subject = 'Dead Man Switch Action Executed - SecureChat';
      final body = '''
This is an automated notification from your SecureChat Dead Man's Switch.

ACTION TAKEN: ${_getActionDescription(settings.deadManSwitch.action)}

This action was executed due to prolonged inactivity of ${settings.deadManSwitch.maxInactivityDays} days.

Timestamp: ${DateTime.now().toIso8601String()}

This is an automated message.
''';

      await _sendEmailViaService(settings.deadManSwitch.emergencyEmail, subject, body);
    } catch (e) {
      AppLogger.error('Failed to send action taken email', e);
    }
  }

  /// Get action description
  String _getActionDescription(DeadManAction action) {
    switch (action) {
      case DeadManAction.deleteMessages:
        return 'All messages will be permanently deleted';
      case DeadManAction.deleteAll:
        return 'All app data will be permanently deleted';
      case DeadManAction.sendEmergencyMessage:
        return 'Emergency alert will be sent';
      case DeadManAction.lockApp:
        return 'App will be locked';
    }
  }

  /// Check if dead man switch is active
  bool get isActive {
    final settings = SettingsManager.instance.currentSettings;
    return settings.deadManSwitch.isEnabled;
  }

  /// Get status information
  Future<Map<String, dynamic>> getStatus() async {
    try {
      final settings = SettingsManager.instance.currentSettings;
      final lastActivity = await _getLastActivity();
      final daysSinceActivity = DateTime.now().difference(lastActivity).inDays;
      
      return {
        'isEnabled': settings.deadManSwitch.isEnabled,
        'lastActivity': lastActivity.toIso8601String(),
        'daysSinceActivity': daysSinceActivity,
        'maxInactivityDays': settings.deadManSwitch.maxInactivityDays,
        'daysRemaining': (settings.deadManSwitch.maxInactivityDays - daysSinceActivity).clamp(0, settings.deadManSwitch.maxInactivityDays),
        'action': settings.deadManSwitch.action.toString(),
      };
    } catch (e) {
      AppLogger.error('Failed to get dead man switch status', e);
      return {};
    }
  }

  /// Force trigger for testing (remove in production)
  Future<void> forceTrigger() async {
    AppLogger.warning('Dead Man Switch force triggered for testing');
    await _triggerDeadManAction();
  }

  /// Apply new settings
  Future<void> applySettings(DeadManSwitchSettings settings) async {
    try {
      if (settings.isEnabled) {
        _setupPeriodicCheck();
        await _updateLastActivity();
      } else {
        _checkTimer?.cancel();
      }
      AppLogger.info('Dead Man Switch settings applied');
    } catch (e) {
      AppLogger.error('Failed to apply dead man switch settings', e);
    }
  }

  /// Dispose dead man switch
  void dispose() {
    _checkTimer?.cancel();
    AppLogger.info('Dead Man Switch disposed');
  }
}

