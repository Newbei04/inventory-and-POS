import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/receipt.dart';
import '../../widgets/store_receipt_header.dart';

class ReceiptViewDialog extends StatefulWidget {
  final Receipt receipt;
  final VoidCallback? onVoid;
  final void Function(List<int> itemIndices)? onRefund;

  const ReceiptViewDialog({
    super.key,
    required this.receipt,
    this.onVoid,
    this.onRefund,
  });

  @override
  State<ReceiptViewDialog> createState() => _ReceiptViewDialogState();
}

class _ReceiptViewDialogState extends State<ReceiptViewDialog> {
  final _selectedItems = <int>{};

  Receipt get _r => widget.receipt;
  bool get _canAct =>
      _r.canModify &&
      DateTime.now().difference(DateTime.parse(_r.date)).inHours < 24;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Stack(
          children: [
            SingleChildScrollView(
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
                      'Receipt #${_r.receiptNo}',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_canAct && _selectedItems.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: Colors.orange.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 16,
                                  color: Colors.orange.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${_selectedItems.length} item${_selectedItems.length == 1 ? '' : 's'} selected for refund',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange.shade800,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ..._r.items.asMap().entries.map(
                      (entry) => _buildItemRow(entry.key, entry.value),
                    ),
                    const Divider(height: 20),
                    _buildTotals(),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${_r.totalItemsQty} total unit${_r.totalItemsQty == 1 ? '' : 's'}  ·  ${_r.items.length} line${_r.items.length == 1 ? '' : 's'}',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildCashChange(),
                    const SizedBox(height: 16),
                    Text(
                      DateFormat('MMM d, yyyy  h:mm a')
                          .format(DateTime.parse(_r.date)),
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                          fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 20),
                    if (_r.isVoided)
                      _buildStatusBanner(
                          'This receipt has been voided',
                          Colors.red.shade50,
                          Colors.red.shade200,
                          Colors.red.shade600)
                    else if (_r.isFullyRefunded)
                      _buildStatusBanner(
                          'This receipt has been fully refunded',
                          Colors.orange.shade50,
                          Colors.orange.shade200,
                          Colors.orange.shade700)
                    else if (_canAct) ...[
                      if (_selectedItems.isNotEmpty)
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.replay, size: 20),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange,
                              side: BorderSide(
                                  color: Colors.orange.shade300),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                            ),
                            onPressed: _onRefundSelected,
                            label: Text(
                                'Refund ${_selectedItems.length} Item${_selectedItems.length == 1 ? '' : 's'}',
                                style:
                                    const TextStyle(fontSize: 15)),
                          ),
                        ),
                      if (_selectedItems.isNotEmpty)
                        const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          icon:
                              const Icon(Icons.cancel_outlined, size: 20),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: BorderSide(
                                color: Colors.red.shade300),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12)),
                          ),
                          onPressed: _onVoid,
                          label: const Text('Void Receipt',
                              style: TextStyle(fontSize: 15)),
                        ),
                      ),
                    ] else
                      Container(
                        width: double.infinity,
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Action window expired (24h limit)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 13),
                        ),
                      ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close',
                            style: TextStyle(fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_r.isVoided || _r.isFullyRefunded)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Transform.rotate(
                      angle: -0.5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _r.isVoided
                                ? Colors.red.shade400
                                : Colors.orange.shade400,
                            width: 4,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _r.isVoided ? 'VOID' : 'REFUNDED',
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            color: _r.isVoided
                                ? Colors.red.shade300
                                : Colors.orange.shade300,
                            letterSpacing: 6,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(int idx, ReceiptItem item) {
    final alreadyRefunded = _r.refundedItemIndices.contains(idx);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_canAct && !alreadyRefunded)
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 1),
                  child: Checkbox(
                    value: _selectedItems.contains(idx),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selectedItems.add(idx);
                        } else {
                          _selectedItems.remove(idx);
                        }
                      });
                    },
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              if (alreadyRefunded)
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 2),
                  child: Icon(Icons.check_circle,
                      size: 18, color: Colors.orange.shade500),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.productName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              decoration: alreadyRefunded
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: alreadyRefunded
                                  ? Colors.grey
                                  : null,
                            ),
                          ),
                        ),
                        Text(
                          '₱${item.total.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            decoration: alreadyRefunded
                                ? TextDecoration.lineThrough
                                : null,
                            color: alreadyRefunded
                                ? Colors.grey
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.quantity} × ₱${item.price.toStringAsFixed(2)}${alreadyRefunded ? '  (refunded)' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: alreadyRefunded
                            ? Colors.orange.shade500
                            : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotals() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('TOTAL',
            style:
                TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(
          '₱${_r.total.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            decoration: _r.isVoided || _r.isFullyRefunded
                ? TextDecoration.lineThrough
                : null,
            color: _r.isVoided
                ? Colors.red
                : _r.isFullyRefunded
                    ? Colors.orange
                    : null,
          ),
        ),
      ],
    );
  }

  Widget _buildCashChange() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Cash',
                style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 14)),
            Text('₱${_r.cash.toStringAsFixed(2)}',
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
              '₱${_r.change.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color:
                    _r.change >= 0 ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusBanner(
      String text, Color bg, Color border, Color textColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
      ),
    );
  }

  void _onVoid() {
    widget.onVoid?.call();
    Navigator.pop(context);
  }

  void _onRefundSelected() {
    widget.onRefund?.call(_selectedItems.toList());
    Navigator.pop(context);
  }
}
