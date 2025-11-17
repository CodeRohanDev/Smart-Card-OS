# Quick Start Guide - Enhanced SmartCard Features

## 🚀 Getting Started

### 1. Import the New Models

```dart
import 'package:smartcardos/models/apdu_response.dart';
import 'package:smartcardos/models/operation_step.dart';
import 'package:smartcardos/services/smartcard_service.dart';
```

### 2. Use the Enhanced Screen

Update your navigation to use the new enhanced screen:

```dart
// In your USB reader screen or device list
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => EnhancedSmartCardScreen(
      deviceId: deviceId,
      deviceName: deviceName,
    ),
  ),
);
```

---

## 📝 Basic Usage Examples

### Example 1: Simple Command with Structured Response

```dart
final smartCardService = SmartCardService();

// Send command and get structured response
final response = await smartCardService.selectMFStructured();

if (response != null) {
  if (response.success) {
    print('✓ Success!');
    print('Data: ${response.formattedData}');
    print('Status: ${response.statusMessage}');
  } else {
    print('✗ Error: ${response.statusMessage}');
    if (response.errorSuggestion != null) {
      print('Suggestion: ${response.errorSuggestion}');
    }
  }
}
```

### Example 2: PIN Verification

```dart
// Verify PIN
final response = await smartCardService.verifyPin('1234');

if (response != null) {
  if (response.success) {
    print('PIN verified successfully!');
  } else {
    // Check for remaining attempts
    if (response.statusWord.startsWith('63 C')) {
      final attempts = int.parse(response.statusWord.substring(4), radix: 16);
      print('Wrong PIN! $attempts attempts remaining');
    } else if (response.statusWord == '69 83') {
      print('PIN is blocked!');
    }
  }
}
```

### Example 3: Read Data from Card

```dart
// Read binary data
final response = await smartCardService.readBinary(
  offset: 0,
  length: 256,
);

if (response != null && response.success) {
  print('Read ${response.dataLength} bytes');
  print('Data: ${response.formattedData}');
  
  // Process the data
  if (response.data != null) {
    processCardData(response.data!);
  }
}
```

### Example 4: Get Card Information

```dart
// Get card serial number
final serialResponse = await smartCardService.getCardSerialNumber();
if (serialResponse != null && serialResponse.success) {
  print('Card Serial: ${serialResponse.formattedData}');
}

// Get cardholder name
final nameResponse = await smartCardService.getCardholderName();
if (nameResponse != null && nameResponse.success) {
  print('Cardholder: ${nameResponse.formattedData}');
}
```

### Example 5: Complete Signing Operation with Logging

```dart
// Start logging the operation
smartCardService.startOperation('Digital Signature');

try {
  // Step 1: Select file
  final selectResp = await smartCardService.selectMFStructured();
  if (!selectResp!.success) throw Exception('Select failed');
  
  // Step 2: Verify PIN
  final pinResp = await smartCardService.verifyPin('1234');
  if (!pinResp!.success) throw Exception('PIN verification failed');
  
  // Step 3: Set security environment
  final mseResp = await smartCardService.mseRestoreStructured(algorithm: 'rsa');
  if (!mseResp!.success) throw Exception('MSE failed');
  
  // Step 4: Sign data
  final data = SmartCardService.generateRandomData32Bytes();
  final signResp = await smartCardService.psoDigitalSignatureStructured(data);
  
  if (signResp!.success) {
    print('Signature: ${signResp.formattedData}');
    smartCardService.endOperation(success: true);
  } else {
    throw Exception('Signature failed');
  }
} catch (e) {
  smartCardService.endOperation(success: false);
  print('Operation failed: $e');
}

// View operation history
final history = smartCardService.operationHistory;
if (history.isNotEmpty) {
  final lastOp = history.first;
  print('Operation: ${lastOp.name}');
  print('Duration: ${lastOp.totalDuration.inMilliseconds}ms');
  print('Steps: ${lastOp.successfulSteps}/${lastOp.steps.length}');
  
  // View each step
  for (var step in lastOp.steps) {
    print('  ${step.stepNumber}. ${step.stepName}: ${step.isSuccess ? "✓" : "✗"} (${step.duration.inMilliseconds}ms)');
  }
}
```

