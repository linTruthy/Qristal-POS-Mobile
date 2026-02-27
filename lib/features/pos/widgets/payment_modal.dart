import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';

class PaymentModal extends ConsumerStatefulWidget {
  final double totalAmount;
  final Function(String method, double amount, String? ref) onConfirmed;

  const PaymentModal({
    super.key,
    required this.totalAmount,
    required this.onConfirmed,
  });

  @override
  ConsumerState<PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends ConsumerState<PaymentModal> {
  String _selectedMethod = 'CASH';
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _refController =
      TextEditingController(); // For Mobile Money

  @override
  void initState() {
    super.initState();
    _amountController.text =
        widget.totalAmount.toStringAsFixed(0); // Default to full amount
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Settle Order",
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(),
            const SizedBox(height: 16),

            // Total Display
            Center(
              child: Text(
                "Total Due: ugx ${widget.totalAmount.toStringAsFixed(0)}",
                style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.emerald),
              ),
            ),
            const SizedBox(height: 24),

            // Payment Methods Tabs
            Row(
              children: [
                _methodCard("CASH", Icons.money, Colors.green),
                const SizedBox(width: 10),
                _methodCard("MOBILE_MONEY", Icons.phone_android, Colors.amber),
                const SizedBox(width: 10),
                _methodCard("CARD", Icons.credit_card, Colors.blue),
              ],
            ),
            const SizedBox(height: 24),

            // Input Fields
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Amount Tendered"),
              style: const TextStyle(fontSize: 24),
            ),

            if (_selectedMethod == 'MOBILE_MONEY') ...[
              const SizedBox(height: 10),
              TextField(
                controller: _refController,
                decoration: const InputDecoration(
                    labelText: "Transaction Reference (Optional)"),
              ),
            ],

            const SizedBox(height: 24),

            // Quick Cash Buttons
            if (_selectedMethod == 'CASH')
              Wrap(
                spacing: 10,
                children: [500, 1000, 2000, 5000, 10000, 20000, 50000]
                    .map((amount) => ActionChip(
                          label: Text(amount.toString()),
                          onPressed: () =>
                              _amountController.text = amount.toString(),
                        ))
                    .toList(),
              ),

            const SizedBox(height: 24),

            // Complete Button
            SizedBox(
              height: 60,
              child: ElevatedButton(
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald),
                onPressed: () {
                  final tendered = double.tryParse(_amountController.text) ?? 0;
                  if (tendered < widget.totalAmount) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Insufficient Amount")));
                    return;
                  }

                  // Calculate Change
                  final change = tendered - widget.totalAmount;
                  if (change > 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Change Due: $change")));
                  }

                  widget.onConfirmed(_selectedMethod, tendered,
                      _refController.text.isEmpty ? null : _refController.text);
                  Navigator.pop(context);
                },
                child: const Text("COMPLETE PAYMENT",
                    style: TextStyle(fontSize: 20)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _methodCard(String id, IconData icon, Color color) {
    final isSelected = _selectedMethod == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedMethod = id),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.2) : AppTheme.surface,
            border: Border.all(
                color: isSelected ? color : Colors.transparent, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? color : Colors.grey, size: 30),
              const SizedBox(height: 4),
              Text(id.replaceAll('_', ' '),
                  style: TextStyle(
                      color: isSelected ? color : Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
