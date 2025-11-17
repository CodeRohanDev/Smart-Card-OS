# 📱 Real Device Testing - Step by Step Guide

## 🎯 What You Need

### Hardware
- ✅ Android phone/tablet (Android 5.0+)
- ✅ USB smartcard reader (e.g., ACR122U, ACR38U)
- ✅ Smartcard with PIN
- ✅ USB OTG cable (if your phone doesn't have USB-C to USB-A)
- ✅ USB cable to connect phone to computer

### Software
- ✅ Flutter installed
- ✅ Android Studio or VS Code
- ✅ ADB (Android Debug Bridge)

---

## 📋 Step-by-Step Testing Process

### STEP 1: Update Your Code (5 minutes)

#### 1.1 Open `lib/screens/usb_reader_screen.dart`

Find the part where you navigate to the smartcard screen. It probably looks like this:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => SmartCardScreen(
      deviceId: device['deviceId'],
      deviceName: device['deviceName'],
    ),
  ),
);
```

#### 1.2 Add Import at the Top

Add this line at the top of the file with other imports:

```dart
import 'enhanced_smartcard_screen.dart';
```

#### 1.3 Replace Navigation

Change `SmartCardScreen` to `EnhancedSmartCardScreen`:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => EnhancedSmartCardScreen(  // Changed this line
      deviceId: device['deviceId'],
      deviceName: device['deviceName'],
    ),
  ),
);
```

#### 1.4 Save the File

Press `Ctrl+S` (Windows) or `Cmd+S` (Mac)

---

### STEP 2: Connect Your Android Device (3 minutes)

#### 2.1 Enable Developer Options on Phone

1. Open **Settings** on your Android phone
2. Go to **About Phone**
3. Tap **Build Number** 7 times
4. You'll see "You are now a developer!"

#### 2.2 Enable USB Debugging

1. Go back to **Settings**
2. Find **Developer Options** (usually in System or Advanced)
3. Turn on **USB Debugging**
4. Turn on **Install via USB** (if available)

#### 2.3 Connect Phone to Computer

1. Use USB cable to connect phone to computer
2. On phone, you'll see "Allow USB debugging?" popup
3. Tap **Allow** (check "Always allow from this computer")

#### 2.4 Verify Connection

Open terminal/command prompt and run:

```bash
flutter devices
```

You should see your Android device listed:

```
Android SDK built for x86 (mobile) • emulator-5554 • android-x86 • Android 11 (API 30)
SM-G991B (mobile) • R5CR1234ABC • android-arm64 • Android 12 (API 31)  ← Your phone
```

---

### STEP 3: Build and Install App (5 minutes)

#### 3.1 Clean Previous Build

```bash
flutter clean
```

#### 3.2 Get Dependencies

```bash
flutter pub get
```

#### 3.3 Build and Run on Device

```bash
flutter run
```

Or if you have multiple devices:

```bash
flutter run -d <device-id>
```

Example:
```bash
flutter run -d R5CR1234ABC
```

#### 3.4 Wait for Installation

You'll see output like:

```
Launching lib/main.dart on SM-G991B in debug mode...
Running Gradle task 'assembleDebug'...
✓ Built build/app/outputs/flutter-apk/app-debug.apk.
Installing build/app/outputs/flutter-apk/app.apk...
Waiting for SM-G991B to report its views...
Debug service listening on ws://127.0.0.1:12345/
Synced 0.0MB.
```

The app should automatically open on your phone!

---

### STEP 4: Prepare Hardware (2 minutes)

#### 4.1 Insert Smartcard into Reader

1. Take your smartcard
2. Insert it into the USB reader
3. Make sure it's fully inserted

#### 4.2 Connect Reader to Phone

**If your phone has USB-C:**
- Use USB-C to USB-A adapter (OTG cable)
- Connect reader to adapter
- Connect adapter to phone

**If your phone has USB-A:**
- Connect reader directly to phone

#### 4.3 Check Connection

When you plug in the reader:
- Phone may show "USB device detected" notification
- App should detect the reader automatically

---

### STEP 5: Test the App (20 minutes)

#### 5.1 Launch and Connect

