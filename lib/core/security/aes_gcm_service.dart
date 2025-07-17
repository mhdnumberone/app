// lib/core/security/aes_gcm_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/logger.dart';
import '../error/error_handler.dart';

final aesGcmServiceProvider = Provider((ref) => AesGcmService());

/// Professional AES-GCM encryption service with proper security standards
class AesGcmService {
  final AesGcm _aesGcm = AesGcm.with256bits();
  final _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 100000,
    bits: 256,
  );

  /// Encrypt text with password using AES-GCM
  Future<String> encryptWithPassword(String plainText, String password) async {
    try {
      final salt = SecretKeyData.random(length: 16).bytes;
      final secretKey = await _pbkdf2.deriveKeyFromPassword(
        password: password,
        nonce: salt,
      );
      final iv = SecretKeyData.random(length: 12).bytes;
      final plainBytes = utf8.encode(plainText);
      final secretBox = await _aesGcm.encrypt(
        plainBytes,
        secretKey: secretKey,
        nonce: iv,
      );
      final combined = Uint8List.fromList(
          salt + iv + secretBox.cipherText + secretBox.mac.bytes);
      return base64UrlEncode(combined);
    } catch (e) {
      AppLogger.error('AES-GCM encryption failed', e);
      throw ErrorHandler.createUserError(
        'ENCRYPTION_FAILED',
        'Failed to encrypt data: ${e.toString()}',
      );
    }
  }

  /// Decrypt text with password using AES-GCM
  Future<String> decryptWithPassword(
      String base64CipherText, String password) async {
    try {
      final combined = base64Url.decode(base64CipherText);
      if (combined.length < (16 + 12 + 0 + 16)) {
        throw ErrorHandler.createUserError(
          'INVALID_DATA_FORMAT',
          'Invalid encrypted data format: too short',
        );
      }
      final salt = combined.sublist(0, 16);
      final iv = combined.sublist(16, 16 + 12);
      final cipherText = combined.sublist(16 + 12, combined.length - 16);
      final macBytes = combined.sublist(combined.length - 16);
      final mac = Mac(macBytes);
      final secretKey = await _pbkdf2.deriveKeyFromPassword(
        password: password,
        nonce: salt,
      );
      final secretBox = SecretBox(cipherText, nonce: iv, mac: mac);
      final decryptedBytes = await _aesGcm.decrypt(
        secretBox,
        secretKey: secretKey,
      );
      return utf8.decode(decryptedBytes);
    } on SecretBoxAuthenticationError {
      AppLogger.error('AES-GCM decryption failed: Authentication error');
      throw ErrorHandler.createUserError(
        'DECRYPTION_FAILED',
        'Decryption failed: Wrong password or corrupted data',
      );
    } catch (e) {
      AppLogger.error('AES-GCM decryption failed', e);
      if (e is AppError) rethrow;
      if (e.toString().contains('Authentication failed')) {
        throw ErrorHandler.createUserError(
          'DECRYPTION_FAILED',
          'Decryption failed: Wrong password or corrupted data',
        );
      }
      throw ErrorHandler.createUserError(
        'DECRYPTION_FAILED',
        'Decryption failed: ${e.toString()}',
      );
    }
  }

  /// Encrypt bytes with password using AES-GCM
  Future<Uint8List> encryptBytesWithPassword(
      Uint8List plainBytes, String password) async {
    try {
      final salt = SecretKeyData.random(length: 16).bytes;
      final secretKey = await _pbkdf2.deriveKeyFromPassword(
        password: password,
        nonce: salt,
      );
      final iv = SecretKeyData.random(length: 12).bytes;
      final secretBox = await _aesGcm.encrypt(
        plainBytes,
        secretKey: secretKey,
        nonce: iv,
      );
      final combined = Uint8List.fromList(
          salt + iv + secretBox.cipherText + secretBox.mac.bytes);
      return combined;
    } catch (e) {
      AppLogger.error('AES-GCM byte encryption failed', e);
      throw ErrorHandler.createUserError(
        'ENCRYPTION_FAILED',
        'Failed to encrypt file data: ${e.toString()}',
      );
    }
  }

  /// Decrypt bytes with password using AES-GCM
  Future<Uint8List> decryptBytesWithPassword(
      Uint8List encryptedBytes, String password) async {
    try {
      if (encryptedBytes.length < (16 + 12 + 0 + 16)) {
        throw ErrorHandler.createUserError(
          'INVALID_DATA_FORMAT',
          'Invalid encrypted file format: too short',
        );
      }
      final salt = encryptedBytes.sublist(0, 16);
      final iv = encryptedBytes.sublist(16, 16 + 12);
      final cipherText =
          encryptedBytes.sublist(16 + 12, encryptedBytes.length - 16);
      final macBytes = encryptedBytes.sublist(encryptedBytes.length - 16);
      final mac = Mac(macBytes);
      final secretKey = await _pbkdf2.deriveKeyFromPassword(
        password: password,
        nonce: salt,
      );
      final secretBox = SecretBox(cipherText, nonce: iv, mac: mac);
      final decryptedBytes = await _aesGcm.decrypt(
        secretBox,
        secretKey: secretKey,
      );
      return Uint8List.fromList(decryptedBytes);
    } on SecretBoxAuthenticationError {
      AppLogger.error('AES-GCM byte decryption failed: Authentication error');
      throw ErrorHandler.createUserError(
        'DECRYPTION_FAILED',
        'File decryption failed: Wrong password or corrupted data',
      );
    } catch (e) {
      AppLogger.error('AES-GCM byte decryption failed', e);
      if (e is AppError) rethrow;
      if (e.toString().contains('Authentication failed')) {
        throw ErrorHandler.createUserError(
          'DECRYPTION_FAILED',
          'File decryption failed: Wrong password or corrupted data',
        );
      }
      throw ErrorHandler.createUserError(
        'DECRYPTION_FAILED',
        'File decryption failed: ${e.toString()}',
      );
    }
  }

  /// Generate a secure random password
  String generateSecurePassword({int length = 16}) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()_+-=[]{}|;:,.<>?';
    final random = SecretKeyData.random(length: length);
    return String.fromCharCodes(random.bytes.map((b) => chars.codeUnitAt(b % chars.length)));
  }

  /// Validate password strength
  bool isPasswordStrong(String password) {
    if (password.length < 8) return false;
    if (!RegExp(r'[A-Z]').hasMatch(password)) return false;
    if (!RegExp(r'[a-z]').hasMatch(password)) return false;
    if (!RegExp(r'[0-9]').hasMatch(password)) return false;
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) return false;
    return true;
  }

  /// Get password strength score (0-100)
  int getPasswordStrength(String password) {
    int score = 0;
    
    // Length bonus
    if (password.length >= 8) score += 20;
    if (password.length >= 12) score += 10;
    if (password.length >= 16) score += 10;
    
    // Character type bonuses
    if (RegExp(r'[a-z]').hasMatch(password)) score += 15;
    if (RegExp(r'[A-Z]').hasMatch(password)) score += 15;
    if (RegExp(r'[0-9]').hasMatch(password)) score += 15;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) score += 15;
    
    return score.clamp(0, 100);
  }
}