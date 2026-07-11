import 'package:flutter/material.dart';

import '../../models/receipt.dart';

class ReceiptRefundDialog extends StatefulWidget {
  final Receipt receipt;
  const ReceiptRefundDialog({super.key, required this.receipt});

  @override
  State<ReceiptRefundDialog> createState() => _ReceiptRefundDialogState();
}

class _ReceiptRefundDialogState extends State<ReceiptRefundDialog> {
  final _selected = <int>{};
  final _qtys = <int, int>{};

  Receipt get _r => widget.receipt;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < _r.items.length; i++) {
      if (!_r.refundedItemIndices.contains(i)) {
        _qtys[i] = _r.items[i].quantity;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalUnits =
        _selected.fold<int>(0, (s, i) => s + (_qtys[i] ?? 0));
    final totalAmount = _selected.fold<double>(
        0, (s, i) => s + _r.items[i].price * (_qtys[i] ?? 0));
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.replay, color: Colors.orange, size: 24),
          const SizedBox(width: 10),
          const Expanded(child: Text('Refund Items')),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_selected.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_selected.length} item${_selected.length == 1 ? '' : 's'} · $totalUnits unit${totalUnits == 1 ? '' : 's'} · ₱${totalAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _r.items.length,
                itemBuilder: (_, i) => _buildItemRow(i),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.pop(context, _buildResult()),
          style: FilledButton.styleFrom(backgroundColor: Colors.orange),
          child: Text(
              'Refund ${_selected.length} Item${_selected.length == 1 ? '' : 's'}'),
        ),
      ],
    );
  }

  Map<int, int> _buildResult() {
    final result = <int, int>{};
    for (final i in _selected) {
      result[i] = _qtys[i] ?? _r.items[i].quantity;
    }
    return result;
  }

  Widget _buildItemRow(int i) {
    final item = _r.items[i];
    final alreadyRefunded = _r.refundedItemIndices.contains(i);
    final isSelected = _selected.contains(i);
    final maxQty = item.quantity;
    final currentQty = _qtys[i] ?? maxQty;
    return Opacity(
      opacity: alreadyRefunded ? 0.5 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            if (alreadyRefunded)
              Icon(Icons.check_circle,
                  size: 20, color: Colors.orange.shade500)
            else
              Checkbox(
                value: isSelected,
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _selected.add(i);
                      _qtys[i] = maxQty;
                    } else {
                      _selected.remove(i);
                    }
                  });
                },
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      decoration: alreadyRefunded
                          ? TextDecoration.lineThrough
                          : null,
                      color: alreadyRefunded ? Colors.grey : null,
                    ),
                  ),
                  Text(
                    alreadyRefunded
                        ? 'Refunded'
                        : '₱${item.price.toStringAsFixed(2)} × $maxQty',
                    style: TextStyle(
                      fontSize: 11,
                      color: alreadyRefunded
                          ? Colors.orange.shade500
                          : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            if (!alreadyRefunded && isSelected) ...[
              IconButton(
                onPressed: currentQty > 1
                    ? () => setState(() => _qtys[i] = currentQty - 1)
                    : null,
                icon:
                    const Icon(Icons.remove_circle_outline, size: 20),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              Text(
                '$currentQty',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
              IconButton(
                onPressed: currentQty < maxQty
                    ? () => setState(() => _qtys[i] = currentQty + 1)
                    : null,
                icon: const Icon(Icons.add_circle_outline, size: 20),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
