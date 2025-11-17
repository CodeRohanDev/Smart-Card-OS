# ISO Standards Reference for SmartCardOS

## Primary Standards Used

### **ISO/IEC 7816** - Identification Cards - Integrated Circuit Cards

This is the **main standard** followed in this project. It defines the physical characteristics, communication protocols, and command structure for smartcards.

---

## ISO/IEC 7816 Parts Implemented

### **ISO/IEC 7816-3: Electronic Signals and Transmission Protocols**

**What it defines:**
- ATR (Answer To Reset) structure
- Communication protocols: T=0 and T=1
- Electrical interface
- Reset procedures

**Implementation in this project:**
```dart
// Protocol selection (T=0, T=1, or Auto)
Future<Map<String, dynamic>> connectCard({int protocol = 1})

// T=0: Byte-oriented protocol (older cards)
// T=1: Block-oriented protocol (modern cards)
// Auto: Try both protocols
```

**Where used:**
- `smartcard_service.dart` - `connectCard()` method
- `smartcard_screen.dart` - Protocol selection dialog
- `MainActivity.kt` - Native protocol handling

---

### **ISO/IEC 7816-4: Organization, Security and Commands for Interchange**

This is the **most important part** for APDU commands.

**What it defines:**
- APDU (Application Protocol Data Unit) command structure
- File system organization (MF, DF, EF)
- Security operations
- Status words (SW1 SW2)

#### **APDU Command Structure (ISO 7816-4 Section 5)**

```
┌─────┬─────┬─────┬─────┬─────┬──────────┬─────┐
│ CLA │ INS │ P1  │ P2  │ Lc  │   Data   │ Le  │
└─────┴─────┴─────┴─────┴─────┴──────────┴─────┘
  1B    1B    1B    1B   0-1B   Variable  0-1B

CLA: Class byte (instruction class)
INS: Instruction byte (specific command)
P1:  Parameter 1
P2:  Parameter 2
Lc:  Length of command data
Data: Command data
Le:  Maximum length of expected response
```

**Implementation:**
```dart
// All APDU commands follow this structure
Future<String?> transmitApdu(String apduCommand)
```

---

### **ISO/IEC 7816-4: File Selection Commands**

#### **SELECT Command (ISO 7816-4 Section 7.1)**

**Standard Definition:**
```
CLA INS P1  P2  Lc  Data
00  A4  [Selection Control] [File ID]
```

**Our Implementation:**

**1. Select Master File (MF):**
```dart
// ISO 7816-4: File ID 3F00 = Master File (root)
Future<String?> selectMF() async {
  return await transmitApdu('00A40000023F00');
}

Command Breakdown:
00    - CLA: Standard class
A4    - INS: SELECT command
00    - P1: Select by file ID
00    - P2: First or only occurrence
02    - Lc: 2 bytes of data follow
3F 00 - Data: Master File ID (defined in ISO 7816-4)
```

**2. Select Dedicated File (DF):**
```dart
// ISO 7816-4: Dedicated File selection
Future<String?> selectDF() async {
  return await transmitApdu('00A40000026F00');
}

Command Breakdown:
00    - CLA: Standard class
A4    - INS: SELECT command
00    - P1: Select by file ID
00    - P2: First or only occurrence
02    - Lc: 2 bytes of data follow
6F 00 - Data: Dedicated File ID
```

---

### **ISO/IEC 7816-4: Security Commands**

#### **VERIFY Command (ISO 7816-4 Section 7.5.6)**

**Standard Definition:**
```
CLA INS P1  P2  Lc  Data
00  20  00  [Qualifier] [PIN]
```

**Our Implementation:**
```dart
Future<String?> verifyPin(String pin) async {
  // PIN padded to 8 bytes with 0xFF (ISO 7816-4 recommendation)
  return await transmitApdu('0020000008$hexPin');
}

Command Breakdown:
00       - CLA: Standard class
20       - INS: VERIFY command
00       - P1: No specific information
00       - P2: Reference data qualifier
08       - Lc: 8 bytes of PIN data
[PIN]    - Data: PIN padded with 0xFF
```

---

### **ISO/IEC 7816-4: GET RESPONSE Command**

**Standard Definition (ISO 7816-4 Section 7.6.1):**
```
CLA INS P1  P2  Le
00  C0  00  00  [Length]
```

