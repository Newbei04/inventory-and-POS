import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/database_helper.dart';
import '../models/product.dart';
import 'scan_screen.dart';

class InventoryV2Screen extends StatefulWidget {
  const InventoryV2Screen({super.key});

  @override
  State<InventoryV2Screen> createState() => _InventoryV2ScreenState();
}

class _InventoryV2ScreenState extends State<InventoryV2Screen> {
  final _db = DatabaseHelper.instance;
  final List<_CountedItem> _countedItems = [];

  int get _totalScanned => _countedItems.length;
  int get _totalAdded =>
      _countedItems.where((e) => e.mode == _CountMode.add).length;
  int get _totalRemoved =>
      _countedItems.where((e) => e.mode == _CountMode.remove).length;

  Future<void> _scanBarcode() async {
    final barcode = await ScanScreen.pickAndScan(
      context,
      title: 'Scan to Count',
    );
    if (barcode == null || barcode.isEmpty || !mounted) return;
    await _onBarcodeScanned(barcode);
  }

  Future<void> _onBarcodeScanned(String barcode) async {
    final product = await _db.getProductByBarcode(barcode);
    if (!mounted) return;

    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No product found for barcode: $barcode'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.orange.shade700,
        ),
      );
      return;
    }

    final result = await showDialog<_CountResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CountDialog(product: product),
    );

    if (result == null || !mounted) return;

    setState(() {
      _countedItems.insert(0, result.item);
    });

    final delta = result.item.mode == _CountMode.add
        ? result.item.quantity
        : -result.item.quantity;
    final reasonLabel = result.item.reason?.label ?? '';
    await _db.adjustStock(result.product.id!, delta, reason: reasonLabel);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.item.mode == _CountMode.add
            ? '+${result.item.quantity} added to ${result.product.name}'
            : '${result.item.quantity} removed from ${result.product.name} (${result.item.reason?.label ?? "N/A"})'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: result.item.mode == _CountMode.add
            ? Colors.green.shade600
            : Colors.orange.shade700,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Count'),
        centerTitle: true,
        actions: [
          if (_countedItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.bar_chart_rounded),
              tooltip: 'Session Summary',
              onPressed: _showSummary,
            ),
        ],
      ),
      body: _countedItems.isEmpty ? _buildEmptyState() : _buildList(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.qr_code_scanner,
                  size: 56, color: Colors.blue.shade400),
            ),
            const SizedBox(height: 24),
            const Text(
              'No items counted yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Scan a barcode to add or remove stock.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _scanBarcode,
              icon: const Icon(Icons.qr_code_scanner, size: 20),
              label: const Text('Start Scanning'),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return Column(
      children: [
        _buildStatsBar(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            itemCount: _countedItems.length,
            itemBuilder: (_, i) => _countedItemCard(_countedItems[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statPill('$_totalScanned', 'Scanned', Colors.blue),
          Container(width: 1, height: 20, color: Colors.grey.shade300),
          _statPill('$_totalAdded', 'Added', Colors.green),
          Container(width: 1, height: 20, color: Colors.grey.shade300),
          _statPill('$_totalRemoved', 'Removed', Colors.orange),
        ],
      ),
    );
  }

  Widget _statPill(String value, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _countedItemCard(_CountedItem item) {
    final isAdd = item.mode == _CountMode.add;
    final Color statusColor = isAdd ? Colors.green : Colors.orange;
    final IconData statusIcon =
        isAdd ? Icons.add_circle : Icons.remove_circle;
    final String statusLabel = isAdd ? '+${item.quantity}' : '-${item.quantity}';

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 44,
                height: 44,
                child: item.product.imagePath.isNotEmpty
                    ? Image.file(
                        File(item.product.imagePath),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _productPlaceholder(item.product),
                      )
                    : _productPlaceholder(item.product),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        item.product.barcode,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      if (!isAdd && item.reason != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: item.reason!.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.reason!.label,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: item.reason!.color,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, color: statusColor, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productPlaceholder(Product p) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.inventory_2, color: Colors.grey.shade400, size: 20),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_countedItems.isNotEmpty)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showSummary,
                  icon: const Icon(Icons.summarize, size: 18),
                  label: const Text('Summary'),
                ),
              ),
            if (_countedItems.isNotEmpty) const SizedBox(width: 12),
            Expanded(
              flex: _countedItems.isEmpty ? 1 : 2,
              child: FilledButton.icon(
                onPressed: _scanBarcode,
                icon: const Icon(Icons.qr_code_scanner, size: 20),
                label: Text(
                    _countedItems.isEmpty ? 'Scan Barcode' : 'Scan Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSummary() {
    final added = _countedItems.where((e) => e.mode == _CountMode.add).toList();
    final removed =
        _countedItems.where((e) => e.mode == _CountMode.remove).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Session Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _summaryChip('$_totalScanned Scanned', Colors.blue),
                  const SizedBox(width: 8),
                  _summaryChip('$_totalAdded Added', Colors.green),
                  const SizedBox(width: 8),
                  _summaryChip('$_totalRemoved Removed', Colors.orange),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  if (added.isNotEmpty) ...[
                    _summarySectionHeader('Stock Added', Colors.green),
                    ...added.map((e) => _summaryTile(e)),
                    const SizedBox(height: 12),
                  ],
                  if (removed.isNotEmpty) ...[
                    _summarySectionHeader('Stock Removed', Colors.orange),
                    ...removed.map((e) => _summaryTile(e)),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color.lerp(color, Colors.black, 0.3),
        ),
      ),
    );
  }

  Widget _summarySectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Color.lerp(color, Colors.black, 0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryTile(_CountedItem item) {
    final isAdd = item.mode == _CountMode.add;
    final Color color = isAdd ? Colors.green : Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  if (!isAdd && item.reason != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.reason!.label,
                      style: TextStyle(
                        fontSize: 11,
                        color: item.reason!.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              isAdd ? '+${item.quantity}' : '-${item.quantity}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color.lerp(color, Colors.black, 0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data models ──

enum _CountMode { add, remove }

enum RemoveReason { expired, defective, destroyed }

extension _RemoveReasonLabel on RemoveReason {
  String get label {
    switch (this) {
      case RemoveReason.expired:
        return 'Expired';
      case RemoveReason.defective:
        return 'Defective';
      case RemoveReason.destroyed:
        return 'Destroyed';
    }
  }

  IconData get icon {
    switch (this) {
      case RemoveReason.expired:
        return Icons.event_busy;
      case RemoveReason.defective:
        return Icons.broken_image;
      case RemoveReason.destroyed:
        return Icons.delete_forever;
    }
  }

  Color get color {
    switch (this) {
      case RemoveReason.expired:
        return Colors.red;
      case RemoveReason.defective:
        return Colors.deepPurple;
      case RemoveReason.destroyed:
        return Colors.brown;
    }
  }
}

class _CountedItem {
  final Product product;
  final _CountMode mode;
  final int quantity;
  final RemoveReason? reason;

  const _CountedItem({
    required this.product,
    required this.mode,
    required this.quantity,
    this.reason,
  });
}

class _CountResult {
  final Product product;
  final _CountedItem item;

  const _CountResult(this.product, this.item);
}

// ── Dialog ──

class _CountDialog extends StatefulWidget {
  final Product product;
  const _CountDialog({required this.product});

  @override
  State<_CountDialog> createState() => _CountDialogState();
}

class _CountDialogState extends State<_CountDialog> {
  final _ctrl = TextEditingController();
  _CountMode _mode = _CountMode.add;
  RemoveReason? _selectedReason;
  String? _errorText;

  int get _currentStock => widget.product.quantity;
  int? get _qty => int.tryParse(_ctrl.text.trim());
  int get _newStock =>
      _qty != null
          ? (_mode == _CountMode.add ? _currentStock + _qty! : _currentStock - _qty!)
          : _currentStock;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final q = _qty;
    if (q == null || q <= 0) {
      setState(() => _errorText = 'Enter a quantity greater than 0');
      return;
    }
    if (_mode == _CountMode.remove && q > _currentStock) {
      setState(
          () => _errorText = 'Can\'t remove more than current stock ($_currentStock)');
      return;
    }
    if (_mode == _CountMode.remove && _selectedReason == null) {
      setState(() => _errorText = 'Select a reason for removal');
      return;
    }
    Navigator.pop(
      context,
      _CountResult(
        widget.product,
        _CountedItem(
          product: widget.product,
          mode: _mode,
          quantity: q,
          reason: _selectedReason,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final isAdd = _mode == _CountMode.add;
    final Color modeColor = isAdd ? Colors.green : Colors.orange;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      title: Row(
        children: [
          Icon(isAdd ? Icons.add_circle : Icons.remove_circle,
              color: modeColor, size: 22),
          const SizedBox(width: 8),
          Text(isAdd ? 'Add Stock' : 'Remove Stock',
              style: const TextStyle(fontSize: 18)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildProductInfo(p),
            const SizedBox(height: 16),
            _buildModeToggle(),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
              decoration: InputDecoration(
                labelText: isAdd ? 'Quantity to add' : 'Quantity to remove',
                prefixIcon: Icon(
                    isAdd ? Icons.add_shopping_cart : Icons.remove_shopping_cart),
                errorText: _errorText,
                suffixText: p.unit,
              ),
              onChanged: (_) {
                if (_errorText != null) setState(() => _errorText = null);
                setState(() {});
              },
              onSubmitted: (_) => _confirm(),
            ),
            if (!isAdd) ...[
              const SizedBox(height: 14),
              _buildReasonPicker(),
            ],
            if (_qty != null && _qty! > 0) ...[
              const SizedBox(height: 14),
              _buildPreviewRow(isAdd),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Skip'),
        ),
        FilledButton(
          onPressed: (_qty != null && _qty! > 0)
              ? (isAdd || _selectedReason != null)
                  ? _confirm
                  : null
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: modeColor,
          ),
          child: const Text('Confirm'),
        ),
      ],
    );
  }

  Widget _buildProductInfo(Product p) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 48,
              height: 48,
              child: p.imagePath.isNotEmpty
                  ? Image.file(
                      File(p.imagePath),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      p.barcode,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                    if (p.category.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          p.category,
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey.shade200,
      child: Icon(Icons.inventory_2, color: Colors.grey.shade400, size: 22),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          Expanded(
            child: _modeTab(
              label: 'Add',
              icon: Icons.add,
              active: _mode == _CountMode.add,
              activeColor: Colors.green,
              onTap: () => setState(() {
                _mode = _CountMode.add;
                _selectedReason = null;
                _errorText = null;
              }),
            ),
          ),
          Expanded(
            child: _modeTab(
              label: 'Remove',
              icon: Icons.remove,
              active: _mode == _CountMode.remove,
              activeColor: Colors.orange,
              onTap: () => setState(() {
                _mode = _CountMode.remove;
                _errorText = null;
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeTab({
    required String label,
    required IconData icon,
    required bool active,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? activeColor.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: active
              ? Border.all(color: activeColor.withValues(alpha: 0.3))
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16, color: active ? activeColor : Colors.grey.shade500),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? activeColor : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReasonPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reason for removal',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: RemoveReason.values.map((r) {
            final selected = _selectedReason == r;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  if (_errorText != null) setState(() => _errorText = null);
                  setState(() => _selectedReason = r);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  decoration: BoxDecoration(
                    color: selected
                        ? r.color.withValues(alpha: 0.1)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? r.color.withValues(alpha: 0.4)
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        r.icon,
                        size: 18,
                        color: selected ? r.color : Colors.grey.shade400,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        r.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: selected ? r.color : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPreviewRow(bool isAdd) {
    final Color color = isAdd ? Colors.green : Colors.orange;
    final newStock = _newStock;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.inventory_2, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$_currentStock ${widget.product.unit}  →  $newStock ${widget.product.unit}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color.lerp(color, Colors.black, 0.2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
