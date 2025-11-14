import 'package:flutter/services.dart';

class UsbService {
  static const MethodChannel _channel = MethodChannel('com.example.smartcardos/usb');
  static const EventChannel _eventChannel = EventChannel('com.example.smartcardos/usb_events');

  // Check if device supports USB OTG
  Future<bool> isUsbSupported() async {
    try {
      final bool result = await _channel.invokeMethod('isUsbSupported');
      return result;
    } catch (e) {
      print('Error checking USB support: $e');
      return false;
    }
  }

  // Get list of connected USB devices
  Future<List<Map<String, dynamic>>> getConnectedDevices() async {
    try {
      final List<dynamic> result = await _channel.invokeMethod('getConnectedDevices');
      return result.map((device) => Map<String, dynamic>.from(device)).toList();
    } catch (e) {
      print('Error getting devices: $e');
      return [];
    }
  }

  // Request permission for USB device
  Future<bool> requestPermission(int deviceId) async {
    try {
      final bool result = await _channel.invokeMethod('requestPermission', {'deviceId': deviceId});
      return result;
    } catch (e) {
      print('Error requesting permission: $e');
      return false;
    }
  }

  // Connect to USB device
  Future<bool> connectDevice(int deviceId) async {
    try {
      final bool result = await _channel.invokeMethod('connectDevice', {'deviceId': deviceId});
      return result;
    } catch (e) {
      print('Error connecting device: $e');
      return false;
    }
  }

  // Read token from dongle
  Future<String?> readToken() async {
    try {
      final String? result = await _channel.invokeMethod('readToken');
      return result;
    } catch (e) {
      print('Error reading token: $e');
      return null;
    }
  }

  // Disconnect from USB device
  Future<bool> disconnectDevice() async {
    try {
      final bool result = await _channel.invokeMethod('disconnectDevice');
      return result;
    } catch (e) {
      print('Error disconnecting device: $e');
      return false;
    }
  }

  // Listen to USB device attach/detach events
  Stream<Map<String, dynamic>> get usbEvents {
    return _eventChannel.receiveBroadcastStream().map((event) => Map<String, dynamic>.from(event));
  }
}
