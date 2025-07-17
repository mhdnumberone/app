import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../managers/settings_manager.dart';
import '../utils/logger.dart';

/// Comprehensive security manager for app protection
class SecurityManager {
  static SecurityManager? _instance;
  static SecurityManager get instance => _instance ??= SecurityManager._();
  SecurityManager._();

  final LocalAuthentication _localAuth = LocalAuthentication();
  static const MethodChannel _securityChannel = MethodChannel('com.example.mictest/security');
  
  Timer? _autoLockTimer;
  DateTime? _lastActiveTime;
  String? _currentPinHash;
  int _wrongPasswordAttempts = 0;
  
  /// Initialize security manager
  Future<void> initialize() async {
    try {
      _lastActiveTime = DateTime.now();
      _setupAutoLock();
      _setupScreenshotProtection();
      _setupAppHiding();
      AppLogger.info('Security manager initialized');
    } catch (e) {
      AppLogger.error('Failed to initialize security manager', e);
    }
  }

  /// Update user activity timestamp
  void updateActivity() {
    _lastActiveTime = DateTime.now();
    _resetAutoLockTimer();
  }

  /// Setup auto-lock functionality
  void _setupAutoLock() {
    final settings = SettingsManager.instance.currentSettings;
    if (settings.security.autoLockMinutes > 0) {
      _resetAutoLockTimer();
    }
  }

  /// Reset auto-lock timer
  void _resetAutoLockTimer() {
    final settings = SettingsManager.instance.currentSettings;
    _autoLockTimer?.cancel();
    
    if (settings.security.autoLockMinutes > 0) {
      _autoLockTimer = Timer(
        Duration(minutes: settings.security.autoLockMinutes),
        _triggerAutoLock,
      );
    }
  }

  /// Trigger auto-lock
  void _triggerAutoLock() {
    AppLogger.info('Auto-lock triggered');
    // Lock the app - redirect to lock screen
    _showLockScreen();
  }

  /// Show lock screen
  void _showLockScreen() {
    // Implementation would redirect to lock screen
    AppLogger.info('Showing lock screen');
  }

  /// Setup screenshot protection
  Future<void> _setupScreenshotProtection() async {
    final settings = SettingsManager.instance.currentSettings;
    if (settings.security.disableScreenshots) {
      try {
        await _securityChannel.invokeMethod('enableScreenshotProtection');
        AppLogger.info('Screenshot protection enabled');
      } catch (e) {
        AppLogger.error('Failed to enable screenshot protection', e);
      }
    }
  }

  /// Setup app hiding from recents
  Future<void> _setupAppHiding() async {
    final settings = SettingsManager.instance.currentSettings;
    if (settings.security.hideFromRecents) {
      try {
        await _securityChannel.invokeMethod('hideFromRecents');
        AppLogger.info('App hiding from recents enabled');
      } catch (e) {
        AppLogger.error('Failed to hide app from recents', e);
      }
    }
  }

