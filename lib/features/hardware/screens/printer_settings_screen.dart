import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/printer_service.dart';

class PrinterSettingsScreen extends ConsumerStatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  ConsumerState<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends ConsumerState<PrinterSettingsScreen> {
  List<BluetoothInfo> _devices = [];
  String? _selectedAddress;
  bool _isLoading = false;
  String _statusMessage = "";

  @override
  void initState() {
    super.initState();
    _initPrinter();
  }

  Future<void> _initPrinter() async {
    if (!Platform.isAndroid) {
      setState(() {
        _statusMessage = "Bluetooth Printing is only supported on Android terminals.";
      });
      return;
    }

    setState(() => _isLoading = true);
    final printer = ref.read(printerServiceProvider);
    
    // Check permission first
    await printer.checkPermission();
    
    final devices = await printer.getPairedDevices();
    final prefs = await SharedPreferences.getInstance();
    final savedAddress = prefs.getString('printer_mac');

    setState(() {
      _devices = devices;
      _selectedAddress = savedAddress;
      _isLoading = false;
    });
  }

  Future<void> _connect(String macAddress) async {
    setState(() => _isLoading = true);
    final printer = ref.read(printerServiceProvider);
    
    final success = await printer.connect(macAddress);
    
    setState(() {
      _isLoading = false;
    });

    if (success) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('printer_mac', macAddress);
      setState(() => _selectedAddress = macAddress);
      
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Printer Connected!")));
    } else {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connection Failed")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Printer Settings")),
      body: Column(
        children: [
          if (_statusMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(color: Colors.amber, child: Padding(padding: const EdgeInsets.all(8), child: Text(_statusMessage))),
            ),
          
          if (_isLoading) const LinearProgressIndicator(),

          Expanded(
            child: _devices.isEmpty 
              ? const Center(child: Text("No paired devices found"))
              : ListView.builder(
                  itemCount: _devices.length,
                  itemBuilder: (context, index) {
                    final device = _devices[index];
                    final isConnected = _selectedAddress == device.macAdress;

                    return ListTile(
                      leading: const Icon(Icons.print),
                      title: Text(device.name),
                      subtitle: Text(device.macAdress),
                      trailing: isConnected 
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : ElevatedButton(
                            onPressed: () => _connect(device.macAdress),
                            child: const Text("Connect"),
                          ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}