1. **Open the app** on your phone
2. You should see **"USB Reader Screen"**
3. Your USB reader should be listed (e.g., "ACS ACR122U")
4. **Tap on the reader** in the list

5. **Protocol Selection Dialog** appears:
   - Choose **"T=1"** (recommended)
   - Or choose **"T=0 | T=1"** (auto-detect)
   - Tap the protocol option

6. **Wait for connection** (2-3 seconds)
   - You'll see "Connecting..." message
   - Then "Card connected!" message

7. **Enhanced Screen Opens** with:
   - Green banner showing "Card Connected"
   - ATR (Answer To Reset) displayed
   - 5 tabs at the top

---

#### 5.2 Test Tab 1: Basic Operations

**Test 1: SELECT MF**

1. Make sure you're on **"Basic"** tab
2. Tap **"SELECT MF"** button
3. **Response Dialog** appears:
   - ✅ Green checkmark icon
   - ✅ Shows "Status: 90 00 - ✓ Success"
   - ✅ May show some data
4. Tap **"Close"** button

**Test 2: MSE RESTORE RSA**

1. Tap **"MSE RSA"** button
2. Check response dialog
3. Should show success (90 00)
4. Tap "Close"

**Test 3: PSO Digital Signature**

1. Tap **"PSO Sign (32 bytes)"** button
2. Response dialog shows:
   - Original data (32 bytes)
   - Signature data (if successful)
   - Status word
3. If you get **"69 82 - Security not satisfied"**:
   - This is normal!
   - It means you need to verify PIN first
   - Go to Security tab (next step)

---

#### 5.3 Test Tab 2: Security Operations

**Swipe left** or tap **"Security"** tab

**Test 1: Verify PIN**

1. In the **PIN text field**, enter your card's PIN
   - Example: `1234` or `123456`
2. Tap **"Verify PIN"** button
3. Check response:
   
   **If PIN is correct:**
   - ✅ Green checkmark
   - ✅ "90 00 - ✓ Success"
   - ✅ Message: "PIN verified!"
   
   **If PIN is wrong:**
   - ❌ Red X icon
   - ❌ "63 C3" (or similar)
   - ❌ Shows: "⚠ 3 attempts remaining"
   - ❌ Orange box with suggestion: "You have 3 attempts remaining before PIN is blocked"

**Test 2: GET CHALLENGE**

1. Tap **"GET CHALLENGE"** button
2. Response shows:
   - 8 bytes of random data
   - Example: "A1 B2 C3 D4 E5 F6 G7 H8"
3. This is random data from the card

**Test 3: INTERNAL AUTHENTICATE**

1. Tap **"INTERNAL AUTHENTICATE"** button
2. May succeed or fail depending on card
3. Check the response

---

#### 5.4 Test Tab 3: Data Operations

**Swipe left** or tap **"Data"** tab

**Test 1: READ BINARY**

1. Tap **"READ BINARY (256 bytes)"** button
2. Response:
   - May show data if file is selected
   - May show error "6A 82 - File not found"
   - This is normal if no file is selected

**Test 2: Get Card Serial Number**

1. Tap **"Get Card Serial Number"** button
2. Response:
   - May show card number
   - Or error if not available
3. Check the data

**Test 3: Get Cardholder Name**

1. Tap **"Get Cardholder Name"** button
2. Check response
3. May or may not be available

---

#### 5.5 Test Tab 4: Advanced Operations

**Swipe left** or tap **"Advanced"** tab

**Test 1: Batch Sign**

1. First, go back to **Security tab**
2. **Verify PIN** (if not already done)
3. Go back to **Basic tab**
4. Tap **"MSE RSA"**
5. Now go to **Advanced tab**
6. Tap **"Batch Sign (3 blocks)"** button
7. Wait 5-10 seconds
8. You'll see message: "Batch complete: 3/3 successful"
9. This signs 3 random data blocks automatically!

**Test 2: Custom APDU**

1. In the **APDU Command** text field, enter:
   ```
   00A40000023F00
   ```
   (This is SELECT MF command)

2. Tap **"Send Custom APDU"** button
3. Response dialog shows the result
4. Try other commands:
   - `0084000008` - GET CHALLENGE
   - `00CA005A00` - GET DATA

---

