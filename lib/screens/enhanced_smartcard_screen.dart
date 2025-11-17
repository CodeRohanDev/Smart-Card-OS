// Enhanced SmartCard Screen with Level 1 & 2 Features
// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/smartcard_service.dart';
import '../services/usb_service.dart';
import '../models/apdu_response.dart';
import '../models/operation_step.dart';

class EnhancedSmartCardScreen extends StatefulWidget {
  final int deviceId;
  final String deviceName;

  const EnhancedSmartCardScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  State<EnhancedSmartCardScreen> createState() => _EnhancedSmartCardScreenState();
}

class _EnhancedSmartCardScreenState extends State<EnhancedSmartCardScreen> with SingleTickerProviderStateMixin {
  final UsbService _usbService = UsbService();
  final SmartCardService _smartCardService = SmartCardService();
  late TabController _tabController;
  
  bool _isCardConnected = false;
  bool _isProcessing = false;
  String? _atr;
  int _selectedProtocol = 1; // Default T=1
  
  // Controllers
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _customApduController = TextEditingController();
  final ScrollController _logScrollController = ScrollController();
  
  // Live log
  final List<Map<String, dynamic>> _liveLog = [];
  bool _showLog = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    // Show protocol dialog after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showProtocolDialog();
    });
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

  Future<void> _connectToDevice() async {
    if (!mounted) return;
    
    setState(() => _isProcessing = true);
    
    try {
      // Request permission
      final hasPermission = await _usbService.requestPermission(widget.deviceId);
      if (!hasPermission) {
        if (mounted) {
          _showMessage('Permission denied', isSuccess: false);
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
        _showMessage('Failed to connect to device', isSuccess: false);
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Connection error: $e', isSuccess: false);
        setState(() => _isProcessing = false);
      }
    }
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
        _showMessage('Card connected with $protocolName protocol!', isSuccess: true);
      } else {
        _showMessage('Failed to connect to card: ${result['error']}', isSuccess: false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showMessage('Card connection error: $e', isSuccess: false);
      }
    }
  }

  void _showMessage(String message, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
      ),
    );
  }

  void _addToLog({
    required String title,
    required String command,
    required ApduResponse response,
  }) {
    setState(() {
      _liveLog.insert(0, {
        'timestamp': DateTime.now(),
        'title': title,
        'command': command,
        'response': response,
      });
      
      // Keep only last 50 entries
      if (_liveLog.length > 50) {
        _liveLog.removeLast();
      }
    });
    
    // Auto-scroll to top
    if (_logScrollController.hasClients) {
      _logScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _clearLog() {
    setState(() {
      _liveLog.clear();
    });
  }

  void _showResponseDialog(ApduResponse response, {String? title, String? commandApdu}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              response.success ? Icons.check_circle : Icons.error,
              color: response.success ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(title ?? 'Response')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Command Sent Section
              if (commandApdu != null) ...[
                Row(
                  children: [
                    const Icon(Icons.arrow_upward, size: 16, color: Color(0xFF6366F1)),
                    const SizedBox(width: 4),
                    const Text(
                      'Command Sent:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        _formatHex(commandApdu),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Color(0xFF6366F1),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${commandApdu.replaceAll(' ', '').length ~/ 2} bytes',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Response Received Section
              Row(
                children: [
                  const Icon(Icons.arrow_downward, size: 16, color: Color(0xFF10B981)),
                  const SizedBox(width: 4),
                  const Text(
                    'Response Received:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              
              // Raw Response
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Raw Response:',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      response.rawResponse,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total: ${response.rawResponse.replaceAll(' ', '').length ~/ 2} bytes',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              
              // Parsed Data Section
              if (response.data != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Data (without status):',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        response.formattedData!,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${response.dataLength} bytes',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              
              // Status Word Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: response.success 
                      ? Colors.green.withOpacity(0.1) 
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: response.success ? Colors.green : Colors.red,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          response.success ? Icons.check_circle_outline : Icons.error_outline,
                          size: 16,
                          color: response.success ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Status Word:',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${response.statusWord} - ${response.statusMessage}',
                      style: TextStyle(
                        color: response.success ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Error Suggestion
              if (response.errorSuggestion != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Suggestion:',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              response.errorSuggestion!,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              // Timing Information
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, size: 14, color: Colors.blue),
                    const SizedBox(width: 6),
                    Text(
                      'Received at: ${response.timestamp.toString().substring(11, 19)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (response.data != null)
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: response.data!));
                _showMessage('Data copied!', isSuccess: true);
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copy Data'),
            ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enhanced Smart Card'),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_showLog ? Icons.visibility_off : Icons.visibility),
            onPressed: () {
              setState(() => _showLog = !_showLog);
            },
            tooltip: _showLog ? 'Hide Log' : 'Show Log',
          ),
          if (_liveLog.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _clearLog,
              tooltip: 'Clear Log',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Basic'),
            Tab(text: 'Security'),
            Tab(text: 'Data'),
            Tab(text: 'Advanced'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: _isCardConnected
          ? Column(
              children: [
                // Main content area
                Expanded(
                  flex: _showLog ? 6 : 10,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBasicTab(),
                      _buildSecurityTab(),
                      _buildDataTab(),
                      _buildAdvancedTab(),
                      _buildHistoryTab(),
                    ],
                  ),
                ),
                // Live log panel
                if (_showLog) ...[
                  const Divider(height: 1, thickness: 2),
                  Expanded(
                    flex: 4,
                    child: _buildLiveLogPanel(),
                  ),
                ],
              ],
            )
          : Center(
              child: _isProcessing
                  ? const CircularProgressIndicator()
                  : const Text('Card not connected'),
            ),
    );
  }

  Widget _buildBasicTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCard(
          title: 'File Selection',
          children: [
            _buildButton('SELECT MF', Icons.folder, () async {
              const commandApdu = '00A40000023F00';
              setState(() => _isProcessing = true);
              final response = await _smartCardService.selectMFStructured();
              setState(() => _isProcessing = false);
              if (response != null) {
                _addToLog(
                  title: 'SELECT MF',
                  command: commandApdu,
                  response: response,
                );
                _showResponseDialog(
                  response,
                  title: 'SELECT MF',
                  commandApdu: commandApdu,
                );
              }
            }),
            const SizedBox(height: 8),
            _buildButton('SELECT DF', Icons.folder_special, () async {
              const commandApdu = '00A40000026F00';
              setState(() => _isProcessing = true);
              final response = await _smartCardService.selectDFStructured();
              setState(() => _isProcessing = false);
              if (response != null) {
                _addToLog(
                  title: 'SELECT DF',
                  command: commandApdu,
                  response: response,
                );
                _showResponseDialog(
                  response,
                  title: 'SELECT DF',
                  commandApdu: commandApdu,
                );
              }
            }),
          ],
        ),
        const SizedBox(height: 16),
        _buildCard(
          title: 'Security Environment',
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildButton('MSE RSA', Icons.security, () async {
                    const commandApdu = '0022F303';
                    setState(() => _isProcessing = true);
                    final response = await _smartCardService.mseRestoreStructured(algorithm: 'rsa');
                    setState(() => _isProcessing = false);
                    if (response != null) {
                      _addToLog(
                        title: 'MSE RESTORE RSA',
                        command: commandApdu,
                        response: response,
                      );
                      _showResponseDialog(
                        response,
                        title: 'MSE RESTORE RSA',
                        commandApdu: commandApdu,
                      );
                    }
                  }),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildButton('MSE ECC', Icons.shield, () async {
                    const commandApdu = '0022F30D';
                    setState(() => _isProcessing = true);
                    final response = await _smartCardService.mseRestoreStructured(algorithm: 'ecc');
                    setState(() => _isProcessing = false);
                    if (response != null) {
                      _addToLog(
                        title: 'MSE RESTORE ECC',
                        command: commandApdu,
                        response: response,
                      );
                      _showResponseDialog(
                        response,
                        title: 'MSE RESTORE ECC',
                        commandApdu: commandApdu,
                      );
                    }
                  }),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildCard(
          title: 'Digital Signature',
          children: [
            _buildButton('PSO Sign (32 bytes)', Icons.draw, () async {
              final data = SmartCardService.generateRandomData32Bytes();
              // APDU: CLA INS P1 P2 Lc Data Le
              // Total: 37 bytes (5 header + 32 data)
              final commandApdu = '002A9E9A20$data 00';
              setState(() => _isProcessing = true);
              final response = await _smartCardService.psoDigitalSignatureStructured(data);
              setState(() => _isProcessing = false);
              if (response != null) {
                _addToLog(
                  title: 'PSO DIGITAL SIGNATURE',
                  command: commandApdu,
                  response: response,
                );
                _showResponseDialog(
                  response,
                  title: 'PSO DIGITAL SIGNATURE',
                  commandApdu: commandApdu,
                );
              }
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildSecurityTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCard(
          title: 'PIN Operations',
          children: [
            TextField(
              controller: _pinController,
              decoration: const InputDecoration(
                labelText: 'PIN',
                hintText: 'Enter PIN',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            _buildButton('Verify PIN', Icons.lock_open, () async {
              if (_pinController.text.isEmpty) {
                _showMessage('Please enter PIN', isSuccess: false);
                return;
              }
              final pin = _pinController.text;
              String hexPin = pin.codeUnits.map((c) => c.toRadixString(16).padLeft(2, '0')).join().toUpperCase().padRight(16, 'F');
              final commandApdu = '002000 0008$hexPin';
              setState(() => _isProcessing = true);
              final response = await _smartCardService.verifyPin(pin);
              setState(() => _isProcessing = false);
              if (response != null) {
                _showResponseDialog(
                  response,
                  title: 'VERIFY PIN',
                  commandApdu: commandApdu,
                );
              }
            }),
          ],
        ),
        const SizedBox(height: 16),
        _buildCard(
          title: 'Authentication',
          children: [
            _buildButton('GET CHALLENGE', Icons.casino, () async {
              setState(() => _isProcessing = true);
              final response = await _smartCardService.getChallenge();
              setState(() => _isProcessing = false);
              if (response != null) {
                _showResponseDialog(
                  response,
                  title: 'GET CHALLENGE',
                  commandApdu: '0084000008',
                );
              }
            }),
            const SizedBox(height: 8),
            _buildButton('INTERNAL AUTHENTICATE', Icons.verified_user, () async {
              // Generate 8-byte challenge
              final challenge = SmartCardService.generateRandomData32Bytes().substring(0, 16);
              final commandApdu = '008800000 8$challenge 00';
              setState(() => _isProcessing = true);
              final response = await _smartCardService.internalAuthenticate(challenge);
              setState(() => _isProcessing = false);
              if (response != null) {
                _showResponseDialog(
                  response,
                  title: 'INTERNAL AUTHENTICATE',
                  commandApdu: commandApdu,
                );
              }
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildDataTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCard(
          title: 'Read Operations',
          children: [
            _buildButton('READ BINARY (256 bytes)', Icons.file_download, () async {
              setState(() => _isProcessing = true);
              final response = await _smartCardService.readBinary(offset: 0, length: 0);
              setState(() => _isProcessing = false);
              if (response != null) {
                _showResponseDialog(
                  response,
                  title: 'READ BINARY',
                  commandApdu: '00B0000000',
                );
              }
            }),
            const SizedBox(height: 8),
            _buildButton('READ RECORD #1', Icons.list_alt, () async {
              setState(() => _isProcessing = true);
              final response = await _smartCardService.readRecord(recordNumber: 1);
              setState(() => _isProcessing = false);
              if (response != null) {
                _showResponseDialog(
                  response,
                  title: 'READ RECORD',
                  commandApdu: '00B2010400',
                );
              }
            }),
          ],
        ),
        const SizedBox(height: 16),
        _buildCard(
          title: 'Card Information',
          children: [
            _buildButton('Get Card Serial Number', Icons.credit_card, () async {
              setState(() => _isProcessing = true);
              final response = await _smartCardService.getCardSerialNumber();
              setState(() => _isProcessing = false);
              if (response != null) {
                _showResponseDialog(
                  response,
                  title: 'Card Serial Number',
                  commandApdu: '00CA005A00',
                );
              }
            }),
            const SizedBox(height: 8),
            _buildButton('Get Cardholder Name', Icons.person, () async {
              setState(() => _isProcessing = true);
              final response = await _smartCardService.getCardholderName();
              setState(() => _isProcessing = false);
              if (response != null) {
                _showResponseDialog(
                  response,
                  title: 'Cardholder Name',
                  commandApdu: '00CA5F2000',
                );
              }
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildAdvancedTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCard(
          title: 'Batch Operations',
          children: [
            _buildButton('Batch Sign (3 blocks)', Icons.batch_prediction, () async {
              final blocks = List.generate(
                3,
                (i) => SmartCardService.generateRandomData32Bytes(),
              );
              
              setState(() => _isProcessing = true);
              final responses = await _smartCardService.batchSign(blocks, algorithm: 'rsa');
              setState(() => _isProcessing = false);
              
              // Show summary
              final successful = responses.where((r) => r.success).length;
              _showMessage(
                'Batch complete: $successful/${responses.length} successful',
                isSuccess: successful == responses.length,
              );
            }),
          ],
        ),
        const SizedBox(height: 16),
        _buildCard(
          title: 'Custom APDU',
          children: [
            TextField(
              controller: _customApduController,
              decoration: const InputDecoration(
                labelText: 'APDU Command',
                hintText: 'e.g., 00A40000023F00',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontFamily: 'monospace'),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 12),
            _buildButton('Send Custom APDU', Icons.send, () async {
              if (_customApduController.text.isEmpty) {
                _showMessage('Please enter APDU command', isSuccess: false);
                return;
              }
              final commandApdu = _customApduController.text;
              setState(() => _isProcessing = true);
              final response = await _smartCardService.transmitApduStructured(
                commandApdu,
                stepName: 'Custom APDU',
              );
              setState(() => _isProcessing = false);
              if (response != null) {
                _showResponseDialog(
                  response,
                  title: 'Custom APDU Response',
                  commandApdu: commandApdu,
                );
              }
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    final history = _smartCardService.operationHistory;
    
    if (history.isEmpty) {
      return const Center(
        child: Text('No operation history yet'),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final operation = history[index];
        return _buildOperationCard(operation);
      },
    );
  }

  Widget _buildOperationCard(OperationLog operation) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Icon(
          operation.success ? Icons.check_circle : Icons.error,
          color: operation.success ? Colors.green : Colors.red,
        ),
        title: Text(operation.name),
        subtitle: Text(
          '${operation.successfulSteps}/${operation.steps.length} steps - ${operation.totalDuration.inMilliseconds}ms',
        ),
        children: operation.steps.map((step) {
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 12,
              backgroundColor: step.isSuccess ? Colors.green : Colors.red,
              child: Text(
                '${step.stepNumber}',
                style: const TextStyle(fontSize: 10, color: Colors.white),
              ),
            ),
            title: Text(step.stepName, style: const TextStyle(fontSize: 13)),
            subtitle: Text(
              '${step.response.statusWord} - ${step.duration.inMilliseconds}ms',
              style: const TextStyle(fontSize: 11),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.info, size: 18),
              onPressed: () => _showResponseDialog(step.response, title: step.stepName),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCard({required String title, required List<Widget> children}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildButton(String label, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: _isProcessing ? null : onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  String _formatHex(String hex) {
    final clean = hex.replaceAll(' ', '').toUpperCase();
    final buffer = StringBuffer();
    for (int i = 0; i < clean.length; i += 2) {
      if (i > 0) buffer.write(' ');
      if (i + 2 <= clean.length) {
        buffer.write(clean.substring(i, i + 2));
      }
    }
    return buffer.toString();
  }

  Widget _buildLiveLogPanel() {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF2D2D2D),
              border: Border(
                bottom: BorderSide(color: Color(0xFF404040), width: 1),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.terminal, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Live Communication Log',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_liveLog.length} entries',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Log entries
          Expanded(
            child: _liveLog.isEmpty
                ? const Center(
                    child: Text(
                      'No communication yet\nCommands and responses will appear here',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _logScrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: _liveLog.length,
                    itemBuilder: (context, index) {
                      final entry = _liveLog[index];
                      return _buildLogEntry(entry);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogEntry(Map<String, dynamic> entry) {
    final timestamp = entry['timestamp'] as DateTime;
    final title = entry['title'] as String;
    final command = entry['command'] as String;
    final response = entry['response'] as ApduResponse;
    
    final timeStr = '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: response.success 
              ? const Color(0xFF10B981).withOpacity(0.3)
              : const Color(0xFFEF4444).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: response.success 
                  ? const Color(0xFF10B981).withOpacity(0.1)
                  : const Color(0xFFEF4444).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  response.success ? Icons.check_circle : Icons.error,
                  size: 14,
                  color: response.success 
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  timeStr,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          // Command
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.arrow_upward,
                  size: 12,
                  color: Color(0xFF6366F1),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: SelectableText(
                    _formatHex(command),
                    style: const TextStyle(
                      color: Color(0xFF6366F1),
                      fontSize: 10,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Response
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.arrow_downward,
                  size: 12,
                  color: Color(0xFF10B981),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        response.rawResponse,
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 10,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${response.statusWord} - ${response.statusMessage}',
                        style: TextStyle(
                          color: response.success 
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pinController.dispose();
    _customApduController.dispose();
    _logScrollController.dispose();
    _smartCardService.disconnectCard();
    _usbService.disconnectDevice();
    super.dispose();
  }
}
