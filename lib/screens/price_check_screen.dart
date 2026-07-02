import 'dart:io';

import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state_widget.dart';
import 'scan_screen.dart';

class PriceCheckScreen extends StatefulWidget {
  const PriceCheckScreen({super.key});

  @override
  State<PriceCheckScreen> createState() => _PriceCheckScreenState();
}

class _PriceCheckScreenState extends State<PriceCheckScreen> {
  final _searchCtrl = TextEditingController();
  final _db = DatabaseHelper.instance;

  Product? _product;
  List<Product> _allProducts = [];
  List<Product> _filtered = [];
  bool _loading = false;
  String? _error;
  bool _showingList = false;
  bool _externalScanner = false;
  bool _suppressOnChanged = false;
  final _extFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _extFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final products = await _db.getAllProducts();
    if (!mounted) return;
    setState(() {
      _allProducts = products;
      _filtered = products;
    });
  }

  void _onSearchChanged(String query) {
    if (_suppressOnChanged) return;
    if (_product != null) {
      setState(() {
        _product = null;
        _error = null;
        _showingList = false;
      });
    }
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() {
        _filtered = _allProducts;
        _error = null;
        _showingList = false;
      });
      return;
    }
    final filtered = _allProducts.where((p) =>
        p.name.toLowerCase().contains(q) ||
        p.barcode.toLowerCase().contains(q) ||
        p.category.toLowerCase().contains(q));
    if (!mounted) return;
    setState(() {
      _filtered = filtered.toList();
      _error = null;
      _showingList = false;
    });
  }

  Future<void> _lookup(String query) async {
    if (query.trim().isEmpty) return;

    // Refresh local cache before lookup to avoid stale data
    await _loadAll();

    if (!mounted) return;
    setState(() {
      _loading = true;
      _product = null;
      _error = null;
      _showingList = false;
    });

    var product = await _db.getProductByBarcode(query.trim());
    if (product != null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _product = product;
      });
      return;
    }

    final results = await _db.getAllProducts(search: query.trim());
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (results.length == 1) {
        _product = results.first;
      } else if (results.isNotEmpty) {
        _filtered = results;
        _showingList = true;
      } else {
        _error = 'No product found for "$query"';
      }
    });
  }

  Future<void> _scan() async {
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const ScanScreen(
          title: 'Scan Price',
          initialMode: ScanMode.camera,
        ),
      ),
    );
    if (barcode != null && mounted) {
      _suppressOnChanged = true;
      _searchCtrl.text = barcode;
      _suppressOnChanged = false;
      _lookup(barcode);
    }
  }

  void _onExtBarcode(String barcode) {
    if (barcode.trim().isNotEmpty) {
      _suppressOnChanged = true;
      _searchCtrl.text = barcode;
      _suppressOnChanged = false;
      _lookup(barcode);
    }
  }

  void _showScannerSettings() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                      Icon(Icons.qr_code_scanner, color: Colors.blue.shade700),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Scanner Mode',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _scannerOption(
              icon: Icons.camera_alt,
              title: 'Camera Scanner',
              subtitle: 'Use the device camera to scan barcodes',
              selected: !_externalScanner,
              onTap: () {
                setState(() => _externalScanner = false);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
            _scannerOption(
              icon: Icons.keyboard,
              title: 'External Scanner',
              subtitle:
                  'Use a USB barcode scanner (keyboard wedge)',
              selected: _externalScanner,
              onTap: () {
                setState(() {
                  _externalScanner = true;
                  _searchCtrl.clear();
                  _product = null;
                  _filtered = _allProducts;
                  _error = null;
                  _showingList = false;
                });
                Navigator.pop(context);
                _extFocusNode.requestFocus();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _scannerOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? Colors.blue : Colors.grey.shade300,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
              color: selected
                  ? Colors.blue.shade50
                  : Colors.grey.shade700,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: selected ? Colors.blue.shade700 : Colors.white,
              size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.blue.shade700 : null,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: Colors.blue.shade600),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBarcodeContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_externalScanner)
          _buildExternalScannerUI()
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Search by name or barcode...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.qr_code_scanner),
                          onPressed: _scan,
                          tooltip: 'Scan barcode',
                        ),
                      ),
                      onChanged: _onSearchChanged,
                      onSubmitted: (v) {
                        if (v.trim().isNotEmpty) _lookup(v);
                      },
                      textInputAction: TextInputAction.search,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => _lookup(_searchCtrl.text),
                    style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
                    child: const Icon(Icons.search),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_product != null)
          _buildProductCard(Theme.of(context))
        else if (_error != null)
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.search_off,
                      size: 48, color: Colors.grey.shade400),
                ),
                const SizedBox(height: 16),
                Text(_error!,
                    style: TextStyle(color: Colors.grey.shade600),
                    textAlign: TextAlign.center),
              ],
            ),
          )
        else if (_showingList)
          _buildResultsList()
        else if (_filtered.isNotEmpty)
          _buildProductList()
        else
          const EmptyStateWidget(
            icon: Icons.inventory_2_outlined,
            title: 'No products yet',
            subtitle: 'Add products from the Products tab',
          ),
      ],
    );
  }

  Widget _buildResultsList() {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('${_filtered.length} product(s) found',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: Colors.grey.shade600)),
          ),
          ..._filtered.map(
            (p) => ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: p.imagePath.isNotEmpty
                      ? Image.file(File(p.imagePath),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.inventory_2))
                      : const Icon(Icons.inventory_2),
                ),
              ),
              title: Text(p.name, style: AppText.nameSmall),
              subtitle: Text(
                  '${AppText.peso}${p.price.toStringAsFixed(2)} • ${p.quantity} ${p.unit}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => setState(() {
                _product = p;
                _showingList = false;
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_searchCtrl.text.trim().isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'All Products — tap to check price',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
        ..._filtered.map(
          (p) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() {
                _product = p;
              }),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: p.imagePath.isNotEmpty
                            ? Image.file(File(p.imagePath),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _placeholder())
                            : _placeholder(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name,
                              style: AppText.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(
                            '${AppText.peso}${p.price.toStringAsFixed(2)}  •  ${p.quantity} ${p.unit}',
                            style: AppText.label,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey.shade400),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey.shade100,
      child:
          Icon(Icons.inventory_2, color: Colors.grey.shade400, size: 24),
    );
  }

  Widget _buildProductCard(ThemeData theme) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (_product!.imagePath.isNotEmpty)
            SizedBox(
              height: 200,
              width: double.infinity,
              child: Image.file(
                File(_product!.imagePath),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    _product!.name,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Divider(height: 32),
                _detailRow(Icons.qr_code, 'Barcode', _product!.barcode),
                const SizedBox(height: 8),
                _detailRow(
                    Icons.category_outlined, 'Category', _product!.category),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    '₱${_product!.price.toStringAsFixed(2)}',
                    style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _infoChip(Icons.money_off, 'Cost',
                          '₱${_product!.cost.toStringAsFixed(2)}'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _infoChip(Icons.inventory_2, 'Stock',
                          '${_product!.quantity} ${_product!.unit}'),
                    ),
                  ],
                ),
                if (_product!.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Description',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: Colors.grey.shade600)),
                  const SizedBox(height: 4),
                  Text(_product!.description),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _product = null),
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Back to list'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExternalScannerUI() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.keyboard,
                size: 40,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'External Scanner Mode',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              'Scan using a USB barcode scanner',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              focusNode: _extFocusNode,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Barcode will appear here...',
                prefixIcon: const Icon(Icons.qr_code),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.camera_alt_outlined),
                  tooltip: 'Switch to camera scanner',
                  onPressed: () {
                    setState(() {
                      _externalScanner = false;
                    });
                  },
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      BorderSide(color: Colors.green.shade400, width: 2),
                ),
              ),
              onSubmitted: _onExtBarcode,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 8),
            Text(
              'Point your scanner at a barcode — '
                  'it will appear and search automatically',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Price Checker'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Scanner settings',
            onPressed: _showScannerSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildBarcodeContent(),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
      ],
    );
  }

  Widget _infoChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
