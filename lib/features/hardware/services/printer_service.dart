import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../pos/models/cart_item.dart';
import 'receipt_generator.dart';

class PrinterService {
  final _generator = ReceiptGenerator();
  
  // --- BLUETOOTH METHODS (Android) ---
  Future<bool> checkPermission() async {
    if (!Platform.isAndroid) return false;
    return await PrintBluetoothThermal.isPermissionBluetoothGranted;
  }

  Future<List<BluetoothInfo>> getPairedDevices() async {
    if (!Platform.isAndroid) return [];
    return await PrintBluetoothThermal.pairedBluetooths;
  }

  Future<bool> connect(String macAddress) async {
    if (!Platform.isAndroid) return false;
    return await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
  }

  // --- UNIVERSAL PRINT ROUTER ---
  Future<void> printReceipt({
    required String orderId,
    required List<CartItem> items,
    required double total,
    required double tendered,
    required String paymentMethod,
    required String cashierName,
  }) async {
    
    // 1. WINDOWS ROUTING (OS Print Spooler via PDF)
    if (Platform.isWindows) {
      final prefs = await SharedPreferences.getInstance();
      final targetPrinterName = prefs.getString('os_printer_name');

      final pdfBytes = await _generator.generatePdfReceipt(
        orderId: orderId, items: items, total: total, 
        tendered: tendered, paymentMethod: paymentMethod, cashierName: cashierName
      );

      if (targetPrinterName != null && targetPrinterName.isNotEmpty) {
        // Print directly silently if configured
        final targetPrinter = Printer(url: targetPrinterName, isAvailable: true, name: targetPrinterName);
        await Printing.directPrintPdf(printer: targetPrinter, onLayout: (_) => pdfBytes);
      } else {
        // Fallback: Show print dialog
        await Printing.layoutPdf(onLayout: (_) => pdfBytes, name: 'Receipt_$orderId');
      }
      return;
    }

    // 2. ANDROID ROUTING (Bluetooth ESC/POS)
    if (Platform.isAndroid) {
      final bool isConnected = await PrintBluetoothThermal.connectionStatus;
      if (isConnected) {
        final List<int> bytes = await _generator.generateTicket(
          orderId: orderId, items: items, total: total, 
          tendered: tendered, paymentMethod: paymentMethod, cashierName: cashierName
        );
        await PrintBluetoothThermal.writeBytes(bytes);
      } else {
        print("Bluetooth Printer not connected on Android.");
      }
    }
  }

  Future<void> printZReport({
    required String shiftId, required String cashierName, required DateTime openingTime,
    required DateTime closingTime, required double openingCash, required double totalSales,
    required double cashSales, required double digitalSales, required double expectedCash,
    required double actualCash,
  }) async {
    if (Platform.isWindows) {
       // Similar implementation using pdf document builder for Z-report...
       // For now, prompt the layout
       await Printing.layoutPdf(onLayout: (_) => _generator.generatePdfReceipt(
          orderId: shiftId, items: [], total: totalSales, tendered: actualCash, paymentMethod: "Z-REPORT", cashierName: cashierName
       ));
       return;
    }
    
    if (Platform.isAndroid && await PrintBluetoothThermal.connectionStatus) {
       final bytes = await _generator.generateZReport(
          shiftId: shiftId, cashierName: cashierName, openingTime: openingTime, closingTime: closingTime, openingCash: openingCash, totalSales: totalSales, cashSales: cashSales, digitalSales: digitalSales, expectedCash: expectedCash, actualCash: actualCash
       );
       await PrintBluetoothThermal.writeBytes(bytes);
    }
  }
}

final printerServiceProvider = Provider((ref) => PrinterService());