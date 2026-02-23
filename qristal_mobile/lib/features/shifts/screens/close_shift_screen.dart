import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../hardware/services/printer_service.dart';
import '../../sync/providers/sync_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/login_screen.dart';
import '../providers/shift_provider.dart';

class CloseShiftScreen extends ConsumerStatefulWidget {
  const CloseShiftScreen({super.key});

  @override
  ConsumerState<CloseShiftScreen> createState() => _CloseShiftScreenState();
}

class _CloseShiftScreenState extends ConsumerState<CloseShiftScreen> {
  final _cashController = TextEditingController();
  ShiftSummary? _summary;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final shiftId = ref.read(activeShiftIdProvider);

    if (shiftId == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final summary = await ref.read(shiftServiceProvider).getShiftSummary(shiftId);
    if (!mounted) return;

    setState(() {
      _summary = summary;
      _isLoading = false;
    });
  }

  Future<void> _handleCloseShift() async {
    if (_summary == null) return;

    final actualCash = double.tryParse(_cashController.text) ?? 0.0;
    final shiftId = _summary!.shift.id;

    // 1. Update Database
    await ref.read(shiftServiceProvider).closeShift(shiftId, actualCash);

    // 2. Print Z-Report
    try {
      await ref.read(printerServiceProvider).printZReport(
            shiftId: shiftId,
            cashierName: "Cashier", // Replace with real name later
            openingTime: _summary!.shift.openingTime,
            closingTime: DateTime.now(),
            openingCash: _summary!.shift.startingCash,
            totalSales: _summary!.totalSales,
            cashSales: _summary!.cashSales,
            digitalSales: _summary!.digitalSales,
            expectedCash: _summary!.expectedCash,
            actualCash: actualCash,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Failed to print Z-Report (continuing logout)")));
      }
    }

    // 3. Clear active shift state
    ref.read(activeShiftIdProvider.notifier).state = null;

    // 4. Force Sync
    ref.read(syncControllerProvider.notifier).performSync();

    // 5. Logout and return to Login Screen
    await ref.read(authControllerProvider.notifier).logout();

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_summary == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("End of Day - Z Report")),
        body: const Center(
          child: Text("No active shift found. Open a shift before closing."),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("End of Day - Z Report")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCard(),
            const SizedBox(height: 30),
            const Text("Cash Reconciliation",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(
              "Expected Cash in Drawer: UGX ${_summary!.expectedCash.toStringAsFixed(0)}",
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _cashController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Actual Counted Cash",
                prefixIcon: Icon(Icons.attach_money),
                hintText: "Enter amount counted",
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
                onPressed: _handleCloseShift,
                child: const Text("CLOSE SHIFT & PRINT",
                    style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _row("Opening Float", _summary!.shift.startingCash),
          const Divider(),
          _row("Cash Sales", _summary!.cashSales),
          _row("Mobile Money / Card", _summary!.digitalSales),
          const Divider(thickness: 2),
          _row("Total Sales", _summary!.totalSales, isBold: true),
        ],
      ),
    );
  }

  Widget _row(String label, double amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            "UGX ${amount.toStringAsFixed(0)}",
            style: TextStyle(
                color: isBold ? AppTheme.emerald : Colors.white,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                fontSize: isBold ? 18 : 14),
          ),
        ],
      ),
    );
  }
}
