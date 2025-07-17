// Optimized State Management for Chat
import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import '../../models/message.dart';
import '../../models/chat_user.dart';
import '../../api/apis.dart';

// State Management for Chat Performance
class ChatStateManager extends ChangeNotifier {
  static final Map<String, ChatStateManager> _instances = {};
  
  // Factory constructor to ensure one instance per conversation
  factory ChatStateManager.forUser(ChatUser user) {
    return _instances.putIfAbsent(
      user.id,
      () => ChatStateManager._(user),
    );
  }
  
  ChatStateManager._(this.user);
  
  final ChatUser user;
  
  // Message Lists
  final List<Message> _confirmedMessages = [];
  final List<Message> _pendingMessages = [];
  final List<Message> _failedMessages = [];
  
  // State Variables
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;
  
  // Upload Progress
  final Map<String, double> _uploadProgress = {};
  
  // Stream Subscriptions
  StreamSubscription? _messageSubscription;
  
  // Getters
  List<Message> get confirmedMessages => List.unmodifiable(_confirmedMessages);
  List<Message> get pendingMessages => List.unmodifiable(_pendingMessages);
  List<Message> get failedMessages => List.unmodifiable(_failedMessages);
  
  // Combined messages for UI (pending + confirmed)
  List<Message> get allMessages {
    final combined = <Message>[];
    combined.addAll(_pendingMessages);
    combined.addAll(_confirmedMessages);
    combined.sort((a, b) => b.sent.compareTo(a.sent));
    return combined;
  }
  
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String? get errorMessage => _errorMessage;
  Map<String, double> get uploadProgress => Map.unmodifiable(_uploadProgress);
  
  // Initialize chat
  void initialize() {
    _loadCachedMessages();
    _startListening();
  }
  
  // Load cached messages for instant display
  void _loadCachedMessages() {
    // TODO: Implement local cache loading
    // This provides instant message display on chat entry
  }
  
  // Start listening to real-time updates
  void _startListening() {
    _messageSubscription?.cancel();
    
    _messageSubscription = APIs.getAllMessagesFiltered(user).listen(
      (snapshot) {
        _handleMessagesUpdate(snapshot);
      },
      onError: (error) {
        _handleError(error);
      },
    );
  }
  
  void _handleMessagesUpdate(snapshot) {
    final newMessages = snapshot.docs
        .map<Message>((doc) => Message.fromJson(doc.data()))
        .toList();
    
    _confirmedMessages.clear();
    _confirmedMessages.addAll(newMessages);
    
    // Remove pending messages that are now confirmed
    _pendingMessages.removeWhere((pending) {
      return _confirmedMessages.any((confirmed) => 
        confirmed.msg == pending.msg && 
        confirmed.fromId == pending.fromId &&
        (int.parse(confirmed.sent) - int.parse(pending.sent)).abs() < 5000 // 5 second tolerance
      );
    });
    
    _isLoading = false;
    _hasError = false;
    notifyListeners();
  }
  
  void _handleError(error) {
    _hasError = true;
    _errorMessage = error.toString();
    _isLoading = false;
    notifyListeners();
  }
  
  // OPTIMISTIC MESSAGE SENDING
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    
    // Create optimistic message
    final optimisticMessage = _createOptimisticMessage(text, Type.text);
    
    // Add to pending messages immediately
    _pendingMessages.insert(0, optimisticMessage);
    notifyListeners();
    
