import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../../pos/models/cart_item.dart';
import 'receipt_generator.dart';

class PrinterService {
  final _generator = ReceiptGenerator();

  // 1. Check Permissions (Android only)
  Future<bool> checkPermission() async {
    if (!Platform.isAndroid) return false;
    
    // print_bluetooth_thermal handles permission requests internally usually,
    // but explicit checking is safer.
    final bool result = await PrintBluetoothThermal.isPermissionBluetoothGranted;
    if (!result) {
       // Only if false, we might want to prompt user. 
       // For now, the library often requests it automatically.
    }
    return result;
  }

  // 2. Scan Devices
  Future<List<BluetoothInfo>> getPairedDevices() async {
    if (!Platform.isAndroid) {
      // Return empty list on Windows for now (avoid crash)
      return [];
    }
    
    // Wait slightly to ensure permissions are active
    final bool permission = await PrintBluetoothThermal.isPermissionBluetoothGranted;
    if (!permission) return [];

    try {
      final List<BluetoothInfo> list = await PrintBluetoothThermal.pairedBluetooths;
      return list;
    } catch (e) {
      print("Error finding devices: $e");
      return [];
    }
  }

  // 3. Connect
  Future<bool> connect(String macAddress) async {
    if (!Platform.isAndroid) return false;
    
    try {
      final bool connected = await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
      return connected;
    } catch (e) {
      print("Error connecting: $e");
      return false;
    }
  }

  // 4. Print
  Future<void> printReceipt({
    required String orderId,
    required List<CartItem> items,
    required double total,
    required double tendered,
    required String paymentMethod,
    required String cashierName,
  }) async {
    if (!Platform.isAndroid) {
      print("Printing not yet implemented for Windows (Requires USB driver integration)");
      return;
    }

    // Check connection status
    final bool isConnected = await PrintBluetoothThermal.connectionStatus;
    if (!isConnected) {
      print("Printer not connected");
      return;
    }

    // Generate Bytes
    final List<int> bytes = await _generator.generateTicket(
      orderId: orderId,
      items: items,
      total: total,
      tendered: tendered,
      paymentMethod: paymentMethod,
      cashierName: cashierName,
    );

    // Send to Printer
    await PrintBluetoothThermal.writeBytes(bytes);
  }
}

final printerServiceProvider = Provider((ref) => PrinterService());