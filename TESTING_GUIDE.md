# 🧪 Testing Guide - Enhanced SmartCard Features

## 🚀 Quick Start Testing

### Step 1: Update Your Navigation

First, let's add the enhanced screen to your app navigation.

**Option A: Replace existing screen (Recommended for testing)**

Open `lib/screens/usb_reader_screen.dart` and find where you navigate to `SmartCardScreen`. Replace it with:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => EnhancedSmartCardScreen(
      deviceId: device['deviceId'],
      deviceName: device['deviceName'],
    ),
  ),
);
```

**Option B: Add as a new option (Keep both screens)**

Add a button to choose which screen to use:

```dart
// Show dialog to choose screen
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Choose Screen'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SmartCardScreen(
                  deviceId: device['deviceId'],
                  deviceName: device['deviceName'],
                ),
              ),
            );
          },
          child: const Text('Original Screen'),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EnhancedSmartCardScreen(
                  deviceId: device['deviceId'],
                  deviceName: device['deviceName'],
                ),
              ),
            );
          },
          child: const Text('Enhanced Screen (NEW)'),
        ),
      ],
    ),
  ),
);
```

### Step 2: Add Import

Add this import at the top of your file:

```dart
import '../screens/enhanced_smartcard_screen.dart';
```

---

## 🧪 Testing Checklist

### ✅ Phase 1: Basic Connection (5 minutes)

1. **Connect USB Reader**
   - Plug in your USB smartcard reader
   - Insert a smartcard

2. **Launch App**
   - Run the app: `flutter run`
   - You should see the USB device list

3. **Connect to Card**
   - Tap on your USB reader device
   - Choose protocol (T=1 recommended)
   - Wait for "Card connected!" message
   - You should see the enhanced screen with 5 tabs

**Expected Result:**
- ✅ Green "Card Connected" banner
- ✅ ATR displayed
- ✅ 5 tabs visible (Basic, Security, Data, Advanced, History)

---

### ✅ Phase 2: Basic Operations (10 minutes)

**Tab 1: Basic Operations**

1. **Test SELECT MF**
   - Tap "SELECT MF" button
   - Response dialog should appear
   - Check:
     - ✅ Green checkmark icon
     - ✅ Status: "90 00 - ✓ Success"
     - ✅ Data displayed (if any)
     - ✅ "Copy Data" button works

2. **Test SELECT DF**
   - Tap "SELECT DF" button
   - Check response dialog
   - May fail if DF doesn't exist (that's OK)

3. **Test MSE RESTORE RSA**
   - Tap "MSE RSA" button
   - Should see success or error
   - Note the status word

4. **Test MSE RESTORE ECC**
   - Tap "MSE ECC" button
   - Check response

5. **Test PSO Sign**
   - Tap "PSO Sign (32 bytes)" button
   - Should generate random data and sign
   - Check response dialog shows signature data

**Expected Results:**
- ✅ All buttons respond
- ✅ Response dialogs show structured data
- ✅ Status words are parsed correctly
- ✅ Success/error icons are correct

---

### ✅ Phase 3: Security Operations (10 minutes)

**Tab 2: Security Operations**

1. **Test VERIFY PIN**
   - Enter PIN in text field (e.g., "1234")
   - Tap "Verify PIN" button
   - Check response:
     - ✅ Success (90 00) if correct
     - ✅ "63 CX" if wrong (X = attempts left)
     - ✅ Error suggestion appears if wrong

2. **Test Wrong PIN**
   - Enter wrong PIN (e.g., "0000")
   - Tap "Verify PIN"
   - Check:
     - ✅ Red error icon
     - ✅ Status shows attempts remaining
     - ✅ Error suggestion: "You have X attempts remaining..."

3. **Test GET CHALLENGE**
   - Tap "GET CHALLENGE" button
   - Should return 8 bytes of random data
   - Check:
     - ✅ Data is 8 bytes (16 hex chars)
     - ✅ Formatted with spaces

4. **Test INTERNAL AUTHENTICATE**
   - Tap "INTERNAL AUTHENTICATE" button
   - Uses auto-generated challenge
   - May fail if PIN not verified (that's OK)
   - Check error suggestion if fails

**Expected Results:**
- ✅ PIN verification works
- ✅ Attempt counter decrements on wrong PIN
- ✅ Error suggestions appear
- ✅ Challenge returns random data

---

### ✅ Phase 4: Data Operations (10 minutes)

**Tab 3: Data Operations**

1. **Test READ BINARY**
   - Tap "READ BINARY (256 bytes)" button
   - May fail if no file selected
   - If fails, check error suggestion
   - If succeeds, check data length

2. **Test READ RECORD**
   - Tap "READ RECORD #1" button
   - May fail if no record file selected
   - Check error message

3. **Test Get Card Serial**
   - Tap "Get Card Serial Number" button
   - May return data or error depending on card
   - Check:
     - ✅ If success: shows card number
     - ✅ If error: shows "File not found" or similar

4. **Test Get Cardholder Name**
   - Tap "Get Cardholder Name" button
   - Check response

**Expected Results:**
- ✅ Commands execute
- ✅ Errors are handled gracefully
- ✅ Error suggestions are helpful
- ✅ Data is formatted correctly

---

### ✅ Phase 5: Advanced Operations (15 minutes)

**Tab 4: Advanced Operations**

1. **Test Batch Sign**
   - Tap "Batch Sign (3 blocks)" button
   - Should sign 3 random data blocks
   - Watch for:
     - ✅ Processing indicator
     - ✅ Success message: "Batch complete: X/3 successful"
   - Check History tab after

2. **Test Custom APDU**
   - Enter a known APDU (e.g., `00A40000023F00`)
   - Tap "Send Custom APDU" button
   - Check response dialog
   - Try different APDUs:
     - `00A40000023F00` - SELECT MF
     - `0084000008` - GET CHALLENGE
     - `00CA005A00` - GET DATA (serial)

**Expected Results:**
- ✅ Batch operation completes
- ✅ Custom APDU works
- ✅ All responses are structured
- ✅ Operation is logged

---

### ✅ Phase 6: Operation History (10 minutes)

**Tab 5: History**

1. **View Operation Logs**
   - After running batch sign, go to History tab
   - Should see "Batch Sign 3 blocks" operation
   - Tap to expand
   - Check:
     - ✅ Shows all steps
     - ✅ Each step has timing
     - ✅ Success/failure icons
     - ✅ Step numbers (1, 2, 3...)

2. **View Step Details**
   - Tap the info icon (ℹ️) on any step
   - Should show response dialog for that step
   - Check:
     - ✅ Command APDU shown
     - ✅ Response data shown
     - ✅ Status word shown
     - ✅ Timing shown

3. **Check Multiple Operations**
   - Run several operations
   - Go to History tab
   - Should see all operations listed
   - Most recent at top

**Expected Results:**
- ✅ All operations are logged
- ✅ Step-by-step details available
- ✅ Timing information accurate
- ✅ Can view individual step responses

---

## 🎯 Specific Test Scenarios

### Scenario 1: Complete Signing Flow

**Goal:** Test the full signing process with logging

**Steps:**
1. Go to Basic tab
2. Tap "SELECT MF" → Should succeed
3. Go to Security tab
4. Enter PIN and tap "Verify PIN" → Should succeed
5. Go to Basic tab
6. Tap "MSE RSA" → Should succeed
7. Tap "PSO Sign" → Should succeed
8. Go to History tab
9. Check that all steps are logged

**Expected:**
- ✅ All 4 steps succeed
- ✅ Each step logged separately
- ✅ Total timing shown
- ✅ Signature data displayed

---

### Scenario 2: Error Handling Test

**Goal:** Test error suggestions

**Steps:**
1. Go to Basic tab
2. Tap "PSO Sign" WITHOUT verifying PIN
3. Should fail with "69 82"
4. Check error suggestion

**Expected:**
- ✅ Error icon (red)
- ✅ Status: "69 82 - ✗ Security status not satisfied"
- ✅ Suggestion: "You need to verify PIN first. Tap 'Verify PIN' button."

---

### Scenario 3: Batch Operation Test

**Goal:** Test batch signing with logging

**Steps:**
1. Go to Security tab
2. Verify PIN
3. Go to Basic tab
4. Tap "MSE RSA"
5. Go to Advanced tab
6. Tap "Batch Sign (3 blocks)"
7. Wait for completion
8. Go to History tab
9. Expand the batch operation

**Expected:**
- ✅ Shows "Batch Sign 3 blocks" operation
- ✅ Multiple steps visible (SELECT MF, MSE, SIGN 1, SIGN 2, SIGN 3)
- ✅ Each signature step has data
- ✅ Total timing shown
- ✅ Success count: "3/3 steps"

---

### Scenario 4: Data Reading Test

**Goal:** Test reading data from card

**Steps:**
1. Go to Basic tab
2. Tap "SELECT MF"
3. Go to Data tab
4. Tap "READ BINARY (256 bytes)"
5. Check response

**Expected:**
- ✅ Either succeeds with data
- ✅ Or fails with helpful error
- ✅ Error suggestion if fails

---

## 🐛 Troubleshooting

### Issue: "Card not connected"

**Solution:**
1. Check USB reader is plugged in
2. Check card is inserted
3. Try reconnecting
4. Check USB permissions

### Issue: All commands fail with "69 82"

**Solution:**
1. Go to Security tab
2. Verify PIN first
3. Then try other commands

### Issue: "File not found" errors

**Solution:**
1. Some cards don't have all files
2. Try SELECT MF first
3. Check card documentation

### Issue: Response dialog doesn't show data

**Solution:**
1. Check if command actually returns data
2. Some commands only return status word
3. Check History tab for details

### Issue: Batch sign fails

**Solution:**
1. Verify PIN first
2. Run MSE RESTORE first
3. Check each step in History tab

---

## 📊 Testing Matrix

| Feature | Test | Expected Result | Status |
|---------|------|-----------------|--------|
| **Connection** | Connect to card | Green banner, ATR shown | ⬜ |
| **SELECT MF** | Tap button | 90 00 success | ⬜ |
| **SELECT DF** | Tap button | Success or error | ⬜ |
| **MSE RSA** | Tap button | 90 00 success | ⬜ |
| **MSE ECC** | Tap button | Success or error | ⬜ |
| **PSO Sign** | Tap button | Signature data | ⬜ |
| **Verify PIN (correct)** | Enter PIN, tap | 90 00 success | ⬜ |
| **Verify PIN (wrong)** | Enter wrong PIN | 63 CX with attempts | ⬜ |
| **GET CHALLENGE** | Tap button | 8 bytes random data | ⬜ |
| **INTERNAL AUTH** | Tap button | Success or error | ⬜ |
| **READ BINARY** | Tap button | Data or error | ⬜ |
| **READ RECORD** | Tap button | Data or error | ⬜ |
| **Get Serial** | Tap button | Serial or error | ⬜ |
| **Get Name** | Tap button | Name or error | ⬜ |
| **Batch Sign** | Tap button | 3 signatures | ⬜ |
| **Custom APDU** | Enter APDU, tap | Response shown | ⬜ |
| **History View** | Go to History tab | Operations listed | ⬜ |
| **Step Details** | Tap info icon | Step response shown | ⬜ |
| **Copy Data** | Tap copy button | Data copied | ⬜ |
| **Error Suggestion** | Cause error | Suggestion shown | ⬜ |

---

## 🎥 Video Testing Guide

### Recording Your Test

1. **Screen Record** (Optional)
   - Start screen recording
   - Go through each tab
   - Try each feature
   - Show success and errors

2. **Take Screenshots**
   - Response dialogs
   - Operation history
   - Error suggestions
   - Each tab

---

## 📝 Test Report Template

```
# Test Report - Enhanced SmartCard Features

