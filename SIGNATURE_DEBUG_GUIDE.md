# Signature Response Debug Guide

## Issue: "No signature data" after successful signing

When you see "No signature data" even though the status shows `90 00` (success), it means the card is returning only the status word without the actual signature data.

## Understanding the Response

### Expected Response Format:
```
[Signature Data] + [Status Word]
Example: 3A 5F 2C ... (64-256 bytes) + 90 00
         └─ Signature ─┘              └─ Status ─┘
```

### What You're Getting:
```
90 00
└─ Only Status Word ─┘
```

## Why This Happens

### 1. **Card Requires GET RESPONSE Command**
Some smartcards don't return data immediately. Instead, they return:
```
Response: 61 XX
          ││ └─ XX = number of bytes available
          └─ 61 = "More data available"
```

Then you must send:
```
Command: 00 C0 00 00 XX
         (GET RESPONSE with length XX)
```

### 2. **Wrong Security Environment**
The MSE RESTORE command might not have been executed, or used wrong algorithm:
- Make sure you called `MSE RESTORE RSA` or `MSE RESTORE ECC` first
- The algorithm must match your card's key type

### 3. **PIN Not Verified**
Some cards require PIN verification before signing:
```
Command: 00 20 00 00 08 [8-byte PIN]
Example: 00 20 00 00 08 31 32 33 34 FF FF FF FF
         (PIN "1234" padded with FF)
```

### 4. **Wrong File Selected**
You might need to select a specific key file before signing:
```
1. SELECT MF:  00 A4 00 00 02 3F 00
2. SELECT DF:  00 A4 00 00 02 [DF ID]
3. SELECT EF:  00 A4 02 0C 02 [Key File ID]
4. MSE RESTORE
5. PSO SIGN
```

### 5. **Card Returns Signature in Multiple Parts**
Some cards use command chaining and return signature in chunks.

## Debugging Steps

### Step 1: Check Raw Response
The updated dialog now shows "Raw Response" section. Look at it:

**If you see only `90 00`:**
- Card accepted command but returned no data
- Might need GET RESPONSE

**If you see `61 XX`:**
- Data is available, need GET RESPONSE
- XX tells you how many bytes to request

**If you see `69 82`:**
- Security conditions not satisfied
- Need PIN verification or MSE RESTORE

**If you see `6A 88`:**
- Referenced data not found
- Wrong key file or not selected

### Step 2: Check Console Logs
The app now prints debug info. Check your IDE console:
```
DEBUG - Raw response: 90 00
DEBUG - Response length: 4 chars
DEBUG - Parsed signature: 
DEBUG - Parsed status: 90 00
DEBUG - Signature length: 0 chars
```

### Step 3: Try Manual GET RESPONSE
If you see `61 XX` status:

1. Note the XX value (e.g., `61 80` means 128 bytes available)
2. Go to "Send APDU Command" field
3. Send: `00C00000XX` (replace XX with the length)
4. This should return the signature

### Step 4: Complete Signing Flow
Try this exact sequence:

```
1. SELECT MF
   Command: 00 A4 00 00 02 3F 00
   Expected: 90 00

2. SELECT DF (if needed)
   Command: 00 A4 00 00 02 6F 00
   Expected: 90 00

3. VERIFY PIN (if needed)
   Command: 00 20 00 00 08 [your PIN padded]
   Expected: 90 00

4. MSE RESTORE
   Command: 00 22 F3 03 (RSA) or 00 22 F3 0D (ECC)
   Expected: 90 00

5. PSO SIGN
   Command: 00 2A 9E 9A 20 [32 bytes data]
   Expected: [signature] 90 00 OR 61 XX

6. GET RESPONSE (if step 5 returned 61 XX)
   Command: 00 C0 00 00 XX
   Expected: [signature] 90 00
```

## Solutions

### Solution 1: Implement Automatic GET RESPONSE

Update `smartcard_service.dart`:

```dart
Future<String?> psoDigitalSignature(String data) async {
  final cleanData = data.replaceAll(' ', '').toUpperCase();
  
  if (!RegExp(r'^[0-9A-F]+$').hasMatch(cleanData)) {
    throw ArgumentError('Data must be in hexadecimal format');
  }
  
  if (cleanData.length != 64) {
    throw ArgumentError('Data must be exactly 32 bytes');
  }
  
  final length = '20';
  final apdu = '002A9E9A$length$cleanData';
  
  // Send PSO command
  final response = await transmitApdu(apdu);
  
  if (response == null) return null;
  
  // Check if response is 61 XX (data available)
  final clean = response.replaceAll(' ', '').toUpperCase();
  if (clean.startsWith('61')) {
    // Extract length
    final dataLength = clean.substring(2, 4);
    // Send GET RESPONSE
    final getResponseCmd = '00C00000$dataLength';
    return await transmitApdu(getResponseCmd);
  }
  
  return response;
}
```