### Example 6: Batch Signing

```dart
// Generate multiple data blocks
final dataBlocks = List.generate(
  5,
  (i) => SmartCardService.generateRandomData32Bytes(),
);

print('Signing ${dataBlocks.length} blocks...');

// Batch sign (automatically logs operation)
final responses = await smartCardService.batchSign(
  dataBlocks,
  algorithm: 'rsa',
);

// Check results
final successful = responses.where((r) => r.success).length;
print('Results: $successful/${responses.length} successful');

// Process each signature
for (var i = 0; i < responses.length; i++) {
  if (responses[i].success) {
    print('Block $i signature: ${responses[i].formattedData}');
  } else {
    print('Block $i failed: ${responses[i].statusMessage}');
  }
}
```

### Example 7: Authentication Flow

```dart
// Get challenge from card
final challengeResp = await smartCardService.getChallenge(length: 8);

if (challengeResp != null && challengeResp.success) {
  final challenge = challengeResp.data!;
  print('Challenge: ${challengeResp.formattedData}');
  
  // Perform internal authentication
  final authResp = await smartCardService.internalAuthenticate(challenge);
  
  if (authResp != null && authResp.success) {
    print('Authentication successful!');
    print('Response: ${authResp.formattedData}');
  } else {
    print('Authentication failed: ${authResp?.statusMessage}');
  }
}
```

### Example 8: Read Records

```dart
// Read first 5 records
for (var i = 1; i <= 5; i++) {
  final response = await smartCardService.readRecord(recordNumber: i);
  
  if (response != null && response.success) {
    print('Record $i: ${response.formattedData}');
  } else if (response?.statusWord == '6A 83') {
    print('Record $i not found');
    break;
  }
}

// Read last record
final lastRecord = await smartCardService.readRecord(
  recordNumber: 0,
  mode: 0x05, // Read last
);

if (lastRecord != null && lastRecord.success) {
  print('Last record: ${lastRecord.formattedData}');
}
```

---

## 🎨 UI Integration Examples

### Example 1: Show Response in Dialog

```dart
void showResponseDialog(BuildContext context, ApduResponse response) {
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
          const Text('Response'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (response.data != null) ...[
            const Text('Data:', style: TextStyle(fontWeight: FontWeight.bold)),
            SelectableText(
              response.formattedData!,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            Text('${response.dataLength} bytes'),
            const SizedBox(height: 12),
          ],
          const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold)),
          Text('${response.statusWord} - ${response.statusMessage}'),
          if (response.errorSuggestion != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(child: Text(response.errorSuggestion!)),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (response.data != null)
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: response.data!));
            },
            child: const Text('Copy Data'),
          ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
```

### Example 2: Display Operation History

```dart
Widget buildOperationHistory(SmartCardService service) {
  final history = service.operationHistory;
  
  return ListView.builder(
    itemCount: history.length,
    itemBuilder: (context, index) {
      final operation = history[index];
      
      return ExpansionTile(
        leading: Icon(
          operation.success ? Icons.check_circle : Icons.error,
          color: operation.success ? Colors.green : Colors.red,
        ),
        title: Text(operation.name),
        subtitle: Text(
          '${operation.successfulSteps}/${operation.steps.length} steps - '
          '${operation.totalDuration.inMilliseconds}ms',
        ),
        children: operation.steps.map((step) {
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 12,
              backgroundColor: step.isSuccess ? Colors.green : Colors.red,
              child: Text('${step.stepNumber}'),
            ),
            title: Text(step.stepName),
            subtitle: Text(
              '${step.response.statusWord} - ${step.duration.inMilliseconds}ms',
            ),
          );
        }).toList(),
      );
    },
  );
}
```

### Example 3: Progress Indicator for Batch Operations

