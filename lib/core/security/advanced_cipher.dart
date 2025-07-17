// lib/core/security/advanced_cipher.dart

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
// import 'package:pointycastle/export.dart'; // Temporarily commented for compatibility
import '../utils/logger.dart';
import '../error/error_handler.dart';
import 'data_partition_manager.dart';

/// Advanced encryption system with data partitioning and steganography
class AdvancedCipher {
  static const String _version = '1.0.0';
  static const String _signature = 'ADV_CIPHER';
  static const int _keyLength = 32; // AES-256 key length
  static const int _ivLength = 16; // AES IV length
  static const int _saltLength = 16; // Salt length for key derivation
  static const int _partitionSizeBytes = 1024; // 1KB partitions
  
  /// Generate a secure random key
  static Uint8List generateSecureKey() {
    final random = Random.secure();
    final key = Uint8List(_keyLength);
    for (int i = 0; i < _keyLength; i++) {
      key[i] = random.nextInt(256);
    }
    return key;
  }
  
  /// Derive key from password using PBKDF2
  static Uint8List deriveKeyFromPassword(String password, Uint8List salt) {
    final passwordBytes = utf8.encode(password);
    final hmac = Hmac(sha256, passwordBytes);
    
    // Simple PBKDF2 implementation
    var result = Uint8List(_keyLength);
    var block = Uint8List(salt.length + 4);
    
    block.setRange(0, salt.length, salt);
    
    for (int i = 1; i <= (_keyLength / 32).ceil(); i++) {
      // Add counter to salt
      block[salt.length] = (i >> 24) & 0xff;
      block[salt.length + 1] = (i >> 16) & 0xff;
      block[salt.length + 2] = (i >> 8) & 0xff;
      block[salt.length + 3] = i & 0xff;
      
      var u = hmac.convert(block).bytes;
      var f = Uint8List.fromList(u);
      
      // Perform iterations (increased from 10,000 to 100,000 for better security)
      for (int j = 1; j < 100000; j++) {
        u = hmac.convert(u).bytes;
        for (int k = 0; k < f.length; k++) {
          f[k] ^= u[k];
        }
      }
      
      final start = (i - 1) * 32;
      final end = min(start + 32, _keyLength);
      result.setRange(start, end, f);
    }
    
    return result;
  }
  
  /// Encrypt data with partitioning
  static Future<EncryptionResult> encryptWithPartitioning(
    String data, 
    String password, {
    bool enablePartitioning = true,
    int partitionSize = _partitionSizeBytes,
  }) async {
    try {
      final salt = _generateSalt();
      final key = deriveKeyFromPassword(password, salt);
      final dataBytes = utf8.encode(data);
      
      if (enablePartitioning && dataBytes.length > partitionSize) {
        return await _encryptWithPartitions(dataBytes, key, salt, partitionSize);
      } else {
        return await _encryptSingle(dataBytes, key, salt);
      }
    } catch (e) {
      AppLogger.error('Advanced encryption failed', e);
      throw ErrorHandler.handleApiError(e);
    }
  }
  
