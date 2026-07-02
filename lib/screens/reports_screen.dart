import 'package:flutter/material.dart';
import '../db/database_helper.dart';

enum ReportPeriod { today, thisWeek, thisMonth, allTime }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _db = DatabaseHelper.instance;
  bool _loading = true;
  ReportPeriod _period = ReportPeriod.today;

  double _totalSales = 0;
  int _transactionCount = 0;
  double _inventoryValue = 0;
  double _inventoryCost = 0;
  int _productCount = 0;
  int _lowStockCount = 0;
  Map<String, Map<String, dynamic>> _topProducts = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTimeRange _getPeriodRange() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    switch (_period) {
      case ReportPeriod.today:
        return DateTimeRange(start: startOfDay, end: now);
      case ReportPeriod.thisWeek:
        final startOfWeek = startOfDay.subtract(Duration(days: now.weekday - 1));
        return DateTimeRange(start: startOfWeek, end: now);
      case ReportPeriod.thisMonth:
        final startOfMonth = DateTime(now.year, now.month, 1);
        return DateTimeRange(start: startOfMonth, end: now);
      case ReportPeriod.allTime:
        return DateTimeRange(start: DateTime(2020), end: now);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final range = _getPeriodRange();
    final results = await Future.wait([
      _db.getTotalSales(from: range.start, to: range.end),
      _db.getTransactionCount(from: range.start, to: range.end),
      _db.getInventoryValue(),
      _db.getInventoryCost(),
      _db.count(),
      _db.getLowStockProducts().then((p) => p.length),
      _db.getTopProducts(),
    ]);
    if (!mounted) return;
    setState(() {
      _totalSales = results[0] as double;
      _transactionCount = results[1] as int;
      _inventoryValue = results[2] as double;
      _inventoryCost = results[3] as double;
      _productCount = results[4] as int;
      _lowStockCount = results[5] as int;
      _topProducts = results[6] as Map<String, Map<String, dynamic>>;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                children: [
                  _buildPeriodChips(),
                  const SizedBox(height: 16),
                  _buildSalesCard(),
                  const SizedBox(height: 16),
                  _buildStatsRow(theme),
                  const SizedBox(height: 20),
                  _buildInventoryCard(),
                  const SizedBox(height: 20),
                  if (_topProducts.isNotEmpty) _buildTopProductsCard(theme),
                ],
              ),
      ),
    );
  }

  Widget _buildPeriodChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _periodChip('Today', ReportPeriod.today),
          const SizedBox(width: 8),
          _periodChip('This Week', ReportPeriod.thisWeek),
          const SizedBox(width: 8),
          _periodChip('This Month', ReportPeriod.thisMonth),
          const SizedBox(width: 8),
          _periodChip('All Time', ReportPeriod.allTime),
        ],
      ),
    );
  }

  Widget _periodChip(String label, ReportPeriod value) {
    final selected = _period == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _period = value);
        _load();
      },
    );
  }

  Widget _buildSalesCard() {
    return Card(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.blue.shade800, Colors.blue.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.trending_up,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  'Sales',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '₱${_totalSales.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _salesChip(
                  Icons.receipt,
                  '$_transactionCount transactions',
                ),
                const SizedBox(width: 10),
                _salesChip(
                  Icons.shopping_cart,
                  '${_periodLabel()} sales',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _salesChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }

  String _periodLabel() {
    switch (_period) {
      case ReportPeriod.today:
        return 'Today';
      case ReportPeriod.thisWeek:
        return 'This Week';
      case ReportPeriod.thisMonth:
        return 'This Month';
      case ReportPeriod.allTime:
        return 'All Time';
    }
  }

  Widget _buildStatsRow(ThemeData theme) {
    return SizedBox(
      height: 90,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _statCard(
            icon: Icons.receipt_long,
            label: 'Transactions',
            value: '$_transactionCount',
            color: Colors.blue,
            bgColor: Colors.blue.shade50,
          ),
          const SizedBox(width: 12),
          _statCard(
            icon: Icons.monetization_on,
            label: 'Avg per Transaction',
            value: _transactionCount > 0
                ? '₱${(_totalSales / _transactionCount).toStringAsFixed(2)}'
                : '₱0.00',
            color: Colors.green,
            bgColor: Colors.green.shade50,
          ),
          const SizedBox(width: 12),
          _statCard(
            icon: Icons.inventory,
            label: 'Total Products',
            value: '$_productCount',
            color: Colors.purple,
            bgColor: Colors.purple.shade50,
          ),
          const SizedBox(width: 12),
          _statCard(
            icon: Icons.warning_amber,
            label: 'Low Stock Items',
            value: '$_lowStockCount',
            color: Colors.red,
            bgColor: Colors.red.shade50,
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: SizedBox(
        width: 150,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: color,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInventoryCard() {
    final profit = _inventoryValue - _inventoryCost;
    final margin = _inventoryValue > 0
        ? ((profit / _inventoryValue) * 100).toStringAsFixed(1)
        : '0.0';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.inventory_2,
                      color: Colors.teal.shade600, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  'Inventory Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _infoRow('Inventory Value', '₱${_inventoryValue.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            _infoRow('Total Cost', '₱${_inventoryCost.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            _infoRow('Potential Profit', '₱${profit.toStringAsFixed(2)}',
                valueColor: profit >= 0 ? Colors.green : Colors.red),
            const SizedBox(height: 8),
            _infoRow('Profit Margin', '$margin%'),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildTopProductsCard(ThemeData theme) {
    final products = _topProducts.values.take(5).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.star, color: Colors.amber.shade600, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  'Top Products',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...products.asMap().entries.map((entry) {
              final i = entry.key;
              final p = entry.value;
              return Padding(
                padding: EdgeInsets.only(bottom: i < products.length - 1 ? 10 : 0),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.amber.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        p['product_name'] as String,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      '${p['total_qty']} sold',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '₱${(p['total_sales'] as double).toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
