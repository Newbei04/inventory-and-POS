import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/database_helper.dart';
import '../models/product.dart';
import '../models/receipt.dart';
import '../utils/usb_scanner_service.dart';
import '../utils/scan_beep.dart';
import '../widgets/pos/payment_dialog.dart';
import '../widgets/pos/qty_dialog.dart';
import '../widgets/pos/receipt_dialog.dart';
import '../widgets/scanner_mode_sheet.dart';
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
  bool _useExternalScanner = false;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    _loadScannerDefault();
    _startScanner();
  }

  Future<void> _loadScannerDefault() async {
    final mode = await _db.getSetting('default_scan_mode');
    if (mounted) setState(() => _useExternalScanner = mode == 'external');
  }

  Future<void> _showScannerMode() async {
    final result = await showScannerModeSheet(
      context,
      isExternal: _useExternalScanner,
    );
    if (result == null || !mounted) return;
    setState(() => _useExternalScanner = result == ScannerChoice.external);
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
        ScanBeep.play();
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

  Future<void> _promptQtyAndAdd(Product product) async {
    final refs = _cart
        .map((c) => CartItemRef(product: c.product, quantity: c.quantity))
        .toList();
    final qty = await showDialog<int>(
      context: context,
      builder: (ctx) => QtyDialog(product: product, cart: refs),
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
    final db = DatabaseHelper.instance;
    final savedMode = await db.getSetting('default_scan_mode');
    if (!mounted) return;
    final mode = savedMode == 'external' ? ScanMode.external : ScanMode.camera;
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ScanScreen(
          title: 'Scan Item',
          initialMode: mode,
        ),
      ),
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
      builder: (_) => PaymentDialog(total: _total),
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
    final lines = _cart
        .map((item) => PosReceiptLine(
              name: item.product.name,
              quantity: item.quantity,
              unitPrice: item.product.price,
              lineTotal: item.total,
            ))
        .toList();
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (_) => PosReceiptDialog(
        items: lines,
        total: _total,
        cash: cash,
        receiptNo: receiptNo,
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
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Scanner settings',
            onPressed: _showScannerMode,
          ),
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

