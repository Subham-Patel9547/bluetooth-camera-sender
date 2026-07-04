import 'package:flutter/services.dart';

class NativeBluetoothService {
  static const MethodChannel _channel = MethodChannel("bluetooth_camera");

  /// Get paired devices
  Future<List<Map<String, dynamic>>> getPairedDevices() async {
    try {
      final List result = await _channel.invokeMethod("getPairedDevices");

      return result.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      print("getPairedDevices Error: $e");
      return [];
    }
  }

  /// Connect to Receiver
  Future<bool> connect(String address) async {
    try {
      final bool connected = await _channel.invokeMethod("connectDevice", {
        "address": address,
      });

      return connected;
    } catch (e) {
      print("Connect Error: $e");
      return false;
    }
  }

  /// Start scanning for nearby unpaired devices
  Future<void> startDiscovery() async {
    try {
      await _channel.invokeMethod("startDiscovery");
    } catch (e) {
      print("startDiscovery Error: $e");
    }
  }

  /// Send START / STOP / SWITCH / FLASH
  Future<bool> sendCommand(String command) async {
    try {
      //  FIX: String ke peeche newline (\n) add karna mandatory hai
      // Taki Receiver side ka native reader loop block na ho aur instantly command read kare.
      final String formattedCommand = command.trim() + "\n";

      final bool sent = await _channel.invokeMethod("sendCommand", {
        "command": formattedCommand,
      });

      return sent;
    } catch (e) {
      print("Send Error for $command: $e");
      return false;
    }
  }
}
