import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';
import '../models/receipt.dart';

enum ReceiptPeriod { today, week, month, all }

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
    }

    // Search filter
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      filtered = filtered.where((r) =>
          r.receiptNo.toLowerCase().contains(q)).toList();
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
                _periodChip('This Week', ReceiptPeriod.week),
                const SizedBox(width: 6),
                _periodChip('This Month', ReceiptPeriod.month),
                const SizedBox(width: 6),
                _periodChip('All', ReceiptPeriod.all),
              ],
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

  Widget _receiptCard(Receipt r) {
    final dateStr = _formatDate(r.date);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _viewReceipt(r),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.receipt_long,
                  color: Colors.blue.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Receipt #${r.receiptNo}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${r.items.length} items',
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
                      color: Colors.blue.shade700,
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
            ],
          ),
        ),
      ),
    );
  }

  void _viewReceipt(Receipt r) {
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long, size: 48, color: Colors.blue.shade600),
              const SizedBox(height: 8),
              const Text(
                'SALE RECEIPT',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 4),
              Text(
                'Receipt #${r.receiptNo}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const Divider(height: 24),
              ...r.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${item.productName} x ${item.quantity}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Text(
                        '₱${item.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TOTAL',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    '₱${r.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _receiptRow('Cash', r.cash),
              _receiptRow(
                'Change',
                r.change,
                valueStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: r.change >= 0 ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('MMM d, yyyy  h:mm a')
                    .format(DateTime.parse(r.date)),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade400,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _receiptRow(String label, double amount, {TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(
            '₱${amount.toStringAsFixed(2)}',
            style: valueStyle ?? const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
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
