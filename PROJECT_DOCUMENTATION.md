# SmartCardOS - Complete Project Documentation

## Table of Contents
1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Project Structure](#project-structure)
4. [How It Works](#how-it-works)
5. [Key Components](#key-components)
6. [Communication Flow](#communication-flow)
7. [Smartcard Commands](#smartcard-commands)
8. [Setup & Installation](#setup--installation)
9. [Usage Guide](#usage-guide)
10. [Troubleshooting](#troubleshooting)

---

## Project Overview

**SmartCardOS** is a Flutter-based Android application that enables communication with smartcards through USB card readers. The app allows you to:

- Connect to USB smartcard readers via OTG cable
- Read smartcard data (ATR - Answer To Reset)
- Send APDU (Application Protocol Data Unit) commands
- Perform cryptographic operations (digital signatures)
- Manage security environments (RSA/ECC)
- Navigate smartcard file systems

### Technology Stack
- **Frontend**: Flutter (Dart)
- **Backend**: Kotlin (Android Native)
- **Communication**: Platform Channels (Flutter ↔ Native)
- **Hardware**: USB Host API (Android)
- **Protocol**: ISO 7816 (Smartcard Standard)

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter Layer (Dart)                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │   Main App   │  │  USB Screen  │  │ Card Screen  │   │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘   │ 
│         │                 │                 │           │
│  ┌──────▼──────────────────▼──────────────────▼──────┐  │
│  │           Platform Channel Bridge                 │  │
│  │  (com.example.smartcardos/usb & /smartcard)       │  │
│  └──────────────────────┬────────────────────────────┘  │
└─────────────────────────┼───────────────────────────────┘
                          │
┌─────────────────────────▼─────────────────────────────────┐
│              Native Android Layer (Kotlin)                │
│  ┌────────────────────────────────────────────────────┐   │
│  │              MainActivity.kt                       │   │
│  │  ┌──────────────┐         ┌──────────────────┐     │   │
│  │  │ USB Manager  │         │ Smartcard Reader │     │   │
│  │  │  - Detect    │         │  - Connect       │     │   │
│  │  │  - Connect   │         │  - Transmit APDU │     │   │
│  │  │  - Read      │         │  - Get ATR       │     │   │
│  │  └──────┬───────┘         └──────┬───────────┘     │   │
│  └─────────┼────────────────────────┼─────────────────┘   │
│            │                        │                     │
│  ┌─────────▼────────────────────────▼─────────────────┐   │
│  │         Android USB Host API                       │   │
│  │         (UsbManager, UsbDevice, UsbInterface)      │   │
│  └─────────────────────────┬──────────────────────────┘   │
└────────────────────────────┼──────────────────────────────┘
                             │
                    ┌────────▼────────┐
                    │  USB Card Reader │
                    │   (Hardware)     │
                    └────────┬─────────┘
                             │
                    ┌────────▼────────┐
                    │   Smart Card    │
                    │   (Hardware)    │
                    └─────────────────┘
```

---

## Project Structure

```
smartcardos/
├── lib/
│   ├── main.dart                      # App entry point
│   ├── screens/
│   │   ├── usb_reader_screen.dart     # USB device management UI
│   │   └── smartcard_screen.dart      # Smartcard operations UI
│   └── services/
│       ├── usb_service.dart           # USB communication service
│       └── smartcard_service.dart     # Smartcard APDU service
│
├── android/
│   └── app/
│       └── src/main/
│           ├── kotlin/.../MainActivity.kt  # Native Android code
│           ├── AndroidManifest.xml         # Permissions & filters
│           └── res/xml/
│               └── device_filter.xml       # USB device filter
│
├── USB_IMPLEMENTATION.md              # Technical implementation docs
├── PROJECT_DOCUMENTATION.md           # This file
└── pubspec.yaml                       # Flutter dependencies
```

---

## How It Works

### 1. **App Initialization**
```dart
// main.dart
void main() {
  runApp(const MyApp());
}
```
- App starts with a home screen
- Two main options: "USB Token Reader" and "Smart Card Reader"

### 2. **USB Detection & Connection**

#### Flutter Side (usb_service.dart):
```dart
// Check if device supports USB OTG
final supported = await usbService.isUsbSupported();

// Get list of connected USB devices
final devices = await usbService.getConnectedDevices();

// Request permission for specific device
final hasPermission = await usbService.requestPermission(deviceId);

// Connect to device
final connected = await usbService.connectDevice(deviceId);
```

#### Native Side (MainActivity.kt):
```kotlin
// Get USB Manager
val usbManager = getSystemService(Context.USB_SERVICE) as UsbManager

// Find device by ID
val device = usbManager.deviceList.values.find { it.deviceId == deviceId }

// Request permission
val permissionIntent = PendingIntent.getBroadcast(...)
usbManager.requestPermission(device, permissionIntent)

// Open connection
val connection = usbManager.openDevice(device)
```

### 3. **Smartcard Communication**

#### Connect to Card:
```dart
// Select protocol: T=0, T=1, or Auto
final result = await smartCardService.connectCard(protocol: 1);

// Get ATR (Answer To Reset)
final atr = result['atr'];
```

#### Native Implementation:
```kotlin
// Get card interface (usually interface 0)
val cardInterface = usbDevice.getInterface(0)

// Claim interface
connection.claimInterface(cardInterface, true)

// Get endpoints for communication
val endpointOut = cardInterface.getEndpoint(0) // OUT
val endpointIn = cardInterface.getEndpoint(1)  // IN

// Power on card and get ATR
val atrCommand = byteArrayOf(0x62, 0x00, ...)
connection.bulkTransfer(endpointOut, atrCommand, ...)
```

### 4. **APDU Command Transmission**

#### APDU Structure:
```
┌─────┬─────┬─────┬─────┬─────┬──────────┬─────┐
│ CLA │ INS │ P1  │ P2  │ Lc  │   Data   │ Le  │
├─────┼─────┼─────┼─────┼─────┼──────────┼─────┤
│ 00  │ A4  │ 00  │ 00  │ 02  │  3F 00   │     │
└─────┴─────┴─────┴─────┴─────┴──────────┴─────┘
  ↓     ↓     ↓     ↓     ↓        ↓        ↓
Class  Ins  Param Param Length   Data   Expected
                                         Response
```

#### Flutter Side:
```dart
// Send APDU command
final response = await smartCardService.transmitApdu('00A40000023F00');

// Response format: [Data] + [SW1 SW2]
// Example: "3F 00 90 00"
//          ↑     ↑
//          Data  Status Word (Success)
```

#### Native Side:
```kotlin
fun transmitApdu(command: String): String {
    // Convert hex string to bytes
    val commandBytes = hexStringToByteArray(command)
    
    // Build CCID command (for card readers)
    val ccidCommand = buildCCIDCommand(commandBytes)
    
    // Send to card reader
    connection.bulkTransfer(endpointOut, ccidCommand, ...)
    
    // Read response
    val response = ByteArray(1024)
    connection.bulkTransfer(endpointIn, response, ...)
    
    // Extract APDU response from CCID wrapper
    return extractApduResponse(response)
}
```

---

## Key Components

### 1. **UsbService** (lib/services/usb_service.dart)

**Purpose**: Manages USB device detection and connection

**Key Methods**:
```dart
class UsbService {
  // Check USB OTG support
  Future<bool> isUsbSupported()
  
  // List connected devices
  Future<List<Map<String, dynamic>>> getConnectedDevices()
  
  // Request user permission
  Future<bool> requestPermission(int deviceId)
  
  // Connect to device
  Future<bool> connectDevice(int deviceId)
  
  // Disconnect
  Future<bool> disconnectDevice()
  
  // Listen to USB events (attach/detach)
  Stream<Map<String, dynamic>> get usbEvents
}
```

**Usage Example**:
```dart
final usbService = UsbService();

// Check support
if (await usbService.isUsbSupported()) {
  // Get devices
  final devices = await usbService.getConnectedDevices();
  
  // Connect to first device
  if (devices.isNotEmpty) {
    final deviceId = devices[0]['deviceId'];
    await usbService.requestPermission(deviceId);
    await usbService.connectDevice(deviceId);
  }
}
```

### 2. **SmartCardService** (lib/services/smartcard_service.dart)

**Purpose**: Handles smartcard APDU commands and operations

**Key Methods**:
```dart
class SmartCardService {
  // Connect to card with protocol
  Future<Map<String, dynamic>> connectCard({int protocol = 1})
  
  // Send raw APDU command
  Future<String?> transmitApdu(String apduCommand)
  
  // Get ATR
  Future<String?> getAtr()
  
  // Disconnect card
  Future<bool> disconnectCard()
  
  // === File Selection ===
  Future<String?> selectMF()  // Select Master File
  Future<String?> selectDF()  // Select Dedicated File
  
  // === Security Operations ===
  Future<String?> mseRestore({required String algorithm})
  Future<String?> psoDigitalSignature(String data)
  
  // === Utilities ===
  static String parseStatusWord(String sw)
  static String generateRandomData32Bytes()
  static Map<String, String> get commonCommands
}
```

**Usage Example**:
```dart
final cardService = SmartCardService();

// Connect with T=1 protocol
final result = await cardService.connectCard(protocol: 1);

if (result['success']) {
  // Select Master File
  await cardService.selectMF();
  
  // Set security environment for RSA
  await cardService.mseRestore(algorithm: 'rsa');
  
  // Sign data
  final data = SmartCardService.generateRandomData32Bytes();
  final signature = await cardService.psoDigitalSignature(data);
  
  print('Signature: $signature');
}
```

### 3. **MainActivity.kt** (Native Android)

**Purpose**: Implements USB and smartcard communication at OS level

**Key Functions**:
```kotlin
class MainActivity : FlutterActivity() {
    
    // USB Channel Methods
    private fun isUsbSupported(): Boolean
    private fun getConnectedDevices(): List<Map<String, Any>>
    private fun requestPermission(deviceId: Int): Boolean
    private fun connectDevice(deviceId: Int): Boolean
    private fun disconnectDevice(): Boolean
    
    // Smartcard Channel Methods
    private fun connectCard(protocol: Int): Map<String, Any>
    private fun transmitApdu(command: String): String?
    private fun getAtr(): String?
    private fun disconnectCard(): Boolean
    
    // Helper Functions
    private fun hexStringToByteArray(hex: String): ByteArray
    private fun byteArrayToHexString(bytes: ByteArray): String
    private fun buildCCIDCommand(apdu: ByteArray): ByteArray
    private fun extractApduResponse(ccidResponse: ByteArray): String
}
```

---

## Communication Flow

### Example: Signing Data

```
┌─────────────┐
│    User     │
│  Taps "Sign"│
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────────────┐
│  SmartCardScreen (UI)                   │
│  - Shows confirmation dialog            │
│  - Generates 32-byte random data        │
└──────┬──────────────────────────────────┘
       │ psoDigitalSignature(data)
       ▼
┌─────────────────────────────────────────┐
│  SmartCardService                       │
│  - Validates data (32 bytes)            │
│  - Builds APDU: 002A9E9A20[data]        │
│  - Calls transmitApdu()                 │
└──────┬──────────────────────────────────┘
       │ MethodChannel.invokeMethod()
       ▼
┌─────────────────────────────────────────┐
│  Platform Channel Bridge                │
│  - Serializes data                      │
│  - Routes to native code                │
└──────┬──────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────┐
│  MainActivity.kt                        │
│  - Receives APDU command                │
│  - Converts hex to bytes                │
│  - Wraps in CCID protocol               │
└──────┬──────────────────────────────────┘
       │ bulkTransfer()
       ▼
┌─────────────────────────────────────────┐
│  USB Host API                           │
│  - Sends to USB endpoint                │
└──────┬──────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────┐
│  Card Reader (Hardware)                 │
│  - Forwards to smartcard                │
└──────┬──────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────┐
│  Smart Card                             │
│  - Processes command                    │
│  - Signs data with private key          │
│  - Returns signature + status           │
└──────┬──────────────────────────────────┘
       │
       ▼ (Response flows back up)
┌─────────────────────────────────────────┐
│  SmartCardScreen                        │
│  - Displays signature in history        │
│  - Shows status (success/error)         │
│  - Allows copying result                │
└─────────────────────────────────────────┘
```

---

## Smartcard Commands

### ISO 7816 APDU Commands

#### 1. **SELECT Commands**

**Select Master File (MF)**:
```
Command:  00 A4 00 00 02 3F 00
          ││ ││ ││ ││ ││ └─┴─ File ID (3F00 = MF)
          ││ ││ ││ ││ └─ Length (2 bytes)
          ││ ││ └─┴─ P1, P2 (selection parameters)
          ││ └─ INS (A4 = SELECT)
          └─ CLA (00 = standard)

Response: 90 00 (Success)
```

**Select Dedicated File (DF)**:
```
Command:  00 A4 00 00 02 6F 00
Response: 90 00 (Success)
```

#### 2. **Security Commands**

**MSE Restore (Manage Security Environment)**:
```
RSA:      00 22 F3 03
          ││ ││ ││ └─ Algorithm (03 = RSA)
          ││ ││ └─ P1 (F3 = Restore)
          ││ └─ INS (22 = MSE)
          └─ CLA

ECC:      00 22 F3 0D
          (0D = ECC algorithm)

Response: 90 00 (Success)
```

**PSO Digital Signature**:
```
Command:  00 2A 9E 9A 20 [32 bytes of data]
          ││ ││ ││ ││ ││
          ││ ││ ││ ││ └─ Lc (length = 32 bytes = 0x20)
          ││ ││ └─┴─ P1, P2 (9E9A = compute signature)
          ││ └─ INS (2A = PSO)
          └─ CLA

Response: [Signature data] 90 00
```

#### 3. **Status Words (SW1 SW2)**

| Status | Meaning |
|--------|---------|
| `90 00` | Success |
| `61 XX` | Success, XX bytes available (use GET RESPONSE) |
| `62 XX` | Warning - State unchanged |
| `63 CX` | Warning - X verification attempts remaining |
| `65 81` | Memory failure |
| `67 00` | Wrong length |
| `69 82` | Security status not satisfied |
| `69 83` | Authentication blocked |
| `69 85` | Conditions not satisfied |
| `6A 82` | File not found |
| `6A 86` | Incorrect P1-P2 |
| `6D 00` | Instruction not supported |
| `6E 00` | Class not supported |

---

## Setup & Installation

### Prerequisites
- Flutter SDK (3.0+)
- Android Studio
- Android device with USB OTG support
- USB smartcard reader
- Smartcard

### Installation Steps

1. **Clone the project**:
```bash
git clone <repository-url>
cd smartcardos
```

2. **Install Flutter dependencies**:
```bash
flutter pub get
```

3. **Configure Android**:
```bash
cd android
./gradlew clean
cd ..
```

4. **Connect Android device** (USB debugging enabled)

5. **Run the app**:
```bash
flutter run
```

### Android Permissions

The app requires these permissions (already configured):

**AndroidManifest.xml**:
```xml
<!-- USB Host support -->
<uses-feature android:name="android.hardware.usb.host" />

<!-- USB permission -->
<uses-permission android:name="android.permission.USB_PERMISSION" />

<!-- Intent filter for USB device attach -->
<intent-filter>
    <action android:name="android.hardware.usb.action.USB_DEVICE_ATTACHED" />
</intent-filter>
```

---

## Usage Guide

### Basic Workflow

1. **Launch App** → Home Screen
2. **Tap "Smart Card Reader"**
3. **Select Protocol** (T=1 recommended)
4. **Grant USB Permission** (system dialog)
5. **Card Connects** → ATR displayed
6. **Perform Operations**:
   - Select MF
   - Select DF
   - MSE Restore (RSA/ECC)
   - Sign Data
7. **View Results** in Command History

### Sending Custom APDU

1. Scroll to "Send APDU Command" section
2. Enter hex command (e.g., `00A40000023F00`)
3. Tap "Transmit"
4. View response in history

### Understanding Responses

**Success Response**:
```
Command:  00 A4 00 00 02 3F 00
Response: 90 00
Status:   ✓ Success
```

**Data Response**:
```
Command:  00 B0 00 00 10
Response: 3F 00 00 1F FF FF FF FF 00 00 00 00 00 00 00 00 90 00
          └────────────── Data (16 bytes) ──────────────┘ └─┘
                                                        Status
```

**Error Response**:
```
Command:  00 A4 00 00 02 FF FF
Response: 6A 82
Status:   ✗ File not found
```

---

## Troubleshooting

### Common Issues

#### 1. **"No USB devices found"**
- Check USB OTG cable connection
- Verify device supports USB OTG
- Try different USB port
- Restart app

#### 2. **"Permission denied"**
- Grant permission in system dialog
- Check AndroidManifest.xml has USB permissions
- Reinstall app if permission dialog doesn't appear

#### 3. **"Failed to connect to card"**
- Ensure card is properly inserted
- Try different protocol (T=0 vs T=1)
- Check card reader compatibility
- Verify card is not damaged

#### 4. **"6A 82 - File not found"**
- File ID doesn't exist on card
- Select MF first before selecting other files
- Check card documentation for valid file IDs

#### 5. **"69 82 - Security status not satisfied"**
- PIN verification required
- Send VERIFY PIN command first
- Check security conditions

#### 6. **"67 00 - Wrong length"**
- Data length doesn't match Lc field
- For PSO signature, must be exactly 32 bytes
- Check APDU format

### Debug Mode

Enable detailed logging in MainActivity.kt:
```kotlin
private val DEBUG = true

if (DEBUG) {
    Log.d("SmartCard", "Command: $command")
    Log.d("SmartCard", "Response: $response")
}
```

### Testing Without Hardware

For development without physical card:
1. Use Android emulator with virtual USB
2. Mock responses in MainActivity.kt
3. Test UI and flow logic

---

## Advanced Topics

### Custom File Selection

To select custom files:
```dart
// Select EF with file ID 2F00
await smartCardService.transmitApdu('00A4020C022F00');
```

### PIN Verification

```dart
// VERIFY PIN command
// Format: 00 20 00 00 08 [8-byte PIN]
final pin = '31323334FFFFFFFF'; // "1234" padded
await smartCardService.transmitApdu('0020000008$pin');
```

### Reading Binary Data

```dart
// READ BINARY command
// Format: 00 B0 [offset] [length]
await smartCardService.transmitApdu('00B0000010'); // Read 16 bytes
```

### Chaining Commands

```dart
// Complete signature flow
await smartCardService.selectMF();
await smartCardService.selectDF();
await smartCardService.mseRestore(algorithm: 'rsa');
final signature = await smartCardService.psoDigitalSignature(data);
```

---

## Project Maintenance

### Adding New Commands

1. **Add method to SmartCardService**:
```dart
Future<String?> myNewCommand() async {
  return await transmitApdu('00XX0000XX');
}
```

2. **Add UI button in SmartCardScreen**:
```dart
_buildOperationButton(
  'My Command',
  Icons.new_icon,
  Colors.blue,
  _myNewCommand,
)
```

3. **Add handler**:
```dart
Future<void> _myNewCommand() async {
  setState(() => _isProcessing = true);
  final response = await _smartCardService.myNewCommand();
  setState(() => _isProcessing = false);
  _addToHistory('MY COMMAND', response ?? 'Failed');
}
```

### Updating Status Word Parser

Add new status codes in `parseStatusWord()`:
```dart
if (clean == '6XXX') return '✗ My custom error';
```

---

## Resources

### Standards & Specifications
- **ISO 7816**: Smartcard standard
- **PC/SC**: Personal Computer/Smart Card standard
- **CCID**: Chip Card Interface Device specification

### Useful Links
- [ISO 7816 APDU Commands](https://cardwerk.com/smart-card-standard-iso7816-4-section-5-basic-organizations/)
- [Android USB Host API](https://developer.android.com/guide/topics/connectivity/usb/host)
- [Flutter Platform Channels](https://docs.flutter.dev/development/platform-integration/platform-channels)

### Card Documentation
- Check your smartcard manufacturer's documentation
- Look for supported APDU commands
- Verify file structure and IDs
- Check security requirements

---

## License & Credits

This project demonstrates USB smartcard communication in Flutter.

**Key Technologies**:
- Flutter/Dart
- Kotlin
- Android USB Host API
- ISO 7816 Protocol

---

## Support

For issues or questions:
1. Check this documentation
2. Review USB_IMPLEMENTATION.md
3. Check command history for error codes
4. Verify hardware compatibility
5. Test with known-working cards

---

**Last Updated**: November 2025
**Version**: 1.0.0
