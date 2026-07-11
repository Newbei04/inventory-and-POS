import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../db/database_helper.dart';
import '../models/product.dart';
import '../utils/scan_beep.dart';
import '../utils/usb_scanner_service.dart';
import '../widgets/scanner_mode_sheet.dart';

enum _ScannerMode { camera, external }

enum _CountMode { add, remove }

enum StockReason { adjustment, expired, defective, destroyed }

extension _StockReasonX on StockReason {
  String get label => switch (this) {
    StockReason.adjustment => 'Adjustment',
    StockReason.expired => 'Expired',
    StockReason.defective => 'Defective',
    StockReason.destroyed => 'Destroyed',
  };
  IconData get icon => switch (this) {
    StockReason.adjustment => Icons.tune,
    StockReason.expired => Icons.event_busy,
    StockReason.defective => Icons.broken_image,
    StockReason.destroyed => Icons.delete_forever,
  };
  Color get color => switch (this) {
    StockReason.adjustment => Colors.blueGrey,
    StockReason.expired => Colors.red,
    StockReason.defective => Colors.deepPurple,
    StockReason.destroyed => Colors.brown,
  };
}

class _CartItem {
  final Product product;
  int quantity;

  _CartItem({required this.product, required this.quantity});
}

class InventoryV2Screen extends StatefulWidget {
  const InventoryV2Screen({super.key});

  @override
  State<InventoryV2Screen> createState() => _InventoryV2ScreenState();
}

class _InventoryV2ScreenState extends State<InventoryV2Screen> {
  final _db = DatabaseHelper.instance;
  final _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  final _usbScanner = UsbScannerService();
  StreamSubscription<String>? _usbSub;
  final _searchCtrl = TextEditingController();

  _ScannerMode _scannerMode = _ScannerMode.camera;
  _CountMode _countMode = _CountMode.add;
  StockReason _selectedReason = StockReason.adjustment;
  final List<_CartItem> _cartItems = [];
  bool _torchOn = false;
  bool _usbConnected = false;
  String _usbStatus = 'Disconnected';
  String? _lastBarcode;
  bool _loading = false;
  bool _scannerHidden = false;

  List<Product> _searchResults = [];
  bool _showingSearch = false;

  int get _totalItems => _cartItems.length;
  int get _totalQty => _cartItems.fold(0, (sum, e) => sum + e.quantity);

  @override
  void initState() {
    super.initState();
    _loadDefaultScanner();
  }

