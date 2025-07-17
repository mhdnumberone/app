// lib/core/cache/message_cache_manager.dart
import 'dart:convert';
import 'dart:developer';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/message.dart';
import '../../models/chat_user.dart';

/// Message cache manager for persistent storage of messages
/// This provides instant loading of recent messages and offline support
class MessageCacheManager {
  static const String _keyPrefix = 'cached_messages_';
  static const String _keyLastUpdate = 'last_update_';
  static const int _maxCachedMessages = 100; // Maximum messages per conversation
  static const int _cacheValidityHours = 24; // Cache validity period
  
  static SharedPreferences? _prefs;
  static final Map<String, List<Message>> _memoryCache = {};
  static final Map<String, DateTime> _lastUpdateCache = {};
  
  /// Initialize the cache manager
  static Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    log('MessageCacheManager initialized');
  }
  
  /// Get cache key for a user
  static String _getCacheKey(String userId) => '$_keyPrefix$userId';
  
  /// Get last update key for a user
  static String _getLastUpdateKey(String userId) => '$_keyLastUpdate$userId';
  
  /// Cache messages for a specific user
  static Future<void> cacheMessages(String userId, List<Message> messages) async {
    try {
      if (_prefs == null) await initialize();
      
      // Limit the number of cached messages
      final messagesToCache = messages.take(_maxCachedMessages).toList();
      
      // Convert messages to JSON
      final jsonMessages = messagesToCache.map((msg) => msg.toJson()).toList();
      final jsonString = jsonEncode(jsonMessages);
      
      // Save to SharedPreferences
      await _prefs!.setString(_getCacheKey(userId), jsonString);
      await _prefs!.setString(_getLastUpdateKey(userId), DateTime.now().toIso8601String());
      
      // Update memory cache
      _memoryCache[userId] = List.from(messagesToCache);
      _lastUpdateCache[userId] = DateTime.now();
      
      log('Cached ${messagesToCache.length} messages for user $userId');
    } catch (e) {
      log('Error caching messages for user $userId: $e');
    }
  }
  
  /// Get cached messages for a specific user
  static Future<List<Message>?> getCachedMessages(String userId) async {
    try {
      // Check memory cache first
      if (_memoryCache.containsKey(userId)) {
        final cachedMessages = _memoryCache[userId]!;
        if (_isCacheValid(userId)) {
          log('Retrieved ${cachedMessages.length} messages from memory cache for user $userId');
          return cachedMessages;
        }
      }
      
      if (_prefs == null) await initialize();
      
      // Check if cache is valid
      if (!_isCacheValid(userId)) {
        log('Cache expired for user $userId');
        return null;
      }
      
      // Get from SharedPreferences
      final jsonString = _prefs!.getString(_getCacheKey(userId));
      if (jsonString == null) {
        log('No cached messages found for user $userId');
        return null;
      }
      
      // Parse JSON
      final jsonList = jsonDecode(jsonString) as List;
      final messages = jsonList.map((json) => Message.fromJson(json)).toList();
      
      // Update memory cache
      _memoryCache[userId] = List.from(messages);
      
      log('Retrieved ${messages.length} messages from persistent cache for user $userId');
      return messages;
    } catch (e) {
      log('Error retrieving cached messages for user $userId: $e');
      return null;
    }
  }
  
  /// Check if cache is valid for a user
  static bool _isCacheValid(String userId) {
    try {
      // Check memory cache first
      if (_lastUpdateCache.containsKey(userId)) {
        final lastUpdate = _lastUpdateCache[userId]!;
        final isValid = DateTime.now().difference(lastUpdate).inHours < _cacheValidityHours;
        return isValid;
      }
      
      // Check persistent cache
      final lastUpdateString = _prefs?.getString(_getLastUpdateKey(userId));
      if (lastUpdateString == null) return false;
      
      final lastUpdate = DateTime.parse(lastUpdateString);
      final isValid = DateTime.now().difference(lastUpdate).inHours < _cacheValidityHours;
      
      // Update memory cache
      if (isValid) {
        _lastUpdateCache[userId] = lastUpdate;
      }
      
      return isValid;
    } catch (e) {
      log('Error checking cache validity for user $userId: $e');
      return false;
    }
  }
  
  /// Clear cached messages for a specific user
  static Future<void> clearUserCache(String userId) async {
    try {
      if (_prefs == null) await initialize();
      
      await _prefs!.remove(_getCacheKey(userId));
      await _prefs!.remove(_getLastUpdateKey(userId));
      
      _memoryCache.remove(userId);
      _lastUpdateCache.remove(userId);
      
      log('Cleared cache for user $userId');
    } catch (e) {
      log('Error clearing cache for user $userId: $e');
    }
  }
  
  /// Clear all cached messages
  static Future<void> clearAllCache() async {
    try {
      if (_prefs == null) await initialize();
      
      final keys = _prefs!.getKeys();
      final keysToRemove = keys.where((key) => 
        key.startsWith(_keyPrefix) || key.startsWith(_keyLastUpdate)
      ).toList();
      
      for (final key in keysToRemove) {
        await _prefs!.remove(key);
      }
      
      _memoryCache.clear();
      _lastUpdateCache.clear();
      
      log('Cleared all message cache');
    } catch (e) {
      log('Error clearing all cache: $e');
    }
  }
  
  /// Get cache statistics
  static Future<MessageCacheStats> getCacheStats() async {
    try {
      if (_prefs == null) await initialize();
      
      final keys = _prefs!.getKeys();
      final messageKeys = keys.where((key) => key.startsWith(_keyPrefix)).toList();
      
      int totalMessages = 0;
      int totalSize = 0;
      
      for (final key in messageKeys) {
        final jsonString = _prefs!.getString(key);
        if (jsonString != null) {
          totalSize += jsonString.length;
          try {
            final jsonList = jsonDecode(jsonString) as List;
            totalMessages += jsonList.length;
          } catch (e) {
            log('Error parsing cached messages for key $key: $e');
          }
        }
      }
      
      return MessageCacheStats(
        totalConversations: messageKeys.length,
        totalMessages: totalMessages,
        totalSizeBytes: totalSize,
        memoryConversations: _memoryCache.length,
        memoryMessages: _memoryCache.values.fold(0, (sum, messages) => sum + messages.length),
      );
    } catch (e) {
      log('Error getting cache stats: $e');
      return MessageCacheStats(
        totalConversations: 0,
        totalMessages: 0,
        totalSizeBytes: 0,
        memoryConversations: 0,
        memoryMessages: 0,
      );
    }
  }
  
  /// Update a single message in cache (for read receipts, etc.)
  static Future<void> updateMessageInCache(String userId, Message updatedMessage) async {
    try {
      // Update memory cache
      if (_memoryCache.containsKey(userId)) {
        final messages = _memoryCache[userId]!;
        final index = messages.indexWhere((msg) => msg.id == updatedMessage.id);
        if (index != -1) {
          messages[index] = updatedMessage;
          
          // Update persistent cache
          await cacheMessages(userId, messages);
          log('Updated message ${updatedMessage.id} in cache for user $userId');
        }
      }
    } catch (e) {
      log('Error updating message in cache for user $userId: $e');
    }
  }
  
  /// Add a new message to cache
  static Future<void> addMessageToCache(String userId, Message newMessage) async {
    try {
      // Get existing messages
      final existingMessages = await getCachedMessages(userId) ?? [];
      
      // Check if message already exists
      final existingIndex = existingMessages.indexWhere((msg) => msg.id == newMessage.id);
      if (existingIndex != -1) {
        // Update existing message
        existingMessages[existingIndex] = newMessage;
      } else {
        // Add new message at the beginning
        existingMessages.insert(0, newMessage);
      }
      
      // Cache the updated list
      await cacheMessages(userId, existingMessages);
      log('Added message ${newMessage.id} to cache for user $userId');
    } catch (e) {
      log('Error adding message to cache for user $userId: $e');
    }
  }
}

/// Cache statistics class
class MessageCacheStats {
  final int totalConversations;
  final int totalMessages;
  final int totalSizeBytes;
  final int memoryConversations;
  final int memoryMessages;
  
  const MessageCacheStats({
    required this.totalConversations,
    required this.totalMessages,
    required this.totalSizeBytes,
    required this.memoryConversations,
    required this.memoryMessages,
  });
  
  double get totalSizeKB => totalSizeBytes / 1024;
  double get totalSizeMB => totalSizeKB / 1024;
  
  @override
  String toString() {
    return 'MessageCacheStats(conversations: $totalConversations, messages: $totalMessages, '
           'size: ${totalSizeMB.toStringAsFixed(2)}MB, memory: $memoryConversations/$memoryMessages)';
  }
}