```dart
Future<void> performBatchSign(BuildContext context) async {
  final dataBlocks = List.generate(10, (i) => 
    SmartCardService.generateRandomData32Bytes()
  );
  
  // Show progress dialog
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('Signing ${dataBlocks.length} blocks...'),
        ],
      ),
    ),
  );
  
  // Perform batch sign
  final responses = await smartCardService.batchSign(
    dataBlocks,
    algorithm: 'rsa',
  );
  
  // Close progress dialog
  Navigator.pop(context);
  
  // Show results
  final successful = responses.where((r) => r.success).length;
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(successful == responses.length ? 'Success!' : 'Partial Success'),
      content: Text('$successful/${responses.length} signatures completed'),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
```

---

## 🔧 Error Handling Best Practices

### Pattern 1: Check Success First

```dart
final response = await smartCardService.selectMFStructured();

if (response == null) {
  print('Communication error');
  return;
}

if (!response.success) {
  print('Command failed: ${response.statusMessage}');
  if (response.errorSuggestion != null) {
    print('Try: ${response.errorSuggestion}');
  }
  return;
}

// Success - process data
if (response.data != null) {
  processData(response.data!);
}
```

### Pattern 2: Handle Specific Errors

```dart
final response = await smartCardService.verifyPin(pin);

if (response == null) return;

switch (response.statusWord.replaceAll(' ', '')) {
  case '9000':
    print('PIN verified!');
    break;
  case '6982':
    print('Security not satisfied');
    break;
  case '6983':
    print('PIN blocked - need PUK');
    break;
  case '6300':
    print('Wrong PIN - no attempts info');
    break;
  default:
    if (response.statusWord.startsWith('63 C')) {
      final attempts = int.parse(response.statusWord.substring(4), radix: 16);
      print('Wrong PIN - $attempts attempts left');
    } else {
      print('Unexpected error: ${response.statusMessage}');
    }
}
```

### Pattern 3: Retry Logic

```dart
Future<ApduResponse?> verifyPinWithRetry(String pin, {int maxAttempts = 3}) async {
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    final response = await smartCardService.verifyPin(pin);
    
    if (response == null) {
      print('Attempt $attempt: Communication error');
      await Future.delayed(const Duration(seconds: 1));
      continue;
    }
    
    if (response.success) {
      print('PIN verified on attempt $attempt');
      return response;
    }
    
    if (response.statusWord == '69 83') {
      print('PIN blocked - stopping retries');
      return response;
    }
    
    print('Attempt $attempt failed: ${response.statusMessage}');
  }
  
  return null;
}
```

---

## 📊 Comparison Table

| Feature | Old Method | New Method |
|---------|-----------|------------|
| **Response Type** | `String?` | `ApduResponse?` |
| **Data Extraction** | Manual parsing | `response.data` |
| **Status Check** | String comparison | `response.success` |
| **Error Message** | Manual lookup | `response.statusMessage` |
| **Error Help** | None | `response.errorSuggestion` |
| **Logging** | Manual | Automatic |
| **Timing** | Manual | Built-in |
| **History** | None | Full operation logs |

---

## 🎯 Next Steps

1. **Try the Enhanced Screen**
   - Run the app and navigate to `EnhancedSmartCardScreen`
   - Explore all 5 tabs
   - Test different commands

2. **Integrate into Your Existing Screens**
   - Replace `transmitApdu()` with `transmitApduStructured()`
   - Use `ApduResponse` for better error handling
   - Add operation logging for complex flows

3. **Customize for Your Needs**
   - Add more commands as needed
   - Customize the UI
   - Add export functionality for logs

4. **Read the Documentation**
   - Check `IMPROVEMENTS_SUMMARY.md` for detailed info
   - Refer to `ISO_7816_QUICK_REFERENCE.md` for ISO standard details

---

**You're now ready to use the enhanced smartcard features!** 🚀

For questions or issues, refer to the ISO 7816-4 standard documentation or the improvement summary.
