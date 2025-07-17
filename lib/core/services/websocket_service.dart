import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';

import '../models/audio_file.dart';
import '../utils/logger.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  static WebSocketService get instance => _instance;

  factory WebSocketService() => _instance;

  WebSocketService._internal() {
    _channel.setMethodCallHandler(_handleMethodCall);
    AppLogger.info('WebSocketService initialized.');
  }

  static const MethodChannel _channel = MethodChannel('com.example.mictest/websocket');
  final StreamController<List<AudioFile>> _audioFilesController = StreamController<List<AudioFile>>.broadcast();
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();

  Stream<List<AudioFile>> get audioFilesStream => _audioFilesController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  void setConnectionStatus(bool status) {
    _isConnected = status;
    if (!_connectionController.isClosed) {
      _connectionController.add(status);
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    AppLogger.info('Received method call from native: ${call.method}');
    switch (call.method) {
      case 'onWebSocketMessage':
        _onWebSocketMessage(call.arguments as String);
        break;
      case 'onWebSocketConnected':
        setConnectionStatus(true);
        break;
      case 'onWebSocketDisconnected':
        setConnectionStatus(false);
        break;
      default:
        AppLogger.warning('Unknown method call: ${call.method}');
    }
  }

  void _onWebSocketMessage(String message) {
    AppLogger.info('Received WebSocket message from native: $message');
    try {
      final Map<String, dynamic> json = jsonDecode(message);
      final String command = json['command'];

      if (command == 'files_list') {
        final List<dynamic> filesData = json['data'];
        final List<AudioFile> files = filesData
            .map((fileData) => AudioFile.fromJson(fileData as Map<String, dynamic>))
            .toList();
        if (!_audioFilesController.isClosed) {
          _audioFilesController.add(files);
          AppLogger.info('Updated audio files list from native WebSocket.');
        }
      } else {
        AppLogger.info('Unhandled WebSocket command from native: $command');
      }
    } catch (e) {
      AppLogger.error('Error processing WebSocket message from native: $message', e);
    }
  }

  Future<void> requestFilesList() async {
    try {
      await _channel.invokeMethod('requestFilesList');
    } catch (e) {
      AppLogger.error('Error requesting files list', e);
    }
  }

  Future<void> requestSDCardScan() async {
    try {
      final request = {
        'command': 'scan_sdcard',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'client_info': 'Flutter-Client-Professional',
        'client_version': '2.0.0'
      };

      await _channel.invokeMethod('sendMessage', {'message': jsonEncode(request)});
      AppLogger.info('SD card scan request sent successfully');
    } catch (e) {
      AppLogger.error('Error sending SD card scan request', e);
      rethrow;
    }
  }

  Future<void> requestStorageInfo() async {
    try {
      final request = {
        'command': 'get_storage_info',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'client_info': 'Flutter-Client-Professional',
        'client_version': '2.0.0'
      };

      await _channel.invokeMethod('sendMessage', {'message': jsonEncode(request)});
      AppLogger.info('Storage info request sent successfully');
    } catch (e) {
      AppLogger.error('Error sending storage info request', e);
      rethrow;
    }
  }

  void dispose() {
    _audioFilesController.close();
    _connectionController.close();
  }
}
