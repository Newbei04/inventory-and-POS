import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';
import '../models/price_change.dart';
import '../models/stock_movement.dart';

class StockLogsScreen extends StatefulWidget {
  const StockLogsScreen({super.key});

  @override
  State<StockLogsScreen> createState() => _StockLogsScreenState();
}

class _StockLogsScreenState extends State<StockLogsScreen> {
  final _db = DatabaseHelper.instance;
  List<StockMovement> _movements = [];
  List<PriceChange> _priceChanges = [];
  bool _loadingMovements = false;
  bool _loadingPrices = false;
  bool _movementsLoaded = false;
  bool _pricesLoaded = false;
  bool _showPrices = false;

  @override
  void initState() {
    super.initState();
    _loadMovements();
  }

  Future<void> _loadMovements() async {
    if (_loadingMovements) return;
    setState(() => _loadingMovements = true);
    try {
      final movements = await _db.getStockMovements(limit: 200);
      if (!mounted) return;
      setState(() {
        _movements = movements;
        _movementsLoaded = true;
        _loadingMovements = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loadingMovements = false);
    }
  }

  Future<void> _loadPrices() async {
    if (_loadingPrices) return;
    setState(() => _loadingPrices = true);
    try {
      final changes = await _db.getPriceChangeList(limit: 200);
      if (!mounted) return;
      setState(() {
        _priceChanges = changes;
        _pricesLoaded = true;
        _loadingPrices = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loadingPrices = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load price logs: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _onTabChanged(bool showPrices) {
    setState(() => _showPrices = showPrices);
    if (showPrices && !_pricesLoaded && !_loadingPrices) {
      _loadPrices();
    } else if (!showPrices && !_movementsLoaded && !_loadingMovements) {
      _loadMovements();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Logs'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.inventory_2_outlined),
                  label: Text('Stock'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.trending_up),
                  label: Text('Prices'),
                ),
              ],
              selected: {_showPrices},
              onSelectionChanged: (v) => _onTabChanged(v.first),
            ),
          ),
          Expanded(
            child: _showPrices
                ? _buildPriceList(theme)
                : _buildStockList(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildStockList(ThemeData theme) {
    if (_loadingMovements) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_movements.isEmpty) {
      return _emptyState(theme, Icons.inventory_2_outlined,
          'No stock movements yet', 'Stock changes will appear here');
    }
    return RefreshIndicator(
      onRefresh: _loadMovements,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: _movements.length,
        itemBuilder: (context, index) {
          final m = _movements[index];
          final date = DateTime.tryParse(m.date);
          final formatted = date != null
              ? DateFormat('MMM d, yyyy – h:mm a').format(date)
              : m.date;
          final isAdd = m.delta >= 0;
          final hasReason = m.reason.isNotEmpty;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isAdd ? Colors.green : Colors.red).shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isAdd
                      ? Icons.add_circle_outline
                      : Icons.remove_circle_outline,
                  color: isAdd ? Colors.green : Colors.red,
                ),
              ),
              title: Text(m.productName,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Row(
                children: [
                  Flexible(
                    child: Text(formatted,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ),
                  if (hasReason) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          m.reason,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isAdd ? '+${m.delta}' : '${m.delta}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isAdd ? Colors.green : Colors.red,
                    ),
                  ),
                  Text('→ ${m.newQuantity}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPriceList(ThemeData theme) {
    if (_loadingPrices) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_priceChanges.isEmpty) {
      return _emptyState(theme, Icons.trending_up, 'No price changes yet',
          'Price and cost updates will appear here');
    }
    return RefreshIndicator(
      onRefresh: _loadPrices,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: _priceChanges.length,
        itemBuilder: (context, index) {
          final pc = _priceChanges[index];
          final date = DateTime.tryParse(pc.date);
          final formatted = date != null
              ? DateFormat('MMM d, yyyy – h:mm a').format(date)
              : pc.date;
          final priceChanged = pc.oldPrice != pc.newPrice;
          final costChanged = pc.oldCost != pc.newCost;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.trending_up,
                        color: Colors.orange.shade700, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pc.productName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 4),
                        if (priceChanged)
                          _priceChangeLine(
                              'Price', pc.oldPrice, pc.newPrice),
                        if (costChanged)
                          _priceChangeLine(
                              'Cost', pc.oldCost, pc.newCost),
                        const SizedBox(height: 4),
                        Text(formatted,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _priceChangeLine(
      String label, double oldVal, double newVal) {
    final up = newVal > oldVal;
    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ),
        Flexible(
          child: Text('₱${oldVal.toStringAsFixed(2)}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12, decoration: TextDecoration.lineThrough)),
        ),
        const SizedBox(width: 4),
        Icon(up ? Icons.arrow_upward : Icons.arrow_downward,
            size: 14, color: up ? Colors.red : Colors.green),
        const SizedBox(width: 4),
        Flexible(
          child: Text('₱${newVal.toStringAsFixed(2)}',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: up ? Colors.red : Colors.green)),
        ),
      ],
    );
  }

  Widget _emptyState(
      ThemeData theme, IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 24),
            Text(title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(subtitle,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