    // Send to server
    try {
      if (_confirmedMessages.isEmpty) {
        await APIs.sendFirstMessage(user, text, Type.text);
      } else {
        await APIs.sendMessage(user, text, Type.text);
      }
    } catch (e) {
      // Move to failed messages
      _pendingMessages.removeWhere((msg) => msg.id == optimisticMessage.id);
      _failedMessages.add(optimisticMessage);
      notifyListeners();
      log('Error sending message: $e');
    }
  }
  
  // OPTIMISTIC FILE SENDING
  Future<void> sendFile(String filePath, Type type) async {
    final optimisticMessage = _createOptimisticMessage(filePath, type);
    
    // Add to pending messages immediately
    _pendingMessages.insert(0, optimisticMessage);
    notifyListeners();
    
    // Start upload with progress tracking
    _uploadProgress[optimisticMessage.id] = 0.0;
    notifyListeners();
    
    try {
      // TODO: Implement actual file upload with progress
      await _uploadFileWithProgress(filePath, optimisticMessage.id, type);
    } catch (e) {
      // Move to failed messages
      _pendingMessages.removeWhere((msg) => msg.id == optimisticMessage.id);
      _failedMessages.add(optimisticMessage);
      _uploadProgress.remove(optimisticMessage.id);
      notifyListeners();
      log('Error uploading file: $e');
    }
  }
  
  Future<void> _uploadFileWithProgress(String filePath, String messageId, Type type) async {
    // Simulate upload progress (replace with actual implementation)
    for (int i = 0; i <= 100; i += 10) {
      await Future.delayed(const Duration(milliseconds: 200));
      _uploadProgress[messageId] = i / 100.0;
      notifyListeners();
    }
    
    // Complete upload
    _uploadProgress.remove(messageId);
    
    // Send message with uploaded file URL
    final fileUrl = 'https://example.com/uploaded_file'; // Replace with actual URL
    
    if (_confirmedMessages.isEmpty) {
      await APIs.sendFirstMessage(user, fileUrl, type);
    } else {
      await APIs.sendMessage(user, fileUrl, type);
    }
  }
  
  Message _createOptimisticMessage(String content, Type type) {
    return Message(
      msg: content,
      toId: user.id,
      read: '',
      type: type,
      sent: DateTime.now().millisecondsSinceEpoch.toString(),
      fromId: APIs.me!.id,
      id: 'pending_${DateTime.now().millisecondsSinceEpoch}',
    );
  }
  
  // Retry failed message
  Future<void> retryMessage(Message failedMessage) async {
    _failedMessages.remove(failedMessage);
    _pendingMessages.add(failedMessage);
    notifyListeners();
    
    try {
      if (failedMessage.type == Type.text) {
        await sendMessage(failedMessage.msg);
      } else {
        await sendFile(failedMessage.msg, failedMessage.type);
      }
    } catch (e) {
      _pendingMessages.remove(failedMessage);
      _failedMessages.add(failedMessage);
      notifyListeners();
    }
  }
  
  // Clear all messages
  void clearMessages() {
    _confirmedMessages.clear();
    _pendingMessages.clear();
    _failedMessages.clear();
    _uploadProgress.clear();
    notifyListeners();
  }
  
  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }
  
  // Static method to dispose specific instance
  static void disposeForUser(String userId) {
    _instances[userId]?.dispose();
    _instances.remove(userId);
  }
  
  // Static method to dispose all instances
  static void disposeAll() {
    for (final instance in _instances.values) {
      instance.dispose();
    }
    _instances.clear();
  }
}

// UI State Manager for Chat Components
class ChatUIStateManager extends ChangeNotifier {
  bool _showEmoji = false;
  bool _isRecording = false;
  bool _showAttachments = false;
  
  bool get showEmoji => _showEmoji;
  bool get isRecording => _isRecording;
  bool get showAttachments => _showAttachments;
  
  void toggleEmoji() {
    _showEmoji = !_showEmoji;
    notifyListeners();
  }
  
  void hideEmoji() {
    if (_showEmoji) {
      _showEmoji = false;
      notifyListeners();
    }
  }
  
  void startRecording() {
    _isRecording = true;
    notifyListeners();
  }
  
  void stopRecording() {
    _isRecording = false;
    notifyListeners();
  }
  
  void toggleAttachments() {
    _showAttachments = !_showAttachments;
    notifyListeners();
  }
  
  void hideAttachments() {
    if (_showAttachments) {
      _showAttachments = false;
      notifyListeners();
    }
  }
}