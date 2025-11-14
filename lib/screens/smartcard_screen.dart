import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/usb_service.dart';
import '../services/smartcard_service.dart';

class SmartCardScreen extends StatefulWidget {
  final int deviceId;
  final String deviceName;

  const SmartCardScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  State<SmartCardScreen> createState() => _SmartCardScreenState();
}

class _SmartCardScreenState extends State<SmartCardScreen> {
  final UsbService _usbService = UsbService();
  final SmartCardService _smartCardService = SmartCardService();
  final TextEditingController _commandController = TextEditingController();
  
  bool _isCardConnected = false;
  bool _isProcessing = false;
  String? _atr;
  int _selectedProtocol = 1; // Default T=1
  List<Map<String, String>> _commandHistory = [];

  @override
  void initState() {
    super.initState();
    // Show protocol dialog after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showProtocolDialog();
    });
  }

  Future<void> _connectToDevice() async {
    if (!mounted) return;
    
    setState(() => _isProcessing = true);
    
    try {
      // Request permission
      final hasPermission = await _usbService.requestPermission(widget.deviceId);
      if (!hasPermission) {
        if (mounted) {
          _showMessage('Permission denied');
          setState(() => _isProcessing = false);
        }
        return;
      }

      // Connect to USB device
      final connected = await _usbService.connectDevice(widget.deviceId);
      
      if (!mounted) return;

      if (connected) {
        await _connectToCard();
      } else {
        _showMessage('Failed to connect to device');
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Connection error: $e');
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _showProtocolDialog() async {
    if (!mounted) return;
    
    final protocol = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Select Protocol'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose the communication protocol for your smart card:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            // _buildProtocolOption(
            //   0,
            //   'T=0',
            //   'Byte-oriented',
            //   'Older cards, simpler protocol',
            //   Icons.looks_one_outlined,
            // ),
            const SizedBox(height: 12),
            _buildProtocolOption(
              1,
              'T=1',
              'Block-oriented',
              'Modern cards, error detection',
              Icons.looks_two_outlined,
            ),
            const SizedBox(height: 12),
            _buildProtocolOption(
              2,
              'T=0 | T=1',
              'Auto-detect',
              'Try both protocols',
              Icons.auto_awesome,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Go back to device list
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (protocol != null && mounted) {
      setState(() => _selectedProtocol = protocol);
      await _connectToDevice();
    } else if (mounted) {
      Navigator.pop(context); // Go back if cancelled
    }
  }

  Widget _buildProtocolOption(int value, String title, String subtitle, String description, IconData icon) {
    return InkWell(
      onTap: () => Navigator.pop(context, value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFF6366F1)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _connectToCard() async {
    if (!mounted) return;
    
    try {
      final result = await _smartCardService.connectCard(protocol: _selectedProtocol);
      
      if (!mounted) return;
      
      setState(() {
        _isCardConnected = result['success'] == true;
        _atr = result['atr'];
        _isProcessing = false;
      });

      if (_isCardConnected) {
        final protocolName = _selectedProtocol == 0 ? 'T=0' : _selectedProtocol == 1 ? 'T=1' : 'Auto';
        _showMessage('Card connected with $protocolName protocol!');
        _addToHistory('ATR', _atr ?? 'N/A');
      } else {
        _showMessage('Failed to connect to card: ${result['error']}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showMessage('Card connection error: $e');
      }
    }
  }

  Future<void> _sendCommand() async {
    final command = _commandController.text.trim();
    if (command.isEmpty) {
      _showMessage('Please enter a command');
      return;
    }

    setState(() => _isProcessing = true);
    
    final response = await _smartCardService.transmitApdu(command);
    
    setState(() => _isProcessing = false);

    if (response != null) {
      _addToHistory(command, response);
      _commandController.clear();
    } else {
      _showMessage('Failed to send command');
    }
  }

  void _addToHistory(String command, String response) {
    setState(() {
      _commandHistory.insert(0, {
        'command': command,
        'response': response,
        'time': DateTime.now().toString().substring(11, 19),
      });
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Smart Card Reader'),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 20),
            if (_isCardConnected) ...[
              _buildCommandInput(),
              const SizedBox(height: 20),
              _buildSmartCardOperations(),
              const SizedBox(height: 20),
              _buildHistory(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isCardConnected
              ? [const Color(0xFF10B981), const Color(0xFF34D399)]
              : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (_isCardConnected ? const Color(0xFF10B981) : const Color(0xFF6366F1))
                .withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Icon(
            _isCardConnected ? Icons.credit_card : Icons.credit_card_off,
            size: 48,
            color: Colors.white,
          ),
          const SizedBox(height: 12),
          Text(
            _isCardConnected ? 'Card Connected' : 'Connecting...',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.deviceName,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          if (_atr != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ATR:',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    _atr!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommandInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Send APDU Command',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commandController,
            decoration: InputDecoration(
              hintText: 'e.g., 00A40000023F00',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.code),
            ),
            style: const TextStyle(fontFamily: 'monospace'),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _sendCommand,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(_isProcessing ? 'Sending...' : 'Transmit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartCardOperations() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Smart Card Operations',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16),
          
          // File Selection
          Row(
            children: [
              Expanded(
                child: _buildOperationButton(
                  'Select MF',
                  Icons.folder_outlined,
                  const Color(0xFF6366F1),
                  _selectMasterFile,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOperationButton(
                  'Select DF',
                  Icons.folder_special_outlined,
                  const Color(0xFF8B5CF6),
                  _selectDedicatedFile,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // MSE Restore
          Row(
            children: [
              Expanded(
                child: _buildOperationButton(
                  'MSE RSA',
                  Icons.security,
                  const Color(0xFF10B981),
                  () => _mseRestore('rsa'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOperationButton(
                  'MSE ECC',
                  Icons.shield,
                  const Color(0xFF14B8A6),
                  () => _mseRestore('ecc'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Digital Signature
          SizedBox(
            width: double.infinity,
            child: _buildOperationButton(
              'PSO Digital Signature (32 bytes)',
              Icons.draw,
              const Color(0xFFEF4444),
              _psoDigitalSignature,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: _isProcessing ? null : onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Future<void> _selectMasterFile() async {
    setState(() => _isProcessing = true);
    final response = await _smartCardService.selectMF();
    setState(() => _isProcessing = false);
    
    if (response != null) {
      _addToHistory('SELECT MF (00A40000023F00)', response);
      _showMessage('Master File selected');
    } else {
      _showMessage('Failed to select Master File');
    }
  }

  Future<void> _selectDedicatedFile() async {
    setState(() => _isProcessing = true);
    final response = await _smartCardService.selectDF();
    setState(() => _isProcessing = false);
    
    if (response != null) {
      _addToHistory('SELECT DF (00A40000026F00)', response);
      _showMessage('Dedicated File selected');
    } else {
      _showMessage('Failed to select Dedicated File');
    }
  }

  Future<void> _mseRestore(String algorithm) async {
    setState(() => _isProcessing = true);
    final response = await _smartCardService.mseRestore(algorithm: algorithm);
    setState(() => _isProcessing = false);
    
    if (response != null) {
      final p2 = algorithm.toLowerCase() == 'rsa' ? '03' : '0D';
      _addToHistory('MSE RESTORE ${algorithm.toUpperCase()} (0022F3$p2)', response);
      _showMessage('MSE Restore ${algorithm.toUpperCase()} executed');
    } else {
      _showMessage('Failed to execute MSE Restore');
    }
  }

  Future<void> _psoDigitalSignature() async {
    // Generate random 32-byte data
    final randomData = SmartCardService.generateRandomData32Bytes();
    
    // Show dialog with the data
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PSO Digital Signature'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will sign the following 32-byte random data:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SelectableText(
                _formatHex(randomData),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Length: 32 bytes (64 hex chars)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    setState(() => _isProcessing = true);
    
    try {
      final response = await _smartCardService.psoDigitalSignature(randomData);
      setState(() => _isProcessing = false);
      
      if (response != null) {
        _addToHistory('PSO DIGITAL SIGNATURE\nData: ${_formatHex(randomData)}', response);
        _showMessage('Digital signature completed');
      } else {
        _showMessage('Failed to execute digital signature');
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      _showMessage('Error: $e');
    }
  }

  Widget _buildHistory() {
    if (_commandHistory.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Command History',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 12),
        ..._commandHistory.map((item) => _buildHistoryItem(item)),
      ],
    );
  }

  Widget _buildHistoryItem(Map<String, String> item) {
    final response = item['response']!;
    final parts = _parseResponse(response);
    final hasValidStatus = parts['statusWord'] != 'N/A' && _isValidStatusWord(parts['statusWord']!.replaceAll(' ', ''));
    final isSuccess = parts['statusWord']?.replaceAll(' ', '') == '9000';
    final statusDescription = hasValidStatus 
        ? SmartCardService.parseStatusWord(parts['statusWord']!)
        : 'Response Received';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasValidStatus 
                    ? (isSuccess ? Icons.check_circle : Icons.error_outline)
                    : Icons.info_outline,
                color: hasValidStatus
                    ? (isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444))
                    : const Color(0xFF6366F1),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusDescription,
                  style: TextStyle(
                    fontSize: 13,
                    color: hasValidStatus
                        ? (isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444))
                        : const Color(0xFF6366F1),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                item['time']!,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: response));
                  _showMessage('Response copied');
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Command
          _buildDataRow('Command', item['command']!, const Color(0xFF6366F1)),
          
          // Full Response (always show)
          const SizedBox(height: 12),
          _buildDataRow('Response', response, const Color(0xFF8B5CF6)),
          const SizedBox(height: 4),
          Text(
            '${response.replaceAll(' ', '').length ~/ 2} bytes total',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
          ),
          
          // Status Word interpretation (only if valid ISO status)
          if (hasValidStatus) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                    size: 16,
                    color: isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Status: ${parts['statusWord']} - ${SmartCardService.parseStatusWord(parts['statusWord']!)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String data, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: SelectableText(
            data,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Map<String, String> _parseResponse(String response) {
    final clean = response.replaceAll(' ', '').toUpperCase();
    
    // Response must be at least 4 chars (2 bytes for status word)
    if (clean.length < 4) {
      return {
        'data': _formatHex(clean),
        'dataLength': (clean.length ~/ 2).toString(),
        'statusWord': 'N/A',
      };
    }

    // Check if last 4 chars look like a valid status word
    final lastFourChars = clean.substring(clean.length - 4);
    final isValidStatusWord = _isValidStatusWord(lastFourChars);
    
    String statusWord;
    String data;
    
    if (isValidStatusWord) {
      // Last 4 chars are status word (SW1 SW2)
      statusWord = lastFourChars;
      // Everything before is data
      data = clean.length > 4 ? clean.substring(0, clean.length - 4) : '';
    } else {
      // Entire response is data - show full response
      data = clean;
      statusWord = clean.length >= 4 ? lastFourChars : 'N/A';
    }
    
    // Format data with spaces
    final formattedData = data.isEmpty ? '' : _formatHex(data);
    final formattedStatus = statusWord == 'N/A' ? 'N/A' : _formatHex(statusWord);
    
    return {
      'data': formattedData,
      'dataLength': (data.length ~/ 2).toString(),
      'statusWord': formattedStatus,
    };
  }

  bool _isValidStatusWord(String sw) {
    // Status words typically start with: 6x, 9x, or specific patterns
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

  String _formatHex(String hex) {
    final buffer = StringBuffer();
    for (int i = 0; i < hex.length; i += 2) {
      if (i > 0) buffer.write(' ');
      buffer.write(hex.substring(i, i + 2));
    }
    return buffer.toString();
  }

  @override
  void dispose() {
    _commandController.dispose();
    _smartCardService.disconnectCard();
    _usbService.disconnectDevice();
    super.dispose();
  }
}
