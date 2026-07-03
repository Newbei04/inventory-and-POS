import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/product.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _db = DatabaseHelper.instance;
  final _searchCtrl = TextEditingController();
  List<Product> _products = [];
  bool _loading = true;
  String _searchQuery = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final products = await _db.getAllProducts(search: _searchQuery);
    if (!mounted) return;
    setState(() {
      _products = products;
      _loading = false;
    });
  }

  void _onSearch(String q) {
    _searchQuery = q;
    // Debounce so a full DB query doesn't fire on every keystroke.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _load();
    });
    // Refresh just the clear-icon visibility immediately.
    setState(() {});
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchCtrl.clear();
    _searchQuery = '';
    _load();
  }

  Future<void> _addStock(Product product) async {
    if (product.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This product is missing an ID and can\'t be updated'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final qty = await showDialog<int>(
      context: context,
      builder: (_) => _AddStockDialog(product: product),
    );

    if (qty == null || !mounted) return;

    try {
      await _db.adjustStock(product.id!, qty);
      if (!mounted) return;
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added $qty ${product.unit}(s) to ${product.name}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Couldn\'t update stock: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  Widget _placeholder(bool lowStock) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: lowStock ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.inventory_2,
        color: lowStock ? Colors.red.shade600 : Colors.green.shade600,
        size: 22,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: _clearSearch,
                )
                    : null,
              ),
              onChanged: _onSearch,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _products.isEmpty
                  ? ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.3,
                  ),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.inventory_2,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No products match your search'
                              : 'No products yet',
                          style: TextStyle(
                              color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                ],
              )
                  : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                itemCount: _products.length,
                itemBuilder: (_, i) => _productCard(_products[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _productCard(Product p) {
    final lowStock = p.quantity <= 5;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _addStock(p),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: p.imagePath.isNotEmpty
                      ? Image.file(
                          File(p.imagePath),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(lowStock),
                        )
                      : _placeholder(lowStock),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          p.barcode.isNotEmpty ? p.barcode : 'No barcode',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500),
                        ),
                        if (p.category.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              p.category,
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey.shade600),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${p.quantity}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: lowStock ? Colors.red.shade600 : Colors.green.shade700,
                    ),
                  ),
                  Text(
                    p.unit,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  if (lowStock)
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Low',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.red.shade600,
                          fontWeight: FontWeight.w500,
                        ),
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
}

class _AddStockDialog extends StatefulWidget {
  final Product product;
  const _AddStockDialog({required this.product});

  @override
  State<_AddStockDialog> createState() => _AddStockDialogState();
}

class _AddStockDialogState extends State<_AddStockDialog> {
  final _ctrl = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Add stock — ${widget.product.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('Current stock: ',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              Text('${widget.product.quantity} ${widget.product.unit}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Quantity to add',
              prefixIcon: const Icon(Icons.add_box_outlined),
              errorText: _errorText,
            ),
            onChanged: (_) {
              if (_errorText != null) {
                setState(() => _errorText = null);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final v = int.tryParse(_ctrl.text.trim());
            if (v == null || v <= 0) {
              setState(() {
                _errorText = 'Enter a whole number greater than 0';
              });
              return;
            }
            Navigator.pop(context, v);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}