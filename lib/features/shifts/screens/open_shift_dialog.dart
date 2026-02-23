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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Open Register"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Enter the starting cash in the till:"),
          const SizedBox(height: 16),
          TextField(
            controller: _cashController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Starting Cash (UGX)",
              prefixIcon: Icon(Icons.attach_money),
            ),
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () async {
            final startingCash = double.tryParse(_cashController.text) ?? 0.0;
            final shiftId = await ref
                .read(shiftServiceProvider)
                .openShift(widget.userId, startingCash);

            // Set active shift in state
            ref.read(activeShiftIdProvider.notifier).state = shiftId;

            if (context.mounted) {
              Navigator.of(context).pop(); // Close dialog
            }
          },
          child: const Text("Open Shift"),
        )
      ],
    );
  }
}
