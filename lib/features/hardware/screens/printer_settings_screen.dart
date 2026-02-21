import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/printer_service.dart';

class PrinterSettingsScreen extends ConsumerStatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  ConsumerState<PrinterSettingsScreen> createState() =>
      _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends ConsumerState<PrinterSettingsScreen> {
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initPrinter();
  }

  Future<void> _initPrinter() async {
    // Request Android 12+ Permissions
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    setState(() => _isLoading = true);

    final printer = ref.read(printerServiceProvider);
    final devices = await printer.getPairedDevices();

    final prefs = await SharedPreferences.getInstance();
    final savedAddress = prefs.getString('printer_mac');

    setState(() {
      _devices = devices;
      if (savedAddress != null) {
        _selectedDevice = devices.firstWhere(
          (d) => d.address == savedAddress,
          orElse: () => devices.first,
        );
      }
      _isLoading = false;
    });
  }

  Future<void> _connect(BluetoothDevice device) async {
    setState(() => _isLoading = true);
    try {
      final printer = ref.read(printerServiceProvider);
      await printer.connect(device);

      // Save preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('printer_mac', device.address!);

      setState(() => _selectedDevice = device);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Printer Connected!")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Connection failed: $e")));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Printer Settings")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    "Select Thermal Printer",
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                ..._devices.map((device) {
                  final isConnected =
                      _selectedDevice?.address == device.address;
                  return ListTile(
                    title: Text(device.name ?? "Unknown Device"),
                    subtitle: Text(device.address ?? ""),
                    trailing: isConnected
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : ElevatedButton(
                            onPressed: () => _connect(device),
                            child: const Text("Connect"),
                          ),
                  );
                }),
                if (_devices.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      "No paired Bluetooth devices found. Go to Android Settings to pair your printer first.",
                    ),
                  ),

                const Divider(),
                ListTile(
                  leading: const Icon(Icons.print),
                  title: const Text("Test Print"),
                  onTap: _selectedDevice == null
                      ? null
                      : () async {
                          // Mock Data for Test
                          // ... pass dummy data to printReceipt service
                        },
                ),
              ],
            ),
    );
  }
}
