// lib/core/security/zero_width_service.dart
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/logger.dart';
import '../error/error_handler.dart';

final zeroWidthServiceProvider = Provider((ref) => ZeroWidthService());

/// Steganography service using zero-width characters for hiding messages
class ZeroWidthService {
  // Zero-width characters for encoding
  static const String _zeroWidthSpace = '\u200B';      // ZWSP - represents 0
  static const String _zeroWidthNonJoiner = '\u200C';  // ZWNJ - represents 1
  static const String _startMarker = '\u2060';         // Word Joiner - start marker
  static const String _endMarker = '\u2062';           // Invisible Times - end marker

  /// Encode a string into zero-width characters
  String encode(String input) {
    try {
      if (input.isEmpty) return '';
      
      final bytes = utf8.encode(input);
      final buffer = StringBuffer();
      
      for (var byte in bytes) {
        for (int i = 7; i >= 0; i--) {
          // Use ZWNJ for 1 and ZWSP for 0
          buffer.write(((byte >> i) & 1) == 1 ? _zeroWidthNonJoiner : _zeroWidthSpace);
        }
      }
      
      AppLogger.info('Zero-width encoding completed for ${input.length} characters');
      return buffer.toString();
    } catch (e) {
      AppLogger.error('Zero-width encoding failed', e);
      throw ErrorHandler.createUserError(
        'ENCODING_FAILED',
        'Failed to encode message: ${e.toString()}',
      );
    }
  }

  /// Decode a string containing zero-width characters back to the original string
  String decode(String input) {
    try {
      // Filter only the relevant zero-width characters
      final zeroWidthRunes = input.runes
          .where((r) => r == _zeroWidthSpace.codeUnitAt(0) || r == _zeroWidthNonJoiner.codeUnitAt(0))
          .toList();

      // Check if the number of bits is a multiple of 8
      if (zeroWidthRunes.isEmpty || zeroWidthRunes.length % 8 != 0) {
        throw ErrorHandler.createUserError(
          'NO_HIDDEN_MESSAGE',
          'No hidden message found or data is corrupted',
        );
      }

      List<int> bytes = [];
      for (int i = 0; i < zeroWidthRunes.length; i += 8) {
        int currentByte = 0;
        for (int j = 0; j < 8; j++) {
          if (zeroWidthRunes[i + j] == _zeroWidthNonJoiner.codeUnitAt(0)) {
            currentByte |= (1 << (7 - j));
          }
        }
        bytes.add(currentByte);
      }
      
      final result = utf8.decode(bytes, allowMalformed: false);
      AppLogger.info('Zero-width decoding completed');
      return result;
    } on FormatException catch (e) {
      AppLogger.error('Zero-width decoding format error', e);
      throw ErrorHandler.createUserError(
        'DECODING_FAILED',
        'Failed to decode hidden message: Invalid character sequence',
      );
    } catch (e) {
      AppLogger.error('Zero-width decoding failed', e);
      if (e is AppError) rethrow;
      throw ErrorHandler.createUserError(
        'DECODING_FAILED',
        'Failed to decode hidden message: ${e.toString()}',
      );
    }
  }

  /// Hide a secret message within a cover text using zero-width characters
  String hideInCoverText(String coverText, String secretMessage) {
    try {
      if (secretMessage.isEmpty) return coverText;
      
      final encodedMessage = encode(secretMessage);
      final hiddenMessage = _startMarker + encodedMessage + _endMarker;
      
      // Distribute the hidden message naturally throughout the cover text
      final result = _distributeInvisibleChars(coverText, hiddenMessage);
      
      AppLogger.info('Message hidden in cover text successfully');
      return result;
    } catch (e) {
      AppLogger.error('Failed to hide message in cover text', e);
      if (e is AppError) rethrow;
      throw ErrorHandler.createUserError(
        'HIDING_FAILED',
        'Failed to hide message: ${e.toString()}',
      );
    }
  }

  /// Extract a hidden message from text containing zero-width characters
  String extractFromText(String combinedText) {
    try {
      final startIndex = combinedText.indexOf(_startMarker);
      final endIndex = combinedText.indexOf(_endMarker);
      
      if (startIndex == -1 || endIndex == -1 || startIndex >= endIndex) {
        throw ErrorHandler.createUserError(
          'NO_HIDDEN_MESSAGE',
          'No hidden message found in the text',
        );
      }
      
      // Extract the hidden portion between markers
      final hiddenPortion = combinedText.substring(startIndex + 1, endIndex);
      
      final result = decode(hiddenPortion);
      AppLogger.info('Hidden message extracted successfully');
      return result;
    } catch (e) {
      AppLogger.error('Failed to extract hidden message', e);
      if (e is AppError) rethrow;
      throw ErrorHandler.createUserError(
        'EXTRACTION_FAILED',
        'Failed to extract hidden message: ${e.toString()}',
      );
    }
  }

  /// Check if text contains hidden message
  bool hasHiddenMessage(String text) {
    final startIndex = text.indexOf(_startMarker);
    final endIndex = text.indexOf(_endMarker);
    return startIndex != -1 && endIndex != -1 && startIndex < endIndex;
  }

  /// Get statistics about hidden message
  Map<String, dynamic> getHiddenMessageStats(String text) {
    try {
      final startIndex = text.indexOf(_startMarker);
      final endIndex = text.indexOf(_endMarker);
      
      if (startIndex == -1 || endIndex == -1 || startIndex >= endIndex) {
        return {
          'hasHiddenMessage': false,
          'hiddenLength': 0,
          'coverLength': text.length,
          'ratio': 0.0,
        };
      }
      
      final hiddenPortion = text.substring(startIndex + 1, endIndex);
      final zeroWidthCount = hiddenPortion.runes
          .where((r) => r == _zeroWidthSpace.codeUnitAt(0) || r == _zeroWidthNonJoiner.codeUnitAt(0))
          .length;
      
      final estimatedMessageLength = zeroWidthCount ~/ 8;
      final ratio = hiddenPortion.length / text.length;
      
      return {
        'hasHiddenMessage': true,
        'hiddenLength': estimatedMessageLength,
        'coverLength': text.length,
        'ratio': ratio,
        'zeroWidthCharCount': zeroWidthCount,
      };
    } catch (e) {
      AppLogger.error('Failed to get hidden message stats', e);
      return {
        'hasHiddenMessage': false,
        'hiddenLength': 0,
        'coverLength': text.length,
        'ratio': 0.0,
        'error': e.toString(),
      };
    }
  }

  /// Distribute invisible characters throughout the cover text naturally
  String _distributeInvisibleChars(String coverText, String invisibleChars) {
    if (coverText.isEmpty) return invisibleChars;
    if (invisibleChars.isEmpty) return coverText;
    
    final result = StringBuffer();
    final words = coverText.split(' ');
    final charsPerWord = (invisibleChars.length / words.length).ceil();
    
    int charIndex = 0;
    for (int i = 0; i < words.length; i++) {
      result.write(words[i]);
      
      // Add invisible characters after each word
      if (charIndex < invisibleChars.length) {
        final endIndex = (charIndex + charsPerWord).clamp(0, invisibleChars.length);
        result.write(invisibleChars.substring(charIndex, endIndex));
        charIndex = endIndex;
      }
      
      // Add space between words (except for the last word)
      if (i < words.length - 1) {
        result.write(' ');
      }
    }
    
    // Add any remaining invisible characters at the end
    if (charIndex < invisibleChars.length) {
      result.write(invisibleChars.substring(charIndex));
    }
    
    return result.toString();
  }
}