import 'dart:async';
import 'dart:developer';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../utils/logger.dart';

/// Centralized error handling system for the application
class ErrorHandler {
  static final ErrorHandler _instance = ErrorHandler._internal();
  static ErrorHandler get instance => _instance;
  
  factory ErrorHandler() => _instance;
  
  ErrorHandler._internal();
  
  /// Initialize global error handling
  static void initialize() {
    // Handle Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      AppLogger.error('Flutter Framework Error', details.exception);
      _logErrorDetails(details);
      
      // In debug mode, show the red screen
      if (kDebugMode) {
        FlutterError.presentError(details);
      }
    };
    
    // Handle async errors that escape the Flutter framework
    PlatformDispatcher.instance.onError = (error, stack) {
      AppLogger.error('Uncaught Platform Error', error);
      log('Stack trace: $stack');
      return true; // Prevents crash
    };
    
    // Handle zone errors
    runZonedGuarded(() {
      // App initialization would happen here
    }, (error, stack) {
      AppLogger.error('Zone Error', error);
      log('Stack trace: $stack');
    });
    
    AppLogger.info('Global error handling initialized');
  }
  
  /// Log detailed error information
  static void _logErrorDetails(FlutterErrorDetails details) {
    final errorInfo = {
      'error': details.exception.toString(),
      'library': details.library ?? 'Unknown',
      'context': details.context?.toString() ?? 'No context',
      'stack': details.stack?.toString() ?? 'No stack trace',
    };
    
    AppLogger.error('Detailed Error Info', errorInfo);
  }
  
  /// Create a user error with custom message
  static AppError createUserError(String errorCode, String userMessage) {
    return AppError(
      type: ErrorType.validation,
      message: userMessage,
      originalError: errorCode,
    );
  }
  
  /// Handle API errors
  static AppError handleApiError(dynamic error) {
    if (error is AppError) {
      return error;
    }
    
    // Parse different types of API errors
    if (error.toString().contains('SocketException')) {
      return AppError(
        type: ErrorType.network,
        message: 'No internet connection available',
        originalError: error,
      );
    }
    
    if (error.toString().contains('TimeoutException')) {
      return AppError(
        type: ErrorType.timeout,
        message: 'Request timeout. Please try again.',
        originalError: error,
      );
    }
    
    if (error.toString().contains('FormatException')) {
      return AppError(
        type: ErrorType.parsing,
        message: 'Invalid data format received',
        originalError: error,
      );
    }
    
    // Default to unknown error
    return AppError(
      type: ErrorType.unknown,
      message: 'An unexpected error occurred',
      originalError: error,
    );
  }
  
  /// Handle file operation errors
  static AppError handleFileError(dynamic error) {
    if (error.toString().contains('Permission')) {
      return AppError(
        type: ErrorType.permission,
        message: 'Permission denied. Please check app permissions.',
        originalError: error,
      );
    }
    
    if (error.toString().contains('FileSystemException')) {
      return AppError(
        type: ErrorType.fileSystem,
        message: 'File operation failed. Please try again.',
        originalError: error,
      );
    }
    
    return AppError(
      type: ErrorType.fileSystem,
      message: 'File operation error',
      originalError: error,
    );
  }
  
  /// Handle WebSocket errors
  static AppError handleWebSocketError(dynamic error) {
    if (error.toString().contains('Connection')) {
      return AppError(
        type: ErrorType.connection,
        message: 'Connection lost. Attempting to reconnect...',
        originalError: error,
      );
    }
    
    return AppError(
      type: ErrorType.connection,
      message: 'WebSocket communication error',
      originalError: error,
    );
  }
  
  /// Show error to user with appropriate UI
  static void showErrorToUser(BuildContext context, AppError error) {
    final message = _getUserFriendlyMessage(error);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _getErrorColor(error.type),
        action: _getErrorAction(context, error),
        duration: _getErrorDuration(error.type),
      ),
    );
    
    // Log for debugging
    AppLogger.error('Error shown to user: ${error.type}', error.message);
  }
  
  /// Get user-friendly error message
  static String _getUserFriendlyMessage(AppError error) {
    switch (error.type) {
      case ErrorType.network:
        return 'Check your internet connection and try again';
      case ErrorType.timeout:
        return 'Request timed out. Please try again';
      case ErrorType.permission:
        return 'Permission required. Please check app settings';
      case ErrorType.fileSystem:
        return 'File operation failed. Please try again';
      case ErrorType.connection:
        return 'Connection issue. Retrying...';
      case ErrorType.parsing:
        return 'Data format error. Please report this issue';
      case ErrorType.authentication:
        return 'Authentication failed. Please login again';
      case ErrorType.validation:
        return error.message; // Use specific validation message
      case ErrorType.unknown:
      default:
        return 'Something went wrong. Please try again';
    }
  }
  
  /// Get error color based on type
  static Color _getErrorColor(ErrorType type) {
    switch (type) {
      case ErrorType.network:
      case ErrorType.connection:
        return Colors.orange;
      case ErrorType.permission:
      case ErrorType.authentication:
        return Colors.red;
      case ErrorType.timeout:
        return Colors.amber;
      case ErrorType.validation:
        return Colors.blue;
      default:
        return Colors.red;
    }
  }
  
  /// Get error action button if needed
  static SnackBarAction? _getErrorAction(BuildContext context, AppError error) {
    switch (error.type) {
      case ErrorType.permission:
        return SnackBarAction(
          label: 'Settings',
          onPressed: () {
            // Open app settings
            // Could implement platform-specific settings opening
          },
        );
      case ErrorType.network:
        return SnackBarAction(
          label: 'Retry',
          onPressed: () {
            // Could implement retry logic
          },
        );
      default:
        return null;
    }
  }
  
  /// Get error display duration
  static Duration _getErrorDuration(ErrorType type) {
    switch (type) {
      case ErrorType.connection:
        return const Duration(seconds: 2);
      case ErrorType.validation:
        return const Duration(seconds: 4);
      default:
        return const Duration(seconds: 3);
    }
  }
}

/// Custom error class for structured error handling
class AppError {
  final ErrorType type;
  final String message;
  final dynamic originalError;
  final StackTrace? stackTrace;
  final DateTime timestamp;
  
  AppError({
    required this.type,
    required this.message,
    this.originalError,
    this.stackTrace,
  }) : timestamp = DateTime.now();
  
  /// Get user-friendly message
  String get userMessage => message;
  
  @override
  String toString() {
    return 'AppError(type: $type, message: $message, timestamp: $timestamp)';
  }
  
  /// Convert to JSON for logging
  Map<String, dynamic> toJson() {
    return {
      'type': type.toString(),
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'originalError': originalError?.toString(),
    };
  }
}

/// Error types for categorization
enum ErrorType {
  network,
  timeout,
  permission,
  fileSystem,
  connection,
  parsing,
  authentication,
  validation,
  unknown,
}

