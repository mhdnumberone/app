// lib/core/security/simple_cipher.dart

import 'dart:developer';

/// A simple Caesar cipher for demonstration purposes.
/// NOT for real-world security.
class SimpleCipher {
  static const int _defaultShift = 3; // Default shift for Caesar cipher

  /// Encrypts a message using a Caesar cipher.
  static String encrypt(String text, {int shift = _defaultShift}) {
    return text.runes.map((rune) {
      if (rune >= 'a'.codeUnitAt(0) && rune <= 'z'.codeUnitAt(0)) {
        return String.fromCharCode(((rune - 'a'.codeUnitAt(0) + shift) % 26) + 'a'.codeUnitAt(0));
      } else if (rune >= 'A'.codeUnitAt(0) && rune <= 'Z'.codeUnitAt(0)) {
        return String.fromCharCode(((rune - 'A'.codeUnitAt(0) + shift) % 26) + 'A'.codeUnitAt(0));
      }
      return String.fromCharCode(rune); // Keep non-alphabetic characters as is
    }).join();
  }

  /// Decrypts a message encrypted with a Caesar cipher.
  static String decrypt(String text, {int shift = _defaultShift}) {
    return encrypt(text, shift: -shift); // Decrypt by shifting in the opposite direction
  }

  /// Hides a secret message within a cover text using invisible characters.
  /// The encrypted secret is embedded using zero-width characters.
  static String hide(String secretMessage, String coverText, {int shift = _defaultShift}) {
    if (secretMessage.isEmpty) {
      return coverText;
    }
    
    final encryptedSecret = encrypt(secretMessage, shift: shift);
    
    // Convert encrypted message to binary representation
    final binaryData = encryptedSecret.codeUnits
        .map((c) => c.toRadixString(2).padLeft(8, '0'))
        .join('');
    
    // Use invisible Unicode characters for steganography
    const zeroWidthSpace = '\u200B';      // Represents '1'
    const zeroWidthNonJoiner = '\u200C';  // Represents '0'
    const wordJoiner = '\u2060';          // Start marker
    const invisibleSeparator = '\u2062';  // End marker
    
    final result = StringBuffer();
    result.write(wordJoiner); // Start marker
    
    // Embed binary data as invisible characters
    for (int i = 0; i < binaryData.length; i++) {
      if (binaryData[i] == '1') {
        result.write(zeroWidthSpace);
      } else {
        result.write(zeroWidthNonJoiner);
      }
    }
    
    result.write(invisibleSeparator); // End marker
    
    // Distribute invisible characters throughout the cover text
    return _distributeInvisibleChars(coverText, result.toString());
  }

  /// Reveals a secret message from a text containing a hidden message.
  static String reveal(String hiddenText, {int shift = _defaultShift}) {
    try {
      // Extract invisible characters representing the hidden message
      const zeroWidthSpace = '\u200B';      // Represents '1'
      const zeroWidthNonJoiner = '\u200C';  // Represents '0'
      const wordJoiner = '\u2060';          // Start marker
      const invisibleSeparator = '\u2062';  // End marker
      
      final startIndex = hiddenText.indexOf(wordJoiner);
      final endIndex = hiddenText.indexOf(invisibleSeparator);
      
      if (startIndex == -1 || endIndex == -1 || startIndex >= endIndex) {
        log('No secret message markers found or invalid format.');
        return ''; // No secret found
      }
      
      // Extract the hidden portion
      final hiddenPortion = hiddenText.substring(startIndex + 1, endIndex);
      
      // Convert invisible characters back to binary
      final binaryData = StringBuffer();
      for (int i = 0; i < hiddenPortion.length; i++) {
        final char = hiddenPortion[i];
        if (char == zeroWidthSpace) {
          binaryData.write('1');
        } else if (char == zeroWidthNonJoiner) {
          binaryData.write('0');
        }
      }
      
      if (binaryData.isEmpty || binaryData.length % 8 != 0) {
        log('Invalid binary data extracted.');
        return '';
      }
      
      // Convert binary back to encrypted text
      final encryptedSecret = StringBuffer();
      for (int i = 0; i < binaryData.length; i += 8) {
        final byte = binaryData.toString().substring(i, i + 8);
        final charCode = int.parse(byte, radix: 2);
        encryptedSecret.writeCharCode(charCode);
      }
      
      // Decrypt the secret message
      return decrypt(encryptedSecret.toString(), shift: shift);
    } catch (e) {
      log('Error revealing secret message: $e');
      return '';
    }
  }
  
  /// Distributes invisible characters throughout the cover text naturally
  static String _distributeInvisibleChars(String coverText, String invisibleChars) {
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
