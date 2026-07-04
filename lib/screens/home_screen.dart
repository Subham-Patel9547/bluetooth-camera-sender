import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/bluetooth_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BluetoothProvider>().loadDevices();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BluetoothProvider>();

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Bluetooth Camera Sender"),
        actions: [
          // ================= DISCOVERY / SCANNING INDICATOR =================
          provider.isScanning
              ? const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.blue,
                    ),
                  ),
                )
              : IconButton(
                  onPressed: () => provider.startScanning(),
                  icon: const Icon(Icons.search),
                  tooltip: "Scan Nearby Devices",
                ),
          IconButton(
            onPressed: () => provider.refresh(),
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Paired Devices",
          ),
        ],
      ),
      body: Column(
        children: [
          // ================= STATUS BAR =================
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            color: provider.connected
                ? Colors.green.shade50
                : Colors.red.shade50,
            child: Text(
              provider.status,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: provider.connected
                    ? Colors.green.shade900
                    : Colors.red.shade900,
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ================= OPEN BLUETOOTH SETTINGS =================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.bluetooth),
                label: const Text("Open Bluetooth & Pair Device"),
                onPressed: () {
                  provider.openBluetoothSettings();
                },
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ================= DEVICE LIST =================
          Expanded(
            child: provider.loading
                ? const Center(child: CircularProgressIndicator())
                : provider.devices.isEmpty
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bluetooth_disabled,
                        size: 60,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 10),
                      Text(
                        "No Paired Devices Found",
                        style: TextStyle(fontSize: 18),
                      ),
                      SizedBox(height: 5),
                      Text(
                        "Please pair a device or start scanning nearby",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  )
                : ListView.builder(
                    itemCount: provider.devices.length,
                    itemBuilder: (context, index) {
                      final device = provider.devices[index];
                      final name = device["name"] ?? "Unknown Device";
                      final address = device["address"] ?? "";

                      //  DYNAMIC CHECK: Kya yeh local mapped index card already connected hai?
                      final bool isCurrentDeviceConnected =
                          provider.connected &&
                          provider.connectedAddress == address;

                      return Card(
                        color: isCurrentDeviceConnected
                            ? Colors.green.shade50
                            : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isCurrentDeviceConnected
                                ? Colors.green
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: ListTile(
                          leading: Icon(
                            Icons.bluetooth,
                            color: isCurrentDeviceConnected
                                ? Colors.green
                                : Colors.blue,
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(address),
                          trailing: ElevatedButton(
                            onPressed: provider.loading
                                ? null
                                : () async {
                                    if (isCurrentDeviceConnected) {
                                      //  Connected hai toh safe clean disconnect execute hoga
                                      await provider.disconnect();
                                    } else {
                                      // 📡 Connected nahi hai toh direct device call handle hoga
                                      await provider.connect(address);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isCurrentDeviceConnected
                                  ? Colors.red
                                  : Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(
                              isCurrentDeviceConnected
                                  ? "Disconnect"
                                  : "Connect",
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          const Divider(),

          // ================= CONTROL BUTTONS PANEL =================
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🔄 SWITCH CAMERA BUTTON
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: provider.connected
                        ? () async {
                            await provider.switchCamera();
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.cameraswitch),
                    label: const Text(
                      "SWITCH CAMERA (FRONT/REAR)",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // 📹 RECORDING CONTROLS ROW
                Row(
                  children: [
                    // START BUTTON
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: provider.connected
                            ? () => provider.startRecording()
                            : null,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text("START"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // PAUSE BUTTON
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: provider.connected
                            ? () => provider.pauseRecording()
                            : null,
                        icon: const Icon(Icons.pause),
                        label: const Text("PAUSE"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // RESUME BUTTON
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: provider.connected
                            ? () => provider.resumeRecording()
                            : null,
                        icon: const Icon(Icons.play_circle_fill),
                        label: const Text("RESUME"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // STOP & SAVE BUTTON
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: provider.connected
                            ? () => provider.stopRecording()
                            : null,
                        icon: const Icon(Icons.stop),
                        label: const Text("STOP & SAVE"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
