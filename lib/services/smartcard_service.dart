import 'package:flutter/services.dart';
import '../models/apdu_response.dart';
import '../models/operation_step.dart';

class SmartCardService {
  static const MethodChannel _channel = MethodChannel('com.example.smartcardos/smartcard');
  
  // Operation logging
  final List<OperationLog> _operationHistory = [];
  OperationLog? _currentOperation;
  final List<OperationStep> _currentSteps = [];

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

  // Send APDU command and get response (legacy - returns raw string)
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

  // Send APDU command and get structured response
  Future<ApduResponse?> transmitApduStructured(String apduCommand, {String? stepName}) async {
    final startTime = DateTime.now();
    
    try {
      final String? result = await _channel.invokeMethod('transmitApdu', {
        'command': apduCommand,
      });
      
      if (result == null) {
        return null;
      }
      
      final response = ApduResponse.parse(result);
      final duration = DateTime.now().difference(startTime);
      
      // Log step if we're in an operation
      if (stepName != null && _currentOperation != null) {
        _currentSteps.add(OperationStep(
          stepNumber: _currentSteps.length + 1,
          stepName: stepName,
          commandApdu: apduCommand,
          response: response,
          duration: duration,
        ));
      }
      
      return response;
    } catch (e) {
      print('Error transmitting APDU: $e');
      return null;
    }
  }