**Date:** [Date]
**Tester:** [Your Name]
**Device:** [Phone/Tablet Model]
**Card Type:** [SmartCard Type]
**Reader:** [USB Reader Model]

## Test Results

### Phase 1: Connection
- [ ] Card connected successfully
- [ ] ATR displayed
- [ ] 5 tabs visible

### Phase 2: Basic Operations
- [ ] SELECT MF works
- [ ] SELECT DF works
- [ ] MSE RSA works
- [ ] MSE ECC works
- [ ] PSO Sign works

### Phase 3: Security
- [ ] PIN verification works
- [ ] Wrong PIN shows attempts
- [ ] GET CHALLENGE works
- [ ] INTERNAL AUTH works

### Phase 4: Data
- [ ] READ BINARY works
- [ ] READ RECORD works
- [ ] Get Serial works
- [ ] Get Name works

### Phase 5: Advanced
- [ ] Batch Sign works
- [ ] Custom APDU works

### Phase 6: History
- [ ] Operations logged
- [ ] Steps visible
- [ ] Timing shown
- [ ] Details accessible

## Issues Found
[List any issues]

## Screenshots
[Attach screenshots]

## Notes
[Any additional notes]
```

---

## 🚀 Quick Test (5 minutes)

If you're short on time, test these essentials:

1. ✅ Connect to card
2. ✅ SELECT MF (Basic tab)
3. ✅ Verify PIN (Security tab)
4. ✅ PSO Sign (Basic tab)
5. ✅ View History (History tab)

If these work, the core functionality is good!

---

## 💡 Tips

1. **Start Simple**
   - Test Basic tab first
   - Then Security
   - Then Data
   - Then Advanced

2. **Check History Often**
   - After each operation
   - Verify logging works
   - Check timing

3. **Test Errors**
   - Try wrong PIN
   - Try commands without PIN
   - Check error suggestions

4. **Use Copy Feature**
   - Copy data to verify
   - Paste in notes
   - Compare results

5. **Read Suggestions**
   - Error suggestions are helpful
   - Follow the advice
   - Learn the flow

---

## ✅ Success Criteria

Your implementation is working if:

- ✅ All tabs load without crashes
- ✅ Response dialogs show structured data
- ✅ Status words are parsed correctly
- ✅ Error suggestions appear
- ✅ Operation history logs everything
- ✅ Copy to clipboard works
- ✅ Timing information is accurate

---

**Ready to test? Start with Phase 1 and work your way through!** 🚀

Good luck! 🎉
