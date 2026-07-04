import 'package:flutter/material.dart';
import '../core/services/native_bluetooth_service.dart';
import 'package:flutter/services.dart';

class BluetoothProvider extends ChangeNotifier {
  final NativeBluetoothService _service = NativeBluetoothService();

  List<Map<String, dynamic>> devices = [];

  bool connected = false;
  bool loading = false;

  bool isScanning = false;

  String connectedAddress = "";

  String status = "Not Connected";

  // ==========================================
  // LOAD PAIRED DEVICES
  // ==========================================
  Future<void> loadDevices() async {
    loading = true;
    notifyListeners();

    try {
      final result = await _service.getPairedDevices();
      devices = List<Map<String, dynamic>>.from(result);
      status = devices.isEmpty ? "No Paired Devices Found" : "Devices Loaded";
    } catch (e) {
      status = "Error Loading Devices";
      devices = [];
    }

    loading = false;
    notifyListeners();
  }

  // ==========================================
  // DISCONNECT DEVICE
  // ==========================================
  // ==========================================
  // DISCONNECT DEVICE
  // ==========================================
  Future<void> disconnect() async {
    loading = true;
    status = "Disconnecting...";
    notifyListeners();

    try {
      //  FIX: 'final const' hata kar sirf 'const' ya 'final' lagayein
      const platform = MethodChannel('bluetooth_camera');

      // Native Kotlin/Java ko trigger karein taaki wo socket close kare
      await platform.invokeMethod('disconnectDevice');

      connected = false;
      connectedAddress = ""; // Reset connected address
      status = "Disconnected";
    } catch (e) {
      print("Native disconnect error: $e. Falling back to state reset.");
      // Fallback: Agar native trigger fail bhi ho jaye, state local reset kar dein
      connected = false;
      connectedAddress = "";
      status = "Disconnected";
    }

    loading = false;
    notifyListeners();
  }



  // ==========================================
  // START SCANNING FOR NEARBY DEVICES
  // ==========================================
  Future<void> startScanning() async {
    isScanning = true;
    status = "Scanning for nearby devices...";
    devices.clear(); // Purani list clear karein
    notifyListeners();

    try {
      // 1. Native ko scanning start karne ko bolein
      await _service.startDiscovery();

      // 2. 8-10 seconds wait karein jab tak hardware scan kar raha hai
      await Future.delayed(const Duration(seconds: 10));

      // 3. Native layer se discovered devices ki list lekar aayein
      const platform = MethodChannel('bluetooth_camera');
      final List? scanResult = await platform.invokeMethod("getDiscoveredDevices");

      if (scanResult != null) {
        devices = scanResult.map((e) => Map<String, dynamic>.from(e)).toList();
      }

      // 4. Paired devices ko bhi isme mix karna chahein toh loadDevices() ka fallback de sakte hain
      if (devices.isEmpty) {
        status = "No Nearby Devices Found. Loading paired fallback.";
        final paired = await _service.getPairedDevices();
        devices = List<Map<String, dynamic>>.from(paired);
      } else {
        status = "Scan Finished. Found ${devices.length} devices.";
      }

    } catch (e) {
      print("Error during scan: $e");
      status = "Scan Failed";
    }

    isScanning = false;
    notifyListeners();
  }

  // ==========================================
  // OPEN BLUETOOTH SETTINGS
  // ==========================================
  Future<void> openBluetoothSettings() async {
    const platform = MethodChannel('android_intent');
    try {
      await platform.invokeMethod('openBluetoothSettings');
    } catch (e) {
      debugPrint("Error opening settings: $e");
    }
  }

  // ==========================================
  // CONNECT DEVICE
  // ==========================================
  Future<void> connect(String address) async {
    if (loading) return;

    loading = true;
    status = "Connecting...";
    notifyListeners();

    try {
      final bool ok = await _service.connect(address);

      if (ok) {
        connected = true;
        connectedAddress = address; // 👈 Add this
        status = "Connected";
      } else {
        connected = false;
        connectedAddress = "";
        status = "Connection Failed";
      }
    } catch (e) {
      connected = false;
      connectedAddress = "";
      status = "Connection Error";
    }

    loading = false;
    notifyListeners();
  }

  // ==========================================
  // GLOBAL COMMAND SENDER (Helper)
  // ==========================================
  Future<bool> _sendRemoteCommand(
    String command,
    String successMsg,
    String failMsg,
  ) async {
    if (!connected) {
      status = "Not Connected";
      notifyListeners();
      return false;
    }

    try {
      final ok = await _service.sendCommand(command);
      status = ok ? successMsg : failMsg;
      notifyListeners();
      return ok;
    } catch (e) {
      status = "$command Error";
      notifyListeners();
      return false;
    }
  }

  // ==========================================
  // START RECORDING
  // ==========================================
  Future<void> startRecording() async {
    await _sendRemoteCommand("START", "START Sent", "Failed to Send START");
  }

  // ==========================================
  // STOP RECORDING
  // ==========================================
  Future<void> stopRecording() async {
    await _sendRemoteCommand("STOP", "STOP Sent", "Failed to Send STOP");
  }

  // ==========================================
  // PAUSE RECORDING
  // ==========================================
  Future<void> pauseRecording() async {
    await _sendRemoteCommand("PAUSE", "PAUSE Sent", "Failed to Send PAUSE");
  }

  // ==========================================
  // RESUME RECORDING
  // ==========================================
  Future<void> resumeRecording() async {
    await _sendRemoteCommand("RESUME", "RESUME Sent", "Failed to Send RESUME");
  }

  // ==========================================
  //  FIXED: SWITCH CAMERA (Ab Error Nahi Aayega!)
  // ==========================================
  Future<void> switchCamera() async {
    await _sendRemoteCommand(
      "SWITCH",
      "SWITCH Cam Sent",
      "Failed to Send SWITCH",
    );
  }

  // ==========================================
  //  BONUS FEATURE: REMOTE FLASH CONTROL
  // ==========================================
  Future<void> toggleFlash() async {
    await _sendRemoteCommand(
      "FLASH",
      "FLASH Toggle Sent",
      "Failed to Send FLASH",
    );
  }

  // ==========================================
  // REFRESH
  // ==========================================
  Future<void> refresh() async {
    await loadDevices();
  }

  // ==========================================
  // RESET CONNECTION
  // ==========================================
  void resetConnection() {
    connected = false;
    status = "Not Connected";
    notifyListeners();
  }
}