  // Start a new operation log
  void startOperation(String operationName) {
    _currentSteps.clear();
    _currentOperation = OperationLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: operationName,
      steps: [],
      startTime: DateTime.now(),
      success: false,
    );
  }

  // End current operation and save to history
  void endOperation({required bool success}) {
    if (_currentOperation == null) return;
    
    final completedOperation = OperationLog(
      id: _currentOperation!.id,
      name: _currentOperation!.name,
      steps: List.from(_currentSteps),
      startTime: _currentOperation!.startTime,
      endTime: DateTime.now(),
      success: success,
    );
    
    _operationHistory.insert(0, completedOperation);
    _currentOperation = null;
    _currentSteps.clear();
  }

  // Get operation history
  List<OperationLog> get operationHistory => List.unmodifiable(_operationHistory);

  // Clear operation history
  void clearOperationHistory() {
    _operationHistory.clear();
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

  /// Select Master File (MF) - Structured response
  Future<ApduResponse?> selectMFStructured() async {
    return await transmitApduStructured('00A40000023F00', stepName: 'SELECT MF');
  }
  
  /// Select Dedicated File (DF)
  /// Command: 00 A4 00 00 02 6F 00
  Future<String?> selectDF() async {
    return await transmitApdu('00A40000026F00');
  }

  /// Select Dedicated File (DF) - Structured response
  Future<ApduResponse?> selectDFStructured() async {
    return await transmitApduStructured('00A40000026F00', stepName: 'SELECT DF');
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
    
    // Build APDU: CLA INS P1 P2 Lc Data Le
    // 00 2A 9E 9A 20 [32 bytes data] 00
    // Total: 37 bytes (5 header + 32 data)
    final apdu = '002A9E9A$length$cleanData 00';
    
    return await transmitApdu(apdu);
  }
  
  /// Generate random 32-byte data for signing (as hex string)
  static String generateRandomData32Bytes() {
    final random = List.generate(32, (i) => (i * 7 + 13) % 256);
    return random.map((b) => b.toRadixString(16).padLeft(2, '0')).join('').toUpperCase();
  }

  // ============================================================================
  // LEVEL 1 FEATURES
  // ============================================================================

  /// VERIFY PIN - ISO 7816-4 Section 11.6.6
  /// @param pin: PIN string (will be padded to 8 bytes with 0xFF)
  /// @param pinReference: PIN reference number (P2 parameter, default 00)
  /// Command: 00 20 00 [P2] 08 [PIN padded with FF]
  Future<ApduResponse?> verifyPin(String pin, {int pinReference = 0x00}) async {
    // Convert PIN to hex
    String hexPin = pin.codeUnits
        .map((c) => c.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
    
    // Pad to 8 bytes (16 hex chars) with FF
    hexPin = hexPin.padRight(16, 'F');
    
    // Build APDU
    final p2 = pinReference.toRadixString(16).padLeft(2, '0').toUpperCase();
    final apdu = '0020 00$p2 08$hexPin';
    
    return await transmitApduStructured(apdu, stepName: 'VERIFY PIN');
  }

  /// READ BINARY - ISO 7816-4 Section 11.4.2
  /// Read data from current Elementary File
  /// @param offset: Offset in the file (0-32767)
  /// @param length: Number of bytes to read (0-256, 0 means 256)
  /// Command: 00 B0 [offset high] [offset low] [length]
  Future<ApduResponse?> readBinary({int offset = 0, int length = 0}) async {
    if (offset < 0 || offset > 32767) {
      throw ArgumentError('Offset must be between 0 and 32767');
    }
    if (length < 0 || length > 256) {
      throw ArgumentError('Length must be between 0 and 256');
    }
    
    // Split offset into high and low bytes
    final offsetHigh = (offset >> 8) & 0xFF;
    final offsetLow = offset & 0xFF;
    
    final p1 = offsetHigh.toRadixString(16).padLeft(2, '0').toUpperCase();
    final p2 = offsetLow.toRadixString(16).padLeft(2, '0').toUpperCase();
    final le = length.toRadixString(16).padLeft(2, '0').toUpperCase();
    
    final apdu = '00B0$p1$p2$le';
    
    return await transmitApduStructured(apdu, stepName: 'READ BINARY');
  }

  /// GET DATA - ISO 7816-4 Section 11.3.1
  /// Retrieve specific data objects from the card
  /// @param tag: Data object tag (P1-P2)
  /// Common tags:
  ///   - 0x5A: Application PAN (Primary Account Number)
  ///   - 0x5F20: Cardholder name
  ///   - 0x5F24: Application expiration date
  ///   - 0x5F25: Application effective date
  ///   - 0x5F28: Issuer country code
  ///   - 0x9F36: Application Transaction Counter (ATC)
  ///   - 0x9F7F: Card Production Life Cycle
  /// Command: 00 CA [P1] [P2] [Le]
  Future<ApduResponse?> getData(int tag, {int length = 0}) async {
    final p1 = ((tag >> 8) & 0xFF).toRadixString(16).padLeft(2, '0').toUpperCase();
    final p2 = (tag & 0xFF).toRadixString(16).padLeft(2, '0').toUpperCase();
    final le = length.toRadixString(16).padLeft(2, '0').toUpperCase();
    
    final apdu = '00CA$p1$p2$le';
    
    return await transmitApduStructured(apdu, stepName: 'GET DATA');
  }

  /// GET DATA - Card Serial Number
  /// Attempts to read card serial number using common tags
  Future<ApduResponse?> getCardSerialNumber() async {
    // Try common serial number tags
    // 0x5A is most common for card number
    return await getData(0x5A);
  }

  /// GET DATA - Cardholder Name
  Future<ApduResponse?> getCardholderName() async {
    return await getData(0x5F20);
  }

  /// CHANGE REFERENCE DATA (Change PIN) - ISO 7816-4 Section 11.6.7
  /// @param oldPin: Current PIN
  /// @param newPin: New PIN
  /// @param pinReference: PIN reference number (default 00)
  /// Command: 00 24 00 [P2] 10 [old PIN][new PIN]
  Future<ApduResponse?> changePin(String oldPin, String newPin, {int pinReference = 0x00}) async {
    // Convert PINs to hex and pad
    String hexOldPin = oldPin.codeUnits
        .map((c) => c.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase()
        .padRight(16, 'F');
    
    String hexNewPin = newPin.codeUnits
        .map((c) => c.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase()
        .padRight(16, 'F');
    
    final p2 = pinReference.toRadixString(16).padLeft(2, '0').toUpperCase();
    final apdu = '002400$p2 10$hexOldPin$hexNewPin';
    
    return await transmitApduStructured(apdu, stepName: 'CHANGE PIN');
  }

  // ============================================================================
  // LEVEL 2 FEATURES
  // ============================================================================

  /// READ RECORD - ISO 7816-4 Section 11.4.6
  /// Read structured records from current file
  /// @param recordNumber: Record number to read (1-254)
  /// @param mode: Reading mode
  ///   - 0x04: Read record by number (P1 = record number)
  ///   - 0x05: Read last record
  ///   - 0x06: Read next record
  ///   - 0x07: Read previous record
  /// @param length: Expected length (0 means all available)
  /// Command: 00 B2 [record] [mode] [length]
  Future<ApduResponse?> readRecord({
    required int recordNumber,
    int mode = 0x04,
    int length = 0,
  }) async {
    if (recordNumber < 1 || recordNumber > 254) {
      throw ArgumentError('Record number must be between 1 and 254');
    }
    
    final p1 = recordNumber.toRadixString(16).padLeft(2, '0').toUpperCase();
    final p2 = mode.toRadixString(16).padLeft(2, '0').toUpperCase();
    final le = length.toRadixString(16).padLeft(2, '0').toUpperCase();
    
    final apdu = '00B2$p1$p2$le';
    
    return await transmitApduStructured(apdu, stepName: 'READ RECORD $recordNumber');
  }

  /// INTERNAL AUTHENTICATE - ISO 7816-4 Section 11.6.4
  /// Challenge-response authentication with the card
  /// @param challenge: Challenge data (typically 8 bytes)
  /// @param algorithm: Algorithm reference (P2)
  /// Command: 00 88 [algorithm] 00 [Lc] [challenge] [Le]
  Future<ApduResponse?> internalAuthenticate(String challenge, {int algorithm = 0x00}) async {
    final cleanChallenge = challenge.replaceAll(' ', '').toUpperCase();
    
    if (!RegExp(r'^[0-9A-F]+$').hasMatch(cleanChallenge)) {
      throw ArgumentError('Challenge must be in hexadecimal format');
    }
    
    final length = (cleanChallenge.length ~/ 2).toRadixString(16).padLeft(2, '0').toUpperCase();
    final p2 = algorithm.toRadixString(16).padLeft(2, '0').toUpperCase();
    
    final apdu = '0088$p2 00$length$cleanChallenge 00';
    
    return await transmitApduStructured(apdu, stepName: 'INTERNAL AUTHENTICATE');
  }

  /// EXTERNAL AUTHENTICATE - ISO 7816-4 Section 11.6.5
  /// Authenticate to the card
  /// @param authData: Authentication data
  /// @param algorithm: Algorithm reference (P2)
  /// Command: 00 82 [algorithm] 00 [Lc] [auth data]
  Future<ApduResponse?> externalAuthenticate(String authData, {int algorithm = 0x00}) async {
    final cleanData = authData.replaceAll(' ', '').toUpperCase();
    
    if (!RegExp(r'^[0-9A-F]+$').hasMatch(cleanData)) {
      throw ArgumentError('Auth data must be in hexadecimal format');
    }
    
    final length = (cleanData.length ~/ 2).toRadixString(16).padLeft(2, '0').toUpperCase();
    final p2 = algorithm.toRadixString(16).padLeft(2, '0').toUpperCase();
    
    final apdu = '0082$p2 00$length$cleanData';
    
    return await transmitApduStructured(apdu, stepName: 'EXTERNAL AUTHENTICATE');
  }

  /// GET CHALLENGE - ISO 7816-4 Section 11.6.2
  /// Request random challenge from the card
  /// @param length: Length of challenge (typically 8 bytes)
  /// Command: 00 84 00 00 [length]
  Future<ApduResponse?> getChallenge({int length = 8}) async {
    if (length < 1 || length > 256) {
      throw ArgumentError('Length must be between 1 and 256');
    }
    
    final le = length.toRadixString(16).padLeft(2, '0').toUpperCase();
    final apdu = '00840000$le';
    
    return await transmitApduStructured(apdu, stepName: 'GET CHALLENGE');
  }

  /// PSO DECIPHER - ISO 7816-8
  /// Decrypt data using card's private key
  /// @param encryptedData: Encrypted data (hex string)
  /// Command: 00 2A 80 86 [Lc] [encrypted data] [Le]
  Future<ApduResponse?> psoDecipher(String encryptedData) async {
    final cleanData = encryptedData.replaceAll(' ', '').toUpperCase();
    
    if (!RegExp(r'^[0-9A-F]+$').hasMatch(cleanData)) {
      throw ArgumentError('Data must be in hexadecimal format');
    }
    
    final length = (cleanData.length ~/ 2).toRadixString(16).padLeft(2, '0').toUpperCase();
    final apdu = '002A8086$length$cleanData 00';
    
    return await transmitApduStructured(apdu, stepName: 'PSO DECIPHER');
  }

  /// Batch Sign Multiple Data Blocks
  /// Signs multiple data blocks in sequence
  /// @param dataBlocks: List of 32-byte hex strings to sign
  /// @param algorithm: 'rsa' or 'ecc'
  /// Returns list of responses for each signature
  Future<List<ApduResponse>> batchSign(List<String> dataBlocks, {required String algorithm}) async {
    startOperation('Batch Sign ${dataBlocks.length} blocks');
    
    final responses = <ApduResponse>[];
    bool allSuccess = true;
    
    try {
      // Step 1: Select MF
      final selectResponse = await selectMFStructured();
      if (selectResponse == null || !selectResponse.success) {
        allSuccess = false;
        endOperation(success: false);
        return responses;
      }
      
      // Step 2: MSE Restore
      final mseResponse = await mseRestoreStructured(algorithm: algorithm);
      if (mseResponse == null || !mseResponse.success) {
        allSuccess = false;
        endOperation(success: false);
        return responses;
      }
      
      // Step 3: Sign each block
      for (int i = 0; i < dataBlocks.length; i++) {
        final response = await psoDigitalSignatureStructured(dataBlocks[i]);
        if (response != null) {
          responses.add(response);
          if (!response.success) {
            allSuccess = false;
          }
        } else {
          allSuccess = false;
          break;
        }
      }
      
      endOperation(success: allSuccess);
      return responses;
    } catch (e) {
      endOperation(success: false);
      rethrow;
    }
  }

  /// MSE Restore - Structured response
  Future<ApduResponse?> mseRestoreStructured({required String algorithm}) async {
    final p2 = algorithm.toLowerCase() == 'rsa' ? '03' : '0D';
    return await transmitApduStructured('0022F3$p2', stepName: 'MSE RESTORE ${algorithm.toUpperCase()}');
  }

  /// PSO Digital Signature - Structured response
  Future<ApduResponse?> psoDigitalSignatureStructured(String data) async {
    final cleanData = data.replaceAll(' ', '').toUpperCase();
    
    if (!RegExp(r'^[0-9A-F]+$').hasMatch(cleanData)) {
      throw ArgumentError('Data must be in hexadecimal format');
    }
    
    if (cleanData.length != 64) {
      throw ArgumentError('Data must be exactly 32 bytes (64 hex characters)');
    }
    
    // Build APDU: CLA INS P1 P2 Lc Data Le
    // 00 2A 9E 9A 20 [32 bytes data] 00
    // Total: 37 bytes (5 header + 32 data)
    final apdu = '002A9E9A20$cleanData 00';
    
    final response = await transmitApduStructured(apdu, stepName: 'PSO SIGN');
    
    if (response == null) return null;
    
    // Handle GET RESPONSE if card indicates more data (61 XX)
    if (response.hasMoreData) {
      final length = response.availableDataLength!.toRadixString(16).padLeft(2, '0').toUpperCase();
      print('Card returned 61 ${length} - Sending GET RESPONSE for $length bytes');
      return await transmitApduStructured('00C00000$length', stepName: 'GET RESPONSE');
    }
    
    // If success (90 00) but no data, try GET RESPONSE with max length
    // Some cards return 90 00 and expect GET RESPONSE to retrieve signature
    if (response.success && (response.data == null || response.data!.isEmpty)) {
      print('Success with no data - Trying GET RESPONSE for signature data');
      
      // Try different lengths for GET RESPONSE
      // RSA-2048 signature = 256 bytes = 0x00 (means 256)
      // RSA-1024 signature = 128 bytes = 0x80
      final lengths = ['00', 'FF', '80']; // Try 256, 255, 128 bytes
      
      for (final length in lengths) {
        print('Trying GET RESPONSE with Le=$length');
        final getResponse = await transmitApduStructured('00C00000$length', stepName: 'GET RESPONSE');
        
        if (getResponse != null && getResponse.data != null && getResponse.data!.isNotEmpty) {
          print('Got signature data: ${getResponse.dataLength} bytes');
          return getResponse;
        }
        
        // If we get an error other than "wrong length", stop trying
        if (getResponse != null && !getResponse.success && !getResponse.statusWord.startsWith('6C')) {
          print('GET RESPONSE failed with: ${getResponse.statusWord}');
          break;
        }
        
        // If card says "wrong length" (6C XX), try the suggested length
        if (getResponse != null && getResponse.statusWord.startsWith('6C')) {
          final correctLength = getResponse.statusWord.substring(3, 5);
          print('Card suggests length: $correctLength');
          final retryResponse = await transmitApduStructured('00C00000$correctLength', stepName: 'GET RESPONSE');
          if (retryResponse != null && retryResponse.data != null) {
            return retryResponse;
          }
        }
      }
      
      // If all GET RESPONSE attempts failed, return original response
      print('All GET RESPONSE attempts failed, returning original response');
    }
    
    return response;
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
