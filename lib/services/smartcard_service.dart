import 'package:flutter/services.dart';

class SmartCardService {
  static const MethodChannel _channel = MethodChannel('com.example.smartcardos/smartcard');

  // Connect to smart card with specified protocol
  Future<Map<String, dynamic>> connectCard({int protocol = 1}) async {
    try {
      final result = await _channel.invokeMethod('connectCard', {
        'protocol': protocol, // 0 = T=0, 1 = T=1, 2 = T=0 or T=1
      });
      return Map<String, dynamic>.from(result);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Send APDU command and get response
  Future<String?> transmitApdu(String apduCommand) async {
    try {
      final String? result = await _channel.invokeMethod('transmitApdu', {
        'command': apduCommand,
      });
      return result;
    } catch (e) {
      print('Error transmitting APDU: $e');
      return null;
    }
  }

  // Get ATR (Answer To Reset)
  Future<String?> getAtr() async {
    try {
      final String? result = await _channel.invokeMethod('getAtr');
      return result;
    } catch (e) {
      print('Error getting ATR: $e');
      return null;
    }
  }

  // Disconnect from card
  Future<bool> disconnectCard() async {
    try {
      final bool result = await _channel.invokeMethod('disconnectCard');
      return result;
    } catch (e) {
      print('Error disconnecting card: $e');
      return false;
    }
  }

  // Common APDU commands
  static const String selectMasterFile = '00A40000023F00';
  static const String getResponse = '00C0000000';
  
  // New smartcard commands
  
  /// Select Master File (MF)
  /// Command: 00 A4 00 00 02 3F 00
  Future<String?> selectMF() async {
    return await transmitApdu('00A40000023F00');
  }
  
  /// Select Dedicated File (DF)
  /// Command: 00 A4 00 00 02 6F 00
  Future<String?> selectDF() async {
    return await transmitApdu('00A40000026F00');
  }
  
  /// MSE Restore - Manage Security Environment Restore
  /// @param algorithm: 'rsa' for RSA (0x03) or 'ecc' for ECC (0x0D)
  /// Command: 00 22 F3 [03|0D]
  Future<String?> mseRestore({required String algorithm}) async {
    final p2 = algorithm.toLowerCase() == 'rsa' ? '03' : '0D';
    return await transmitApdu('0022F3$p2');
  }
  
  /// PSO Digital Signature - Perform Security Operation for Digital Signature
  /// @param data: Random data to be signed (must be 32 bytes / 64 hex chars)
  /// Command: 00 2A 9E 9A [length] [data]
  /// Returns the signature response
  Future<String?> psoDigitalSignature(String data) async {
    // Remove spaces and validate
    final cleanData = data.replaceAll(' ', '').toUpperCase();
    
    // Validate hex format
    if (!RegExp(r'^[0-9A-F]+$').hasMatch(cleanData)) {
      throw ArgumentError('Data must be in hexadecimal format');
    }
    
    // Validate length (32 bytes = 64 hex characters)
    if (cleanData.length != 64) {
      throw ArgumentError('Data must be exactly 32 bytes (64 hex characters), got ${cleanData.length ~/ 2} bytes');
    }
    
    // Calculate length byte (0x20 = 32 in hex)
    final length = '20';
    
    // Build APDU: CLA INS P1 P2 Lc Data
    final apdu = '002A9E9A$length$cleanData';
    
    return await transmitApdu(apdu);
  }
  
  /// Generate random 32-byte data for signing (as hex string)
  static String generateRandomData32Bytes() {
    final random = List.generate(32, (i) => (i * 7 + 13) % 256);
    return random.map((b) => b.toRadixString(16).padLeft(2, '0')).join('').toUpperCase();
  }
  
  // Parse status word
  static String parseStatusWord(String sw) {
    final clean = sw.replaceAll(' ', '').toUpperCase();
    
    // Success
    if (clean == '9000') return '✓ Success';
    if (clean.startsWith('91')) return '✓ Success with ${int.parse(clean.substring(2), radix: 16)} bytes available';
    
    // Warning - State unchanged (62XX)
    if (clean == '6200') return '⚠ No information given';
    if (clean == '6281') return '⚠ Data may be corrupted';
    if (clean == '6282') return '⚠ End of file reached';
    if (clean == '6283') return '⚠ File invalidated';
    if (clean == '6284') return '⚠ FCI not formatted';
    if (clean == '6285') return '⚠ File in termination state';
    
    // Warning - State changed (63XX)
    if (clean == '6300') return '⚠ Verification failed';
    if (clean == '6381') return '⚠ File filled up';
    if (clean.startsWith('63C')) {
      final attempts = int.parse(clean.substring(3), radix: 16);
      return '⚠ $attempts attempts remaining';
    }
    
    // Execution error - Memory (65XX)
    if (clean == '6500') return '✗ Memory error';
    if (clean == '6581') return '✗ Memory failure';
    
    // Wrong length (67XX)
    if (clean == '6700') return '✗ Wrong length';
    
    // Functions in CLA not supported (68XX)
    if (clean == '6800') return '✗ CLA not supported';
    if (clean == '6881') return '✗ Logical channel not supported';
    if (clean == '6882') return '✗ Secure messaging not supported';
    if (clean == '6883') return '✗ Last command expected';
    if (clean == '6884') return '✗ Command chaining not supported';
    
    // Command not allowed (69XX)
    if (clean == '6900') return '✗ Command not allowed';
    if (clean == '6981') return '✗ Incompatible with file structure';
    if (clean == '6982') return '✗ Security status not satisfied';
    if (clean == '6983') return '✗ Authentication blocked';
    if (clean == '6984') return '✗ Referenced data invalidated';
    if (clean == '6985') return '✗ Conditions not satisfied';
    if (clean == '6986') return '✗ No EF selected';
    if (clean == '6987') return '✗ Expected SM data missing';
    if (clean == '6988') return '✗ SM data incorrect';
    
    // Wrong parameters (6AXX)
    if (clean == '6A00') return '✗ Wrong parameters';
    if (clean == '6A80') return '✗ Incorrect data field';
    if (clean == '6A81') return '✗ Function not supported';
    if (clean == '6A82') return '✗ File not found';
    if (clean == '6A83') return '✗ Record not found';
    if (clean == '6A84') return '✗ Not enough memory';
    if (clean == '6A85') return '✗ Lc inconsistent with TLV';
    if (clean == '6A86') return '✗ Incorrect P1-P2';
    if (clean == '6A87') return '✗ Lc inconsistent with P1-P2';
    if (clean == '6A88') return '✗ Referenced data not found';
    if (clean == '6A89') return '✗ File already exists';
    if (clean == '6A8A') return '✗ DF name already exists';
    
    // Wrong P1-P2 (6BXX)
    if (clean == '6B00') return '✗ Wrong P1-P2 parameters';
    
    // Wrong Le (6CXX)
    if (clean.startsWith('6C')) {
      final correctLength = int.parse(clean.substring(2), radix: 16);
      return '✗ Wrong Le (correct: $correctLength)';
    }
    
    // Instruction not supported (6DXX)
    if (clean == '6D00') return '✗ Instruction not supported';
    
    // Class not supported (6EXX)
    if (clean == '6E00') return '✗ Class not supported';
    
    // No diagnosis (6FXX)
    if (clean == '6F00') return '✗ No precise diagnosis';
    
    return 'Status: $sw';
  }
  
  // Get all common APDU commands
  static Map<String, String> get commonCommands => {
    'SELECT MF': '00A40000023F00',
    'SELECT DF': '00A40000026F00',
    'SELECT EF': '00A4020C02',
    'READ BINARY': '00B0000000',
    'UPDATE BINARY': '00D6000000',
    'READ RECORD': '00B2000000',
    'UPDATE RECORD': '00DC000000',
    'GET RESPONSE': '00C0000000',
    'VERIFY PIN': '0020000008',
    'CHANGE PIN': '0024000008',
    'GET CHALLENGE': '0084000008',
    'INTERNAL AUTH': '0088000000',
    'EXTERNAL AUTH': '0082000000',
    'GET DATA': '00CA000000',
    'PUT DATA': '00DA000000',
    'MSE RESTORE RSA': '0022F303',
    'MSE RESTORE ECC': '0022F30D',
  };
}
