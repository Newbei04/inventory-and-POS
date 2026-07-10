import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';
import '../models/receipt.dart';
import '../widgets/store_receipt_header.dart';

enum ReceiptPeriod { today, week, month, custom, all }

class ReceiptsScreen extends StatefulWidget {
  const ReceiptsScreen({super.key});

  @override
  State<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen> {
  final _db = DatabaseHelper.instance;
  final _searchCtrl = TextEditingController();
  List<Receipt> _allReceipts = [];
  List<Receipt> _filtered = [];
  bool _loading = true;
  ReceiptPeriod _period = ReceiptPeriod.all;
  DateTimeRange? _customRange;
  int _statusFilter = 0; // 0=All, 1=Active, 2=Voided, 3=Refunded

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final receipts = await _db.getAllReceipts();
    if (!mounted) return;
    setState(() {
      _allReceipts = receipts;
      _loading = false;
    });
    _applyFilters();
  }

  void _applyFilters() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    List<Receipt> filtered = List.from(_allReceipts);

    // Date filter
    if (_period == ReceiptPeriod.today) {
      final tomorrow = todayStart.add(const Duration(days: 1));
      filtered = filtered.where((r) {
        final d = DateTime.parse(r.date);
        return d.isAfter(todayStart.subtract(const Duration(seconds: 1))) &&
            d.isBefore(tomorrow);
      }).toList();
    } else if (_period == ReceiptPeriod.week) {
      final weekStart = todayStart.subtract(Duration(days: todayStart.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 7));
      filtered = filtered.where((r) {
        final d = DateTime.parse(r.date);
        return d.isAfter(weekStart.subtract(const Duration(seconds: 1))) &&
            d.isBefore(weekEnd);
      }).toList();
    } else if (_period == ReceiptPeriod.month) {
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 1);
      filtered = filtered.where((r) {
        final d = DateTime.parse(r.date);
        return d.isAfter(monthStart.subtract(const Duration(seconds: 1))) &&
            d.isBefore(monthEnd);
      }).toList();
    } else if (_period == ReceiptPeriod.custom && _customRange != null) {
      final rangeStart = DateTime(_customRange!.start.year, _customRange!.start.month, _customRange!.start.day);
      final rangeEnd = _customRange!.end.add(const Duration(days: 1));
      filtered = filtered.where((r) {
        final d = DateTime.parse(r.date);
        return d.isAfter(rangeStart.subtract(const Duration(seconds: 1))) &&
            d.isBefore(rangeEnd);
      }).toList();
    }

    // Search filter
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      filtered = filtered.where((r) =>
          r.receiptNo.toLowerCase().contains(q)).toList();
    }

    // Status filter
    if (_statusFilter == 1) {
      filtered = filtered.where((r) => !r.isVoided && !r.isRefunded).toList();
    } else if (_statusFilter == 2) {
      filtered = filtered.where((r) => r.isVoided).toList();
    } else if (_statusFilter == 3) {
      filtered = filtered.where((r) => r.isRefunded || r.isPartiallyRefunded).toList();
    }

    if (!mounted) return;
    setState(() => _filtered = filtered);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipts'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search receipt no...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _applyFilters();
                        },
                      )
                    : null,
              ),
              onChanged: (_) => _applyFilters(),
            ),
          ),
          // Period chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                _periodChip('Today', ReceiptPeriod.today),
                const SizedBox(width: 6),
                _periodChip('Week', ReceiptPeriod.week),
                const SizedBox(width: 6),
                _periodChip('Month', ReceiptPeriod.month),
                const SizedBox(width: 6),
                _periodChip('Custom', ReceiptPeriod.custom),
                const SizedBox(width: 6),
                _periodChip('All', ReceiptPeriod.all),
              ],
            ),
          ),
          // Custom date range picker
          if (_period == ReceiptPeriod.custom)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: InkWell(
                onTap: _pickDateRange,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue.shade200),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.blue.shade50,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.date_range, size: 18, color: Colors.blue.shade600),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _customRange != null
                              ? '${DateFormat('MMM d, yyyy').format(_customRange!.start)} — ${DateFormat('MMM d, yyyy').format(_customRange!.end)}'
                              : 'Pick date range...',
                          style: TextStyle(
                            fontSize: 13,
                            color: _customRange != null ? Colors.blue.shade700 : Colors.grey.shade500,
                          ),
                        ),
                      ),
                      if (_customRange != null)
                        Icon(Icons.close, size: 16, color: Colors.grey.shade500),
                    ],
                  ),
                ),
              ),
            ),
          // Status filter
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Row(
              children: [
                _statusChip('All', 0, Icons.receipt_long, Colors.blue),
                const SizedBox(width: 6),
                _statusChip('Active', 1, Icons.check_circle_outline, Colors.green),
                const SizedBox(width: 6),
                _statusChip('Voided', 2, Icons.cancel_outlined, Colors.red),
                const SizedBox(width: 6),
                _statusChip('Refunded', 3, Icons.replay, Colors.orange),
              ],
            ),
          ),
          // Summary bar
          if (!_loading && _allReceipts.isNotEmpty && _filtered.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    _summaryStat('${_filtered.length}', 'receipts'),
                    _summaryDivider(),
                    _summaryStat('${_filtered.fold(0, (s, r) => s + r.totalItemsQty)}', 'items'),
                    _summaryDivider(),
                    _summaryStat('₱${_filtered.fold(0.0, (s, r) => s + r.total).toStringAsFixed(2)}', 'total'),
                  ],
                ),
              ),
            ),
          // Body
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _allReceipts.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.35,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.receipt_long,
                                        size: 64, color: Colors.grey.shade300),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No receipts yet',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Complete a sale in POS to generate receipts',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : _filtered.isEmpty
                          ? ListView(
                              children: [
                                SizedBox(
                                  height: MediaQuery.of(context).size.height * 0.35,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.search_off,
                                            size: 48, color: Colors.grey.shade400),
                                        const SizedBox(height: 12),
                                        Text(
                                          'No receipts match',
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              itemCount: _filtered.length,
                              itemBuilder: (_, i) => _receiptCard(_filtered[i]),
                            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _periodChip(String label, ReceiptPeriod period) {
    final selected = _period == period;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _period = period);
          _applyFilters();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? Colors.blue : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              color: selected ? Colors.white : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String label, int value, IconData icon, MaterialColor color) {
    final selected = _statusFilter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _statusFilter = value);
          _applyFilters();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.shade100 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
            border: selected ? Border.all(color: color.shade400, width: 1.5) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: selected ? color.shade700 : Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? color.shade700 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _receiptCard(Receipt r) {
    final dateStr = _formatDate(r.date);
    final isRefunded = r.isFullyRefunded;
    final isPartialRefund = r.isPartiallyRefunded;
    final canAct = r.canModify && DateTime.now().difference(DateTime.parse(r.date)).inHours < 24;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: r.isVoided ? Colors.red.shade50 : isRefunded ? Colors.orange.shade50 : isPartialRefund ? Colors.orange.shade50 : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _viewReceipt(r),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: r.isVoided ? Colors.red.shade50 : isRefunded ? Colors.orange.shade50 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  r.isVoided ? Icons.cancel_outlined : (isRefunded || isPartialRefund) ? Icons.replay : Icons.receipt_long,
                  color: r.isVoided ? Colors.red.shade400 : (isRefunded || isPartialRefund) ? Colors.orange.shade600 : Colors.blue.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Receipt #${r.receiptNo}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        if (r.isVoided) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'VOID',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ),
                        ],
                        if (isRefunded || isPartialRefund) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isRefunded ? 'REFUNDED' : 'PARTIAL',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${r.items.length} line${r.items.length == 1 ? '' : 's'}  ·  ${r.totalItemsQty} unit${r.totalItemsQty == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₱${r.total.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: r.isVoided ? Colors.red.shade400 : isRefunded ? Colors.orange.shade600 : Colors.blue.shade700,
                      decoration: r.isVoided || isRefunded ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.grey.shade500, size: 20),
                padding: EdgeInsets.zero,
                splashRadius: 18,
                onSelected: (value) {
                  if (value == 'view') _viewReceipt(r);
                  if (value == 'void') _standaloneVoid(r);
                  if (value == 'refund') _standaloneRefund(r);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'view', child: Row(children: [Icon(Icons.visibility_outlined, size: 18), SizedBox(width: 10), Text('View')])),
                  if (canAct && !r.isVoided && !isRefunded)
                    PopupMenuItem(
                      value: 'void',
                      child: Row(children: [Icon(Icons.cancel_outlined, size: 18, color: Colors.red.shade400), const SizedBox(width: 10), Text('Void', style: TextStyle(color: Colors.red.shade400))]),
                    ),
                  if (canAct && !r.isVoided && !isRefunded)
                    PopupMenuItem(
                      value: 'refund',
                      child: Row(children: [Icon(Icons.replay, size: 18, color: Colors.orange.shade600), const SizedBox(width: 10), Text('Refund', style: TextStyle(color: Colors.orange.shade600))]),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _viewReceipt(Receipt r) {
    final canAct = r.canModify && DateTime.now().difference(DateTime.parse(r.date)).inHours < 24;
    final selectedItems = <int>{};
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: StatefulBuilder(
            builder: (ctx, setDialogState) => Stack(
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
                          'Receipt #${r.receiptNo}',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (canAct && selectedItems.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${selectedItems.length} item${selectedItems.length == 1 ? '' : 's'} selected for refund',
                                      style: TextStyle(fontSize: 12, color: Colors.orange.shade800, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ...r.items.asMap().entries.map(
                          (entry) {
                            final idx = entry.key;
                            final item = entry.value;
                            final alreadyRefunded = r.refundedItemIndices.contains(idx);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (canAct && !alreadyRefunded)
                                        Padding(
                                          padding: const EdgeInsets.only(right: 8, top: 1),
                                          child: Checkbox(
                                            value: selectedItems.contains(idx),
                                            onChanged: (v) {
                                              setDialogState(() {
                                                if (v == true) {
                                                  selectedItems.add(idx);
                                                } else {
                                                  selectedItems.remove(idx);
                                                }
                                              });
                                            },
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ),
                                      if (alreadyRefunded)
                                        Padding(
                                          padding: const EdgeInsets.only(right: 8, top: 2),
                                          child: Icon(Icons.check_circle, size: 18, color: Colors.orange.shade500),
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
                                                      decoration: alreadyRefunded ? TextDecoration.lineThrough : null,
                                                      color: alreadyRefunded ? Colors.grey : null,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  '₱${item.total.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                    decoration: alreadyRefunded ? TextDecoration.lineThrough : null,
                                                    color: alreadyRefunded ? Colors.grey : null,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${item.quantity} × ₱${item.price.toStringAsFixed(2)}${alreadyRefunded ? '  (refunded)' : ''}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: alreadyRefunded ? Colors.orange.shade500 : Colors.grey.shade500,
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
                          },
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(
                              '₱${r.total.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                decoration: r.isVoided || r.isFullyRefunded ? TextDecoration.lineThrough : null,
                                color: r.isVoided ? Colors.red : r.isFullyRefunded ? Colors.orange : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${r.totalItemsQty} total unit${r.totalItemsQty == 1 ? '' : 's'}  ·  ${r.items.length} line${r.items.length == 1 ? '' : 's'}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Cash', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                            Text('₱${r.cash.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Change', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                            Text(
                              '₱${r.change.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: r.change >= 0 ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          DateFormat('MMM d, yyyy  h:mm a').format(DateTime.parse(r.date)),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontFamily: 'monospace'),
                        ),
                        const SizedBox(height: 20),
                        if (r.isVoided)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Text(
                              'This receipt has been voided',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.w600),
                            ),
                          )
                        else if (r.isFullyRefunded)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Text(
                              'This receipt has been fully refunded',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.w600),
                            ),
                          )
                        else if (canAct) ...[
                          if (selectedItems.isNotEmpty)
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.replay, size: 20),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.orange,
                                  side: BorderSide(color: Colors.orange.shade300),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () => _confirmRefund(ctx, r, setDialogState, itemIndices: selectedItems.toList()),
                                label: Text('Refund ${selectedItems.length} Item${selectedItems.length == 1 ? '' : 's'}', style: const TextStyle(fontSize: 15)),
                              ),
                            ),
                          if (selectedItems.isNotEmpty) const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.cancel_outlined, size: 20),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: BorderSide(color: Colors.red.shade300),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => _confirmVoid(ctx, r, setDialogState),
                              label: const Text('Void Receipt', style: TextStyle(fontSize: 15)),
                            ),
                          ),
                        ] else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Action window expired (24h limit)',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                            ),
                          ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Close', style: TextStyle(fontSize: 15)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (r.isVoided || r.isFullyRefunded)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Transform.rotate(
                          angle: -0.5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: r.isVoided ? Colors.red.shade400 : Colors.orange.shade400,
                                width: 4,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              r.isVoided ? 'VOID' : 'REFUNDED',
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w900,
                                color: r.isVoided ? Colors.red.shade300 : Colors.orange.shade300,
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
        ),
      ),
    );
  }

  Future<void> _confirmVoid(BuildContext ctx, Receipt r, StateSetter setDialogState) async {
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 40),
        title: const Text('Void Receipt?'),
        content: Text(
          'This will mark receipt #${r.receiptNo} as voided and restore ${r.items.length} product(s) back to inventory. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Void'),
          ),
        ],
      ),
    );
    if (confirm == true && ctx.mounted) {
      await _db.voidReceipt(r.id!);
      if (!ctx.mounted) return;
      Navigator.pop(ctx);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Receipt #${r.receiptNo} voided — stock restored'),
            backgroundColor: Colors.orange.shade700,
          ),
        );
      }
    }
  }

  Future<void> _confirmRefund(BuildContext ctx, Receipt r, StateSetter setDialogState, {List<int>? itemIndices}) async {
    final isPartial = itemIndices != null && itemIndices.length < r.items.length;
    final count = itemIndices?.length ?? r.items.length;
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        icon: const Icon(Icons.replay, color: Colors.orange, size: 40),
        title: Text(isPartial ? 'Refund $count Item${count == 1 ? '' : 's'}?' : 'Refund Receipt?'),
        content: Text(
          isPartial
              ? 'This will refund $count item(s) from receipt #${r.receiptNo} and deduct stock. Other items will remain unchanged.'
              : 'This will refund receipt #${r.receiptNo} and deduct all ${r.totalItemsQty} unit(s) from inventory. Items with inadequate stock will be partially refunded.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Refund'),
          ),
        ],
      ),
    );
    if (confirm == true && ctx.mounted) {
      final inadequate = await _db.refundReceipt(r.id!, itemIndices: itemIndices);
      if (!ctx.mounted) return;
      Navigator.pop(ctx);
      _load();
      if (mounted) {
        if (inadequate.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isPartial
                  ? '$count item(s) refunded — stock deducted'
                  : 'Receipt #${r.receiptNo} refunded — stock deducted'),
              backgroundColor: Colors.orange.shade700,
            ),
          );
        } else {
          final names = inadequate.map((i) {
            final refundedQty = i['refunded'] as int? ?? 0;
            final sold = i['sold'] as int;
            if (refundedQty == 0) return '${i['name']} (0/$sold)';
            return '${i['name']} ($refundedQty/$sold)';
          }).join(', ');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Partial refund: $names'),
              backgroundColor: Colors.orange.shade900,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  Future<void> _standaloneVoid(Receipt r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 40),
        title: const Text('Void Receipt?'),
        content: Text(
          'This will mark receipt #${r.receiptNo} as voided and restore ${r.items.length} product(s) back to inventory. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Void'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await _db.voidReceipt(r.id!);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Receipt #${r.receiptNo} voided — stock restored'),
            backgroundColor: Colors.orange.shade700,
          ),
        );
      }
    }
  }

  Future<void> _standaloneRefund(Receipt r) async {
    final selected = <int>{};
    final qtys = <int, int>{};
    for (var i = 0; i < r.items.length; i++) {
      if (!r.refundedItemIndices.contains(i)) {
        qtys[i] = r.items[i].quantity;
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final totalUnits = selected.fold<int>(0, (s, i) => s + (qtys[i] ?? 0));
          final totalAmount = selected.fold<double>(0, (s, i) => s + r.items[i].price * (qtys[i] ?? 0));
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
                  if (selected.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${selected.length} item${selected.length == 1 ? '' : 's'} · $totalUnits unit${totalUnits == 1 ? '' : 's'} · ₱${totalAmount.toStringAsFixed(2)}',
                              style: TextStyle(fontSize: 12, color: Colors.orange.shade800, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: r.items.length,
                      itemBuilder: (_, i) {
                        final item = r.items[i];
                        final alreadyRefunded = r.refundedItemIndices.contains(i);
                        final isSelected = selected.contains(i);
                        final maxQty = item.quantity;
                        final currentQty = qtys[i] ?? maxQty;
                        return Opacity(
                          opacity: alreadyRefunded ? 0.5 : 1,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                if (alreadyRefunded)
                                  Icon(Icons.check_circle, size: 20, color: Colors.orange.shade500)
                                else
                                  Checkbox(
                                    value: isSelected,
                                    onChanged: (v) {
                                      setDialogState(() {
                                        if (v == true) {
                                          selected.add(i);
                                          qtys[i] = maxQty;
                                        } else {
                                          selected.remove(i);
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
                                          decoration: alreadyRefunded ? TextDecoration.lineThrough : null,
                                          color: alreadyRefunded ? Colors.grey : null,
                                        ),
                                      ),
                                      Text(
                                        alreadyRefunded ? 'Refunded' : '₱${item.price.toStringAsFixed(2)} × $maxQty',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: alreadyRefunded ? Colors.orange.shade500 : Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!alreadyRefunded && isSelected) ...[
                                  IconButton(
                                    onPressed: currentQty > 1
                                        ? () => setDialogState(() => qtys[i] = currentQty - 1)
                                        : null,
                                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  ),
                                  Text(
                                    '$currentQty',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                  IconButton(
                                    onPressed: currentQty < maxQty
                                        ? () => setDialogState(() => qtys[i] = currentQty + 1)
                                        : null,
                                    icon: const Icon(Icons.add_circle_outline, size: 20),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
              FilledButton(
                onPressed: selected.isEmpty
                    ? null
                    : () => Navigator.pop(dCtx, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.orange),
                child: Text('Refund ${selected.length} Item${selected.length == 1 ? '' : 's'}'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == true && mounted) {
      final itemQuantities = <int, int>{};
      for (final i in selected) {
        itemQuantities[i] = qtys[i] ?? r.items[i].quantity;
      }
      final inadequate = await _db.refundReceipt(r.id!, itemQuantities: itemQuantities);
      _load();
      if (mounted) {
        if (inadequate.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${selected.length} item(s) refunded — stock deducted'),
              backgroundColor: Colors.orange.shade700,
            ),
          );
        } else {
          final names = inadequate.map((i) {
            final refundedQty = i['refunded'] as int? ?? 0;
            final sold = i['sold'] as int;
            if (refundedQty == 0) return '${i['name']} (0/$sold)';
            return '${i['name']} ($refundedQty/$sold)';
          }).join(', ');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Partial refund: $names'),
              backgroundColor: Colors.orange.shade900,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 1)),
      initialDateRange: _customRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(primary: Colors.blue),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _customRange = picked);
      _applyFilters();
    } else if (_customRange == null) {
      setState(() => _period = ReceiptPeriod.all);
    }
  }

  Widget _summaryStat(String value, String label) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _summaryDivider() {
    return Container(
      width: 1,
      height: 24,
      color: Colors.grey.shade300,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return DateFormat('MMM d, h:mm a').format(dt);
    } catch (_) {
      return '';
    }
  }
}