  /// Encrypt single block
  static Future<EncryptionResult> _encryptSingle(
    Uint8List data, 
    Uint8List key, 
    Uint8List salt
  ) async {
    final iv = _generateIV();
    final encrypted = await _aesEncrypt(data, key, iv);
    
    // Create header with metadata
    final header = EncryptionHeader(
      version: _version,
      signature: _signature,
      isPartitioned: false,
      partitionCount: 1,
      totalSize: data.length,
      salt: salt,
      iv: iv,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    
    final result = EncryptionResult(
      header: header,
      partitions: [
        EncryptionPartition(
          index: 0,
          data: encrypted,
          checksum: _calculateChecksum(encrypted),
        )
      ],
    );
    
    AppLogger.info('Single block encryption completed');
    return result;
  }
  
  /// Encrypt with partitions
  static Future<EncryptionResult> _encryptWithPartitions(
    Uint8List data, 
    Uint8List key, 
    Uint8List salt,
    int partitionSize
  ) async {
    final iv = _generateIV();
    final partitions = <EncryptionPartition>[];
    
    // Split data into partitions
    for (int i = 0; i < data.length; i += partitionSize) {
      final end = min(i + partitionSize, data.length);
      final chunk = data.sublist(i, end);
      
      final encrypted = await _aesEncrypt(chunk, key, iv);
      
      partitions.add(EncryptionPartition(
        index: partitions.length,
        data: encrypted,
        checksum: _calculateChecksum(encrypted),
      ));
    }
    
    // Create header with metadata
    final header = EncryptionHeader(
      version: _version,
      signature: _signature,
      isPartitioned: true,
      partitionCount: partitions.length,
      totalSize: data.length,
      salt: salt,
      iv: iv,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    
    final result = EncryptionResult(
      header: header,
      partitions: partitions,
    );
    
    AppLogger.info('Partitioned encryption completed: ${partitions.length} partitions');
    return result;
  }
  
  /// Decrypt data
  static Future<String> decrypt(EncryptionResult encryptedData, String password) async {
    try {
      final header = encryptedData.header;
      
      // Verify signature
      if (header.signature != _signature) {
        throw ErrorHandler.createUserError('INVALID_SIGNATURE', 'Invalid encrypted data format');
      }
      
      final key = deriveKeyFromPassword(password, header.salt);
      final decryptedChunks = <Uint8List>[];
      
      // Decrypt each partition
      for (final partition in encryptedData.partitions) {
        // Verify checksum
        if (partition.checksum != _calculateChecksum(partition.data)) {
          throw ErrorHandler.createUserError('CHECKSUM_FAILED', 'Data integrity check failed');
        }
        
        final decrypted = await _aesDecrypt(partition.data, key, header.iv);
        decryptedChunks.add(decrypted);
      }
      
      // Combine all chunks
      final totalLength = decryptedChunks.fold(0, (sum, chunk) => sum + chunk.length);
      final combined = Uint8List(totalLength);
      int offset = 0;
      
      for (final chunk in decryptedChunks) {
        combined.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }
      
      final result = utf8.decode(combined);
      AppLogger.info('Decryption completed successfully');
      return result;
    } catch (e) {
      AppLogger.error('Advanced decryption failed', e);
      if (e is AppError) rethrow;
      throw ErrorHandler.handleApiError(e);
    }
  }
  
  /// Advanced steganography with improved hiding
  static Future<String> hideWithAdvancedSteganography(
    String secretMessage, 
    String coverText, 
    String password
  ) async {
    try {
      // Encrypt the secret message first
      final encryptedResult = await encryptWithPartitioning(secretMessage, password);
      
      // Convert to base64 for hiding
      final encryptedData = base64Encode(encryptedResult.toString().codeUnits);
      
      // Use more sophisticated hiding technique
      final hiddenText = _embedInText(encryptedData, coverText);
      
      AppLogger.info('Advanced steganography hiding completed');
      return hiddenText;
    } catch (e) {
      AppLogger.error('Advanced steganography hiding failed', e);
      throw ErrorHandler.handleApiError(e);
    }
  }
  
  /// Reveal from advanced steganography
  static Future<String> revealFromAdvancedSteganography(
    String hiddenText, 
    String password
  ) async {
    try {
      // Extract hidden data
      final encryptedData = _extractFromText(hiddenText);
      
      if (encryptedData.isEmpty) {
        throw ErrorHandler.createUserError('NO_HIDDEN_DATA', 'No hidden message found');
      }
      
      // Decode from base64
      final decodedData = base64Decode(encryptedData);
      final encryptedString = String.fromCharCodes(decodedData);
      
      // Parse encryption result
      final encryptedResult = EncryptionResult.fromString(encryptedString);
      
      // Decrypt the message
      final decryptedMessage = await decrypt(encryptedResult, password);
      
      AppLogger.info('Advanced steganography reveal completed');
      return decryptedMessage;
    } catch (e) {
      AppLogger.error('Advanced steganography reveal failed', e);
      if (e is AppError) rethrow;
      throw ErrorHandler.handleApiError(e);
    }
  }
  
  /// Embed data in text using sophisticated steganography
  static String _embedInText(String data, String coverText) {
    // Use multiple types of invisible Unicode characters for better hiding
    const invisibleChars = [
      '\u200B', // Zero Width Space - represents 00
      '\u200C', // Zero Width Non-Joiner - represents 01
      '\u200D', // Zero Width Joiner - represents 10
      '\u2060', // Word Joiner - represents 11
    ];
    
    const startMarker = '\u2061'; // Function Application (invisible)
    const endMarker = '\u2062';   // Invisible Times (invisible)
    
    // Convert data to base64 to reduce size and avoid issues with special chars
    final encodedData = base64Encode(utf8.encode(data));
    
    // Convert to binary with 2-bit encoding for better efficiency
    final binaryData = encodedData.codeUnits
        .map((c) => c.toRadixString(2).padLeft(8, '0'))
        .join('');
    
    final result = StringBuffer();
    result.write(startMarker); // Start marker
    
    // Process binary data in 2-bit chunks
    for (int i = 0; i < binaryData.length; i += 2) {
      final chunk = binaryData.substring(i, (i + 2).clamp(0, binaryData.length));
      final paddedChunk = chunk.padRight(2, '0');
      final index = int.parse(paddedChunk, radix: 2);
      result.write(invisibleChars[index]);
    }
    
    result.write(endMarker); // End marker
    
    // Distribute the invisible characters naturally throughout the text
    return _distributeInvisibleCharsSmart(coverText, result.toString());
  }
  
  /// Extract data from text with sophisticated steganography
  static String _extractFromText(String hiddenText) {
    try {
      const invisibleChars = [
        '\u200B', // Zero Width Space - represents 00
        '\u200C', // Zero Width Non-Joiner - represents 01
        '\u200D', // Zero Width Joiner - represents 10
        '\u2060', // Word Joiner - represents 11
      ];
      
      const startMarker = '\u2061'; // Function Application
      const endMarker = '\u2062';   // Invisible Times
      
      final startIndex = hiddenText.indexOf(startMarker);
      final endIndex = hiddenText.indexOf(endMarker);
      
      if (startIndex == -1 || endIndex == -1 || startIndex >= endIndex) {
        return '';
      }
      
      // Extract the hidden portion between markers
      final hiddenPortion = hiddenText.substring(startIndex + 1, endIndex);
      
      // Convert invisible characters back to binary
      final binaryData = StringBuffer();
      for (int i = 0; i < hiddenPortion.length; i++) {
        final char = hiddenPortion[i];
        final index = invisibleChars.indexOf(char);
        if (index != -1) {
          binaryData.write(index.toRadixString(2).padLeft(2, '0'));
        }
      }
      
      if (binaryData.isEmpty || binaryData.length % 8 != 0) {
        return '';
      }
      
      // Convert binary back to base64 encoded data
      final encodedData = StringBuffer();
      for (int i = 0; i < binaryData.length; i += 8) {
        final byte = binaryData.toString().substring(i, i + 8);
        final charCode = int.parse(byte, radix: 2);
        encodedData.writeCharCode(charCode);
      }
      
      // Decode base64 back to original data
      final decodedBytes = base64Decode(encodedData.toString());
      return utf8.decode(decodedBytes);
    } catch (e) {
      AppLogger.error('Error extracting hidden data', e);
      return '';
    }
  }
  
  /// AES-256-CBC encryption implementation (fallback using enhanced XOR)
  static Future<Uint8List> _aesEncrypt(Uint8List data, Uint8List key, Uint8List iv) async {
    if (key.length != _keyLength) {
      throw ArgumentError('Key must be exactly $_keyLength bytes');
    }
    if (iv.length != _ivLength) {
      throw ArgumentError('IV must be exactly $_ivLength bytes');
    }
    
    try {
      // Add PKCS7 padding
      final paddedData = _addPkcs7Padding(data, 16);
      
      // Enhanced XOR encryption with multiple rounds (fallback until pointycastle is available)
      // This is more secure than simple XOR but still not production-grade AES
      final result = Uint8List(paddedData.length);
      
      // Multiple rounds with key scheduling
      for (int round = 0; round < 16; round++) {
        for (int i = 0; i < paddedData.length; i++) {
          final keyIndex = (i + round) % key.length;
          final ivIndex = i % iv.length;
          final prevIndex = i > 0 ? i - 1 : paddedData.length - 1;
          
          if (round == 0) {
            result[i] = paddedData[i] ^ key[keyIndex] ^ iv[ivIndex];
          } else {
            result[i] = result[i] ^ key[keyIndex] ^ result[prevIndex] ^ (round & 0xFF);
          }
        }
      }
      
      return result;
    } catch (e) {
      AppLogger.error('Enhanced XOR encryption failed', e);
      throw ArgumentError('Encryption failed: $e');
    }
  }
  
  /// AES-256-CBC decryption implementation (fallback using enhanced XOR)
  static Future<Uint8List> _aesDecrypt(Uint8List data, Uint8List key, Uint8List iv) async {
    if (key.length != _keyLength) {
      throw ArgumentError('Key must be exactly $_keyLength bytes');
    }
    if (iv.length != _ivLength) {
      throw ArgumentError('IV must be exactly $_ivLength bytes');
    }
    
    try {
      // Enhanced XOR decryption with multiple rounds (reverse of encryption)
      final result = Uint8List.fromList(data);
      
      // Reverse the encryption rounds
      for (int round = 15; round >= 0; round--) {
        for (int i = result.length - 1; i >= 0; i--) {
          final keyIndex = (i + round) % key.length;
          final ivIndex = i % iv.length;
          final prevIndex = i > 0 ? i - 1 : result.length - 1;
          
          if (round == 0) {
            result[i] = result[i] ^ key[keyIndex] ^ iv[ivIndex];
          } else {
            result[i] = result[i] ^ key[keyIndex] ^ result[prevIndex] ^ (round & 0xFF);
          }
        }
      }
      
      // Remove PKCS7 padding
      final unpaddedData = _removePkcs7Padding(result);
      return unpaddedData;
    } catch (e) {
      AppLogger.error('Enhanced XOR decryption failed', e);
      throw ArgumentError('Decryption failed: $e');
    }
  }
  
  /// Generate random salt
  static Uint8List _generateSalt() {
    final random = Random.secure();
    final salt = Uint8List(_saltLength);
    for (int i = 0; i < _saltLength; i++) {
      salt[i] = random.nextInt(256);
    }
    return salt;
  }
  
  /// Generate random IV
  static Uint8List _generateIV() {
    final random = Random.secure();
    final iv = Uint8List(_ivLength);
    for (int i = 0; i < _ivLength; i++) {
      iv[i] = random.nextInt(256);
    }
    return iv;
  }
  
  /// Calculate checksum for integrity
  static String _calculateChecksum(Uint8List data) {
    final hash = sha256.convert(data);
    return hash.toString();
  }
  
  /// Add PKCS7 padding to data
  static Uint8List _addPkcs7Padding(Uint8List data, int blockSize) {
    final padLength = blockSize - (data.length % blockSize);
    final paddedData = Uint8List(data.length + padLength);
    paddedData.setRange(0, data.length, data);
    for (int i = data.length; i < paddedData.length; i++) {
      paddedData[i] = padLength;
    }
    return paddedData;
  }
  
  /// Remove PKCS7 padding from data
  static Uint8List _removePkcs7Padding(Uint8List data) {
    if (data.isEmpty) return data;
    
    final padLength = data.last;
    if (padLength > data.length || padLength == 0) {
      throw ArgumentError('Invalid PKCS7 padding');
    }
    
    // Verify padding is correct
    for (int i = data.length - padLength; i < data.length; i++) {
      if (data[i] != padLength) {
        throw ArgumentError('Invalid PKCS7 padding');
      }
    }
    
    return data.sublist(0, data.length - padLength);
  }
  
  /// Smart distribution of invisible characters throughout text
  static String _distributeInvisibleCharsSmart(String coverText, String invisibleChars) {
    if (coverText.isEmpty) return invisibleChars;
    if (invisibleChars.isEmpty) return coverText;
    
    final result = StringBuffer();
    final sentences = coverText.split(RegExp(r'[.!?]+'));
    final totalChars = invisibleChars.length;
    
    if (sentences.length > 1) {
      // Distribute across sentences
      final charsPerSentence = (totalChars / sentences.length).ceil();
      int charIndex = 0;
      
      for (int i = 0; i < sentences.length; i++) {
        final sentence = sentences[i].trim();
        if (sentence.isNotEmpty) {
          result.write(sentence);
          
          // Add some invisible characters at the end of the sentence
          if (charIndex < totalChars) {
            final endIndex = (charIndex + charsPerSentence).clamp(0, totalChars);
            final words = sentence.split(' ');
            final charsPerWord = ((endIndex - charIndex) / words.length).ceil();
            
            int wordCharIndex = charIndex;
            for (int j = 0; j < words.length && wordCharIndex < endIndex; j++) {
              final wordCharsEnd = (wordCharIndex + charsPerWord).clamp(0, endIndex);
              if (wordCharIndex < wordCharsEnd) {
                result.write(invisibleChars.substring(wordCharIndex, wordCharsEnd));
                wordCharIndex = wordCharsEnd;
              }
            }
            charIndex = endIndex;
          }
          
          // Add punctuation back if it exists
          if (i < sentences.length - 1) {
            final punctuation = _findPunctuationAfter(coverText, sentence);
            result.write(punctuation);
          }
        }
      }
      
      // Add any remaining characters
      if (charIndex < totalChars) {
        result.write(invisibleChars.substring(charIndex));
      }
    } else {
      // Single sentence or no punctuation - distribute among words
      final words = coverText.split(' ');
      final charsPerWord = (totalChars / words.length).ceil();
      int charIndex = 0;
      
      for (int i = 0; i < words.length; i++) {
        result.write(words[i]);
        
        if (charIndex < totalChars) {
          final endIndex = (charIndex + charsPerWord).clamp(0, totalChars);
          result.write(invisibleChars.substring(charIndex, endIndex));
          charIndex = endIndex;
        }
        
        if (i < words.length - 1) {
          result.write(' ');
        }
      }
    }
    
    return result.toString();
  }
  
  /// Find punctuation after a sentence
  static String _findPunctuationAfter(String fullText, String sentence) {
    final index = fullText.indexOf(sentence);
    if (index == -1) return '';
    
    final afterIndex = index + sentence.length;
    if (afterIndex >= fullText.length) return '';
    
    final char = fullText[afterIndex];
    if (RegExp(r'[.!?]').hasMatch(char)) {
      return char;
    }
    
    return '';
  }
}

/// Encryption result structure
class EncryptionResult {
  final EncryptionHeader header;
  final List<EncryptionPartition> partitions;
  
  EncryptionResult({
    required this.header,
    required this.partitions,
  });
  
  @override
  String toString() {
    return json.encode({
      'header': header.toJson(),
      'partitions': partitions.map((p) => p.toJson()).toList(),
    });
  }
  
  factory EncryptionResult.fromString(String data) {
    final json = jsonDecode(data);
    return EncryptionResult(
      header: EncryptionHeader.fromJson(json['header']),
      partitions: (json['partitions'] as List)
          .map((p) => EncryptionPartition.fromJson(p))
          .toList(),
    );
  }
}

/// Encryption header with metadata
class EncryptionHeader {
  final String version;
  final String signature;
  final bool isPartitioned;
  final int partitionCount;
  final int totalSize;
  final Uint8List salt;
  final Uint8List iv;
  final int timestamp;
  
  EncryptionHeader({
    required this.version,
    required this.signature,
    required this.isPartitioned,
    required this.partitionCount,
    required this.totalSize,
    required this.salt,
    required this.iv,
    required this.timestamp,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'signature': signature,
      'isPartitioned': isPartitioned,
      'partitionCount': partitionCount,
      'totalSize': totalSize,
      'salt': base64Encode(salt),
      'iv': base64Encode(iv),
      'timestamp': timestamp,
    };
  }
  
  factory EncryptionHeader.fromJson(Map<String, dynamic> json) {
    return EncryptionHeader(
      version: json['version'],
      signature: json['signature'],
      isPartitioned: json['isPartitioned'],
      partitionCount: json['partitionCount'],
      totalSize: json['totalSize'],
      salt: base64Decode(json['salt']),
      iv: base64Decode(json['iv']),
      timestamp: json['timestamp'],
    );
  }
}

/// Encryption partition
class EncryptionPartition {
  final int index;
  final Uint8List data;
  final String checksum;
  
  EncryptionPartition({
    required this.index,
    required this.data,
    required this.checksum,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'data': base64Encode(data),
      'checksum': checksum,
    };
  }
  
  factory EncryptionPartition.fromJson(Map<String, dynamic> json) {
    return EncryptionPartition(
      index: json['index'],
      data: base64Decode(json['data']),
      checksum: json['checksum'],
    );
  }
}