/// APDU Response Model
/// Represents a structured response from a smartcard APDU command
class ApduResponse {
  /// Response data (without status word)
  final String? data;
  
  /// Status word (SW1-SW2)
  final String statusWord;
  
  /// Human-readable status message
  final String statusMessage;
  
  /// Whether the operation was successful (9000 or 61XX)
  final bool success;
  
  /// Full raw response (data + status word)
  final String rawResponse;
  
  /// Timestamp when response was received
  final DateTime timestamp;
  
  /// Data length in bytes
  final int dataLength;
  
  /// Whether more data is available (61XX)
  final bool hasMoreData;
  
  /// Available data length if hasMoreData is true
  final int? availableDataLength;

  ApduResponse({
    this.data,
    required this.statusWord,
    required this.statusMessage,
    required this.success,
    required this.rawResponse,
    required this.timestamp,
    required this.dataLength,
    required this.hasMoreData,
    this.availableDataLength,
  });

  /// Parse raw APDU response string into structured ApduResponse
  factory ApduResponse.parse(String rawResponse) {
    final clean = rawResponse.replaceAll(' ', '').toUpperCase();
    final timestamp = DateTime.now();
    
    // Response must be at least 4 chars (2 bytes for status word)
    if (clean.length < 4) {
      return ApduResponse(
        data: clean.isEmpty ? null : clean,
        statusWord: 'N/A',
        statusMessage: 'Invalid response',
        success: false,
        rawResponse: rawResponse,
        timestamp: timestamp,
        dataLength: clean.length ~/ 2,
        hasMoreData: false,
      );
    }

    // Extract status word (last 4 chars = 2 bytes)
    final statusWord = clean.substring(clean.length - 4);
    final data = clean.length > 4 ? clean.substring(0, clean.length - 4) : null;
    
    // Check if status word is valid
    final isValidStatus = _isValidStatusWord(statusWord);
    
    if (!isValidStatus) {
      // Entire response might be data
      return ApduResponse(
        data: clean,
        statusWord: 'N/A',
        statusMessage: 'No status word detected',
        success: false,
        rawResponse: rawResponse,
        timestamp: timestamp,
        dataLength: clean.length ~/ 2,
        hasMoreData: false,
      );
    }
    
    // Parse status word
    final sw1 = statusWord.substring(0, 2);
    final sw2 = statusWord.substring(2, 4);
    
    // Check success
    final isSuccess = statusWord == '9000' || sw1 == '61' || sw1 == '91';
    
    // Check if more data available
    final hasMoreData = sw1 == '61';
    final availableDataLength = hasMoreData ? int.parse(sw2, radix: 16) : null;
    
    // Get status message
    final statusMessage = _getStatusMessage(statusWord);
    
    return ApduResponse(
      data: data,
      statusWord: _formatHex(statusWord),
      statusMessage: statusMessage,
      success: isSuccess,
      rawResponse: rawResponse,
      timestamp: timestamp,
      dataLength: data?.length ?? 0 ~/ 2,
      hasMoreData: hasMoreData,
      availableDataLength: availableDataLength,
    );
  }

  /// Check if string is a valid status word
  static bool _isValidStatusWord(String sw) {
    if (sw.length != 4) return false;
    
    final firstByte = sw.substring(0, 2);
    
    // Common status word patterns
    final validPrefixes = [
      '90', '91', // Success
      '61', '62', '63', // Warnings
      '64', '65', '66', '67', '68', '69', // Errors
      '6A', '6B', '6C', '6D', '6E', '6F', // Errors
      '92', '94', '98', // Application specific
    ];
    
    return validPrefixes.contains(firstByte);
  }

  /// Get human-readable status message
  static String _getStatusMessage(String sw) {
    final clean = sw.replaceAll(' ', '').toUpperCase();
    
    // Success
    if (clean == '9000') return '✓ Success';
    if (clean.startsWith('91')) return '✓ Success with ${int.parse(clean.substring(2), radix: 16)} bytes available';
    if (clean.startsWith('61')) return '✓ Success - ${int.parse(clean.substring(2), radix: 16)} bytes available';
    
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

  /// Format hex string with spaces
  static String _formatHex(String hex) {
    final buffer = StringBuffer();
    for (int i = 0; i < hex.length; i += 2) {
      if (i > 0) buffer.write(' ');
      if (i + 2 <= hex.length) {
        buffer.write(hex.substring(i, i + 2));
      }
    }
    return buffer.toString();
  }

  /// Get formatted data with spaces
  String? get formattedData => data != null ? _formatHex(data!) : null;

  /// Get error suggestion based on status word
  String? get errorSuggestion {
    final clean = statusWord.replaceAll(' ', '');
    
    if (clean == '6982') {
      return 'You need to verify PIN first. Tap "Verify PIN" button.';
    }
    if (clean == '6983') {
      return 'PIN is blocked. You need to unblock it with PUK or reset the card.';
    }
    if (clean == '6985') {
      return 'Check the command sequence. Some commands must be executed in order.';
    }
    if (clean == '6A82') {
      return 'The file you\'re trying to access doesn\'t exist. Check file selection.';
    }
    if (clean == '6A86') {
      return 'The P1-P2 parameters are incorrect. Check the command format.';
    }
    if (clean == '6A88') {
      return 'The key or PIN reference doesn\'t exist. Select the correct file first.';
    }
    if (clean == '6700') {
      return 'The Lc or Le field is wrong. Check the data length.';
    }
    if (clean.startsWith('6C')) {
      final correctLength = int.parse(clean.substring(2), radix: 16);
      return 'Resend the command with Le=$correctLength';
    }
    if (clean.startsWith('63C')) {
      final attempts = int.parse(clean.substring(3), radix: 16);
      return 'You have $attempts attempts remaining before PIN is blocked.';
    }
    
    return null;
  }

  @override
  String toString() {
    return 'ApduResponse(status: $statusWord, success: $success, data: ${data?.substring(0, data!.length > 20 ? 20 : data!.length)}...)';
  }
}