  /// Authenticate with biometrics
  Future<bool> authenticateWithBiometrics() async {
    try {
      final settings = SettingsManager.instance.currentSettings;
      if (!settings.security.requireBiometric) {
        return true;
      }

      final isAvailable = await _localAuth.canCheckBiometrics;
      if (!isAvailable) {
        AppLogger.warning('Biometric authentication not available');
        return false;
      }

      final isAuthenticated = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access the app',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (isAuthenticated) {
        _wrongPasswordAttempts = 0;
        updateActivity();
      }

      return isAuthenticated;
    } catch (e) {
      AppLogger.error('Biometric authentication failed', e);
      return false;
    }
  }

  /// Set PIN code
  Future<bool> setPinCode(String pin) async {
    try {
      if (pin.length < 4) {
        AppLogger.warning('PIN too short');
        return false;
      }

      _currentPinHash = _hashPin(pin);
      await _savePinHash(_currentPinHash!);
      AppLogger.info('PIN code set successfully');
      return true;
    } catch (e) {
      AppLogger.error('Failed to set PIN code', e);
      return false;
    }
  }

  /// Verify PIN code
  Future<bool> verifyPinCode(String pin) async {
    try {
      final settings = SettingsManager.instance.currentSettings;
      if (!settings.security.requirePin) {
        return true;
      }

      if (_currentPinHash == null) {
        _currentPinHash = await _loadPinHash();
      }

      if (_currentPinHash == null) {
        AppLogger.warning('No PIN set');
        return false;
      }

      final inputHash = _hashPin(pin);
      if (inputHash == _currentPinHash) {
        _wrongPasswordAttempts = 0;
        updateActivity();
        return true;
      } else {
        _wrongPasswordAttempts++;
        AppLogger.warning('Wrong PIN attempt: $_wrongPasswordAttempts');
        
        // Check for self-destruct trigger
        await _checkSelfDestructTrigger();
        return false;
      }
    } catch (e) {
      AppLogger.error('PIN verification failed', e);
      return false;
    }
  }

  /// Hash PIN using SHA-256
  String _hashPin(String pin) {
    final bytes = utf8.encode(pin + 'salt_secure_chat');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Save PIN hash to secure storage
  Future<void> _savePinHash(String hash) async {
    try {
      await _securityChannel.invokeMethod('savePinHash', {'hash': hash});
    } catch (e) {
      AppLogger.error('Failed to save PIN hash', e);
    }
  }

  /// Load PIN hash from secure storage
  Future<String?> _loadPinHash() async {
    try {
      return await _securityChannel.invokeMethod('loadPinHash');
    } catch (e) {
      AppLogger.error('Failed to load PIN hash', e);
      return null;
    }
  }

  /// Check if self-destruct should be triggered
  Future<void> _checkSelfDestructTrigger() async {
    final settings = SettingsManager.instance.currentSettings;
    if (!settings.selfDestruct.isEnabled) return;

    if (_wrongPasswordAttempts >= settings.selfDestruct.wrongPasswordAttempts) {
      AppLogger.warning('Self-destruct triggered by wrong password attempts');
      await _triggerSelfDestruct();
    }
  }

  /// Trigger self-destruct
  Future<void> _triggerSelfDestruct() async {
    try {
      final settings = SettingsManager.instance.currentSettings;
      AppLogger.warning('Triggering self-destruct: ${settings.selfDestruct.type}');

      switch (settings.selfDestruct.type) {
        case SelfDestructType.deleteMessages:
          await _deleteMessages();
          break;
        case SelfDestructType.deleteAll:
          await _deleteAllData();
          break;
        case SelfDestructType.wipeDevice:
          await _wipeDevice();
          break;
      }
    } catch (e) {
      AppLogger.error('Self-destruct execution failed', e);
    }
  }

  /// Delete messages only
  Future<void> _deleteMessages() async {
    try {
      await _securityChannel.invokeMethod('deleteMessages');
      AppLogger.info('Messages deleted by self-destruct');
    } catch (e) {
      AppLogger.error('Failed to delete messages', e);
    }
  }

  /// Delete all app data
  Future<void> _deleteAllData() async {
    try {
      await _securityChannel.invokeMethod('deleteAllData');
      AppLogger.info('All data deleted by self-destruct');
    } catch (e) {
      AppLogger.error('Failed to delete all data', e);
    }
  }

  /// Wipe device (if possible)
  Future<void> _wipeDevice() async {
    try {
      if (Platform.isAndroid) {
        await _securityChannel.invokeMethod('wipeDevice');
        AppLogger.info('Device wipe initiated');
      } else {
        // On iOS, just delete all app data
        await _deleteAllData();
      }
    } catch (e) {
      AppLogger.error('Failed to wipe device', e);
    }
  }

  /// Check for security threats
  Future<Map<String, bool>> checkSecurityThreats() async {
    try {
      final result = await _securityChannel.invokeMethod('checkSecurityThreats');
      return Map<String, bool>.from(result ?? {});
    } catch (e) {
      AppLogger.error('Failed to check security threats', e);
      return {};
    }
  }

  /// Apply security settings
  Future<void> applySecuritySettings(SecuritySettings settings) async {
    try {
      // Apply screenshot protection
      if (settings.disableScreenshots) {
        await _securityChannel.invokeMethod('enableScreenshotProtection');
      } else {
        await _securityChannel.invokeMethod('disableScreenshotProtection');
      }

      // Apply app hiding
      if (settings.hideFromRecents) {
        await _securityChannel.invokeMethod('hideFromRecents');
      } else {
        await _securityChannel.invokeMethod('showInRecents');
      }

      // Setup auto-lock
      _resetAutoLockTimer();

      AppLogger.info('Security settings applied successfully');
    } catch (e) {
      AppLogger.error('Failed to apply security settings', e);
    }
  }

  /// Dispose security manager
  void dispose() {
    _autoLockTimer?.cancel();
    AppLogger.info('Security manager disposed');
  }
}