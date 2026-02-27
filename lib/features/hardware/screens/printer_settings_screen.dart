import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../services/printer_service.dart';

class PrinterSettingsScreen extends ConsumerStatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  ConsumerState<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends ConsumerState<PrinterSettingsScreen> {
  // State for Android
  List<BluetoothInfo> _btDevices = [];
  String? _selectedBtAddress;
  
  // State for Windows
  List<Printer> _osPrinters = [];
  String? _selectedOsPrinterName;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initPrinters();
  }

  Future<void> _initPrinters() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();

    if (Platform.isAndroid) {
      final printer = ref.read(printerServiceProvider);
      await printer.checkPermission();
      final devices = await printer.getPairedDevices();
      setState(() {
        _btDevices = devices;
        _selectedBtAddress = prefs.getString('printer_mac');
      });
    } else if (Platform.isWindows) {
      final printers = await Printing.listPrinters();
      setState(() {
        _osPrinters = printers.where((p) => p.isAvailable).toList();
        _selectedOsPrinterName = prefs.getString('os_printer_name');
      });
    }
    setState(() => _isLoading = false);
  }

  // Handle Android Connection
  Future<void> _connectAndroid(String macAddress) async {
    setState(() => _isLoading = true);
    final printer = ref.read(printerServiceProvider);
    final success = await printer.connect(macAddress);
    
    if (success) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('printer_mac', macAddress);
      setState(() => _selectedBtAddress = macAddress);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bluetooth Printer Connected!"), backgroundColor: AppTheme.emerald));
    }
    setState(() => _isLoading = false);
  }

  // Handle Windows Selection
  Future<void> _saveWindowsPrinter(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('os_printer_name', name);
    setState(() => _selectedOsPrinterName = name);
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("System Printer Set as Default!"), backgroundColor: AppTheme.emerald));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Terminal Printer Settings")),
      body: Column(
        children: [
          if (_isLoading) const LinearProgressIndicator(),

          // ANDROID BLUETOOTH VIEW
          if (Platform.isAndroid) ...[
            Container(padding: const EdgeInsets.all(16), child: const Text("Paired Bluetooth Printers", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
            Expanded(
              child: _btDevices.isEmpty ? const Center(child: Text("No paired devices found")) : ListView.builder(
                itemCount: _btDevices.length,
                itemBuilder: (context, index) {
                  final device = _btDevices[index];
                  final isConnected = _selectedBtAddress == device.macAdress;

                  return ListTile(
                    leading: const Icon(Icons.bluetooth),
                    title: Text(device.name),
                    subtitle: Text(device.macAdress),
                    trailing: isConnected 
                      ? const Icon(Icons.check_circle, color: AppTheme.emerald)
                      : ElevatedButton(onPressed: () => _connectAndroid(device.macAdress), child: const Text("Connect")),
                  );
                },
              ),
            ),
          ],

          // WINDOWS NATIVE SPOOLER VIEW
          if (Platform.isWindows) ...[
            Container(padding: const EdgeInsets.all(16), child: const Text("Available System Printers", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
            Expanded(
              child: _osPrinters.isEmpty ? const Center(child: Text("No system printers installed.")) : ListView.builder(
                itemCount: _osPrinters.length,
                itemBuilder: (context, index) {
                  final printer = _osPrinters[index];
                  final isSelected = _selectedOsPrinterName == printer.name;

                  return ListTile(
                    leading: const Icon(Icons.print),
                    title: Text(printer.name),
                    subtitle: Text(printer.url),
                    trailing: isSelected 
                      ? const Icon(Icons.check_circle, color: AppTheme.emerald)
                      : ElevatedButton(onPressed: () => _saveWindowsPrinter(printer.name), child: const Text("Set as Default")),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}