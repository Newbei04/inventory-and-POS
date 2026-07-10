import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/database_helper.dart';
import '../models/price_change.dart';
import '../models/product.dart';
import '../widgets/scanner_mode_sheet.dart';
import 'scan_screen.dart';

class UpdatePriceScreen extends StatefulWidget {
  const UpdatePriceScreen({super.key});

  @override
  State<UpdatePriceScreen> createState() => _UpdatePriceScreenState();
}

class _UpdatePriceScreenState extends State<UpdatePriceScreen> {
  final _db = DatabaseHelper.instance;
  final _searchCtrl = TextEditingController();
  List<Product> _products = [];
  List<Product> _filtered = [];
  bool _loading = true;
  Timer? _debounce;
  bool _useExternalScanner = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _loadScannerDefault();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadScannerDefault() async {
    final mode = await _db.getSetting('default_scan_mode');
    if (mounted) setState(() => _useExternalScanner = mode == 'external');
  }

  Future<void> _loadProducts() async {
    setState(() => _loading = true);
    final products = await _db.getAllProducts();
    if (!mounted) return;
    setState(() {
      _products = products;
      _filtered = products;
      _loading = false;
    });
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final query = q.trim().toLowerCase();
      if (!mounted) return;
      setState(() {
        _filtered = query.isEmpty
            ? _products
            : _products.where((p) =>
                p.name.toLowerCase().contains(query) ||
                p.barcode.toLowerCase().contains(query) ||
                p.category.toLowerCase().contains(query)).toList();
      });
    });
    setState(() {});
  }

  Future<void> _scanBarcode() async {
    final mode = _useExternalScanner ? ScanMode.external : ScanMode.camera;
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ScanScreen(title: 'Scan Product', initialMode: mode),
      ),
    );
    if (barcode == null || barcode.isEmpty || !mounted) return;
    final product = await _db.getProductByBarcode(barcode);
    if (!mounted) return;
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No product found for: $barcode')),
      );
      return;
    }
    _showUpdateDialog(product);
  }

  Future<void> _showScannerMode() async {
    final result = await showScannerModeSheet(
      context,
      isExternal: _useExternalScanner,
    );
    if (result == null || !mounted) return;
    setState(() => _useExternalScanner = result == ScannerChoice.external);
  }

  Future<void> _showUpdateDialog(Product product) async {
    final priceCtrl = TextEditingController(
      text: product.price.toStringAsFixed(2),
    );
    final costCtrl = TextEditingController(
      text: product.cost.toStringAsFixed(2),
    );
    String? errorText;
    bool dialogAlive = true;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.attach_money, color: Colors.amber.shade700),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Update Price',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: product.imagePath.isNotEmpty
                              ? Image.file(
                                  File(product.imagePath),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.inventory_2, size: 20),
                                )
                              : const Icon(Icons.inventory_2, size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              product.barcode,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Selling Price',
                    prefixText: '₱ ',
                    prefixIcon: const Icon(Icons.attach_money),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (_) {
                    if (dialogAlive && errorText != null) {
                      setDialogState(() => errorText = null);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: costCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Cost Price',
                    prefixText: '₱ ',
                    prefixIcon: const Icon(Icons.money_off),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (_) {
                    if (dialogAlive && errorText != null) {
                      setDialogState(() => errorText = null);
                    }
                  },
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorText!,
                    style: TextStyle(color: Colors.red.shade600, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 12),
                _buildMarginPreview(priceCtrl, costCtrl),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final newPrice = double.tryParse(priceCtrl.text.trim());
                final newCost = double.tryParse(costCtrl.text.trim());
                if (newPrice == null || newPrice < 0) {
                  setDialogState(() => errorText = 'Enter a valid price');
                  return;
                }
                if (newCost == null || newCost < 0) {
                  setDialogState(() => errorText = 'Enter a valid cost');
                  return;
                }
                dialogAlive = false;
                Navigator.pop(ctx, true);
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );

    if (result != true || !mounted) return;

    final newPrice = double.tryParse(priceCtrl.text.trim()) ?? product.price;
    final newCost = double.tryParse(costCtrl.text.trim()) ?? product.cost;

    if (newPrice == product.price && newCost == product.cost) return;

    final updated = product.copyWith(
      price: newPrice,
      cost: newCost,
      dateUpdated: DateTime.now().toIso8601String(),
    );

    await _db.updateProduct(updated);

    if (newPrice != product.price || newCost != product.cost) {
      await _db.insertPriceChangeRaw(
        PriceChange(
          productId: product.id!,
          productName: product.name,
          oldPrice: product.price,
          newPrice: newPrice,
          oldCost: product.cost,
          newCost: newCost,
          date: DateTime.now().toIso8601String(),
        ),
      );
    }

    if (!mounted) return;
    await _loadProducts();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Price updated for ${product.name}'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green.shade600,
      ),
    );
  }

  Widget _buildMarginPreview(TextEditingController priceCtrl, TextEditingController costCtrl) {
    final price = double.tryParse(priceCtrl.text) ?? 0;
    final cost = double.tryParse(costCtrl.text) ?? 0;
    final margin = cost > 0 ? ((price - cost) / cost * 100) : 0.0;
    final profit = price - cost;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: margin >= 0 ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: margin >= 0
              ? Colors.green.shade200
              : Colors.red.shade200,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text(
                '₱${profit.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: margin >= 0
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                ),
              ),
              Text(
                'Profit',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          Container(
            width: 1,
            height: 24,
            color: Colors.grey.shade300,
          ),
          Column(
            children: [
              Text(
                '${margin.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: margin >= 0
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                ),
              ),
              Text(
                'Margin',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Price'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Scanner settings',
            onPressed: _showScannerMode,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearch('');
                        },
                      )
                    : IconButton(
                        icon: const Icon(Icons.qr_code_scanner, size: 20),
                        onPressed: _scanBarcode,
                        tooltip: 'Scan barcode',
                      ),
              ),
              onChanged: _onSearch,
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off,
                                size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              _searchCtrl.text.isNotEmpty
                                  ? 'No products match your search'
                                  : 'No products yet',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) => _productTile(_filtered[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _productTile(Product p) {
    final profit = p.price - p.cost;
    final margin = p.cost > 0 ? (profit / p.cost * 100) : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showUpdateDialog(p),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: p.imagePath.isNotEmpty
                      ? Image.file(
                          File(p.imagePath),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.inventory_2, size: 20),
                        )
                      : const Icon(Icons.inventory_2, size: 20),
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
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          p.barcode,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${p.quantity} ${p.unit}',
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₱${p.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${margin >= 0 ? '+' : ''}${margin.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 11,
                      color: margin >= 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