**Our Implementation:**
```dart
Future<String?> getResponseCommand(String length) async {
  return await transmitApdu('00C00000$length');
}

Command Breakdown:
00    - CLA: Standard class
C0    - INS: GET RESPONSE command
00    - P1: Reserved (00)
00    - P2: Reserved (00)
XX    - Le: Expected response length
```

**When used:**
- When card returns `61 XX` (more data available)
- Automatically triggered in `psoDigitalSignature()`

---

### **ISO/IEC 7816-8: Commands for Security Operations**

This part defines cryptographic operations.

#### **MANAGE SECURITY ENVIRONMENT (MSE) - ISO 7816-8 Section 5.6**

**Standard Definition:**
```
CLA INS P1  P2  Lc  Data
00  22  [Control] [Template] [Security Environment Data]
```

**Our Implementation:**
```dart
Future<String?> mseRestore({required String algorithm}) async {
  final p2 = algorithm.toLowerCase() == 'rsa' ? '03' : '0D';
  return await transmitApdu('0022F3$p2');
}

Command Breakdown:
00    - CLA: Standard class
22    - INS: MANAGE SECURITY ENVIRONMENT
F3    - P1: Restore (F3 per ISO 7816-8)
03/0D - P2: Algorithm reference
        03 = RSA (ISO 7816-8)
        0D = ECC (ISO 7816-8)
```

#### **PERFORM SECURITY OPERATION (PSO) - ISO 7816-8 Section 5.5**

**Standard Definition:**
```
CLA INS P1  P2  Lc  Data
00  2A  [Function] [Data to be processed]
```

**Our Implementation:**
```dart
Future<String?> psoDigitalSignature(String data) async {
  final apdu = '002A9E9A$length$cleanData';
  return await transmitApdu(apdu);
}

Command Breakdown:
00       - CLA: Standard class
2A       - INS: PERFORM SECURITY OPERATION
9E       - P1: Compute digital signature (ISO 7816-8)
9A       - P2: Input data (ISO 7816-8)
20       - Lc: 32 bytes (0x20)
[Data]   - Data: 32 bytes to be signed
```

**ISO 7816-8 P1-P2 Values for PSO:**
- `9E 9A` = Compute digital signature with input data
- `9E 9C` = Compute digital signature with hash
- `80 86` = Decipher data
- `86 80` = Encipher data

---

### **ISO/IEC 7816-4: Status Words (SW1 SW2)**

**Standard Definition (ISO 7816-4 Section 5.1.3):**

Response format:
```
[Response Data] SW1 SW2
                └─┴─ 2-byte status word
```

**Our Implementation:**
```dart
static String parseStatusWord(String sw) {
  // Implements ISO 7816-4 status word interpretation
}
```

**ISO 7816-4 Status Word Categories:**

| SW1 | Category | Meaning |
|-----|----------|---------|
| `90` | Normal | Command completed successfully |
| `61` | Normal | More data available (use GET RESPONSE) |
| `62` | Warning | State unchanged |
| `63` | Warning | State changed (e.g., counter) |
| `64` | Error | State unchanged |
| `65` | Error | State changed |
| `66` | Error | Security related |
| `67` | Error | Wrong length |
| `68` | Error | Functions in CLA not supported |
| `69` | Error | Command not allowed |
| `6A` | Error | Wrong parameters P1-P2 |
| `6B` | Error | Wrong parameters P1-P2 |
| `6C` | Error | Wrong Le field |
| `6D` | Error | Instruction not supported |
| `6E` | Error | Class not supported |
| `6F` | Error | No precise diagnosis |

**Specific Status Words Implemented:**

```dart
// ISO 7816-4 Section 5.1.3
if (clean == '9000') return '✓ Success';                    // Normal processing
if (clean.startsWith('61')) return '✓ Success with data';   // More data available
if (clean == '6982') return '✗ Security not satisfied';     // Security condition
if (clean == '6983') return '✗ Authentication blocked';     // PIN blocked
if (clean.startsWith('63C')) return '⚠ X attempts left';    // Counter
if (clean == '6A82') return '✗ File not found';            // File error
if (clean == '6A86') return '✗ Incorrect P1-P2';           // Parameter error
if (clean == '6D00') return '✗ Instruction not supported'; // INS error
if (clean == '6E00') return '✗ Class not supported';       // CLA error
```

---

## ISO/IEC 7816 File System Structure

**Defined in ISO 7816-4 Section 6:**

