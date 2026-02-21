import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../pos/models/cart_item.dart';

class PrinterService {
  final BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;

  // Get list of paired devices
  Future<List<BluetoothDevice>> getPairedDevices() async {
    return await bluetooth.getBondedDevices();
  }

  // Connect to specific device
  Future<void> connect(BluetoothDevice device) async {
    bool? isConnected = await bluetooth.isConnected;
    if (isConnected == true) {
      await bluetooth.connect(device);
    }
  }

  // THE RECEIPT LOGIC
  Future<void> printReceipt({
    required String orderId,
    required List<CartItem> items,
    required double total,
    required double tendered,
    required String paymentMethod,
    required String cashierName,
  }) async {
    if ((await bluetooth.isConnected) != true) return;

    final fmt = NumberFormat("#,##0", "en_US");
    final date = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    // 1. Header
    bluetooth.printCustom("QRISTAL POS", 3, 1); // Size 3, Center
    bluetooth.printCustom("Kampala, Uganda", 1, 1);
    bluetooth.printCustom("Tel: +256 700 000000", 1, 1);
    bluetooth.printNewLine();

    // 2. Meta Data
    bluetooth.printLeftRight(
      "Rcpt: ${orderId.substring(0, 6)}",
      "Staff: $cashierName",
      1,
    );
    bluetooth.printCustom("Date: $date", 1, 0); // Left align
    bluetooth.printCustom("--------------------------------", 1, 1);

    // 3. Items
    bluetooth.printLeftRight("Item", "Total (UGX)", 1);

    for (var item in items) {
      // Print Item Name
      bluetooth.printCustom(item.product.name, 1, 0);

      // Print Qty x Price and Line Total
      String quantityLine =
          "${item.quantity} x ${fmt.format(item.product.price)}";
      String totalLine = fmt.format(item.total);

      bluetooth.printLeftRight(quantityLine, totalLine, 0);
    }

    bluetooth.printCustom("--------------------------------", 1, 1);

    // 4. Totals
    bluetooth.printLeftRight("TOTAL", fmt.format(total), 2); // Size 2 (Larger)
    bluetooth.printNewLine();
    bluetooth.printLeftRight("PAID ($paymentMethod)", fmt.format(tendered), 1);
    bluetooth.printLeftRight("CHANGE", fmt.format(tendered - total), 1);

    // 5. Footer
    bluetooth.printNewLine();
    bluetooth.printCustom("Thank you for dining with us!", 1, 1);
    bluetooth.printCustom("Powered by Qristal", 0, 1);
    bluetooth.printNewLine();
    bluetooth.printNewLine();
    bluetooth.paperCut(); // Only works on supported printers
  }
}

final printerServiceProvider = Provider((ref) => PrinterService());
