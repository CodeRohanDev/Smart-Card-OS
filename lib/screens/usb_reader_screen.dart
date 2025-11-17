import 'package:flutter/material.dart';
import 'package:smartcardos/screens/enhanced_smartcard_screen.dart';
import '../services/usb_service.dart';
import 'smartcard_screen.dart';

class UsbReaderScreen extends StatefulWidget {
  const UsbReaderScreen({super.key});

  @override
  State<UsbReaderScreen> createState() => _UsbReaderScreenState();
}

class _UsbReaderScreenState extends State<UsbReaderScreen> {
  final UsbService _usbService = UsbService();
  
  bool _isUsbSupported = false;
  bool _isConnected = false;
  bool _isReading = false;
  String? _tokenData;
  List<Map<String, dynamic>> _devices = [];
  String _statusMessage = 'Checking USB support...';

  @override
  void initState() {
    super.initState();
    _checkUsbSupport();
    _listenToUsbEvents();
  }

  Future<void> _checkUsbSupport() async {
    final supported = await _usbService.isUsbSupported();
    setState(() {
      _isUsbSupported = supported;
      _statusMessage = supported 
          ? 'USB OTG supported. Connect your dongle.' 
          : 'USB OTG not supported on this device';
    });
    if (supported) {
      _scanDevices();
    }
  }

  Future<void> _scanDevices() async {
    setState(() => _statusMessage = 'Scanning for devices...');
    final devices = await _usbService.getConnectedDevices();
    setState(() {
      _devices = devices;
      _statusMessage = devices.isEmpty 
          ? 'No USB devices found. Please connect your dongle.' 
          : '${devices.length} device(s) found';
    });
  }

  void _openSmartCardScreen(int deviceId, String deviceName) {
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => SmartCardScreen(
    //       deviceId: deviceId,
    //       deviceName: deviceName,
    //     ),
    //   ),
    // );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedSmartCardScreen(
          deviceId: deviceId,
          deviceName: deviceName,
        ),
      ),
    );
  }

  Future<void> _readToken() async {
    if (!_isConnected) {
      _showSnackBar('Please connect to a device first');
      return;
    }

    setState(() {
      _isReading = true;
      _statusMessage = 'Reading token from dongle...';
    });

    final token = await _usbService.readToken();
    
    setState(() {
      _isReading = false;
      if (token != null && token.isNotEmpty) {
        _tokenData = token;
        _statusMessage = 'Token read successfully!';
      } else {
        _statusMessage = 'Failed to read token';
      }
    });
  }

  Future<void> _disconnect() async {
    final disconnected = await _usbService.disconnectDevice();
    setState(() {
      _isConnected = !disconnected;
      _statusMessage = disconnected 
          ? 'Disconnected' 
          : 'Failed to disconnect';
      if (disconnected) {
        _tokenData = null;
      }
    });
  }

  void _listenToUsbEvents() {
    _usbService.usbEvents.listen((event) {
      final action = event['action'] as String?;
      if (action == 'attached') {
        _showSnackBar('USB device attached');
        _scanDevices();
      } else if (action == 'detached') {
        _showSnackBar('USB device detached');
        setState(() {
          _isConnected = false;
          _tokenData = null;
        });
        _scanDevices();
      }
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('USB Token Reader'),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _scanDevices,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 20),
            if (_isUsbSupported) ...[
              _buildDevicesList(),
              const SizedBox(height: 20),
              if (_isConnected) ...[
                _buildReadButton(),
                const SizedBox(height: 20),
              ],
              if (_tokenData != null) _buildTokenDisplay(),
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
          colors: _isConnected 
              ? [const Color(0xFF10B981), const Color(0xFF34D399)]
              : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (_isConnected ? const Color(0xFF10B981) : const Color(0xFF6366F1))
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
            _isConnected ? Icons.usb_rounded : Icons.usb_off_rounded,
            size: 48,
            color: Colors.white,
          ),
          const SizedBox(height: 12),
          Text(
            _isConnected ? 'Connected' : 'Not Connected',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDevicesList() {
    if (_devices.isEmpty) {
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
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(
              Icons.cable_rounded,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'No devices found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect your USB dongle via OTG',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Available Devices',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 12),
        ..._devices.map((device) => _buildDeviceCard(device)),
      ],
    );
  }

  Widget _buildDeviceCard(Map<String, dynamic> device) {
    final deviceId = device['deviceId'] as int;
    final deviceName = device['deviceName'] as String? ?? 'Unknown Device';
    final vendorId = device['vendorId'] as int? ?? 0;
    final productId = device['productId'] as int? ?? 0;

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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.usb_rounded,
            color: Color(0xFF6366F1),
            size: 28,
          ),
        ),
        title: Text(
          deviceName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          'VID: ${vendorId.toRadixString(16).toUpperCase()} | PID: ${productId.toRadixString(16).toUpperCase()}',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 13,
          ),
        ),
        trailing: ElevatedButton(
          onPressed: _isConnected ? null : () => _openSmartCardScreen(deviceId, deviceName),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Connect'),
        ),
      ),
    );
  }

  Widget _buildReadButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isReading ? null : _readToken,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isReading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else
                  const Icon(Icons.nfc_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Text(
                  _isReading ? 'Reading...' : 'Read Token',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTokenDisplay() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF10B981),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Token Data',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              _tokenData ?? '',
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'monospace',
                color: Color(0xFF1F2937),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Copy to clipboard functionality
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6366F1),
                    side: const BorderSide(color: Color(0xFF6366F1)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _disconnect,
                  icon: const Icon(Icons.power_settings_new_rounded),
                  label: const Text('Disconnect'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
