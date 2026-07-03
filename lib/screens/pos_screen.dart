import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';
import '../models/product.dart';
import '../models/receipt.dart';
import '../utils/usb_scanner_service.dart';
import 'scan_screen.dart';

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double get total => product.price * quantity;
}

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _barcodeCtrl = TextEditingController();
  final _db = DatabaseHelper.instance;
  final _cart = <CartItem>[];
  final _focusNode = FocusNode();
  final _scanner = UsbScannerService();
  StreamSubscription<String>? _scannerSub;
  List<Product> _searchResults = [];
  Timer? _searchDebounce;
  bool _scannerConnected = false;
  bool _checkingOut = false;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    _startScanner();
  }

  @override
  void dispose() {
    _scannerSub?.cancel();
    _scanner.dispose();
    _searchDebounce?.cancel();
    _barcodeCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startScanner() {
    _scanner.connect();
    _scannerSub?.cancel();
    _scannerSub = _scanner.barcodeStream.listen((barcode) {
      if (mounted) {
        setState(() => _scannerConnected = _scanner.isConnected);
        _addByBarcode(barcode, showQty: false);
      }
    });
    if (mounted) {
      setState(() => _scannerConnected = _scanner.isConnected);
    }
  }

  int get _itemCount => _cart.length;
  double get _total => _cart.fold(0, (s, i) => s + i.total);

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? Colors.red.shade600 : null,
      ),
    );
  }

  /// Add [quantity] of [product] to the cart. Bounds the quantity by the
  /// product's known stock so the cart can never hold more than what's on hand.
  void _addToCart(Product product, {int quantity = 1}) {
    final existingIndex = _cart.indexWhere((i) => i.product.id == product.id);
    final inCart = existingIndex >= 0 ? _cart[existingIndex].quantity : 0;

    if (product.quantity <= 0) {
      _showSnack('${product.name} is out of stock', error: true);
      return;
    }
    final available = product.quantity - inCart;
    if (quantity > available) {
      _showSnack(
        'Only $available ${product.unit} of ${product.name} available',
        error: true,
      );
      return;
    }
    setState(() {
      if (existingIndex >= 0) {
        _cart[existingIndex].quantity += quantity;
      } else {
        _cart.add(CartItem(product: product, quantity: quantity));
      }
    });
  }

  Future<void> _addByBarcode(String query, {bool showQty = true}) async {
    if (query.trim().isEmpty) return;
    Product? product = await _db.getProductByBarcode(query.trim());
    if (product == null && _searchResults.isNotEmpty) {
      product = _searchResults.first;
    }
    if (!mounted) return;
    if (product == null) {
      _showSnack('No product found for "$query"');
      return;
    }
    setState(() => _searchResults = []);
    _barcodeCtrl.clear();
    if (showQty) {
      await _promptQtyAndAdd(product);
    } else {
      _addToCart(product);
      _focusNode.requestFocus();
    }
  }

  void _onSearchChanged(String q) {
    _searchDebounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      final results = await _db.getAllProducts(search: q.trim());
      if (mounted) setState(() => _searchResults = results);
    });
  }

  Future<void> _addByProduct(Product product) async {
    _promptQtyAndAdd(product);
  }

  /// Show a dialog to pick quantity, then add to cart.
  Future<void> _promptQtyAndAdd(Product product) async {
    final qty = await showDialog<int>(
      context: context,
      builder: (ctx) => _QtyDialog(product: product, cart: _cart),
    );
    if (qty != null && mounted) {
      _addToCart(product, quantity: qty);
      _focusNode.requestFocus();
    }
  }

  Future<void> _searchProduct() async {
    final ctrl = TextEditingController();
    List<Product> results = [];
    Timer? debounce;

    try {
      final product = await showDialog<Product>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Text('Search Product'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: ctrl,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Type product name or barcode...',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (q) {
                          debounce?.cancel();
                          debounce = Timer(const Duration(milliseconds: 300),
                                  () async {
                                final r = await _db.getAllProducts(search: q);
                                setDialogState(() => results = r);
                              });
                        },
                      ),
                      if (results.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 280,
                          child: ListView.separated(
                            itemCount: results.length,
                            separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final p = results[i];
                              return ListTile(
                                dense: true,
                                title: Text(p.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  '₱${p.price.toStringAsFixed(2)}  •  Stock: ${p.quantity}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600),
                                ),
                                trailing: Text(p.barcode,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade400)),
                                onTap: () => Navigator.pop(ctx, p),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (product != null && mounted) {
        _addByProduct(product);
      }
    } finally {
      debounce?.cancel();
      ctrl.dispose();
    }
  }

  Future<void> _scan() async {
    final barcode = await ScanScreen.pickAndScan(
      context,
      title: 'Scan Item',
    );
    if (barcode != null && mounted) {
      _barcodeCtrl.text = barcode;
      _addByBarcode(barcode);
    }
  }

  void _removeItem(int index) {
    setState(() => _cart.removeAt(index));
  }

  void _clearCart() {
    if (_cart.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear cart?'),
        content: Text('$_itemCount item(s) will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(ctx);
              final saved = List<CartItem>.from(_cart);
              setState(() => _cart.clear());
              _focusNode.requestFocus();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${saved.length} item(s) cleared'),
                    action: SnackBarAction(
                      label: 'Undo',
                      onPressed: () => setState(() => _cart.addAll(saved)),
                    ),
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Future<void> _editQuantity(CartItem item) async {
    final ctrl = TextEditingController(text: '${item.quantity}');
    String? errorText;

    try {
      final qty = await showDialog<int>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('${item.product.name} — quantity'),
            content: TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Quantity',
                prefixIcon: const Icon(Icons.edit),
                helperText: 'In stock: ${item.product.quantity}',
                errorText: errorText,
              ),
              onChanged: (_) {
                if (errorText != null) {
                  setDialogState(() => errorText = null);
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final v = int.tryParse(ctrl.text.trim());
                  if (v == null || v <= 0) {
                    setDialogState(() {
                      errorText = 'Enter a whole number greater than 0';
                    });
                    return;
                  }
                  if (v > item.product.quantity) {
                    setDialogState(() {
                      errorText = 'Only ${item.product.quantity} in stock';
                    });
                    return;
                  }
                  Navigator.pop(ctx, v);
                },
                child: const Text('Set'),
              ),
            ],
          ),
        ),
      );
      if (qty != null && mounted) {
        setState(() => item.quantity = qty);
      }
    } finally {
      ctrl.dispose();
    }
  }

  Future<void> _checkout() async {
    if (_cart.isEmpty || _checkingOut) return;

    final paid = await showDialog<double>(
      context: context,
      builder: (_) => _PaymentDialog(total: _total),
    );

    if (paid == null || !mounted) return;
    final cashPaid = paid;

    setState(() => _checkingOut = true);
    try {
      // Re-check every item against fresh DB stock right before deducting,
      // in case something changed since items were added to the cart.
      final shortages = <String>[];
      for (final item in _cart) {
        if (item.product.id == null) {
          shortages.add('${item.product.name} (missing ID)');
          continue;
        }
        final fresh = await _db.getProductByBarcode(item.product.barcode);
        if (fresh == null || fresh.quantity < item.quantity) {
          shortages.add(
            '${item.product.name} (have ${fresh?.quantity ?? 0}, need ${item.quantity})',
          );
        }
      }
      if (shortages.isNotEmpty) {
        _showSnack('Not enough stock: ${shortages.join(', ')}', error: true);
        return;
      }

      // Deduct stock, rolling back anything already deducted if one fails
      // partway through so we don't end up with half a sale applied.
      final deducted = <CartItem>[];
      try {
        for (final item in _cart) {
          await _db.adjustStock(item.product.id!, -item.quantity);
          deducted.add(item);
        }
      } catch (e) {
        for (final item in deducted) {
          try {
            await _db.adjustStock(item.product.id!, item.quantity);
          } catch (_) {
            // Best-effort rollback; nothing more we can do if this fails too.
          }
        }
        _showSnack('Checkout failed, no changes saved: $e', error: true);
        return;
      }

      final now = DateTime.now();
      final receiptNo =
      '${now.millisecondsSinceEpoch}${Random().nextInt(900) + 100}'
          .substring(5);
      final receipt = Receipt(
        receiptNo: receiptNo,
        subtotal: _total,
        tax: 0,
        total: _total,
        cash: cashPaid,
        change: cashPaid - _total,
        date: now.toIso8601String(),
        items: _cart
            .map((item) => ReceiptItem(
          productId: item.product.id!,
          productName: item.product.name,
          barcode: item.product.barcode,
          price: item.product.price,
          quantity: item.quantity,
          total: item.total,
        ))
            .toList(),
      );

      try {
        await _db.insertReceipt(receipt);
      } catch (e) {
        // Stock was already deducted and the sale did happen; don't roll
        // that back over a receipt-logging failure, just surface it.
        _showSnack(
          'Sale completed but the receipt failed to save: $e',
          error: true,
        );
      }

      if (!mounted) return;
      HapticFeedback.heavyImpact();
      _showReceipt(cashPaid, receiptNo);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _cart.clear());
          _focusNode.requestFocus();
        }
      });
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  void _showReceipt(double cash, String receiptNo) {
    final change = cash - _total;
    final now = DateTime.now();

    showDialog(
      context: context,
      useSafeArea: false,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Price Checker',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Receipt #$receiptNo',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 24),
              ..._cart.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.product.name,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Text(
                        '${item.quantity} × ₱${item.product.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 72,
                        child: Text(
                          '₱${item.total.toStringAsFixed(2)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 16),
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
                    '₱${_total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Cash', style: TextStyle(color: Colors.grey.shade600)),
                  Text('₱${cash.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Change', style: TextStyle(color: Colors.grey.shade600)),
                  Text(
                    '₱${change.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: change >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                DateFormat('MMM d, yyyy  h:mm a').format(now),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('POS'),
            if (_cart.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_itemCount',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search product',
            onPressed: _searchProduct,
          ),
          if (_cart.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Clear cart',
              onPressed: _clearCart,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _barcodeCtrl,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: 'Search product name or barcode...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_scannerConnected)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Tooltip(
                                message: 'USB scanner connected',
                                child: Icon(Icons.usb,
                                    size: 18, color: Colors.green),
                              ),
                            ),
                          IconButton(
                            icon: const Icon(Icons.qr_code_scanner),
                            onPressed: _scan,
                            tooltip: 'Scan',
                          ),
                        ],
                      ),
                    ),
                    onChanged: _onSearchChanged,
                    onSubmitted: _addByBarcode,
                    textInputAction: TextInputAction.done,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _addByBarcode(_barcodeCtrl.text),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                  child: const Icon(Icons.add_shopping_cart),
                ),
              ],
            ),
          ),
          if (_searchResults.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: _searchResults.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, indent: 16, endIndent: 16),
                itemBuilder: (_, i) {
                  final p = _searchResults[i];
                  return ListTile(
                    dense: true,
                    leading: p.imagePath.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              width: 36,
                              height: 36,
                              child: Image.file(
                                File(p.imagePath),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.inventory_2, size: 20),
                              ),
                            ),
                          )
                        : const Icon(Icons.inventory_2, size: 20),
                    title: Text(p.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '₱${p.price.toStringAsFixed(2)}  •  Stock: ${p.quantity} ${p.unit}',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    onTap: () async {
                      setState(() => _searchResults = []);
                      _barcodeCtrl.clear();
                      await _promptQtyAndAdd(p);
                    },
                  );
                },
              ),
            ),
          Expanded(
            child: _cart.isEmpty
                ? Center(
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
                      Icons.shopping_cart_outlined,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Cart is empty',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Scan items or tap search to add products',
                    style: TextStyle(color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 200),
              itemCount: _cart.length,
              itemBuilder: (context, index) {
                final item = _cart[index];
                return Dismissible(
                  key: ValueKey('${item.product.id}_$index'),
                  direction: DismissDirection.horizontal,
                  background: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.delete_outline,
                        color: Colors.red.shade400),
                  ),
                  secondaryBackground: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.delete_outline,
                        color: Colors.red.shade400),
                  ),
                  confirmDismiss: (_) async {
                    _removeItem(index);
                    return false;
                  },
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onLongPress: () => _editQuantity(item),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 48,
                                height: 48,
                                child:
                                item.product.imagePath.isNotEmpty
                                    ? Image.file(
                                  File(item.product.imagePath),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _posPlaceholder(),
                                )
                                    : _posPlaceholder(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.product.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '₱${item.product.price.toStringAsFixed(2)} × ${item.quantity}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₱${item.total.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _qtyBtn(
                                      Icons.remove,
                                          () {
                                        if (item.quantity > 1) {
                                          setState(() =>
                                          item.quantity--);
                                        } else {
                                          _removeItem(index);
                                        }
                                      },
                                    ),
                                    GestureDetector(
                                      onTap: () =>
                                          _editQuantity(item),
                                      child: Padding(
                                        padding:
                                        const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        child: Text(
                                          '${item.quantity}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                    ),
                                    _qtyBtn(
                                      Icons.add,
                                          () {
                                        if (item.quantity + 1 >
                                            item.product.quantity) {
                                          _showSnack(
                                            'Only ${item.product.quantity} ${item.product.unit} of ${item.product.name} in stock',
                                            error: true,
                                          );
                                          return;
                                        }
                                        setState(
                                                () => item.quantity++);
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomSheet: _cart.isNotEmpty
          ? Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    '₱${_total.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _checkingOut ? null : _checkout,
                  icon: _checkingOut
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.payments),
                  label: Text(
                    _checkingOut ? 'Processing...' : 'Charge',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      )
          : null,
    );
  }

  Widget _posPlaceholder() {
    return Container(
      color: Colors.grey.shade100,
      child: const Icon(Icons.inventory_2, size: 22, color: Colors.grey),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onPressed) {
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 16,
        icon: Icon(icon),
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: Colors.grey.shade100,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}

/// Dialog for entering cash amount during checkout.
class _PaymentDialog extends StatefulWidget {
  final double total;
  const _PaymentDialog({required this.total});

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final _ctrl = TextEditingController();

  List<double> get _suggestions {
    final t = widget.total;
    return [
      t,
      (t + 0.5 - t % 0.5),
      (t + 1 - t % 1),
      (t + 5 - t % 5),
      (t + 10 - t % 10),
      (t + 20 - t % 20),
      (t + 50 - t % 50),
      (t + 100 - t % 100),
    ]
        .map((v) => double.parse(v.toStringAsFixed(2)))
        .toSet()
        .toList()
      ..sort();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.total;
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: const Row(
        children: [
          Icon(Icons.payments, size: 24),
          SizedBox(width: 8),
          Text('Payment'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total:', style: TextStyle(fontSize: 16)),
              Text('₱${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  )),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Cash amount',
              prefixText: '₱ ',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _suggestions.map((s) {
              final isExact = s == total;
              return ActionChip(
                label: Text(
                  isExact ? 'Exact' : '₱${s.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isExact ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                onPressed: () => _ctrl.text = s.toStringAsFixed(2),
              );
            }).toList(),
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
            final raw = _ctrl.text.trim();
            final cash = double.tryParse(raw);
            if (cash == null || cash <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enter a valid amount')),
              );
            } else if (cash < total) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Cash (₱${cash.toStringAsFixed(2)}) is less than total (₱${total.toStringAsFixed(2)})',
                  ),
                ),
              );
            } else {
              Navigator.pop(context, cash);
            }
          },
          child: const Text('Pay'),
        ),
      ],
    );
  }
}

/// Dialog for picking a quantity before adding to cart.
class _QtyDialog extends StatefulWidget {
  final Product product;
  final List<CartItem> cart;
  const _QtyDialog({required this.product, required this.cart});

  @override
  State<_QtyDialog> createState() => _QtyDialogState();
}

class _QtyDialogState extends State<_QtyDialog> {
  final _ctrl = TextEditingController(text: '1');
  String? _error;

  int get _inCart {
    final i = widget.cart
        .indexWhere((c) => c.product.id == widget.product.id);
    return i >= 0 ? widget.cart[i].quantity : 0;
  }

  int get _available => widget.product.quantity - _inCart;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final v = int.tryParse(_ctrl.text.trim());
    if (v == null || v <= 0) {
      setState(() => _error = 'Enter a whole number greater than 0');
      return;
    }
    if (v > _available) {
      setState(
        () => _error = 'Only $_available ${widget.product.unit} available',
      );
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Add ${widget.product.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          Text(
            'In cart: $_inCart  •  Available: $_available ${widget.product.unit}',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          if (_available <= 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No stock available',
                style: TextStyle(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _available > 0 ? _submit : null,
          child: const Text('Add to cart'),
        ),
      ],
    );
  }
}