import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _ready = false;
  bool _flashOn = false;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _controller?.dispose();
      _controller = null;
      _ready = false;
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No camera available')),
          );
          Navigator.of(context).pop();
        }
        return;
      }
      final controller = CameraController(cameras[0], ResolutionPreset.medium);
      await controller.initialize();
      if (_flashOn) {
        await controller.setFlashMode(FlashMode.torch);
      }
      if (mounted) {
        setState(() {
          _cameras = cameras;
          _controller = controller;
          _ready = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _capture() async {
    if (_controller == null || !_controller!.value.isInitialized || _capturing) return;
    setState(() => _capturing = true);
    try {
      if (_flashOn) {
        await _controller!.setFlashMode(FlashMode.always);
      }
      final file = await _controller!.takePicture();
      if (mounted) {
        setState(() => _capturing = false);
        Navigator.of(context).pop(file.path);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _capturing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture error: $e')),
        );
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;
    final idx = _cameras!.indexOf(_controller!.description);
    final next = (idx + 1) % _cameras!.length;
    try {
      final newController = CameraController(_cameras![next], ResolutionPreset.medium);
      await newController.initialize();
      if (_flashOn) {
        await newController.setFlashMode(FlashMode.torch);
      }
      final old = _controller;
      if (mounted) {
        setState(() {
          _controller = newController;
        });
      }
      await old?.dispose();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Switch camera error: $e')),
        );
      }
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final newMode = !_flashOn;
    try {
      await _controller!.setFlashMode(
        newMode ? FlashMode.torch : FlashMode.off,
      );
      _flashOn = newMode;
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Flash error: $e')),
        );
      }
    }
  }

  void _showExitDialog() {
    showDialog<bool>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard photo?'),
        content: const Text(
          'Do you want to exit without capturing a photo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    ).then((result) {
      if (result == true && mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _showExitDialog();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('Capture Photo'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _showExitDialog,
          ),
        ),
      body: _ready && _controller != null && _controller!.value.isInitialized
          ? Stack(
              children: [
                ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller!.value.previewSize!.height,
                        height: _controller!.value.previewSize!.width,
                        child: CameraPreview(_controller!),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white54, width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: const BoxDecoration(
          color: Colors.black,
          border: Border(top: BorderSide(color: Colors.white12)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              GestureDetector(
                onTap: _switchCamera,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cameraswitch,
                      color: Colors.white, size: 24),
                ),
              ),
              GestureDetector(
                onTap: _capturing ? null : _capture,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: _capturing ? 0.5 : 1.0,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _capturing ? Colors.grey.shade300 : Colors.white,
                    ),
                    child: _capturing
                        ? const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Colors.black54,
                            ),
                          )
                        : const Icon(Icons.camera_alt,
                            color: Colors.black, size: 32),
                  ),
                ),
              ),
              GestureDetector(
                onTap: _toggleFlash,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _flashOn
                        ? Colors.amber.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _flashOn ? Icons.flash_on : Icons.flash_off,
                    color: _flashOn ? Colors.amber : Colors.white,
                    size: 24,
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
}
