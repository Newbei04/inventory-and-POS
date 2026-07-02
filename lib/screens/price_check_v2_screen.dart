import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../db/database_helper.dart';
import '../models/product.dart';

enum _ScannerMode { camera, external }

class PriceCheckV2Screen extends StatefulWidget {
  const PriceCheckV2Screen({super.key});

  @override
  State<PriceCheckV2Screen> createState() => _PriceCheckV2ScreenState();
}

class _PriceCheckV2ScreenState extends State<PriceCheckV2Screen> {
  final _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  final _extCtrl = TextEditingController();
  final _extFocusNode = FocusNode();
  final _db = DatabaseHelper.instance;

  _ScannerMode _mode = _ScannerMode.camera;
  Product? _product;
  bool _found = false;
  bool _loading = false;
  bool _torchOn = false;
  String? _lastBarcode;
  bool _extActive = false;
  String _extStatus = 'Enter barcode below';
  BluetoothDevice? _selectedDevice;
  List<BluetoothDevice> _pairedDevices = [];

  @override
  void initState() {
    super.initState();
    _scannerController.start();
    _extFocusNode.addListener(_onExtFocusChange);
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _extCtrl.dispose();
    _extFocusNode.dispose();
    super.dispose();
  }

  void _onExtFocusChange() {
    if (!mounted) return;
    setState(() {
      _extActive = _extFocusNode.hasFocus;
      _extStatus = _extFocusNode.hasFocus
          ? (_selectedDevice != null
              ? 'Connected — point scanner at a barcode'
              : 'Type or scan a barcode')
          : 'Tap to activate input';
    });
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
      await _scannerController.start();
      _extFocusNode.unfocus();
    } else {
      await _scannerController.stop();
      _extCtrl.clear();
      _extFocusNode.requestFocus();
    }
  }

  void _flipCamera() {
    _scannerController.switchCamera();
    setState(() {});
  }

  void _toggleTorch() {
    _scannerController.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_loading) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final value = barcodes.first.rawValue;
    if (value == null || value.isEmpty || value == _lastBarcode) return;
    _lookup(value);
  }

  void _onExtBarcode(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || _loading || trimmed == _lastBarcode) return;
    _lookup(trimmed);
    _extCtrl.clear();
  }

  Future<void> _lookup(String barcode) async {
    setState(() {
      _loading = true;
      _product = null;
      _found = false;
    });

    final bc = barcode.trim();
    _lastBarcode = bc;
    final product = await _db.getProductByBarcode(bc);

    if (!mounted) return;
    setState(() {
      _loading = false;
      _product = product;
      _found = true;
    });

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _found && _lastBarcode == bc) {
        setState(() {
          _found = false;
          _product = null;
          _lastBarcode = null;
        });
        if (_mode == _ScannerMode.external) {
          _extFocusNode.requestFocus();
        }
      }
    });
  }

  void _reset() {
    setState(() {
      _found = false;
      _product = null;
      _lastBarcode = null;
    });
    if (_mode == _ScannerMode.external) {
      _extFocusNode.requestFocus();
    }
  }

  // ── Bluetooth ──

  Future<void> _loadPairedDevices() async {
    try {
      final devices = await FlutterBluetoothSerial.instance.getBondedDevices();
      if (mounted) {
        setState(() => _pairedDevices = devices);
      }
    } catch (_) {}
  }

  Future<void> _showDevicePicker() async {
    await _loadPairedDevices();
    if (!mounted) return;
    final device = await showModalBottomSheet<BluetoothDevice>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Select Bluetooth Scanner',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                '${_pairedDevices.length} paired device(s) found',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              if (_pairedDevices.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.bluetooth_disabled,
                            size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text('No paired devices',
                            style: TextStyle(color: Colors.grey.shade600)),
                        const SizedBox(height: 4),
                        Text('Pair your scanner in Bluetooth settings',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                )
              else
                ..._pairedDevices.map(
                  (d) => ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _selectedDevice?.address == d.address
                            ? Colors.green.shade50
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.bluetooth_connected,
                        color: _selectedDevice?.address == d.address
                            ? Colors.green
                            : Colors.grey.shade600,
                      ),
                    ),
                    title: Text(d.name ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(d.address,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500)),
                    trailing: _selectedDevice?.address == d.address
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                    onTap: () => Navigator.pop(ctx, d),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (device != null && mounted) {
      setState(() {
        _selectedDevice = device;
        _extActive = true;
        _extStatus = 'Connected — point scanner at a barcode';
      });
      _extFocusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_mode == _ScannerMode.camera
            ? 'Price Check'
            : 'Price Check — External'),
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
          PopupMenuButton<_ScannerMode>(
            icon: const Icon(Icons.more_vert),
            onSelected: _setMode,
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _ScannerMode.camera,
                child: Row(
                  children: [
                    Icon(Icons.qr_code_scanner,
                        color: _mode == _ScannerMode.camera
                            ? Colors.blue
                            : null,
                        size: 20),
                    const SizedBox(width: 12),
                    const Text('Camera Scanner'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _ScannerMode.external,
                child: Row(
                  children: [
                    Icon(Icons.bluetooth_connected,
                        color: _mode == _ScannerMode.external
                            ? Colors.blue
                            : null,
                        size: 20),
                    const SizedBox(width: 12),
                    const Text('External Scanner'),
                  ],
                ),
              ),
            ],
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
          MobileScanner(
            controller: _scannerController,
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
                  color: _extActive
                      ? Colors.green.shade50
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _selectedDevice != null
                      ? Icons.bluetooth_connected
                      : Icons.keyboard,
                  color: _extActive ? Colors.green : Colors.grey.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _extStatus,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: _extActive ? Colors.green.shade700 : Colors.grey.shade600,
                      ),
                    ),
                    if (_selectedDevice != null)
                      Text(
                        _selectedDevice!.name ?? _selectedDevice!.address,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                      ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _showDevicePicker,
                icon: Icon(Icons.bluetooth_searching,
                    size: 16, color: Colors.grey.shade600),
                label: Text('Device',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _extCtrl,
            focusNode: _extFocusNode,
            autofocus: true,
            style: const TextStyle(fontSize: 18),
            decoration: InputDecoration(
              hintText: 'Scan or type barcode...',
              prefixIcon: const Icon(Icons.qr_code),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: Colors.blue.shade400, width: 2),
              ),
              suffixIcon: _extCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.send, size: 18),
                      onPressed: () => _onExtBarcode(_extCtrl.text),
                    )
                  : null,
            ),
            onSubmitted: _onExtBarcode,
            textInputAction: TextInputAction.done,
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
        : Icons.keyboard;
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