### Solution 2: Add PIN Verification

Add to `smartcard_service.dart`:

```dart
/// Verify PIN
/// @param pin: PIN as hex string (will be padded to 8 bytes)
Future<String?> verifyPin(String pin) async {
  // Convert PIN to hex if it's numeric
  String hexPin = '';
  if (RegExp(r'^\d+$').hasMatch(pin)) {
    // Numeric PIN - convert each digit to hex
    for (int i = 0; i < pin.length; i++) {
      hexPin += pin.codeUnitAt(i).toRadixString(16).padLeft(2, '0');
    }
  } else {
    hexPin = pin;
  }
  
  // Pad to 8 bytes (16 hex chars) with FF
  hexPin = hexPin.padRight(16, 'F');
  
  return await transmitApdu('0020000008$hexPin');
}
```

### Solution 3: Check Card Documentation

Every smartcard is different. You need to:

1. **Find your card's datasheet**
   - Search for your card model + "datasheet"
   - Look for APDU command reference

2. **Check signing requirements**
   - Does it need PIN?
   - Which files to select?
   - What's the correct MSE command?
   - Does it use GET RESPONSE?

3. **Look for example code**
   - Search for your card model + "APDU examples"
   - Check manufacturer's SDK

## Testing with Known Cards

### JavaCard / JCOP Cards:
```
1. SELECT MF: 00 A4 00 00 02 3F 00
2. VERIFY PIN: 00 20 00 00 08 31 32 33 34 FF FF FF FF
3. MSE RESTORE: 00 22 41 B6 06 84 01 81 80 01 02
4. PSO SIGN: 00 2A 9E 9A 20 [data]
```

### PIV Cards (Personal Identity Verification):
```
1. SELECT PIV APP: 00 A4 04 00 09 A0 00 00 03 08 00 00 10 00
2. VERIFY PIN: 00 20 00 80 08 [PIN]
3. GENERAL AUTHENTICATE: 00 87 07 9A [data]
```

### OpenPGP Cards:
```
1. SELECT OpenPGP: 00 A4 04 00 06 D2 76 00 01 24 01
2. VERIFY PIN: 00 20 00 81 [PIN length] [PIN]
3. PSO SIGN: 00 2A 9E 9A [data length] [data]
```

## Next Steps

1. **Run the app and try signing**
2. **Check the "Raw Response" in the dialog**
3. **Check console logs for DEBUG messages**
4. **Share the raw response here for analysis**
5. **Check your card's documentation**

## Common Response Patterns

| Response | Meaning | Action |
|----------|---------|--------|
| `90 00` only | Success but no data | Check if signature was expected |
| `61 XX` | Data available | Send GET RESPONSE (00 C0 00 00 XX) |
| `6C XX` | Wrong length | Resend with correct Le (XX) |
| `69 82` | Security not satisfied | Verify PIN or set MSE |
| `69 85` | Conditions not satisfied | Check file selection |
| `6A 88` | Data not found | Select correct key file |
| `6D 00` | Command not supported | Card doesn't support PSO |

## Example Debug Output

**Good Response (with signature):**
```
DEBUG - Raw response: 3A 5F 2C 8B ... (128 bytes) ... 90 00
DEBUG - Response length: 260 chars (130 bytes)
DEBUG - Parsed signature: 3A 5F 2C 8B ... (126 bytes)
DEBUG - Parsed status: 90 00
DEBUG - Signature length: 252 chars (126 bytes)
```

**Bad Response (no signature):**
```
DEBUG - Raw response: 90 00
DEBUG - Response length: 4 chars (2 bytes)
DEBUG - Parsed signature: 
DEBUG - Parsed status: 90 00
DEBUG - Signature length: 0 chars (0 bytes)
```

**Response needs GET RESPONSE:**
```
DEBUG - Raw response: 61 80
DEBUG - Response length: 4 chars (2 bytes)
DEBUG - Parsed signature: 
DEBUG - Parsed status: 61 80
DEBUG - Signature length: 0 chars (0 bytes)
→ Need to send: 00 C0 00 00 80
```

---

**Remember**: The card is working (status `90 00`), but it's not returning the signature data in the response. This is a protocol/flow issue, not a code bug.
