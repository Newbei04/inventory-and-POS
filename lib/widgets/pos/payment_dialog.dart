import 'package:flutter/material.dart';

class PaymentDialog extends StatefulWidget {
  final double total;
  const PaymentDialog({super.key, required this.total});

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  final _ctrl = TextEditingController();

  List<double> get _suggestions {
    final t = widget.total;
    return [
      t,
      (t + 0.5 - t % 0.5),
      (t + 1 - t % 1),
      (t + 5 - t % 5),
      (t + 10 - t % 10),
      (t + 20 - t % 20),
      (t + 50 - t % 50),
      (t + 100 - t % 100),
    ]
        .map((v) => double.parse(v.toStringAsFixed(2)))
        .toSet()
        .toList()
      ..sort();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.total;
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: const Row(
        children: [
          Icon(Icons.payments, size: 24),
          SizedBox(width: 8),
          Text('Payment'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total:', style: TextStyle(fontSize: 16)),
              Text('₱${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  )),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Cash amount',
              prefixText: '₱ ',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _suggestions.map((s) {
              final isExact = s == total;
              return ActionChip(
                label: Text(
                  isExact ? 'Exact' : '₱${s.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isExact ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                onPressed: () => _ctrl.text = s.toStringAsFixed(2),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final raw = _ctrl.text.trim();
            final cash = double.tryParse(raw);
            if (cash == null || cash <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enter a valid amount')),
              );
            } else if (cash < total) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Cash (₱${cash.toStringAsFixed(2)}) is less than total (₱${total.toStringAsFixed(2)})',
                  ),
                ),
              );
            } else {
              Navigator.pop(context, cash);
            }
          },
          child: const Text('Pay'),
        ),
      ],
    );
  }
}
