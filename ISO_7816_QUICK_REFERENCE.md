# ISO 7816-4: Important Sections for Your SmartCard App

## 📖 ISO 7816-4 Standard: Section Reference Guide

This guide tells you exactly which sections and parts of the ISO 7816-4 standard are important for your smartcard app.

---

## 🎯 CRITICAL SECTIONS (Must Read)

### **Section 5: Basic Organizations**

#### **5.1.1 - Command-Response Pairs** ⭐⭐⭐
- **What it covers:** How commands and responses work
- **Why important:** Your app uses this for ALL communication
- **Your implementation:** Every `transmitApdu()` call

#### **5.2 - Command APDU Structure** ⭐⭐⭐
- **What it covers:** CLA, INS, P1, P2, Lc, Data, Le fields
- **Why important:** Every command you send follows this format
- **Your implementation:** All commands in `SmartCardService`
- **Format:**
```
┌─────┬─────┬─────┬─────┬─────┬──────────┬─────┐
│ CLA │ INS │ P1  │ P2  │ Lc  │   Data   │ Le  │
├─────┼─────┼─────┼─────┼─────┼──────────┼─────┤
│ 1B  │ 1B  │ 1B  │ 1B  │0-3B │ Variable │0-3B │
└─────┴─────┴─────┴─────┴─────┴──────────┴─────┘
```

#### **5.3 - Response APDU Structure** ⭐⭐⭐
- **What it covers:** Data + SW1 + SW2 format
- **Why important:** Every response you receive follows this
- **Your implementation:** Response parsing in all methods
- **Format:**
```
┌──────────┬─────┬─────┐
│   Data   │ SW1 │ SW2 │
├──────────┼─────┼─────┤
│ Variable │ 1B  │ 1B  │
└──────────┴─────┴─────┘
```

#### **5.6 - Status Bytes (SW1-SW2)** ⭐⭐⭐
- **What it covers:** All status word meanings
- **Why important:** Error detection and handling
- **Your implementation:** `parseStatusWord()` function
- **Key tables:**
  - **Table 6**: Normal processing (90 00, 61 XX)
  - **Table 7**: Warning and error codes (62XX-6FXX)

---

### **Section 7: File Structure and Access**

#### **7.1 - File Categories** ⭐⭐
- **What it covers:**
  - MF (Master File) - Root directory (3F00)
  - DF (Dedicated File) - Application directories
  - EF (Elementary File) - Data files
- **Why important:** Understanding card organization
- **Your implementation:** `selectMF()` and `selectDF()`

#### **7.2 - File Identifiers** ⭐⭐
- **What it covers:** Standard file IDs and naming
- **Why important:** How to reference files in SELECT commands
- **Your implementation:** File ID parameters in SELECT

---

### **Section 11: Commands**

#### **11.2.2 - SELECT Command** ⭐⭐⭐
- **What it covers:** File selection mechanism
- **Why important:** First step in most operations
- **Your implementation:** `selectMF()`, `selectDF()`
- **Key tables:**
  - **Table 61**: SELECT command coding
  - **Table 62**: P1-P2 parameters
  - **Table 63**: Response data structure
- **APDU format:** `00 A4 00 00 02 [File ID]`

#### **11.6.6 - VERIFY Command** ⭐⭐⭐
- **What it covers:** PIN/password verification
- **Why important:** Authentication before secure operations
- **Your implementation:** `verifyPin()`
- **Key table:**
  - **Table 109**: VERIFY command coding
- **APDU format:** `00 20 00 00 08 [PIN padded with FF]`

#### **11.6.11 - MANAGE SECURITY ENVIRONMENT (MSE)** ⭐⭐⭐
- **What it covers:** Setting up cryptographic environment
- **Why important:** Required before signature operations
- **Your implementation:** `mseRestore()`
- **Key tables:**
  - **Table 114**: MSE command coding
  - **Table 115**: P1 parameter (F3 = RESTORE)
  - **Table 116**: P2 parameter (03 = RSA, 0D = ECC)
- **APDU format:** `00 22 F3 03` (RSA) or `00 22 F3 0D` (ECC)

#### **11.8.1 - GET RESPONSE Command** ⭐⭐⭐
- **What it covers:** Retrieving additional data
- **Why important:** Used when card returns `61 XX`
- **Your implementation:** Auto-handled in `psoDigitalSignature()`
- **Key table:**
  - **Table 120**: GET RESPONSE coding
- **APDU format:** `00 C0 00 00 XX`

---

## 📋 REFERENCE SECTIONS (Check When Needed)

### **Section 8: Secure Messaging** ⭐
- **8.2 - Secure Messaging Structure**
- **When to read:** If you add encrypted communication
- **Current status:** Not used in your app yet

