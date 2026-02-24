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
        final shouldContinue = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Printing Failed'),
            content: const Text(
                'Could not print the Z-Report. Do you want to continue closing the shift without printing?'),
            actions: [
              TextButton(
                onPressed: () {
                  // To allow retrying, we just close the dialog.
                  // The user can then press the "CLOSE SHIFT & PRINT" button again.
                  Navigator.of(context).pop(false);
                },
                child: const Text('Retry'),
              ),
              TextButton(
                onPressed: () {
                  // Continue with closing the shift.
                  Navigator.of(context).pop(true);
                },
                child: const Text('Continue without Printing'),
              ),
            ],
          ),
        );

        // If the user chooses to not continue (i.e., they want to retry),
        // we stop the execution of this function.
        if (shouldContinue != true) {
          return; // Stop the close shift process.
        }
      }
    }

    // 3. Clear active shift state
    ref.read(activeShiftIdProvider.notifier).state = null;

    // 4. Force Sync
    ref.read(syncControllerProvider.notifier).performSync();

    // 5. Navigate to Login
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_summary == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Close Shift")),
        body: const Center(
          child: Text("No active shift."),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Close Shift"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Shift Summary", ),
            const Divider(height: 30),
            _buildSummaryRow("Total Sales:", _summary!.totalSales),
            _buildSummaryRow("Cash Sales:", _summary!.cashSales),
            _buildSummaryRow("Digital Sales:", _summary!.digitalSales),
            const Divider(height: 30),
            _buildSummaryRow("Starting Cash:", _summary!.shift.startingCash),
            _buildSummaryRow("Expected Cash in Drawer:", _summary!.expectedCash),
            const SizedBox(height: 30),
            Text("Counted Cash", ),
            const SizedBox(height: 10),
            TextField(
              controller: _cashController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
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

  Widget _buildSummaryRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text("₺${value.toStringAsFixed(2)}",
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }
}
