import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../db/database_helper.dart';
import '../models/product.dart';
import '../utils/scan_beep.dart';
import '../utils/usb_scanner_service.dart';
import '../widgets/scanner_mode_sheet.dart';
import 'main_shell.dart';

enum _ScannerMode { camera, external }

class PriceCheckV2Screen extends StatefulWidget {
  const PriceCheckV2Screen({super.key});

  @override
  State<PriceCheckV2Screen> createState() => _PriceCheckV2ScreenState();
}

class _PriceCheckV2ScreenState extends State<PriceCheckV2Screen>
    with WidgetsBindingObserver {
  MobileScannerController? _scannerController;
  final _db = DatabaseHelper.instance;

  _ScannerMode _mode = _ScannerMode.camera;
  Product? _product;
  bool _found = false;
  bool _loading = false;
  bool _torchOn = false;
  String? _lastBarcode;
  final _scanner = UsbScannerService();
  StreamSubscription<String>? _scannerSub;
  bool _scannerConnected = false;
  String _scannerStatus = 'Disconnected';
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    tabVisibilityNotifier.addListener(_onTabChanged);
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    _loadDefaultScanner();
  }

  void _syncCamera() {
    if (!mounted || _scannerController == null) return;
    if (_mode != _ScannerMode.camera) return;
    setState(() {});
  }

  void _onTabChanged() {
    final visible = tabVisibilityNotifier.currentTabIndex == 0;
    if (_visible == visible) return;
    _visible = visible;
    _syncCamera();
  }

  Future<void> _loadDefaultScanner() async {
    final mode = await _db.getSetting('default_scan_mode');
    if (!mounted) return;
    final targetMode = mode == 'external'
        ? _ScannerMode.external
        : _ScannerMode.camera;
    if (targetMode != _mode) {
      await _setMode(targetMode);
    } else {
      _syncCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    tabVisibilityNotifier.removeListener(_onTabChanged);
    _scannerSub?.cancel();
    _scanner.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) _syncCamera();
    }
  }

  Future<void> _setMode(_ScannerMode mode) async {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      _found = false;
      _product = null;
      _loading = false;
      _lastBarcode = null;
    });
    if (mode == _ScannerMode.camera) {
      _scannerSub?.cancel();
      _scanner.disconnect();
      _syncCamera();
    } else {
      await _scannerController?.stop();
      _startScanner();
    }
  }

  void _flipCamera() {
    _scannerController?.switchCamera();
    setState(() {});
  }

  void _toggleTorch() {
    _scannerController?.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_loading) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final value = barcodes.first.rawValue;
    if (value == null || value.isEmpty || value == _lastBarcode) return;
    ScanBeep.play();
    _lookup(value);
  }

  void _onScannerBarcode(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || _loading || trimmed == _lastBarcode) return;
    ScanBeep.play();
    _lookup(trimmed);
  }

  void _startScanner() {
    _scanner.connect();
    _scannerSub?.cancel();
    _scannerSub = _scanner.barcodeStream.listen((barcode) {
      if (mounted) {
        setState(() {
          _scannerConnected = _scanner.isConnected;
          _scannerStatus = _scanner.status;
        });
        _onScannerBarcode(barcode);
      }
    });
  }

  Future<void> _lookup(String barcode) async {
    setState(() {
      _loading = true;
      _product = null;
      _found = false;
      _scannerStatus = 'Looking up barcode...';
    });

    final bc = barcode.trim();
    _lastBarcode = bc;
    final product = await _db.getProductByBarcode(bc);

    if (!mounted) return;
    setState(() {
      _loading = false;
      _product = product;
      _found = true;
      _scannerStatus = product != null
          ? 'Found: ${product.name}'
          : 'No match for that barcode';
    });

    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && _found && _lastBarcode == bc) {
        setState(() {
          _found = false;
          _product = null;
          _lastBarcode = null;
          _scannerStatus = _scannerConnected
              ? 'Scan a barcode'
              : 'Disconnected';
        });
      }
    });
  }

  void _reset() {
    setState(() {
      _found = false;
      _product = null;
      _lastBarcode = null;
      _scannerStatus = _scannerConnected
          ? 'Scan a barcode'
          : 'Disconnected';
    });
  }

  Future<void> _showScannerMode() async {
    final result = await showScannerModeSheet(
      context,
      isExternal: _mode == _ScannerMode.external,
    );
    if (result == null || !mounted) return;
    final targetMode = result == ScannerChoice.external
        ? _ScannerMode.external
        : _ScannerMode.camera;
    await _setMode(targetMode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_mode == _ScannerMode.camera
            ? 'Price Check'
            : 'Price Check — USB Scanner'),
        centerTitle: true,
        actions: [
          if (_mode == _ScannerMode.camera) ...[
            IconButton(
              icon: const Icon(Icons.flip_camera_android),
              tooltip: 'Flip camera',
              onPressed: _flipCamera,
            ),
            IconButton(
              icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
              tooltip: 'Toggle flashlight',
              onPressed: _toggleTorch,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Scanner settings',
            onPressed: _showScannerMode,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_mode == _ScannerMode.camera)
            _buildCameraSection()
          else
            _buildExternalSection(),
          Expanded(
            child: _found && _product != null
                ? _buildProductDisplay(_product!)
                : _found && _product == null
                ? _buildNotFound()
                : _buildIdle(),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraSection() {
    return SizedBox(
      height: 220,
      child: Stack(
        children: [
          if (_scannerController != null && _visible)
            MobileScanner(
              controller: _scannerController!,
              onDetect: _onDetect,
            ),
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: _found
                    ? Colors.green
                    : _loading
                    ? Colors.amber
                    : Colors.white38,
                width: 3,
              ),
            ),
          ),
          Center(
            child: Container(
              width: 200,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _found
                      ? Colors.green.shade400
                      : Colors.white.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: _loading
                  ? const Center(
                child: CircularProgressIndicator(color: Colors.amber),
              )
                  : null,
            ),
          ),
          if (!_found && !_loading)
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Center(
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Point camera at a barcode',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExternalSection() {
    final connected = _scannerConnected;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _loading
                      ? Colors.amber.shade50
                      : _found
                      ? (_product != null
                      ? Colors.green.shade50
                      : Colors.orange.shade50)
                      : connected
                      ? Colors.green.shade50
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _loading
                    ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.amber.shade700,
                  ),
                )
                    : Icon(
                  _found
                      ? (_product != null
                      ? Icons.check_circle
                      : Icons.error_outline)
                      : (connected ? Icons.usb : Icons.usb_off),
                  color: _found
                      ? (_product != null
                      ? Colors.green
                      : Colors.orange)
                      : (connected ? Colors.green : Colors.grey.shade600),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _scannerStatus,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: _loading
                        ? Colors.amber.shade800
                        : _found
                        ? (_product != null
                        ? Colors.green.shade700
                        : Colors.orange.shade700)
                        : connected
                        ? Colors.green.shade700
                        : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!connected)
            FilledButton.icon(
              onPressed: _startScanner,
              icon: const Icon(Icons.usb, size: 18),
              label: const Text('Connect USB Scanner'),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 16, color: Colors.green),
                  SizedBox(width: 6),
                  Text(
                    'Scanner ready — scan a barcode',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductDisplay(Product p) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle,
              color: Colors.green.shade600,
              size: 48,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            p.name,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if (p.barcode.isNotEmpty)
            Text(
              p.barcode,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
                letterSpacing: 1,
              ),
            ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue.shade200, width: 1),
            ),
            child: Column(
              children: [
                Text(
                  'Price',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₱${p.price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (p.category.isNotEmpty)
                _infoChip(Icons.category, p.category),
              const SizedBox(width: 8),
              _infoChip(
                Icons.inventory_2,
                'Stock: ${p.quantity} ${p.unit}',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Scan another barcode to continue',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.qr_code_scanner, size: 18),
            label: const Text('Scan Next'),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  Widget _buildNotFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off,
              color: Colors.orange.shade600,
              size: 48,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Product not found',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'No product matches this barcode',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  Widget _buildIdle() {
    final icon = _mode == _ScannerMode.camera
        ? Icons.qr_code_scanner
        : Icons.usb;
    final msg = _mode == _ScannerMode.camera
        ? 'Point the camera at a product barcode\nto see the price'
        : 'Type or scan a barcode using an\nexternal scanner to see the price';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 64, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 20),
          Text(
            'Scan a barcode',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            msg,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}