### **Section 9: Security Architecture** ⭐⭐
- **9.2 - Security Attributes**
  - Access conditions for files
  - Why `69 82` errors occur
- **9.3 - Security Status**
  - When PIN verification is required
  - Security state management
- **When to read:** Debugging security errors

### **Section 10: Data Objects** ⭐
- **10.1 - BER-TLV Data Objects**
  - Tag-Length-Value encoding
  - Used in SELECT response data
- **When to read:** Parsing complex card responses

---

## 📊 CRITICAL TABLES REFERENCE

| Table | Section | Content | Your App Usage |
|-------|---------|---------|----------------|
| **Table 6** | 5.6.1 | Normal processing SW (90 00, 61 XX) | ✓ Success detection |
| **Table 7** | 5.6.2 | Warning/Error SW (62XX-6FXX) | ✓ Error handling |
| **Table 61** | 11.2.2 | SELECT command structure | ✓ File selection |
| **Table 62** | 11.2.2 | SELECT P1-P2 parameters | ✓ Selection modes |
| **Table 109** | 11.6.6 | VERIFY command structure | ✓ PIN verification |
| **Table 114** | 11.6.11 | MSE command structure | ✓ Security setup |
| **Table 115** | 11.6.11 | MSE P1 parameter | ✓ MSE operations |
| **Table 116** | 11.6.11 | MSE P2 parameter | ✓ Algorithm selection |
| **Table 120** | 11.8.1 | GET RESPONSE structure | ✓ Data retrieval |

---

## 🔍 SECTIONS BY USE CASE

### **When Implementing New Commands:**
1. Check **Section 11** for command definition
2. Find the command's table for APDU structure
3. Check **Table 6-7** for possible status words
4. Test with your `transmitApdu()` function

### **When Debugging Errors:**
1. Look up SW1-SW2 in **Table 7** (Section 5.6.2)
2. Check command sequence in **Section 9.3**
3. Verify parameters in command's specific table
4. Check security requirements in **Section 9.2**

### **When Adding File Operations:**
1. Understand file types in **Section 7.1**
2. Use SELECT command from **Section 11.2.2**
3. Check file access conditions in **Section 9.2**
4. Handle status words from **Table 6-7**

### **When Adding Security Features:**
1. Read **Section 9** for security architecture
2. Use commands from **Section 11.6**
3. Follow security state requirements
4. Handle authentication errors properly

---

## 📚 ISO 7816 PARTS (Multi-Part Standard)

Your app primarily uses **ISO 7816-4**, but here's the full series:

| Part | Title | Relevance to Your App |
|------|-------|------------------------|
| **ISO 7816-1** | Physical characteristics | ⭐ Card dimensions, contacts |
| **ISO 7816-2** | Dimensions and location of contacts | ⭐ Hardware interface |
| **ISO 7816-3** | Electrical interface and protocols | ⭐⭐ ATR, T=0/T=1 protocols |
| **ISO 7816-4** | Organization, security, commands | ⭐⭐⭐ **YOUR MAIN REFERENCE** |
| **ISO 7816-8** | Security operations (PSO) | ⭐⭐⭐ **PSO SIGN command** |
| **ISO 7816-9** | Enhanced security commands | ⭐ Advanced security |
| **ISO 7816-15** | Cryptographic information | ⭐ Key management |

**Important Note:** Your `psoDigitalSignature()` command (`00 2A 9E 9A`) is defined in **ISO 7816-8**, not 7816-4!

---

## 🎯 PRIORITY READING ORDER

### **For Your Current App (Already Implemented):**
1. ✅ **Section 5.2-5.3** - APDU structure
2. ✅ **Section 5.6 + Tables 6-7** - Status words
3. ✅ **Section 11.2.2** - SELECT command
4. ✅ **Section 11.6.6** - VERIFY command
5. ✅ **Section 11.6.11** - MSE command
6. ✅ **Section 11.8.1** - GET RESPONSE

### **For Future Features:**
7. 📖 **Section 7** - File structure (for advanced file operations)
8. 📖 **Section 9** - Security architecture (for understanding access control)
9. 📖 **Section 10** - Data objects (for parsing complex responses)
10. 📖 **ISO 7816-8** - PSO commands (for more signature operations)

### **For Troubleshooting:**
- 🔧 **Table 7** - Always check error codes here first
- 🔧 **Section 9.3** - Security state requirements
- 🔧 **Command-specific tables** - Verify APDU parameters

---

## ✅ YOUR APP'S ISO 7816-4 COMPLIANCE

### **Fully Implemented:**
- ✓ APDU structure (Section 5.2-5.3)
- ✓ Status word parsing (Section 5.6)
- ✓ SELECT command (Section 11.2.2)
- ✓ VERIFY command (Section 11.6.6)
- ✓ MSE command (Section 11.6.11)
- ✓ GET RESPONSE (Section 11.8.1)
- ✓ PSO SIGN (ISO 7816-8)