#### 5.6 Test Tab 5: History

**Swipe left** or tap **"History"** tab

**View Operation Logs**

1. You should see all operations you just performed
2. Example: "Batch Sign 3 blocks"
3. **Tap on any operation** to expand it
4. You'll see:
   - Step 1: SELECT MF - ✓ (15ms)
   - Step 2: MSE RESTORE RSA - ✓ (12ms)
   - Step 3: PSO SIGN - ✓ (45ms)
   - Step 4: PSO SIGN - ✓ (43ms)
   - Step 5: PSO SIGN - ✓ (44ms)

**View Step Details**

1. Tap the **info icon (ℹ️)** next to any step
2. Response dialog shows:
   - Command sent
   - Data received
   - Status word
   - Timing
3. Tap "Close"

---

### STEP 6: Test Complete Signing Flow (5 minutes)

Let's test the complete flow from start to finish:

#### 6.1 Go to Basic Tab

1. Tap **"Basic"** tab
2. Tap **"SELECT MF"**
3. Wait for success

#### 6.2 Go to Security Tab

1. Tap **"Security"** tab
2. Enter your PIN
3. Tap **"Verify PIN"**
4. Wait for success

#### 6.3 Go to Basic Tab

1. Tap **"Basic"** tab
2. Tap **"MSE RSA"**
3. Wait for success

#### 6.4 Sign Data

1. Tap **"PSO Sign (32 bytes)"**
2. Response dialog shows:
   - Original data (32 bytes)
   - Signature data (256 bytes for RSA-2048)
   - Status: 90 00 - ✓ Success

#### 6.5 Check History

1. Go to **"History"** tab
2. You should see all 4 operations logged
3. Expand to see each step
4. Check timing information

---

## 📸 What You Should See

### Main Screen
```
┌─────────────────────────────────┐
│  ← Enhanced Smart Card          │
├─────────────────────────────────┤
│ Basic Security Data Advanced... │
├─────────────────────────────────┤
│                                 │
│  ┌───────────────────────────┐ │
│  │   Card Connected          │ │
│  │   ✓                       │ │
│  │   ACS ACR122U             │ │
│  │   ATR: 3B 8F 80 01...     │ │
│  └───────────────────────────┘ │
│                                 │
│  File Selection                 │
│  ┌─────────────┬─────────────┐ │
│  │ SELECT MF   │ SELECT DF   │ │
│  └─────────────┴─────────────┘ │
│                                 │
│  Security Environment           │
│  ┌─────────────┬─────────────┐ │
│  │  MSE RSA    │  MSE ECC    │ │
│  └─────────────┴─────────────┘ │
│                                 │
│  Digital Signature              │
│  ┌───────────────────────────┐ │
│  │ PSO Sign (32 bytes)       │ │
│  └───────────────────────────┘ │
└─────────────────────────────────┘
```

### Response Dialog (Success)
```
┌─────────────────────────────────┐
│  ✓ Response                     │
├─────────────────────────────────┤
│  Data:                          │
│  ┌───────────────────────────┐ │
│  │ 6F 19 84 01 01 85 02 3F   │ │
│  │ 00 86 09 01 02 03 04 05   │ │
│  └───────────────────────────┘ │
│  9 bytes                        │
│                                 │
│  Status:                        │
│  ┌───────────────────────────┐ │
│  │ 90 00 - ✓ Success         │ │
│  └───────────────────────────┘ │
│                                 │
│  [Copy Data]  [Close]           │
└─────────────────────────────────┘
```

### Response Dialog (Error with Suggestion)
```
┌─────────────────────────────────┐
│  ✗ Response                     │
├─────────────────────────────────┤
│  Status:                        │
│  ┌───────────────────────────┐ │
│  │ 69 82 - ✗ Security status │ │
│  │ not satisfied             │ │
│  └───────────────────────────┘ │
│                                 │
│  ┌───────────────────────────┐ │
│  │ 💡 You need to verify PIN │ │
│  │ first. Tap 'Verify PIN'   │ │
│  │ button.                   │ │
│  └───────────────────────────┘ │
│                                 │
│  [Close]                        │
└─────────────────────────────────┘
```

---

## 🐛 Troubleshooting

