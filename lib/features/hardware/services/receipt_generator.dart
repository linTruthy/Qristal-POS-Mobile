import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';
import '../../pos/models/cart_item.dart';

class ReceiptGenerator {
  // Generate the byte list for the printer
  Future<List<int>> generateTicket({
    required String orderId,
    required List<CartItem> items,
    required double total,
    required double tendered,
    required String paymentMethod,
    required String cashierName,
  }) async {
    // 1. Load the Capability Profile (usually 'default' works for most Chinese printers)
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile); // 58mm paper is standard for cheap handhelds
    
    List<int> bytes = [];

    // 2. Header
    bytes += generator.text('QRISTAL POS',
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          bold: true,
        ));
    bytes += generator.text('Kampala, Uganda', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('Tel: +256 700 000000', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.hr();
    
    // 3. Meta Data
    bytes += generator.row([
      PosColumn(text: 'Rcpt: ${orderId.substring(0, 6)}', width: 6),
      PosColumn(text: 'Staff: $cashierName', width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.text('Date: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}');
    bytes += generator.hr();

    // 4. Items Header
    bytes += generator.row([
      PosColumn(text: 'Item', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(text: 'Total', width: 6, styles: const PosStyles(bold: true, align: PosAlign.right)),
    ]);
    
    // 5. Items List
    final fmt = NumberFormat("#,##0", "en_US");
    for (var item in items) {
      bytes += generator.row([
        PosColumn(
            text: '${item.quantity}x ${item.product.name}', 
            width: 8,
            styles: const PosStyles(align: PosAlign.left)
        ),
        PosColumn(
            text: fmt.format(item.total), 
            width: 4, 
            styles: const PosStyles(align: PosAlign.right)
        ),
      ]);
    }

    bytes += generator.hr();

    // 6. Totals
    bytes += generator.row([
      PosColumn(text: 'TOTAL', width: 6, styles: const PosStyles(height: PosTextSize.size2, bold: true)),
      PosColumn(
          text: fmt.format(total), 
          width: 6, 
          styles: const PosStyles(align: PosAlign.right, height: PosTextSize.size2, bold: true)
      ),
    ]);

    bytes += generator.text('Paid via $paymentMethod: ${fmt.format(tendered)}');
    bytes += generator.text('Change: ${fmt.format(tendered - total)}');

    // 7. Footer
    bytes += generator.feed(1);
    bytes += generator.text('Thank you for visiting!', styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text('Powered by Qristal POS', styles: const PosStyles(align: PosAlign.center, codeTable: 'CP1252'));
    bytes += generator.feed(2);
    bytes += generator.cut();

    return bytes;
  }
}