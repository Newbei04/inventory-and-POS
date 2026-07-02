import 'dart:io';

import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/error_view_widget.dart';
import '../widgets/skeleton_widget.dart';
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
  bool _gridView = false;

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
          SnackBar(
            content: Text('${product.name} deleted'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                await _dbHelper.insertProduct(product);
                _loadProducts();
                _loadCategories();
              },
            ),
          ),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_gridView ? Icons.list : Icons.grid_view_rounded),
            tooltip: _gridView ? 'List view' : 'Grid view',
            onPressed: () => setState(() => _gridView = !_gridView),
          ),
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
                  return const ProductListSkeleton();
                }
                if (snapshot.hasError) {
                  return ErrorViewWidget(
                    message: snapshot.error.toString(),
                    onRetry: _loadProducts,
                  );
                }

                var products = snapshot.data ?? [];
                products = _filterByCategory(products);

                if (products.isEmpty) {
                  final isFiltered = _searchController.text.isNotEmpty || _selectedCategory != null;
                  return EmptyStateWidget(
                    icon: Icons.inventory_2_outlined,
                    title: isFiltered ? 'No products found' : 'No products yet',
                    subtitle: isFiltered
                        ? 'Try a different search or filter'
                        : 'Tap + to add your first product',
                    actionLabel: isFiltered ? null : 'Add Product',
                    onAction: isFiltered ? null : _addProduct,
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _loadProducts(),
                  child: _gridView
                      ? GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.72,
                          ),
                          itemCount: products.length,
                          itemBuilder: (context, index) => _buildGridItem(products[index]),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                          itemCount: products.length,
                          itemBuilder: (context, index) => _buildListItem(products[index]),
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

  Widget _buildListItem(Product product) {
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
        onTap: () => _showProductDetail(product),
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
                          '${AppText.peso}${product.price.toStringAsFixed(2)}',
                          style: AppText.price,
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
  }

  Widget _buildGridItem(Product product) {
    final isLowStock = product.quantity <= 5;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showProductDetail(product),
        onLongPress: () => _deleteProduct(product),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: double.infinity,
                    child: product.imagePath.isNotEmpty
                        ? Image.file(
                            File(product.imagePath),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _productPlaceholder(isLowStock),
                          )
                        : _productPlaceholder(isLowStock),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isLowStock)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Low',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.red.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${AppText.peso}${product.price.toStringAsFixed(2)}',
                style: AppText.price,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.inventory_2, size: 12, color: Colors.grey.shade500),
                  const SizedBox(width: 3),
                  Text(
                    '${product.quantity} ${product.unit}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isLowStock ? Colors.red.shade600 : Colors.grey.shade600,
                      fontWeight: isLowStock ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    iconSize: 18,
                    icon: Icon(Icons.add_circle, color: Colors.green.shade600),
                    tooltip: 'Add stock',
                    onPressed: () => _addStock(product),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showProductDetail(Product product) async {
    final isLowStock = product.quantity <= 5;
    final profit = product.price - product.cost;
    final profitMargin = product.cost > 0
        ? ((profit / product.cost) * 100).toStringAsFixed(1)
        : '0.0';

    final action = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image header
            if (product.imagePath.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: Image.file(
                  File(product.imagePath),
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _detailPlaceholder(isLowStock),
                ),
              )
            else
              _detailPlaceholder(isLowStock),
            // Info section
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          product.category,
                          style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.qr_code, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        product.barcode,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      expandedInfo('Price', '₱${product.price.toStringAsFixed(2)}', Colors.blue),
                      Container(width: 1, height: 40, color: Colors.grey.shade200),
                      expandedInfo('Cost', '₱${product.cost.toStringAsFixed(2)}', Colors.grey.shade700),
                      Container(width: 1, height: 40, color: Colors.grey.shade200),
                      expandedInfo('Margin', '$profitMargin%', profit >= 0 ? Colors.green : Colors.red),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.inventory_2, size: 16, color: isLowStock ? Colors.red.shade600 : Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(
                        '${product.quantity} ${product.unit}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isLowStock ? Colors.red.shade600 : Colors.black87,
                        ),
                      ),
                      if (isLowStock) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Low Stock',
                            style: TextStyle(fontSize: 11, color: Colors.red.shade600, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (product.description.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      product.description,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 12),
            // Action row 1: Edit + Add Stock
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context, 'edit'),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context, 'stock'),
                      icon: const Icon(Icons.add_circle, size: 18),
                      label: const Text('Add Stock'),
                    ),
                  ),
                ],
              ),
            ),
            // Action row 2: Delete
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context, 'delete'),
                  icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade400),
                  label: Text('Delete Product', style: TextStyle(color: Colors.red.shade400)),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;
    switch (action) {
      case 'edit':
        _editProduct(product);
      case 'stock':
        _addStock(product);
      case 'delete':
        _deleteProduct(product);
    }
  }

  Widget expandedInfo(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _detailPlaceholder(bool isLowStock) {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isLowStock ? Colors.red.shade50 : Colors.grey.shade100,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Icon(
        Icons.inventory_2,
        size: 64,
        color: isLowStock ? Colors.red.shade300 : Colors.grey.shade400,
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
