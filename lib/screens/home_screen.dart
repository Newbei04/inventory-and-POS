import 'dart:io';

import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/product.dart';
import 'add_edit_product_screen.dart';
import 'scan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Product>> _products;
  final _searchController = TextEditingController();
  final _dbHelper = DatabaseHelper.instance;
  List<String> _categories = [];
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadProducts();
  }

  Future<void> _loadCategories() async {
    final cats = await _dbHelper.getCategories();
    if (mounted) setState(() => _categories = cats);
  }

  void _loadProducts() {
    setState(() {
      _products = _dbHelper.getAllProducts(
        search: _searchController.text.isEmpty ? null : _searchController.text,
      );
    });
  }

  void _onSearchChanged(String value) {
    _loadProducts();
  }

  List<Product> _filterByCategory(List<Product> products) {
    if (_selectedCategory == null) return products;
    return products.where((p) => p.category == _selectedCategory).toList();
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Product'),
        content: Text('Delete "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _dbHelper.deleteProduct(product.id!);
      _loadProducts();
      _loadCategories();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${product.name} deleted')),
        );
      }
    }
  }

  void _editProduct(Product product) async {
    final updated = await Navigator.push<Product>(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditProductScreen(existing: product),
      ),
    );
    if (updated != null) {
      _loadProducts();
      _loadCategories();
    }
  }

  Future<void> _addStock(Product product) async {
    final ctrl = TextEditingController();
    final qty = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Add stock — ${product.name}'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Quantity to add',
            prefixIcon: Icon(Icons.add_box_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final val = int.tryParse(ctrl.text.trim());
              if (val != null && val > 0) Navigator.pop(context, val);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (qty == null || !mounted) return;
    await _dbHelper.adjustStock(product.id!, qty);
    _loadProducts();
  }

  void _addProduct() async {
    final created = await Navigator.push<Product>(
      context,
      MaterialPageRoute(builder: (context) => const AddEditProductScreen()),
    );
    if (created != null) {
      _loadProducts();
      _loadCategories();
    }
  }

  void _scanBarcode() async {
    final barcode = await ScanScreen.pickAndScan(context);
    if (barcode == null || !mounted) return;
    final existing = await _dbHelper.getProductByBarcode(barcode);
    if (mounted) {
      if (existing != null) {
        _editProduct(existing);
      } else {
        final created = await Navigator.push<Product>(
          context,
          MaterialPageRoute(
            builder: (context) => AddEditProductScreen(prefilledBarcode: barcode),
          ),
        );
        if (created != null) {
          _loadProducts();
          _loadCategories();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan barcode',
            onPressed: _scanBarcode,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          if (_categories.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                children: [
                  _filterChip('All', null),
                  ..._categories.map((c) => _filterChip(c, c)),
                ],
              ),
            ),
          Expanded(
            child: FutureBuilder<List<Product>>(
              future: _products,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                          const SizedBox(height: 16),
                          Text('Something went wrong', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(
                            snapshot.error.toString(),
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          FilledButton.tonalIcon(
                            onPressed: _loadProducts,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                var products = snapshot.data ?? [];
                products = _filterByCategory(products);

                if (products.isEmpty) {
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
                            child: Icon(
                              Icons.inventory_2_outlined,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _searchController.text.isNotEmpty || _selectedCategory != null
                                ? 'No products found'
                                : 'No products yet',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchController.text.isNotEmpty || _selectedCategory != null
                                ? 'Try a different search or filter'
                                : 'Tap + to add your first product',
                            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _loadProducts(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      final profit = product.price - product.cost;
                      final profitMargin = product.cost > 0
                          ? ((profit / product.cost) * 100).toStringAsFixed(1)
                          : '0.0';
                      final isLowStock = product.quantity <= 5;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _editProduct(product),
                          onLongPress: () => _deleteProduct(product),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: SizedBox(
                                    width: 60,
                                    height: 60,
                                    child: product.imagePath.isNotEmpty
                                        ? Image.file(
                                            File(product.imagePath),
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => _productPlaceholder(isLowStock),
                                          )
                                        : _productPlaceholder(isLowStock),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              product.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isLowStock)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.red.shade50,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'Low',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.red.shade600,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade50,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              product.category,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.blue.shade700,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            product.barcode,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(Icons.inventory_2, size: 14, color: Colors.grey.shade500),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${product.quantity} ${product.unit}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isLowStock ? Colors.red.shade600 : Colors.grey.shade700,
                                              fontWeight: isLowStock ? FontWeight.w600 : FontWeight.normal,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            '₱${product.price.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Column(
                                  children: [
                                    Text(
                                      '$profitMargin%',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: profit >= 0 ? Colors.green : Colors.red,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        iconSize: 18,
                                        icon: Icon(Icons.add_circle, color: Colors.green.shade600),
                                        tooltip: 'Add stock',
                                        onPressed: () => _addStock(product),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addProduct,
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
    );
  }

  Widget _filterChip(String label, String? category) {
    final selected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() => _selectedCategory = selected ? null : category);
        },
        showCheckmark: false,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.grey.shade100,
        selectedColor: Colors.blue.shade100,
        labelStyle: TextStyle(
          color: selected ? Colors.blue.shade800 : Colors.grey.shade700,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          fontSize: 13,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

Widget _productPlaceholder(bool isLowStock) {
  return Container(
    color: isLowStock ? Colors.red.shade50 : Colors.grey.shade100,
    child: Icon(
      Icons.inventory_2,
      color: isLowStock ? Colors.red.shade300 : Colors.grey.shade400,
      size: 28,
    ),
  );
}
