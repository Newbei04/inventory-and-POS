import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../widgets/store_receipt_header.dart';

class PosReceiptDialog extends StatelessWidget {
  final List<PosReceiptLine> items;
  final double total;
  final double cash;
  final String receiptNo;

  const PosReceiptDialog({
    super.key,
    required this.items,
    required this.total,
    required this.cash,
    required this.receiptNo,
  });

  double get change => cash - total;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 36, 28, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const StoreReceiptHeader(),
                const SizedBox(height: 16),
                Text(
                  'SALE RECEIPT',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    letterSpacing: 2,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Receipt #$receiptNo',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 20),
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                            Text(
                              '₱${item.lineTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${item.quantity} × ₱${item.unitPrice.toStringAsFixed(2)}',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TOTAL',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      '₱${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Cash',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 14)),
                    Text('₱${cash.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 14)),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Change',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 14)),
                    Text(
                      '₱${change.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: change >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  DateFormat('MMM d, yyyy  h:mm a').format(now),
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade400,
                      fontFamily: 'monospace'),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child:
                        const Text('Done', style: TextStyle(fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PosReceiptLine {
  final String name;
  final int quantity;
  final double unitPrice;
  final double lineTotal;

  const PosReceiptLine({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });
}
