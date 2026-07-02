import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

enum ScanMode { camera, photo, external }

class ScanScreen extends StatefulWidget {
  const ScanScreen({
    super.key,
    this.title = 'Scan Barcode',
    this.initialMode = ScanMode.camera,
  });

  final String title;
  final ScanMode initialMode;

  /// Shows a bottom sheet to pick Camera Scanner or External Scanner,
  /// then opens [ScanScreen] in the chosen mode.
  static Future<String?> pickAndScan(
    BuildContext context, {
    String title = 'Scan Barcode',
  }) {
    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Choose scan method',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.qr_code_scanner,
                    color: Colors.blue.shade700,
                  ),
                ),
                title: const Text('Camera Scanner'),
                subtitle: const Text('Scan barcodes using the device camera'),
                onTap: () => Navigator.pop(ctx, 'camera'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 4),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.bluetooth_connected,
                    color: Colors.green.shade700,
                  ),
                ),
                title: const Text('External Scanner'),
                subtitle: const Text('Use a Bluetooth or USB barcode scanner'),
                onTap: () => Navigator.pop(ctx, 'external'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((mode) {
      if (mode == null) return null;
      if (!context.mounted) return null;
      return Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => ScanScreen(
            title: title,
            initialMode: mode == 'external'
                ? ScanMode.external
                : ScanMode.camera,
          ),
        ),
      );
    });
  }

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    autoStart: false,
  );
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _cameraReady = false;
  bool _handled = false;
  late AnimationController _animCtrl;
  late ScanMode _scanMode;
  final _extFocusNode = FocusNode();
  final _extCtrl = TextEditingController();
  String _extStatus = 'Ready';
  bool _extActive = false;
  BluetoothDevice? _selectedDevice;
  List<BluetoothDevice> _pairedDevices = [];
  bool _scanningDevices = false;

  @override
  void initState() {
    super.initState();
    _scanMode = widget.initialMode;
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _extFocusNode.addListener(_onExtFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startMode(_scanMode);
    });
  }

  void _onExtFocusChange() {
    if (!mounted) return;
    setState(() {
      _extActive = _extFocusNode.hasFocus;
      if (_selectedDevice != null) {
        _extStatus = _extFocusNode.hasFocus
            ? 'Connected — waiting for scanner input...'
            : 'Connected — tap to activate';
      } else {
        _extStatus = _extFocusNode.hasFocus
            ? 'No device selected — waiting'
            : 'No device selected';
      }
    });
  }

  Future<void> _startMode(ScanMode mode) async {
    setState(() => _scanMode = mode);
    switch (mode) {
      case ScanMode.camera:
        await _scannerController.start();
      case ScanMode.photo:
        await _initPhotoCamera();
      case ScanMode.external:
        _selectedDevice = null;
        _extStatus = 'No device selected';
        _extActive = false;
        _extCtrl.clear();
        _extFocusNode.requestFocus();
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _scanMode == ScanMode.external) {
              _showDevicePicker();
            }
          });
        }
    }
  }

  Future<void> _initPhotoCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty || !mounted) return;
      _cameras = cameras;
      final controller = CameraController(cameras[0], ResolutionPreset.high);
      await controller.initialize();
      if (mounted) {
        setState(() {
          _cameraController = controller;
          _cameraReady = true;
        });
      }
    } catch (_) {}
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final value = barcodes.first.rawValue;
    if (value == null || value.isEmpty) return;
    _handled = true;
    HapticFeedback.lightImpact();
    Navigator.of(context).pop(value);
  }

  Future<void> _manualEntry() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Enter barcode'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Barcode / SKU',
            prefixIcon: Icon(Icons.qr_code),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (code != null && code.isNotEmpty && mounted) {
      Navigator.of(context).pop(code);
    }
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    try {
      final file = await _cameraController!.takePicture();
      if (mounted) Navigator.of(context).pop(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Capture error: $e')));
      }
    }
  }

  Future<void> _setScanMode(ScanMode mode) async {
    if (mode == _scanMode) return;
    await _scannerController.stop();
    _cameraController?.dispose();
    _cameraController = null;
    _cameraReady = false;
    _handled = false;
    setState(() => _scanMode = mode);

    switch (mode) {
      case ScanMode.camera:
        await _scannerController.start();
      case ScanMode.photo:
        await _initPhotoCamera();
      case ScanMode.external:
        _selectedDevice = null;
        _extCtrl.clear();
        _extStatus = 'No device selected';
        _extActive = false;
        _extFocusNode.requestFocus();
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _scanMode == ScanMode.external) {
              _showDevicePicker();
            }
          });
        }
    }
  }

  Future<void> _switchPhotoCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;
    final idx = _cameras!.indexOf(_cameraController!.description);
    final next = (idx + 1) % _cameras!.length;
    final old = _cameraController;
    _cameraController = CameraController(
      _cameras![next],
      ResolutionPreset.high,
    );
    await _cameraController!.initialize();
    await old?.dispose();
    if (mounted) setState(() {});
  }

  void _onExtBarcode(String value) {
    if (value.trim().isNotEmpty) {
      setState(() => _extStatus = 'Scanned!');
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) Navigator.of(context).pop(value.trim());
        });
      }
    }
  }

  Future<void> _loadPairedDevices() async {
    setState(() => _scanningDevices = true);
    try {
      final devices = await FlutterBluetoothSerial.instance.getBondedDevices();
      if (mounted) {
        setState(() {
          _pairedDevices = devices;
          _scanningDevices = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _scanningDevices = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not load devices: $e')));
      }
    }
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
                        Icon(
                          Icons.bluetooth_disabled,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No paired devices',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pair your scanner in Bluetooth settings',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
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
                    title: Text(
                      d.name ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      d.address,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    trailing: _selectedDevice?.address == d.address
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                    onTap: () => Navigator.pop(ctx, d),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              if (_pairedDevices.isNotEmpty) ...[
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Open Bluetooth settings to pair a new device',
                          ),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Pair new device'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (device != null && mounted) {
      setState(() {
        _selectedDevice = device;
        _extActive = true;
        _extStatus = 'Connected — waiting for scanner input...';
      });
      _extFocusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _scannerController.dispose();
    _cameraController?.dispose();
    _extFocusNode.dispose();
    _extCtrl.dispose();
    super.dispose();
  }

  static const _bgColor = Color(0xFF0D1117);
  static const _surfaceColor = Color(0xFF161B22);
  static const _accent = Color(0xFF4FC3F7);
  static const _accentSoft = Color(0xFF1A3A4A);
  static const _textDim = Color(0xFF8B949E);
  static const _textBright = Color(0xFFE6EDF3);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _surfaceColor,
        foregroundColor: _textBright,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(widget.title),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PopupMenuButton<ScanMode>(
            icon: const Icon(Icons.more_vert, color: _textBright),
            onSelected: _setScanMode,
            surfaceTintColor: _surfaceColor,
            color: _surfaceColor,
            itemBuilder: (_) => [
              PopupMenuItem(
                value: ScanMode.camera,
                child: Row(
                  children: [
                    Icon(
                      Icons.qr_code_scanner,
                      color: _scanMode == ScanMode.camera
                          ? _accent
                          : _textBright,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Camera Scanner',
                      style: TextStyle(
                        color: _scanMode == ScanMode.camera
                            ? _accent
                            : _textBright,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: ScanMode.photo,
                child: Row(
                  children: [
                    Icon(
                      Icons.camera_alt,
                      color: _scanMode == ScanMode.photo
                          ? _accent
                          : _textBright,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Photo Capture',
                      style: TextStyle(
                        color: _scanMode == ScanMode.photo
                            ? _accent
                            : _textBright,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: ScanMode.external,
                child: Row(
                  children: [
                    Icon(
                      Icons.keyboard,
                      color: _scanMode == ScanMode.external
                          ? _accent
                          : _textBright,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'External Scanner',
                      style: TextStyle(
                        color: _scanMode == ScanMode.external
                            ? _accent
                            : _textBright,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    switch (_scanMode) {
      case ScanMode.camera:
        return _buildScannerMode();
      case ScanMode.photo:
        return _buildPhotoMode();
      case ScanMode.external:
        return _buildExternalMode();
    }
  }

  Widget _buildScannerMode() {
    return Stack(
      children: [
        MobileScanner(controller: _scannerController, onDetect: _onDetect),
        CustomPaint(size: Size.infinite, painter: _ScannerOverlayPainter()),
        Center(
          child: Container(
            width: 280,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _accent.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _accent.withValues(alpha: 0.08),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Stack(
              children: [
                _cornerBracket(Alignment.topLeft, -1, -1),
                _cornerBracket(Alignment.topRight, 1, -1),
                _cornerBracket(Alignment.bottomLeft, -1, 1),
                _cornerBracket(Alignment.bottomRight, 1, 1),
                AnimatedBuilder(
                  animation: _animCtrl,
                  builder: (context, _) {
                    return Positioned(
                      left: 12,
                      right: 12,
                      top: 12 + (_animCtrl.value * (200 - 24)),
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _accent.withValues(alpha: 0),
                              _accent,
                              _accent.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 12,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _accentSoft.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Align barcode within frame',
                        style: TextStyle(
                          color: _accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoMode() {
    if (!_cameraReady || _cameraController == null) {
      return const Center(child: CircularProgressIndicator(color: _accent));
    }
    return Stack(
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: _cameraController!.value.aspectRatio,
            child: CameraPreview(_cameraController!),
          ),
        ),
        Center(
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white38, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExternalMode() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: 400,
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _extActive
                        ? const Color(0xFF0A2E1A)
                        : const Color(0xFF1C2128),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.bluetooth_connected,
                    size: 48,
                    color: _extActive ? const Color(0xFF58C4A6) : _textDim,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _extActive ? const Color(0xFF58C4A6) : _textDim,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _extStatus,
                      style: TextStyle(
                        color: _extActive ? const Color(0xFF58C4A6) : _textDim,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Use a Bluetooth or USB barcode scanner paired with your device',
                  style: TextStyle(color: _textDim, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _extCtrl,
                  focusNode: _extFocusNode,
                  autofocus: true,
                  style: const TextStyle(color: _textBright, fontSize: 18),
                  decoration: InputDecoration(
                    hintText: 'Barcode will appear here...',
                    hintStyle: TextStyle(
                      color: _textDim.withValues(alpha: 0.5),
                    ),
                    prefixIcon: const Icon(Icons.qr_code, color: _textDim),
                    filled: true,
                    fillColor: const Color(0xFF0D1117),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Color(0xFF58C4A6),
                        width: 2,
                      ),
                    ),
                  ),
                  onSubmitted: _onExtBarcode,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 12),
                Text(
                  _selectedDevice != null
                      ? 'Scanner ready — point at a barcode'
                      : 'Select a device below, then point your scanner at a barcode',
                  style: TextStyle(
                    color: _textDim.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _showDevicePicker,
                    icon: _scanningDevices
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _textDim,
                            ),
                          )
                        : Icon(
                            Icons.bluetooth_searching,
                            color: _textDim,
                            size: 18,
                          ),
                    label: Text(
                      _selectedDevice != null
                          ? (_selectedDevice!.name ?? _selectedDevice!.address)
                          : 'Select Bluetooth Device',
                      style: TextStyle(color: _textDim, fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _textDim.withValues(alpha: 0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    switch (_scanMode) {
      case ScanMode.camera:
        return _buildScannerBottomBar();
      case ScanMode.photo:
        return _buildPhotoBottomBar();
      case ScanMode.external:
        return const SizedBox.shrink();
    }
  }

  Widget _buildScannerBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_surfaceColor.withValues(alpha: 0.95), _surfaceColor],
        ),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ctrlButton(
              icon: ValueListenableBuilder(
                valueListenable: _scannerController,
                builder: (_, state, __) {
                  final on = state.torchState == TorchState.on;
                  return Icon(
                    on ? Icons.flash_on : Icons.flash_off,
                    color: _textBright,
                  );
                },
              ),
              label: 'Flash',
              onTap: () => _scannerController.toggleTorch(),
            ),
            _ctrlButton(
              icon: const Icon(Icons.keyboard, color: _textBright),
              label: 'Manual',
              onTap: _manualEntry,
            ),
            _ctrlButton(
              icon: const Icon(Icons.cameraswitch, color: _textBright),
              label: 'Flip',
              onTap: () => _scannerController.switchCamera(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_surfaceColor.withValues(alpha: 0.95), _surfaceColor],
        ),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ctrlButton(
              icon: const Icon(Icons.cameraswitch, color: _textBright),
              label: 'Flip',
              onTap: _switchPhotoCamera,
            ),
            GestureDetector(
              onTap: _capturePhoto,
              child: Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.black,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }

  Widget _ctrlButton({
    required Widget icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _textBright.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: icon,
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: _textDim, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _cornerBracket(Alignment align, double dx, double dy) {
    return Align(
      alignment: align,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            border: Border(
              top: dy < 0
                  ? const BorderSide(color: _accent, width: 3)
                  : BorderSide.none,
              bottom: dy > 0
                  ? const BorderSide(color: _accent, width: 3)
                  : BorderSide.none,
              left: dx < 0
                  ? const BorderSide(color: _accent, width: 3)
                  : BorderSide.none,
              right: dx > 0
                  ? const BorderSide(color: _accent, width: 3)
                  : BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x99000000);
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: 280,
      height: 200,
    );
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.largest),
        Path()
          ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(20))),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
