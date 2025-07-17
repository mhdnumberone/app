// lib/core/auth/session_manager.dart
import 'dart:convert';
import 'dart:developer';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/chat_user.dart';
import '../../models/agent_identity.dart';
import '../../api/apis.dart';

/// Session manager for persistent user authentication and data
/// Provides seamless re-authentication and cached user data
class SessionManager {
  static const String _keyCurrentUser = 'current_user_session';
  static const String _keyCurrentAgent = 'current_agent_session';
  static const String _keyLastLoginTime = 'last_login_time';
  static const String _keyAgentCode = 'agent_code';
  static const String _keyAutoLogin = 'auto_login_enabled';
  static const String _keyUserPreferences = 'user_preferences';
  static const int _sessionValidityDays = 7; // Session expires after 7 days
  
  static SharedPreferences? _prefs;
  static ChatUser? _cachedUser;
  static AgentIdentity? _cachedAgent;
  static DateTime? _lastLoginTime;
  
  /// Initialize the session manager
  static Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    log('SessionManager initialized');
  }
  
  /// Save user session after successful login
  static Future<void> saveUserSession(ChatUser user, {String? agentCode}) async {
    try {
      if (_prefs == null) await initialize();
      
      // Save user data
      await _prefs!.setString(_keyCurrentUser, jsonEncode(user.toJson()));
      await _prefs!.setString(_keyLastLoginTime, DateTime.now().toIso8601String());
      await _prefs!.setBool(_keyAutoLogin, true);
      
      // Save agent code if provided
      if (agentCode != null) {
        await _prefs!.setString(_keyAgentCode, agentCode);
      }
      
      // Update cached data
      _cachedUser = user;
      _lastLoginTime = DateTime.now();
      
      log('User session saved for user: ${user.id}');
    } catch (e) {
      log('Error saving user session: $e');
    }
  }
  
  /// Save agent session after successful login
  static Future<void> saveAgentSession(AgentIdentity agent, String agentCode) async {
    try {
      if (_prefs == null) await initialize();
      
      // Save agent data
      await _prefs!.setString(_keyCurrentAgent, jsonEncode(agent.toFirestore()));
      await _prefs!.setString(_keyAgentCode, agentCode);
      await _prefs!.setString(_keyLastLoginTime, DateTime.now().toIso8601String());
      await _prefs!.setBool(_keyAutoLogin, true);
      
      // Update cached data
      _cachedAgent = agent;
      _lastLoginTime = DateTime.now();
      
      log('Agent session saved for agent: ${agent.agentCode}');
    } catch (e) {
      log('Error saving agent session: $e');
    }
  }
  
  /// Get cached user session
  static Future<ChatUser?> getCachedUserSession() async {
    try {
      if (_cachedUser != null && _isSessionValid()) {
        return _cachedUser;
      }
      
      if (_prefs == null) await initialize();
      
      // Check if session is valid
      if (!_isSessionValid()) {
        log('User session expired');
        return null;
      }
      
      // Get user data from storage
      final userJson = _prefs!.getString(_keyCurrentUser);
      if (userJson == null) {
        log('No cached user session found');
        return null;
      }
      
      // Parse user data
      final userData = jsonDecode(userJson);
      final user = ChatUser.fromJson(userData);
      
      // Update cached data
      _cachedUser = user;
      
      log('Retrieved cached user session for user: ${user.id}');
      return user;
    } catch (e) {
      log('Error retrieving cached user session: $e');
      return null;
    }
  }
  
  /// Get cached agent session
  static Future<AgentIdentity?> getCachedAgentSession() async {
    try {
      if (_cachedAgent != null && _isSessionValid()) {
        return _cachedAgent;
      }
      
      if (_prefs == null) await initialize();
      
      // Check if session is valid
      if (!_isSessionValid()) {
        log('Agent session expired');
        return null;
      }
      
      // Get agent data from storage
      final agentJson = _prefs!.getString(_keyCurrentAgent);
      if (agentJson == null) {
        log('No cached agent session found');
        return null;
      }
      
      // Parse agent data
      final agentData = jsonDecode(agentJson) as Map<String, dynamic>;
      // Create a dummy DocumentSnapshot to pass to fromFirestore
      final dummySnapshot = _DummyDocumentSnapshot(agentData);
      final agent = AgentIdentity.fromFirestore(dummySnapshot);
      
      // Update cached data
      _cachedAgent = agent;
      
      log('Retrieved cached agent session for agent: ${agent.agentCode}');
      return agent;
    } catch (e) {
      log('Error retrieving cached agent session: $e');
      return null;
    }
  }
  
  /// Get stored agent code
  static Future<String?> getStoredAgentCode() async {
    try {
      if (_prefs == null) await initialize();
      
      final agentCode = _prefs!.getString(_keyAgentCode);
      log('Retrieved stored agent code: ${agentCode != null ? '***' : 'none'}');
      return agentCode;
    } catch (e) {
      log('Error retrieving stored agent code: $e');
      return null;
    }
  }
  
  /// Check if auto-login is enabled
  static Future<bool> isAutoLoginEnabled() async {
    try {
      if (_prefs == null) await initialize();
      
      final autoLogin = _prefs!.getBool(_keyAutoLogin) ?? false;
      final sessionValid = _isSessionValid();
      
      log('Auto-login enabled: $autoLogin, Session valid: $sessionValid');
      return autoLogin && sessionValid;
    } catch (e) {
      log('Error checking auto-login status: $e');
      return false;
    }
  }
  
  /// Set auto-login preference
  static Future<void> setAutoLogin(bool enabled) async {
    try {
      if (_prefs == null) await initialize();
      
      await _prefs!.setBool(_keyAutoLogin, enabled);
      log('Auto-login set to: $enabled');
    } catch (e) {
      log('Error setting auto-login: $e');
    }
  }
  
  /// Check if current session is valid
  static bool _isSessionValid() {
    try {
      if (_prefs == null) return false;
      
      final lastLoginString = _prefs!.getString(_keyLastLoginTime);
      if (lastLoginString == null) return false;
      
      final lastLogin = DateTime.parse(lastLoginString);
      final daysSinceLogin = DateTime.now().difference(lastLogin).inDays;
      
      final isValid = daysSinceLogin < _sessionValidityDays;
      _lastLoginTime = lastLogin;
      
      return isValid;
    } catch (e) {
      log('Error checking session validity: $e');
      return false;
    }
  }
  
  /// Restore session and set APIs.me and APIs.currentAgent
  static Future<SessionRestoreResult> restoreSession() async {
    try {
      log('Attempting to restore session...');
      
      // Check if auto-login is enabled
      if (!await isAutoLoginEnabled()) {
        log('Auto-login disabled or session expired');
        return SessionRestoreResult.disabled;
      }
      
      // Try to restore user session
      final cachedUser = await getCachedUserSession();
      if (cachedUser != null) {
        APIs.me = cachedUser;
        log('User session restored successfully');
        return SessionRestoreResult.userRestored;
      }
      
      // Try to restore agent session
      final cachedAgent = await getCachedAgentSession();
      if (cachedAgent != null) {
        APIs.currentAgent = cachedAgent;
        log('Agent session restored successfully');
        return SessionRestoreResult.agentRestored;
      }
      
      log('No valid session found to restore');
      return SessionRestoreResult.noSession;
    } catch (e) {
      log('Error restoring session: $e');
      return SessionRestoreResult.error;
    }
  }
  
  /// Clear user session
  static Future<void> clearUserSession() async {
    try {
      if (_prefs == null) await initialize();
      
      await _prefs!.remove(_keyCurrentUser);
      await _prefs!.remove(_keyLastLoginTime);
      await _prefs!.remove(_keyAutoLogin);
      
      _cachedUser = null;
      _lastLoginTime = null;
      
      log('User session cleared');
    } catch (e) {
      log('Error clearing user session: $e');
    }
  }
  
  /// Clear agent session
  static Future<void> clearAgentSession() async {
    try {
      if (_prefs == null) await initialize();
      
      await _prefs!.remove(_keyCurrentAgent);
      await _prefs!.remove(_keyAgentCode);
      await _prefs!.remove(_keyLastLoginTime);
      await _prefs!.remove(_keyAutoLogin);
      
      _cachedAgent = null;
      _lastLoginTime = null;
      
      log('Agent session cleared');
    } catch (e) {
      log('Error clearing agent session: $e');
    }
  }
  
  /// Clear all sessions
  static Future<void> clearAllSessions() async {
    try {
      await clearUserSession();
      await clearAgentSession();
      
      if (_prefs == null) await initialize();
      await _prefs!.remove(_keyUserPreferences);
      
      log('All sessions cleared');
    } catch (e) {
      log('Error clearing all sessions: $e');
    }
  }
  
  /// Get session statistics
  static Future<SessionStats> getSessionStats() async {
    try {
      if (_prefs == null) await initialize();
      
      final hasUser = _prefs!.containsKey(_keyCurrentUser);
      final hasAgent = _prefs!.containsKey(_keyCurrentAgent);
      final hasAgentCode = _prefs!.containsKey(_keyAgentCode);
      final autoLoginEnabled = _prefs!.getBool(_keyAutoLogin) ?? false;
      final sessionValid = _isSessionValid();
      
      DateTime? lastLogin;
      final lastLoginString = _prefs!.getString(_keyLastLoginTime);
      if (lastLoginString != null) {
        lastLogin = DateTime.parse(lastLoginString);
      }
      
      return SessionStats(
        hasUserSession: hasUser,
        hasAgentSession: hasAgent,
        hasStoredAgentCode: hasAgentCode,
        autoLoginEnabled: autoLoginEnabled,
        sessionValid: sessionValid,
        lastLoginTime: lastLogin,
        sessionValidityDays: _sessionValidityDays,
      );
    } catch (e) {
      log('Error getting session stats: $e');
      return SessionStats(
        hasUserSession: false,
        hasAgentSession: false,
        hasStoredAgentCode: false,
        autoLoginEnabled: false,
        sessionValid: false,
        lastLoginTime: null,
        sessionValidityDays: _sessionValidityDays,
      );
    }
  }
  
  /// Save user preferences
  static Future<void> saveUserPreferences(Map<String, dynamic> preferences) async {
    try {
      if (_prefs == null) await initialize();
      
      await _prefs!.setString(_keyUserPreferences, jsonEncode(preferences));
      log('User preferences saved');
    } catch (e) {
      log('Error saving user preferences: $e');
    }
  }
  
  /// Get user preferences
  static Future<Map<String, dynamic>?> getUserPreferences() async {
    try {
      if (_prefs == null) await initialize();
      
      final prefsJson = _prefs!.getString(_keyUserPreferences);
      if (prefsJson == null) return null;
      
      final preferences = jsonDecode(prefsJson) as Map<String, dynamic>;
      log('User preferences retrieved');
      return preferences;
    } catch (e) {
      log('Error retrieving user preferences: $e');
      return null;
    }
  }
}

/// Session restore result enum
enum SessionRestoreResult {
  userRestored,
  agentRestored,
  noSession,
  disabled,
  error,
}

/// Session statistics class
class SessionStats {
  final bool hasUserSession;
  final bool hasAgentSession;
  final bool hasStoredAgentCode;
  final bool autoLoginEnabled;
  final bool sessionValid;
  final DateTime? lastLoginTime;
  final int sessionValidityDays;
  
  const SessionStats({
    required this.hasUserSession,
    required this.hasAgentSession,
    required this.hasStoredAgentCode,
    required this.autoLoginEnabled,
    required this.sessionValid,
    required this.lastLoginTime,
    required this.sessionValidityDays,
  });
  
  String get sessionAge {
    if (lastLoginTime == null) return 'Unknown';
    final age = DateTime.now().difference(lastLoginTime!);
    if (age.inDays > 0) return '${age.inDays} day(s) ago';
    if (age.inHours > 0) return '${age.inHours} hour(s) ago';
    return '${age.inMinutes} minute(s) ago';
  }
  
  @override
  String toString() {
    return 'SessionStats(user: $hasUserSession, agent: $hasAgentSession, '
           'valid: $sessionValid, autoLogin: $autoLoginEnabled, age: $sessionAge)';
  }
}