package com.example.smartcardos

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbManager
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.smartcardos/usb"
    private val SMARTCARD_CHANNEL = "com.example.smartcardos/smartcard"
    private val EVENT_CHANNEL = "com.example.smartcardos/usb_events"
    private val ACTION_USB_PERMISSION = "com.example.smartcardos.USB_PERMISSION"

    private var usbManager: UsbManager? = null
    private var usbDevice: UsbDevice? = null
    private var usbConnection: UsbDeviceConnection? = null
    private var usbInterface: UsbInterface? = null
    private var bulkIn: UsbEndpoint? = null
    private var bulkOut: UsbEndpoint? = null
    private var eventSink: EventChannel.EventSink? = null
    private var permissionResult: MethodChannel.Result? = null
    private var isCardConnected = false
    private var atr: String? = null

    private val usbReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                ACTION_USB_PERMISSION -> {
                    synchronized(this) {
                        val device: UsbDevice? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
                        } else {
                            @Suppress("DEPRECATION")
                            intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                        }
                        
                        val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
                        android.util.Log.d("USB", "Permission result: $granted for device: ${device?.deviceName}")
                        
                        permissionResult?.success(granted)
                        permissionResult = null
                    }
                }
                UsbManager.ACTION_USB_DEVICE_ATTACHED -> {
                    eventSink?.success(mapOf("action" to "attached"))
                }
                UsbManager.ACTION_USB_DEVICE_DETACHED -> {
                    eventSink?.success(mapOf("action" to "detached"))
                    usbConnection?.close()
                    usbConnection = null
                    usbDevice = null
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        usbManager = getSystemService(Context.USB_SERVICE) as UsbManager

        // Register USB broadcast receiver
        val filter = IntentFilter().apply {
            addAction(ACTION_USB_PERMISSION)
            addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
            addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(usbReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(usbReceiver, filter)
        }

        // Method Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isUsbSupported" -> {
                    result.success(true) // Most Android devices support USB OTG
                }
                
                "getConnectedDevices" -> {
                    val deviceList = usbManager?.deviceList?.values?.map { device ->
                        mapOf(
                            "deviceId" to device.deviceId,
                            "deviceName" to device.deviceName,
                            "vendorId" to device.vendorId,
                            "productId" to device.productId,
                            "deviceClass" to device.deviceClass,
                            "deviceSubclass" to device.deviceSubclass
                        )
                    } ?: emptyList()
                    result.success(deviceList)
                }
                
                "requestPermission" -> {
                    val deviceId = call.argument<Int>("deviceId")
                    val device = usbManager?.deviceList?.values?.find { it.deviceId == deviceId }
                    
                    android.util.Log.d("USB", "Requesting permission for device: ${device?.deviceName}")
                    
                    if (device != null) {
                        // Check if already has permission
                        if (usbManager?.hasPermission(device) == true) {
                            android.util.Log.d("USB", "Already has permission")
                            result.success(true)
                            return@setMethodCallHandler
                        }
                        
                        // Store result to call later from broadcast receiver
                        permissionResult = result
                        
                        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            PendingIntent.FLAG_MUTABLE
                        } else {
                            0
                        }
                        val permissionIntent = PendingIntent.getBroadcast(
                            this,
                            0,
                            Intent(ACTION_USB_PERMISSION),
                            flags
                        )
                        
                        android.util.Log.d("USB", "Requesting permission via dialog")
                        usbManager?.requestPermission(device, permissionIntent)
                    } else {
                        android.util.Log.d("USB", "Device not found")
                        result.success(false)
                    }
                }
                
                "connectDevice" -> {
                    val deviceId = call.argument<Int>("deviceId")
                    val device = usbManager?.deviceList?.values?.find { it.deviceId == deviceId }
                    
                    android.util.Log.d("USB", "Attempting to connect to device: ${device?.deviceName}")
                    
                    if (device != null) {
                        if (usbManager?.hasPermission(device) == true) {
                            try {
                                usbConnection = usbManager?.openDevice(device)
                                usbDevice = device
                                val success = usbConnection != null
                                android.util.Log.d("USB", "Connection result: $success")
                                result.success(success)
                            } catch (e: Exception) {
                                android.util.Log.e("USB", "Connection error: ${e.message}")
                                result.success(false)
                            }
                        } else {
                            android.util.Log.d("USB", "No permission for device")
                            result.success(false)
                        }
                    } else {
                        android.util.Log.d("USB", "Device not found")
                        result.success(false)
                    }
                }
                
                "readToken" -> {
                    if (usbConnection != null && usbDevice != null) {
                        try {
                            // This is a basic example - you'll need to customize based on your dongle
                            val endpoint = usbDevice?.getInterface(0)?.getEndpoint(0)
                            val buffer = ByteArray(64)
                            
                            if (endpoint != null) {
                                val bytesRead = usbConnection?.bulkTransfer(
                                    endpoint,
                                    buffer,
                                    buffer.size,
                                    5000 // 5 second timeout
                                )
                                
                                if (bytesRead != null && bytesRead > 0) {
                                    val tokenData = buffer.take(bytesRead).toByteArray()
                                    val hexString = tokenData.joinToString("") { 
                                        "%02X".format(it) 
                                    }
                                    result.success(hexString)
                                } else {
                                    result.success("No data received")
                                }
                            } else {
                                result.error("NO_ENDPOINT", "No endpoint found", null)
                            }
                        } catch (e: Exception) {
                            result.error("READ_ERROR", e.message, null)
                        }
                    } else {
                        result.error("NOT_CONNECTED", "Device not connected", null)
                    }
                }
                
                "disconnectDevice" -> {
                    usbConnection?.close()
                    usbConnection = null
                    usbDevice = null
                    result.success(true)
                }
                
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Event Channel for USB events
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )

        // Smart Card Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMARTCARD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "connectCard" -> {
                    val protocol = call.argument<Int>("protocol") ?: 1
                    connectToSmartCard(result, protocol)
                }
                
                "transmitApdu" -> {
                    val command = call.argument<String>("command")
                    if (command != null) {
                        transmitApdu(command, result)
                    } else {
                        result.error("INVALID_COMMAND", "Command is null", null)
                    }
                }
                
                "getAtr" -> {
                    result.success(atr)
                }
                
                "disconnectCard" -> {
                    disconnectSmartCard()
                    result.success(true)
                }
                
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun connectToSmartCard(result: MethodChannel.Result, protocol: Int = 1) {
        if (usbConnection == null || usbDevice == null) {
            result.error("NO_DEVICE", "USB device not connected", null)
            return
        }

        try {
            // Find CCID interface (Class 0x0B)
            for (i in 0 until usbDevice!!.interfaceCount) {
                val intf = usbDevice!!.getInterface(i)
                if (intf.interfaceClass == 11) { // CCID class
                    usbInterface = intf
                    break
                }
            }

            if (usbInterface == null) {
                result.error("NO_CCID", "No CCID interface found", null)
                return
            }

            // Claim interface
            if (!usbConnection!!.claimInterface(usbInterface, true)) {
                result.error("CLAIM_FAILED", "Failed to claim interface", null)
                return
            }

            // Find bulk endpoints
            for (i in 0 until usbInterface!!.endpointCount) {
                val endpoint = usbInterface!!.getEndpoint(i)
                if (endpoint.type == android.hardware.usb.UsbConstants.USB_ENDPOINT_XFER_BULK) {
                    if (endpoint.direction == android.hardware.usb.UsbConstants.USB_DIR_IN) {
                        bulkIn = endpoint
                    } else {
                        bulkOut = endpoint
                    }
                }
            }

            if (bulkIn == null || bulkOut == null) {
                result.error("NO_ENDPOINTS", "Bulk endpoints not found", null)
                return
            }

            // Get protocol parameter (0=T0, 1=T1, 2=Auto)
            val protocol = (result as? MethodChannel.Result)?.let { 
                // This will be passed from Flutter
                1 // Default to T=1
            } ?: 1

            // Power on card and get ATR
            val atrResponse = powerOnCard(protocol)
            if (atrResponse != null) {
                atr = atrResponse
                isCardConnected = true
                
                // Set protocol parameters
                setProtocolParameters(protocol)
                
                result.success(mapOf(
                    "success" to true,
                    "atr" to atrResponse,
                    "protocol" to protocol
                ))
            } else {
                result.error("POWER_ON_FAILED", "Failed to power on card", null)
            }

        } catch (e: Exception) {
            android.util.Log.e("SmartCard", "Connection error: ${e.message}")
            result.error("CONNECTION_ERROR", e.message, null)
        }
    }

    private fun powerOnCard(protocol: Int = 1): String? {
        try {
            // PC_to_RDR_IccPowerOn command
            val command = byteArrayOf(
                0x62.toByte(), // IccPowerOn
                0x00, 0x00, 0x00, 0x00, // Length
                0x00, // Slot
                0x00, // Seq
                0x01, // Voltage: 5V
                0x00, 0x00 // RFU
            )

            val sent = usbConnection?.bulkTransfer(bulkOut, command, command.size, 5000)
            if (sent != command.size) {
                android.util.Log.e("SmartCard", "Failed to send power on command")
                return null
            }

            // Read response
            val response = ByteArray(512)
            val received = usbConnection?.bulkTransfer(bulkIn, response, response.size, 5000)
            
            if (received != null && received > 10) {
                // Extract ATR from response (skip CCID header)
                val atrLength = response[1].toInt() and 0xFF
                val atrBytes = response.copyOfRange(10, 10 + atrLength)
                return atrBytes.joinToString(" ") { "%02X".format(it) }
            }

        } catch (e: Exception) {
            android.util.Log.e("SmartCard", "Power on error: ${e.message}")
        }
        return null
    }

    private fun transmitApdu(commandHex: String, result: MethodChannel.Result) {
        if (!isCardConnected) {
            result.error("NOT_CONNECTED", "Card not connected", null)
            return
        }

        try {
            // Parse hex command
            val commandBytes = hexStringToByteArray(commandHex)
            
            // Build PC_to_RDR_XfrBlock
            val ccidCommand = ByteArray(10 + commandBytes.size)
            ccidCommand[0] = 0x6F.toByte() // XfrBlock
            ccidCommand[1] = (commandBytes.size and 0xFF).toByte()
            ccidCommand[2] = ((commandBytes.size shr 8) and 0xFF).toByte()
            ccidCommand[3] = ((commandBytes.size shr 16) and 0xFF).toByte()
            ccidCommand[4] = ((commandBytes.size shr 24) and 0xFF).toByte()
            ccidCommand[5] = 0x00 // Slot
            ccidCommand[6] = 0x00 // Seq
            ccidCommand[7] = 0x00 // BWI
            ccidCommand[8] = 0x00 // Level parameter
            ccidCommand[9] = 0x00 // RFU
            System.arraycopy(commandBytes, 0, ccidCommand, 10, commandBytes.size)

            // Send command
            val sent = usbConnection?.bulkTransfer(bulkOut, ccidCommand, ccidCommand.size, 5000)
            if (sent != ccidCommand.size) {
                result.error("SEND_FAILED", "Failed to send APDU", null)
                return
            }

            // Read response
            val response = ByteArray(512)
            val received = usbConnection?.bulkTransfer(bulkIn, response, response.size, 5000)
            
            if (received != null && received > 10) {
                val dataLength = (response[1].toInt() and 0xFF) or 
                                ((response[2].toInt() and 0xFF) shl 8)
                val responseData = response.copyOfRange(10, 10 + dataLength)
                val hexResponse = responseData.joinToString(" ") { "%02X".format(it) }
                result.success(hexResponse)
            } else {
                result.error("NO_RESPONSE", "No response from card", null)
            }

        } catch (e: Exception) {
            android.util.Log.e("SmartCard", "Transmit error: ${e.message}")
            result.error("TRANSMIT_ERROR", e.message, null)
        }
    }

    private fun disconnectSmartCard() {
        try {
            // Power off card
            val command = byteArrayOf(
                0x63.toByte(), // IccPowerOff
                0x00, 0x00, 0x00, 0x00,
                0x00, // Slot
                0x00, // Seq
                0x00, 0x00, 0x00 // RFU
            )
            usbConnection?.bulkTransfer(bulkOut, command, command.size, 1000)
            
            usbInterface?.let {
                usbConnection?.releaseInterface(it)
            }
            isCardConnected = false
            atr = null
        } catch (e: Exception) {
            android.util.Log.e("SmartCard", "Disconnect error: ${e.message}")
        }
    }

    private fun setProtocolParameters(protocol: Int) {
        try {
            // PC_to_RDR_SetParameters command
            val protocolType = when (protocol) {
                0 -> 0x00.toByte() // T=0
                1 -> 0x01.toByte() // T=1
                else -> 0x01.toByte() // Default T=1
            }
            
            val command = byteArrayOf(
                0x61.toByte(), // SetParameters
                0x07, 0x00, 0x00, 0x00, // Length = 7
                0x00, // Slot
                0x00, // Seq
                protocolType, // Protocol
                0x00, 0x00, // RFU
                // Protocol parameters (7 bytes for T=1)
                0x11, // IFSC
                0x10, // IFSD
                0x00, // BWI
                0x00, // CWI
                0x00, // Clock stop
                0x00, // IFSC presence
                0x00  // NAD
            )
            
            usbConnection?.bulkTransfer(bulkOut, command, command.size, 1000)
            
            // Read response
            val response = ByteArray(512)
            usbConnection?.bulkTransfer(bulkIn, response, response.size, 1000)
            
            android.util.Log.d("SmartCard", "Protocol set to: ${if (protocol == 0) "T=0" else "T=1"}")
        } catch (e: Exception) {
            android.util.Log.e("SmartCard", "Set protocol error: ${e.message}")
        }
    }

    private fun hexStringToByteArray(s: String): ByteArray {
        val clean = s.replace(" ", "").replace(":", "")
        val len = clean.length
        val data = ByteArray(len / 2)
        var i = 0
        while (i < len) {
            data[i / 2] = ((Character.digit(clean[i], 16) shl 4) +
                          Character.digit(clean[i + 1], 16)).toByte()
            i += 2
        }
        return data
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(usbReceiver)
        } catch (e: Exception) {
            // Receiver not registered
        }
        usbConnection?.close()
    }
}