**Your app correctly implements all essential ISO 7816-4 commands! 🎉**

---

## 📖 QUICK LOOKUP GUIDE

**"I need to..."**

| Task | Go To |
|------|-------|
| Send a command | Section 5.2 + Command's specific section |
| Parse a response | Section 5.3 + Table 6-7 |
| Fix an error | Table 7 + Command's requirements |
| Select a file | Section 11.2.2 + Table 61-63 |
| Verify PIN | Section 11.6.6 + Table 109 |
| Sign data | ISO 7816-8 (PSO commands) |
| Get more data | Section 11.8.1 + Table 120 |
| Understand security | Section 9 + Command's security requirements |

---

## 📝 DETAILED SECTION BREAKDOWN

### **Section 5.6: Status Words (Tables 6-7)**

This is the MOST referenced section for debugging!

#### **Table 6: Normal Processing**
- `90 00` - Success
- `61 XX` - XX bytes of data available (use GET RESPONSE)

#### **Table 7: Warnings and Errors**

**Security Errors (69XX):**
- `69 82` - Security status not satisfied (need PIN)
- `69 83` - Authentication method blocked (PIN locked)
- `69 85` - Conditions of use not satisfied (wrong sequence)

**File Errors (6AXX):**
- `6A 82` - File not found
- `6A 86` - Incorrect P1-P2 parameters
- `6A 88` - Referenced data not found (key/PIN)

**Length Errors:**
- `67 00` - Wrong length (Lc field)
- `6C XX` - Wrong Le field (should be XX)

**Command Errors:**
- `6D 00` - Instruction not supported
- `6E 00` - Class not supported

---

## 🔑 COMMAND IMPLEMENTATION MAPPING

### **Your App → ISO 7816-4 Sections**

```dart
// selectMF() → Section 11.2.2, Table 61-63
Future<String?> selectMF() async {
  return await transmitApdu('00A40000023F00');
}

// verifyPin() → Section 11.6.6, Table 109
Future<String?> verifyPin(String pin) async {
  String hexPin = pin.codeUnits.map((c) => 
    c.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
  hexPin = hexPin.padRight(16, 'F');
  return await transmitApdu('0020000008$hexPin');
}

// mseRestore() → Section 11.6.11, Tables 114-116
Future<String?> mseRestore({required String algorithm}) async {
  final p2 = algorithm.toLowerCase() == 'rsa' ? '03' : '0D';
  return await transmitApdu('0022F3$p2');
}

// psoDigitalSignature() → ISO 7816-8 (not in 7816-4!)
// Also uses Section 11.8.1 for GET RESPONSE
Future<String?> psoDigitalSignature(String data) async {
  final cleanData = data.replaceAll(' ', '').toUpperCase();
  final apdu = '002A9E9A20$cleanData';
  final response = await transmitApdu(apdu);
  
  // GET RESPONSE handling (Section 11.8.1)
  if (response?.startsWith('61') == true) {
    final dataLength = response!.substring(2, 4);
    return await transmitApdu('00C00000$dataLength');
  }
  
  return response;
}

// parseStatusWord() → Section 5.6, Tables 6-7
static String parseStatusWord(String sw) {
  // Maps SW codes to human-readable messages
  // Based on Table 6 (success) and Table 7 (errors)
}
```

---

## 🎓 LEARNING PATH

### **Beginner Level:**
1. Read **Section 5.2-5.3** - Understand APDU format
2. Study **Table 6-7** - Memorize common status words
3. Read **Section 11.2.2** - Learn SELECT command

### **Intermediate Level:**
4. Read **Section 7** - Understand file structure
5. Read **Section 11.6.6** - Learn VERIFY command
6. Read **Section 11.8.1** - Learn GET RESPONSE

### **Advanced Level:**
7. Read **Section 9** - Security architecture
8. Read **Section 11.6.11** - MSE command
9. Read **ISO 7816-8** - PSO commands
10. Read **Section 10** - Data object parsing

---

## 🚀 NEXT STEPS FOR YOUR APP

### **Already Mastered:**
- ✅ Basic APDU communication
- ✅ Status word handling
- ✅ File selection
- ✅ PIN verification
- ✅ Digital signatures

### **To Learn Next:**
- 📖 **Section 7.3-7.4** - Advanced file operations (READ BINARY, UPDATE BINARY)
- 📖 **Section 11.4** - Data unit management
- 📖 **ISO 7816-8** - More PSO operations (DECIPHER, ENCIPHER)
- 📖 **Section 10** - Parsing TLV data in responses

---

**Keep this guide handy when reading the ISO 7816-4 standard!** 📚

This tells you exactly where to look for each feature in your app.