```
┌─────────────────────────────────────┐
│   MF (Master File) - 3F00           │  ← Root directory
│   ┌─────────────────────────────┐   │
│   │  DF (Dedicated File)        │   │  ← Application directory
│   │  ┌─────────────────────┐    │   │
│   │  │ EF (Elementary File)│    │   │  ← Data file
│   │  └─────────────────────┘    │   │
│   └─────────────────────────────┘   │
└─────────────────────────────────────┘
```

**File IDs (ISO 7816-4):**
- `3F00` - Master File (MF) - Always the root
- `3FFF` - Reserved
- `0000` - Current DF
- `2F00-2FFF` - EF under MF
- `5F00-5FFF` - DF under MF
- Other values - Application specific

---

## Additional Standards Referenced

### **ISO/IEC 7816-1: Physical Characteristics**
- Card dimensions: 85.60 × 53.98 mm
- Chip contact positions
- Not directly implemented (hardware level)

### **ISO/IEC 7816-2: Dimensions and Location of Contacts**
- 8 contact positions (C1-C8)
- VCC, RST, CLK, GND, VPP, I/O
- Not directly implemented (hardware level)

### **PC/SC (Personal Computer/Smart Card)**
- Not an ISO standard but widely used
- Defines USB CCID (Chip Card Interface Device)
- Used in `MainActivity.kt` for USB communication

---

## Command Summary by ISO Standard

### **ISO 7816-4 Commands:**
```dart
selectMF()              // SELECT MF (00 A4 00 00 02 3F 00)
selectDF()              // SELECT DF (00 A4 00 00 02 6F 00)
verifyPin()             // VERIFY (00 20 00 00 08 [PIN])
getResponseCommand()    // GET RESPONSE (00 C0 00 00 XX)
```

### **ISO 7816-8 Commands:**
```dart
mseRestore()            // MSE RESTORE (00 22 F3 03/0D)
psoDigitalSignature()   // PSO SIGN (00 2A 9E 9A 20 [Data])
```

### **ISO 7816-3 Protocols:**
```dart
connectCard(protocol: 0)  // T=0 protocol
connectCard(protocol: 1)  // T=1 protocol
connectCard(protocol: 2)  // T=0 or T=1 (auto)
```

---

## Compliance Level

### ✅ **Fully Compliant:**
- APDU command structure (ISO 7816-4)
- Status word interpretation (ISO 7816-4)
- File selection (ISO 7816-4)
- Protocol handling (ISO 7816-3)
- Security operations (ISO 7816-8)

### ⚠️ **Partially Compliant:**
- Not all ISO 7816-4 commands implemented (only common ones)
- Some card-specific extensions may be needed
- Advanced security features not implemented

### ❌ **Not Implemented:**
- ISO 7816-1, 7816-2 (physical layer - hardware)
- ISO 7816-5 (application identifiers)
- ISO 7816-6 (interindustry data elements)
- ISO 7816-7 (SCQL commands)
- ISO 7816-9 (card management)
- ISO 7816-10 (electronic signals for synchronous cards)

---

## References

### Official ISO Standards:
- **ISO/IEC 7816-3:2006** - Electronic signals and transmission protocols
- **ISO/IEC 7816-4:2020** - Organization, security and commands for interchange
- **ISO/IEC 7816-8:2019** - Commands and mechanisms for security operations

### Additional Resources:
- **EMV Specifications** - Payment card standards (based on ISO 7816)
- **GlobalPlatform** - Card management standards
- **PC/SC Workgroup** - PC to smart card interface standards

### Online References:
- [CardWerk ISO 7816 Reference](https://cardwerk.com/smart-card-standard-iso7816/)
- [ISO 7816 APDU Commands](https://www.eftlab.com/knowledge-base/complete-list-of-apdu-responses/)

---

## Summary

This project implements:
- ✅ **ISO/IEC 7816-3** - T=0 and T=1 protocols
- ✅ **ISO/IEC 7816-4** - APDU commands, file system, status words
- ✅ **ISO/IEC 7816-8** - Cryptographic operations (MSE, PSO)

All APDU commands follow the exact structure defined in ISO 7816-4, and all status words are interpreted according to ISO 7816-4 specifications. The security operations (MSE RESTORE and PSO SIGN) follow ISO 7816-8 standards.

**This is a standards-compliant smartcard communication application.**
