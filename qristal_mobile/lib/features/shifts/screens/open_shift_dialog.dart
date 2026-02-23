// lib/features/shifts/screens/open_shift_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/shift_provider.dart';

class OpenShiftDialog extends ConsumerStatefulWidget {
  final String userId;
  const OpenShiftDialog({super.key, required this.userId});

  @override
  ConsumerState<OpenShiftDialog> createState() => _OpenShiftDialogState();
}

class _OpenShiftDialogState extends ConsumerState<OpenShiftDialog> {
  final _cashController = TextEditingController();
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Open Register"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
              "Enter the starting cash amount in the drawer to begin your shift."),
          const SizedBox(height: 16),
          TextField(
            controller: _cashController,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: "Starting Cash (UGX)",
              prefixIcon: Icon(Icons.money),
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            // Prevent backing out without opening shift, force logout effectively in real app
            // For now just pop
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel")),
        ElevatedButton(
          onPressed: _isSubmitting
              ? null
              : () async {
                  setState(() => _isSubmitting = true);
                  final startingCash =
                      double.tryParse(_cashController.text) ?? 0.0;

                  try {
                    final shiftId = await ref
                        .read(shiftServiceProvider)
                        .openShift(widget.userId, startingCash);

                    // Set active shift in state
                    ref.read(activeShiftIdProvider.notifier).state = shiftId;

                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  } catch (e) {
                    // handle error
                  } finally {
                    if (mounted) setState(() => _isSubmitting = false);
                  }
                },
          child: _isSubmitting
              ? const SizedBox(
                  width: 20, height: 20, child: CircularProgressIndicator())
              : const Text("Open Shift"),
        )
      ],
    );
  }
}