### Problem 1: App doesn't detect USB reader

**Solution:**
1. Unplug USB reader from phone
2. Close and reopen the app
3. Plug in USB reader
4. Wait 2-3 seconds
5. Pull down to refresh the list

### Problem 2: "Permission denied" error

**Solution:**
1. When you plug in the reader, Android shows a permission dialog
2. Tap "Allow" or "OK"
3. Check "Use by default for this USB device"
4. Try again

### Problem 3: "Card not connected" message

**Solution:**
1. Check smartcard is fully inserted in reader
2. Try removing and reinserting the card
3. Disconnect and reconnect the reader
4. Restart the app

### Problem 4: All commands fail with "69 82"

**Solution:**
1. This means "Security not satisfied"
2. Go to Security tab
3. Enter PIN
4. Tap "Verify PIN"
5. Now try other commands

### Problem 5: "File not found" errors

**Solution:**
1. This is normal for some cards
2. Not all cards have all files
3. Try SELECT MF first
4. Then try other commands

### Problem 6: App crashes when tapping button

**Solution:**
1. Check the terminal/console for error messages
2. Make sure you saved all files
3. Try `flutter clean` and `flutter run` again
4. Check that all imports are correct

### Problem 7: Can't see the new enhanced screen

**Solution:**
1. Make sure you updated the navigation in `usb_reader_screen.dart`
2. Make sure you added the import
3. Try hot restart (press 'R' in terminal)
4. Or stop and run `flutter run` again

---

## ✅ Success Checklist

After testing, you should have:

- [x] Connected to USB reader
- [x] Seen the enhanced screen with 5 tabs
- [x] Tested SELECT MF (success)
- [x] Tested PIN verification
- [x] Tested PSO Sign (with signature data)
- [x] Tested GET CHALLENGE (8 random bytes)
- [x] Tested Batch Sign (3 signatures)
- [x] Viewed operation history
- [x] Seen step-by-step details
- [x] Seen error suggestions
- [x] Copied data to clipboard

---

## 📹 Recording Your Test

### Take Screenshots

1. **Main screen** - showing 5 tabs
2. **Response dialog** - showing success
3. **Response dialog** - showing error with suggestion
4. **History tab** - showing operations
5. **Expanded operation** - showing steps

### Screen Record (Optional)

1. Enable screen recording on your phone
2. Record yourself:
   - Connecting to card
   - Testing each tab
   - Viewing responses
   - Checking history
3. This helps for debugging later

---

## 🎯 Quick Test (5 minutes)

If you're short on time, just test these:

1. ✅ Connect to card
2. ✅ Tap "SELECT MF" (Basic tab)
3. ✅ Enter PIN and tap "Verify PIN" (Security tab)
4. ✅ Tap "PSO Sign" (Basic tab)
5. ✅ Check History tab

If these work, everything is working! 🎉

---

## 📊 Expected Results Summary

| Action | Expected Result |
|--------|----------------|
| Connect reader | Device appears in list |
| Tap device | Protocol dialog appears |
| Choose protocol | "Card connected!" message |
| SELECT MF | Green ✓, 90 00 success |
| Verify PIN (correct) | Green ✓, 90 00 success |
| Verify PIN (wrong) | Red ✗, 63 CX, attempts shown |
| PSO Sign (no PIN) | Red ✗, 69 82, suggestion shown |
| PSO Sign (with PIN) | Green ✓, signature data shown |
| GET CHALLENGE | Green ✓, 8 bytes random data |
| Batch Sign | "3/3 successful" message |
| View History | All operations listed |
| Expand operation | Steps shown with timing |
| Tap info icon | Step details dialog |
| Copy data | "Data copied!" message |

---

## 🎉 You're Done!

If you've completed all the tests, congratulations! Your enhanced smartcard app is working perfectly on a real device! 🚀

**Next steps:**
- Customize the UI to your needs
- Add more features
- Test with different cards
- Share with your team

---

**Need help?** Check the other documentation files:
- `QUICK_START_GUIDE.md` - Code examples
- `FEATURE_LIST.md` - All features
- `IMPROVEMENTS_SUMMARY.md` - Detailed guide
- `TESTING_GUIDE.md` - Comprehensive testing