  @override
  void dispose() {
    _usbSub?.cancel();
    _usbScanner.dispose();
    _scannerController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDefaultScanner() async {
    final mode = await _db.getSetting('default_scan_mode');
    if (!mounted) return;
    final target = mode == 'external' ? _ScannerMode.external : _ScannerMode.camera;
    if (target != _scannerMode) {
      await _setScannerMode(target);
    } else if (_scannerMode == _ScannerMode.camera) {
      _scannerController.start();
    }
  }

  Future<void> _setScannerMode(_ScannerMode mode) async {
    if (mode == _scannerMode) return;
    setState(() {
      _scannerMode = mode;
      _lastBarcode = null;
      _loading = false;
    });
    if (mode == _ScannerMode.camera) {
      _usbSub?.cancel();
      _usbScanner.disconnect();
      await _scannerController.start();
    } else {
      await _scannerController.stop();
      _startUsbScanner();
    }
  }

  void _startUsbScanner() {
    _usbScanner.connect();
    _usbSub?.cancel();
    _usbSub = _usbScanner.barcodeStream.listen((barcode) {
      if (mounted) {
        setState(() {
          _usbConnected = _usbScanner.isConnected;
          _usbStatus = _usbScanner.status;
        });
        _onBarcodeDetected(barcode);
      }
    });
    if (mounted) {
      setState(() {
        _usbConnected = _usbScanner.isConnected;
        _usbStatus = _usbScanner.status;
      });
    }
  }

  void _flipCamera() => _scannerController.switchCamera();
  void _toggleTorch() {
    _scannerController.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  void _onCameraDetect(BarcodeCapture capture) {
    if (_loading) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final value = barcodes.first.rawValue;
    if (value == null || value.isEmpty || value == _lastBarcode) return;
    _onBarcodeDetected(value);
  }

  Future<void> _onBarcodeDetected(String barcode) async {
    ScanBeep.play();
    final bc = barcode.trim();
    _lastBarcode = bc;
    setState(() => _loading = true);

    final product = await _db.getProductByBarcode(bc);
    if (!mounted) return;
    setState(() => _loading = false);

    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No product found for: $bc'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 1),
        ),
      );
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _lastBarcode = null);
      });
      return;
    }

    if (_countMode == _CountMode.add) {
      _addToCart(product);
    } else {
      _addToRemoveCart(product);
    }

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _lastBarcode = null);
    });
  }

  void _addToCart(Product product) {
    final idx = _cartItems.indexWhere((e) => e.product.id == product.id);
    if (idx >= 0) {
      _cartItems[idx].quantity++;
    } else {
      _cartItems.insert(0, _CartItem(product: product, quantity: 1));
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} — qty ${_cartItems.firstWhere((e) => e.product.id == product.id).quantity}'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 600),
      ),
    );
  }

  void _addToRemoveCart(Product product) {
    final idx = _cartItems.indexWhere((e) => e.product.id == product.id);
    if (idx >= 0) {
      _cartItems[idx].quantity++;
    } else {
      _cartItems.insert(0, _CartItem(product: product, quantity: 1));
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} — marking ${_cartItems.firstWhere((e) => e.product.id == product.id).quantity} for removal'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(milliseconds: 600),
      ),
    );
  }

  void _onSearch(String q) {
    if (q.trim().isEmpty) {
      setState(() { _searchResults = []; _showingSearch = false; });
      return;
    }
    setState(() => _showingSearch = true);
    _db.getAllProducts(search: q.trim()).then((r) {
      if (mounted) setState(() => _searchResults = r);
    });
  }

  void _selectSearchProduct(Product p) {
    _searchCtrl.clear();
    setState(() { _searchResults = []; _showingSearch = false; });
    if (_countMode == _CountMode.add) {
      _addToCart(p);
    } else {
      _addToRemoveCart(p);
    }
  }

  void _clearCart() => setState(() => _cartItems.clear());

  Future<void> _applyAll() async {
    if (_cartItems.isEmpty) return;

    int success = 0;
    for (final item in _cartItems) {
      try {
        if (_countMode == _CountMode.add) {
          await _db.adjustStock(item.product.id!, item.quantity, reason: 'Restock', type: 'add');
        } else {
          final clamped = item.quantity > item.product.quantity ? item.product.quantity : item.quantity;
          await _db.adjustStock(item.product.id!, -clamped, reason: _selectedReason.label, type: 'remove');
        }
        success++;
      } catch (_) {}
    }

    if (!mounted) return;
    final isAdd = _countMode == _CountMode.add;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isAdd ? 'Added stock for $success product(s)' : 'Removed stock for $success product(s)'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isAdd ? Colors.green.shade600 : Colors.orange.shade700,
        duration: const Duration(seconds: 2),
      ),
    );
    setState(() => _cartItems.clear());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_scannerMode == _ScannerMode.camera
            ? 'Inventory Count'
            : 'Inventory Count — USB'),
        centerTitle: true,
        actions: [
          if (_cartItems.isNotEmpty)
            IconButton(
              icon: Badge(label: Text('${_cartItems.length}', style: const TextStyle(fontSize: 10, color: Colors.white)),
                  child: const Icon(Icons.shopping_cart_outlined, size: 22)),
              tooltip: 'View Cart',
              onPressed: _showCartSheet,
            ),
          if (_scannerMode == _ScannerMode.camera && !_scannerHidden) ...[
            IconButton(
              icon: const Icon(Icons.flip_camera_android, size: 22),
              tooltip: 'Flip camera',
              onPressed: _flipCamera,
            ),
            IconButton(
              icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off, size: 22),
              tooltip: 'Flashlight',
              onPressed: _toggleTorch,
            ),
          ],
          IconButton(
            icon: Icon(_scannerHidden ? Icons.visibility_off : Icons.visibility, size: 22),
            tooltip: _scannerHidden ? 'Show scanner' : 'Hide scanner',
            onPressed: () => setState(() => _scannerHidden = !_scannerHidden),
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, size: 22),
            tooltip: 'Scanner settings',
            onPressed: _showScannerModeSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_scannerHidden) ...[
            if (_scannerMode == _ScannerMode.camera)
              _buildCameraSection()
            else
              _buildUsbSection(),
          ],
          _buildModeBar(),
          if (_countMode == _CountMode.remove) _buildReasonBar(),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: _countMode == _CountMode.add ? 'Search to add...' : 'Search to remove...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchCtrl.clear(); _onSearch(''); })
                    : null,
              ),
              onChanged: _onSearch,
            ),
          ),
          if (_showingSearch)
            Expanded(
              child: _searchResults.isEmpty
                  ? Center(child: Text('No products found', style: TextStyle(color: Colors.grey.shade500)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
                      itemCount: _searchResults.length,
                      itemBuilder: (_, i) => _searchTile(_searchResults[i]),
                    ),
            )
          else
            Expanded(
              child: _cartItems.isEmpty ? _buildEmptyState() : _buildCartList(),
            ),
          ],
        ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ── Camera section ──

  Widget _buildCameraSection() {
    return SizedBox(
      height: 200,
      child: Stack(
        children: [
          MobileScanner(controller: _scannerController, onDetect: _onCameraDetect),
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: _loading ? Colors.amber : Colors.white38,
                width: 3,
              ),
            ),
          ),
          Center(
            child: Container(
              width: 200,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _loading ? Colors.amber.shade400 : Colors.white.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                  : null,
            ),
          ),
          if (!_loading)
            Positioned(
              left: 0, right: 0, bottom: 12,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    _countMode == _CountMode.add
                        ? 'Scan to add stock'
                        : 'Scan to remove stock',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── USB section ──

  Widget _buildUsbSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _loading ? Colors.amber.shade50 : _usbConnected ? Colors.green.shade50 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: _loading
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber.shade700))
                : Icon(_usbConnected ? Icons.usb : Icons.usb_off, size: 20,
                    color: _usbConnected ? Colors.green : Colors.grey.shade600),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _loading ? 'Looking up...' : _usbConnected ? 'Ready — scan a barcode' : _usbStatus,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                color: _loading ? Colors.amber.shade800 : _usbConnected ? Colors.green.shade700 : Colors.grey.shade600),
            ),
          ),
          if (!_usbConnected)
            FilledButton.tonal(
              onPressed: _startUsbScanner,
              child: const Text('Connect', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  // ── Mode bar ──

  Widget _buildModeBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.all(2),
      child: Row(
        children: [
          Expanded(child: _modeTab('Add', Icons.add, _countMode == _CountMode.add, Colors.green, () {
            setState(() { _countMode = _CountMode.add; _cartItems.clear(); });
          })),
          Expanded(child: _modeTab('Remove', Icons.remove, _countMode == _CountMode.remove, Colors.orange, () {
            setState(() { _countMode = _CountMode.remove; _cartItems.clear(); });
          })),
        ],
      ),
    );
  }

  Widget _modeTab(String label, IconData icon, bool active, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: active ? Border.all(color: color.withValues(alpha: 0.3)) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: active ? color : Colors.grey.shade500),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: active ? color : Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  // ── Reason bar ──

  Widget _buildReasonBar() {
    const reasons = [StockReason.expired, StockReason.defective, StockReason.destroyed, StockReason.adjustment];

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reason', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.orange.shade700)),
          const SizedBox(height: 4),
          Row(
            children: reasons.map((r) {
              final sel = _selectedReason == r;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedReason = r),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    decoration: BoxDecoration(
                      color: sel ? r.color.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: sel ? r.color.withValues(alpha: 0.5) : Colors.grey.shade200),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(r.icon, size: 14, color: sel ? r.color : Colors.grey.shade400),
                        const SizedBox(height: 2),
                        Text(r.label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                            color: sel ? r.color : Colors.grey.shade500)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Empty state ──

  Widget _buildEmptyState() {
    final isAdd = _countMode == _CountMode.add;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: (isAdd ? Colors.green : Colors.orange).shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(isAdd ? Icons.add_shopping_cart : Icons.remove_shopping_cart,
                  size: 48, color: (isAdd ? Colors.green : Colors.orange).shade300),
            ),
            const SizedBox(height: 16),
            Text(isAdd ? 'No items to add' : 'No items to remove',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              isAdd ? 'Scan a barcode — same product increments qty' : 'Scan a barcode to mark for removal',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  // ── Cart list ──

  Widget _buildCartList() {
    final isAdd = _countMode == _CountMode.add;
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statPill('$_totalItems', 'Items', Colors.blue),
              Container(width: 1, height: 16, color: Colors.grey.shade300),
              _statPill('$_totalQty', 'Total', isAdd ? Colors.green : Colors.orange),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 80),
            itemCount: _cartItems.length,
            itemBuilder: (_, i) => _cartItemCard(_cartItems[i]),
          ),
        ),
      ],
    );
  }

  Widget _statPill(String value, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _cartItemCard(_CartItem item) {
    final isAdd = _countMode == _CountMode.add;
    final color = isAdd ? Colors.green : Colors.orange;
    final maxQty = isAdd ? 9999 : item.product.quantity;

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 36, height: 36,
                child: item.product.imagePath.isNotEmpty
                    ? Image.file(File(item.product.imagePath), fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder())
                    : _placeholder(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 1),
                  Text('Stock: ${item.product.quantity}', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _qtyBtn(Icons.remove, () {
                  setState(() {
                    if (item.quantity <= 1) {
                      _cartItems.remove(item);
                    } else {
                      item.quantity--;
                    }
                  });
                }),
                SizedBox(
                  width: 36,
                  child: Text('${item.quantity}', textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
                ),
                _qtyBtn(Icons.add, () {
                  setState(() {
                    if (item.quantity < maxQty) item.quantity++;
                  });
                }),
              ],
            ),
            GestureDetector(
              onTap: () => setState(() => _cartItems.remove(item)),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close, size: 16, color: Colors.grey.shade400),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26, height: 26,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14, color: Colors.grey.shade600),
      ),
    );
  }

  Widget _placeholder() => Container(
    color: Colors.grey.shade200,
    child: Icon(Icons.inventory_2, color: Colors.grey.shade400, size: 18),
  );

  Widget _searchTile(Product p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: true,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: 32, height: 32,
            child: p.imagePath.isNotEmpty
                ? Image.file(File(p.imagePath), fit: BoxFit.cover)
                : _placeholder(),
          ),
        ),
        title: Text(p.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1),
        subtitle: Text('${p.barcode}  •  ${p.quantity} ${p.unit}',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        trailing: Icon(Icons.add_circle_outline, color: _countMode == _CountMode.add ? Colors.green : Colors.orange, size: 20),
        onTap: () => _selectSearchProduct(p),
      ),
    );
  }

  // ── Bottom bar ──

  Widget _buildBottomBar() {
    final isAdd = _countMode == _CountMode.add;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: Row(
          children: [
            if (_cartItems.isNotEmpty)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _clearCart,
                  icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                  label: const Text('Clear', style: TextStyle(fontSize: 12)),
                ),
              ),
            if (_cartItems.isNotEmpty) const SizedBox(width: 8),
            Expanded(
              flex: _cartItems.isEmpty ? 1 : 2,
              child: FilledButton.icon(
                onPressed: _cartItems.isNotEmpty ? _applyAll : null,
                icon: const Icon(Icons.check_circle, size: 18),
                label: Text(
                  _cartItems.isEmpty
                      ? 'Scan a barcode'
                      : isAdd ? 'Apply Add (${_cartItems.length})' : 'Apply Remove (${_cartItems.length})',
                  style: const TextStyle(fontSize: 12),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _cartItems.isNotEmpty ? (isAdd ? Colors.green : Colors.orange) : Colors.grey.shade300,
                ),
              ),
            ),
          ],
        ),
    );
  }

  // ── Cart bottom sheet ──

  void _showCartSheet() {
    final isAdd = _countMode == _CountMode.add;
    final color = isAdd ? Colors.green : Colors.orange;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6, minChildSize: 0.3, maxChildSize: 0.9, expand: false,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            Container(margin: const EdgeInsets.only(top: 10), width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(isAdd ? 'Add Stock Cart' : 'Remove Stock Cart',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: _cartItems.length,
                itemBuilder: (_, i) {
                  final item = _cartItems[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      dense: true,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 32, height: 32,
                          child: item.product.imagePath.isNotEmpty
                              ? Image.file(File(item.product.imagePath), fit: BoxFit.cover)
                              : _placeholder(),
                        ),
                      ),
                      title: Text(item.product.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      subtitle: Text(_selectedReason.label, style: TextStyle(fontSize: 10, color: _selectedReason.color)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text(isAdd ? '+${item.quantity}' : '-${item.quantity}',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showScannerModeSheet() async {
    final result = await showScannerModeSheet(context, isExternal: _scannerMode == _ScannerMode.external);
    if (result == null || !mounted) return;
    await _setScannerMode(result == ScannerChoice.external ? _ScannerMode.external : _ScannerMode.camera);
  }
}
