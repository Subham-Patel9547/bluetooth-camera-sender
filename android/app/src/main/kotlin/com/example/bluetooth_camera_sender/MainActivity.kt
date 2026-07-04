package com.example.bluetooth_camera_sender

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.OutputStream
import java.util.UUID
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {

    private val CHANNEL = "bluetooth_camera"

    // Standard SPP UUID (Dono App me BILKUL SAME hona chahiye)
    private val APP_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

    private var bluetoothAdapter: BluetoothAdapter? = null
    private var socket: BluetoothSocket? = null
    private var outputStream: OutputStream? = null

    private val discoveredDevicesList = ArrayList<Map<String, String>>()
    private var isReceiverRegistered = false

    // BroadcastReceiver implementation nearby devices scan capture karne ke liye
    private val discoveryReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val action: String? = intent.action
            if (BluetoothDevice.ACTION_FOUND == action) {
                val device: BluetoothDevice? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                }

                if (device != null) {
                    // Runtime permission handling for device name extraction
                    var hasPermission = true
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        if (ActivityCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {
                            hasPermission = false
                        }
                    }

                    val deviceName = if (hasPermission) device.name ?: "Unknown Device" else "Unknown Device"
                    val deviceAddress = device.address

                    // Duplicate items mapping filter logic
                    val exists = discoveredDevicesList.any { it["address"] == deviceAddress }
                    if (!exists) {
                        val deviceMap = HashMap<String, String>()
                        deviceMap["name"] = deviceName
                        deviceMap["address"] = deviceAddress
                        discoveredDevicesList.add(deviceMap)
                        Log.d("BT_SCAN", "Nearby device registered: $deviceName -> $deviceAddress")
                    }
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getPairedDevices" -> {
                    result.success(getPairedDevices())
                }
                "connectDevice" -> {
                    val address = call.argument<String>("address")!!
                    thread {
                        val success = connect(address)
                        runOnUiThread {
                            result.success(success)
                        }
                    }
                }
                "sendCommand" -> {
                    val command = call.argument<String>("command")!!
                    thread {
                        val ok = send(command)
                        runOnUiThread {
                            result.success(ok)
                        }
                    }
                }
                //  ADDED: Nearby device discovery triggers
                "startDiscovery" -> {
                    discoveredDevicesList.clear()
                    val adapter = bluetoothAdapter
                    if (adapter != null) {
                        // Scan permissions check safety fallback
                        var canScan = true
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            if (ActivityCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_SCAN) != PackageManager.PERMISSION_GRANTED) {
                                canScan = false
                            }
                        }

                        if (canScan) {
                            if (adapter.isDiscovering) {
                                adapter.cancelDiscovery()
                            }
                            
                            // Context broadcast pairing integration
                            if (!isReceiverRegistered) {
                                val filter = IntentFilter(BluetoothDevice.ACTION_FOUND)
                                registerReceiver(discoveryReceiver, filter)
                                isReceiverRegistered = true
                            }
                            
                            val started = adapter.startDiscovery()
                            Log.d("BT_SCAN", "Hardware scan discovery status initialized: $started")
                            result.success(started)
                        } else {
                            Log.e("BT_SCAN", "BLUETOOTH_SCAN permission missing execution halt")
                            result.error("PERMISSION_DENIED", "Bluetooth Scan permission not granted", null)
                        }
                    } else {
                        result.error("NO_BLUETOOTH", "Hardware adapter not initialized", null)
                    }
                }
                //  ADDED: Discovered devices fetch channel link
                "getDiscoveredDevices" -> {
                    result.success(discoveredDevicesList)
                }
                //  ADDED: Safe live hardware socket disconnect command block
                "disconnectDevice" -> {
                    thread {
                        val disconnected = disconnect()
                        runOnUiThread {
                            result.success(disconnected)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getPairedDevices(): List<HashMap<String, String>> {
        val list = arrayListOf<HashMap<String, String>>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (ActivityCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {
                return list
            }
        }

        bluetoothAdapter?.bondedDevices?.forEach {
            val map = HashMap<String, String>()
            map["name"] = it.name ?: "Unknown"
            map["address"] = it.address
            list.add(map)
        }
        return list
    }

    private fun connect(address: String): Boolean {
        val device = bluetoothAdapter?.getRemoteDevice(address) ?: return false

        try {
            // 1. Pehle cancel discovery karein (Handshake stable karne ke liye)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (ActivityCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED) {
                    bluetoothAdapter?.cancelDiscovery()
                }
            } else {
                bluetoothAdapter?.cancelDiscovery()
            }

            // 2. Try Standard Secure Socket
            var targetSocket = device.createRfcommSocketToServiceRecord(APP_UUID)
            
            try {
                targetSocket.connect()
                socket = targetSocket
                outputStream = targetSocket.outputStream
                Log.d("Bluetooth", "Connected successfully via Secure Socket")
                return true
            } catch (e: Exception) {
                Log.e("Bluetooth", "Standard socket failed, trying insecure fallback...", e)
                
                // 3. FALLBACK: Android 11+ socket -1 read timeout failure bypass logic
                targetSocket = device.createInsecureRfcommSocketToServiceRecord(APP_UUID)
                targetSocket.connect()
                socket = targetSocket
                outputStream = targetSocket.outputStream
                Log.d("Bluetooth", "Connected successfully via Insecure Fallback Socket")
                return true
            }
        } catch (e: Exception) {
            Log.e("Bluetooth", "All connection attempts failed", e)
            return false
        }
    }

    private fun send(command: String): Boolean {
        // Socket check fix: `socket?.isConnected` ko sahi reference diya hai
        if (outputStream == null || socket == null || socket?.isConnected == false) {
            Log.e("BT_SENDER", "Socket not connected, cannot send command")
            return false
        }
        return try {
            // Newline auto-appending logic to satisfy receiver buffer stream
            val formattedCommand = if (command.endsWith("\n")) command else "$command\n"
            outputStream?.write(formattedCommand.toByteArray(Charsets.UTF_8))
            outputStream?.flush()
            Log.d("BT_SENDER", "Successfully sent: ${formattedCommand.trim()}")
            true
        } catch (e: Exception) {
            Log.e("BT_SENDER", "Send Error", e)
            false
        }
    }

    //  ADDED: Internal core cleanup function for safe hardware disconnect toggles
    private fun disconnect(): Boolean {
        return try {
            outputStream?.close()
            socket?.close()
            outputStream = null
            socket = null
            Log.d("BT_SENDER", "Hardware socket channel successfully released")
            true
        } catch (e: Exception) {
            Log.e("BT_SENDER", "Error releasing communication streams", e)
            false
        }
    }

    //  ADDED: Native activity tracking cleanup listener to completely prevent leaks
    override fun onDestroy() {
        super.onDestroy()
        if (isReceiverRegistered) {
            try {
                unregisterReceiver(discoveryReceiver)
                isReceiverRegistered = false
            } catch (e: Exception) {
                Log.e("BT_SENDER", "Error unregistering discovery layout mapping", e)
            }
        }
    }
}