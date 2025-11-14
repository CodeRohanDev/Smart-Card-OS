# USB Token Reader Implementation

## What Was Created

### 1. **Platform Channel Service** (`lib/services/usb_service.dart`)
- Dart service to communicate with native Android code
- Methods:
  - `isUsbSupported()` - Check if device supports USB OTG
  - `getConnectedDevices()` - List all connected USB devices
  - `requestPermission()` - Request user permission for USB access
  - `connectDevice()` - Connect to specific USB device
  - `readToken()` - Read token data from dongle
  - `disconnectDevice()` - Disconnect from device
  - `usbEvents` - Stream for USB attach/detach events

### 2. **USB Reader Screen** (`lib/screens/usb_reader_screen.dart`)
- Beautiful UI to interact with USB dongle
- Features:
  - Status card showing connection state
  - Device list with connect buttons
  - Read token button
  - Token data display with copy/disconnect options
  - Real-time USB device detection

### 3. **Native Android Code** (`MainActivity.kt`)
- Platform channel implementation using Android USB Host API
- Handles:
  - USB device detection
  - Permission requests
  - Device connection/disconnection
  - Data reading via bulk transfer
  - USB attach/detach broadcast events

### 4. **Android Configuration**
- **AndroidManifest.xml**: USB permissions and intent filters
- **device_filter.xml**: USB device filter (matches any USB device)

## How It Works

1. **User opens USB Reader screen** from home menu
2. **App checks USB support** on device
3. **Scans for connected devices** automatically
4. **User connects dongle** via OTG cable
5. **App detects device** and shows in list
6. **User taps "Connect"** button
7. **Permission dialog** appears (Android system)
8. **User grants permission**
9. **App connects** to USB device
10. **User taps "Read Token"** button
11. **App reads data** from dongle via bulk transfer
12. **Token displayed** in hex format

## Customization Needed

### For Your Specific Dongle:

In `MainActivity.kt`, update the `readToken` method:

```kotlin
// Current implementation uses basic bulk transfer
// You may need to:

1. Send specific APDU commands for smart cards
2. Use different transfer types (control, interrupt)
3. Parse response in specific format
4. Handle multi-step authentication
5. Implement encryption/decryption
```

### Example for Smart Card Reader:

```kotlin
// Send SELECT command
val selectCommand = byteArrayOf(0x00, 0xA4, 0x04, 0x00, ...)
usbConnection?.bulkTransfer(endpoint, selectCommand, ...)

// Read response
val response = ByteArray(256)
usbConnection?.bulkTransfer(endpoint, response, ...)
```

### Device Filter:

Update `device_filter.xml` to match your dongle:

```xml
<usb-device vendor-id="1234" product-id="5678" />
```

## Testing

1. **Without dongle**: App will show "No devices found"
2. **With dongle**: Device appears in list
3. **After connect**: Status changes to "Connected"
4. **After read**: Token data displays in hex format

## Next Steps

1. **Test with your actual dongle**
2. **Check vendor/product IDs** in device list
3. **Customize read logic** based on dongle protocol
4. **Add error handling** for specific cases
5. **Implement token parsing** (hex to readable format)
6. **Add token validation** logic
7. **Store token** securely if needed

## Notes

- The current implementation reads raw data via bulk transfer
- You'll need to customize based on your dongle's communication protocol
- Smart card readers typically use APDU commands
- Security tokens may have specific authentication flows
- Test thoroughly with your actual hardware
